module TrueType
  module Tables
    module CFF
      # CFF2 CharString interpreter with blend operator support.
      # Extends the CFF1 interpreter with variable font interpolation.
      class CFF2CharstringInterpreter
        include IOHelpers

        # Variation store for computing blend deltas
        @variation_store : Variations::ItemVariationStore?

        # Normalized variation coordinates
        @normalized_coords : Array(Float64)?

        # Current vsindex (variation store index) from Private DICT
        @vsindex : UInt16

        # Region scalars for current vsindex (cached)
        @region_scalars : Array(Float64)?

        def initialize(
          @variation_store : Variations::ItemVariationStore? = nil,
          @normalized_coords : Array(Float64)? = nil,
          @vsindex : UInt16 = 0
        )
          @stack = [] of Float64
          @current_contour = [] of OutlinePoint
          @contours = [] of Contour
          @x = 0.0
          @y = 0.0
        end

        def execute(data : Bytes) : GlyphOutline
          reset_state
          return GlyphOutline.new if data.empty?

          # Pre-compute region scalars if we have variation data
          compute_region_scalars

          io = IO::Memory.new(data)

          while io.pos < data.size
            op = read_uint8(io)

            case op
            when 4
              # vmoveto
              finish_contour
              @y += pop_number
              move_to
            when 5
              # rlineto
              while @stack.size >= 2
                @x += pop_number
                @y += pop_number
                line_to
              end
            when 6
              # hlineto
              while @stack.size >= 1
                @x += pop_number
                line_to
                break if @stack.empty?
                @y += pop_number
                line_to
              end
            when 7
              # vlineto
              while @stack.size >= 1
                @y += pop_number
                line_to
                break if @stack.empty?
                @x += pop_number
                line_to
              end
            when 8
              # rrcurveto
              while @stack.size >= 6
                curve_to(pop_number, pop_number, pop_number, pop_number, pop_number, pop_number)
              end
            when 14
              # endchar
              finish_contour
              break
            when 15
              # CFF2: vsindex - set variation store index
              @vsindex = pop_number.to_u16
              compute_region_scalars
            when 16
              # CFF2: blend operator
              handle_blend
            when 21
              # rmoveto
              finish_contour
              @x += pop_number
              @y += pop_number
              move_to
            when 22
              # hmoveto
              finish_contour
              @x += pop_number
              move_to
            when 24
              # rcurveline
              while @stack.size >= 8
                curve_to(pop_number, pop_number, pop_number, pop_number, pop_number, pop_number)
              end
              if @stack.size >= 2
                @x += pop_number
                @y += pop_number
                line_to
              end
            when 25
              # rlinecurve
              while @stack.size >= 8
                @x += pop_number
                @y += pop_number
                line_to
              end
              if @stack.size >= 6
                curve_to(pop_number, pop_number, pop_number, pop_number, pop_number, pop_number)
              end
            when 26
              # vvcurveto
              if @stack.size.odd?
                @x += pop_number
              end
              while @stack.size >= 4
                curve_to(0, pop_number, pop_number, pop_number, 0, pop_number)
              end
            when 27
              # hhcurveto
              if @stack.size.odd?
                @y += pop_number
              end
              while @stack.size >= 4
                curve_to(pop_number, 0, pop_number, pop_number, pop_number, 0)
              end
            when 28
              @stack << read_int16(io).to_f64
            when 30
              # vhcurveto
              while @stack.size >= 4
                if (@stack.size // 4).even?
                  curve_to(0, pop_number, pop_number, pop_number, pop_number, 0)
                else
                  curve_to(pop_number, 0, pop_number, pop_number, 0, pop_number)
                end
              end
            when 31
              # hvcurveto
              while @stack.size >= 4
                if (@stack.size // 4).even?
                  curve_to(pop_number, 0, pop_number, pop_number, 0, pop_number)
                else
                  curve_to(0, pop_number, pop_number, pop_number, pop_number, 0)
                end
              end
            when 32..246
              @stack << (op.to_i32 - 139).to_f64
            when 247..250
              b1 = read_uint8(io)
              @stack << ((op.to_i32 - 247) * 256 + b1.to_i32 + 108).to_f64
            when 251..254
              b1 = read_uint8(io)
              @stack << (-(op.to_i32 - 251) * 256 - b1.to_i32 - 108).to_f64
            when 255
              value = read_int32(io)
              @stack << (value.to_f64 / 65536.0)
            else
              # Unsupported operator; clear stack to keep parser moving
              @stack.clear
            end
          end

          build_outline
        end

        # Handle the blend operator (operator 16)
        # Stack: n(0) .. n(k-1) d(0,0) .. d(k-1,0) ... d(0,r-1) .. d(k-1,r-1) numBlends blend
        # Result: v(0) .. v(k-1)
        # Where v(i) = n(i) + sum(d(i,j) * scalar(j))
        private def handle_blend
          return if @stack.empty?

          # Number of blend operands
          num_blends = @stack.pop.to_i
          return if num_blends <= 0

          # Get region count from variation store
          region_count = @region_scalars.try(&.size) || 0

          # Total items needed: k base values + k * r deltas
          # k = num_blends, r = region_count
          k = num_blends
          total_needed = k * (1 + region_count)

          return if @stack.size < total_needed

          # Apply blend if we have variation data
          if region_count > 0 && @region_scalars
            scalars = @region_scalars.not_nil!

            # Process each operand
            k.times do |i|
              # Base value is at stack[i]
              base_idx = @stack.size - total_needed + i
              base_value = @stack[base_idx]

              # Apply deltas
              delta_total = 0.0
              region_count.times do |r|
                delta_idx = @stack.size - total_needed + k + i * region_count + r
                delta_total += @stack[delta_idx] * scalars[r]
              end

              @stack[base_idx] = base_value + delta_total
            end
          end

          # Remove delta values, keep only blended base values
          delta_count = k * region_count
          delta_count.times { @stack.pop }
        end

        # Compute region scalars for current vsindex
        private def compute_region_scalars
          return unless vstore = @variation_store
          return unless coords = @normalized_coords

          @region_scalars = vstore.compute_scalars(@vsindex, coords)
        end

        private def reset_state
          @stack.clear
          @current_contour.clear
          @contours.clear
          @x = 0.0
          @y = 0.0
        end

        private def pop_number : Float64
          @stack.shift? || 0.0
        end

        private def move_to
          @current_contour << OutlinePoint.on_curve(@x.round.to_i16, @y.round.to_i16)
        end

        private def line_to
          @current_contour << OutlinePoint.on_curve(@x.round.to_i16, @y.round.to_i16)
        end

        private def curve_to(dx1 : Float64, dy1 : Float64, dx2 : Float64, dy2 : Float64, dx3 : Float64, dy3 : Float64)
          x1 = @x + dx1
          y1 = @y + dy1
          x2 = x1 + dx2
          y2 = y1 + dy2
          x3 = x2 + dx3
          y3 = y2 + dy3

          @current_contour << OutlinePoint.cubic_control(x1.round.to_i16, y1.round.to_i16)
          @current_contour << OutlinePoint.cubic_control(x2.round.to_i16, y2.round.to_i16)
          @current_contour << OutlinePoint.on_curve(x3.round.to_i16, y3.round.to_i16)

          @x = x3
          @y = y3
        end

        private def finish_contour
          return if @current_contour.empty?
          @contours << Contour.new(@current_contour.dup)
          @current_contour.clear
        end

        private def build_outline : GlyphOutline
          points = @contours.flat_map(&.points)
          if points.empty?
            GlyphOutline.new
          else
            x_min = points.min_of(&.x)
            y_min = points.min_of(&.y)
            x_max = points.max_of(&.x)
            y_max = points.max_of(&.y)
            GlyphOutline.new(@contours.dup, x_min, y_min, x_max, y_max)
          end
        end

        extend IOHelpers
      end
    end
  end
end
