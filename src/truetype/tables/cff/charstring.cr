module TrueType
  module Tables
    module CFF
      # Minimal Type 2 CharString interpreter (move/line/curve)
      class CharstringInterpreter
        include IOHelpers

        def initialize
          @stack = [] of Float64
          @current_contour = [] of OutlinePoint
          @contours = [] of Contour
          @x = 0.0
          @y = 0.0
        end

        def execute(data : Bytes) : GlyphOutline
          reset_state
          return GlyphOutline.new if data.empty?

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
            when 28
              @stack << read_int16(io).to_f64
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
