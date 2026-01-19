module TrueType
  # Extracts glyph outlines from TrueType font data
  class OutlineExtractor
    include IOHelpers

    # Simple glyph flags
    module SimpleFlags
      ON_CURVE_POINT              = 0x01_u8
      X_SHORT_VECTOR              = 0x02_u8
      Y_SHORT_VECTOR              = 0x04_u8
      REPEAT_FLAG                 = 0x08_u8
      X_IS_SAME_OR_POSITIVE_SHORT = 0x10_u8
      Y_IS_SAME_OR_POSITIVE_SHORT = 0x20_u8
      OVERLAP_SIMPLE              = 0x40_u8
    end

    # Extract outline from a simple glyph (not composite)
    def self.extract_simple(glyph_data : Tables::GlyphData) : GlyphOutline
      return empty_outline(glyph_data) if glyph_data.empty?
      return empty_outline(glyph_data) if glyph_data.number_of_contours <= 0

      data = glyph_data.raw_data
      return empty_outline(glyph_data) if data.empty?

      io = IO::Memory.new(data)
      num_contours = glyph_data.number_of_contours.to_i32

      # Read end points of contours
      end_points = Array(UInt16).new(num_contours)
      num_contours.times do
        end_points << read_uint16(io)
      end

      # Calculate total number of points
      num_points = end_points.last.to_i32 + 1

      # Read instruction length and skip instructions
      instruction_length = read_uint16(io)
      io.skip(instruction_length.to_i32)

      # Read flags
      flags = Array(UInt8).new(num_points, 0_u8)
      i = 0
      while i < num_points
        flag = read_uint8(io)
        flags[i] = flag
        i += 1

        # Handle repeat flag
        if (flag & SimpleFlags::REPEAT_FLAG) != 0
          repeat_count = read_uint8(io).to_i32
          repeat_count.times do
            break if i >= num_points
            flags[i] = flag
            i += 1
          end
        end
      end

      # Read X coordinates
      x_coords = Array(Int16).new(num_points, 0_i16)
      x = 0_i16
      num_points.times do |idx|
        flag = flags[idx]
        if (flag & SimpleFlags::X_SHORT_VECTOR) != 0
          delta = read_uint8(io).to_i16
          if (flag & SimpleFlags::X_IS_SAME_OR_POSITIVE_SHORT) != 0
            x += delta
          else
            x -= delta
          end
        elsif (flag & SimpleFlags::X_IS_SAME_OR_POSITIVE_SHORT) == 0
          x += read_int16(io)
        end
        # If X_IS_SAME_OR_POSITIVE_SHORT is set and X_SHORT_VECTOR is not, x stays the same
        x_coords[idx] = x
      end

      # Read Y coordinates
      y_coords = Array(Int16).new(num_points, 0_i16)
      y = 0_i16
      num_points.times do |idx|
        flag = flags[idx]
        if (flag & SimpleFlags::Y_SHORT_VECTOR) != 0
          delta = read_uint8(io).to_i16
          if (flag & SimpleFlags::Y_IS_SAME_OR_POSITIVE_SHORT) != 0
            y += delta
          else
            y -= delta
          end
        elsif (flag & SimpleFlags::Y_IS_SAME_OR_POSITIVE_SHORT) == 0
          y += read_int16(io)
        end
        # If Y_IS_SAME_OR_POSITIVE_SHORT is set and Y_SHORT_VECTOR is not, y stays the same
        y_coords[idx] = y
      end

      # Build contours
      contours = [] of Contour
      start_point = 0
      end_points.each do |end_point|
        contour = Contour.new
        (start_point..end_point.to_i32).each do |pt_idx|
          flag = flags[pt_idx]
          point_type = (flag & SimpleFlags::ON_CURVE_POINT) != 0 ? PointType::OnCurve : PointType::QuadraticControl
          contour.add(OutlinePoint.new(x_coords[pt_idx], y_coords[pt_idx], point_type))
        end
        contours << contour unless contour.empty?
        start_point = end_point.to_i32 + 1
      end

      GlyphOutline.new(
        contours,
        glyph_data.x_min,
        glyph_data.y_min,
        glyph_data.x_max,
        glyph_data.y_max,
        composite: false
      )
    rescue ex
      # Return empty outline on parse error
      empty_outline(glyph_data)
    end

    # A component of a composite glyph with its transformation
    record CompositeComponent,
      glyph_id : UInt16,
      flags : UInt16,
      arg1 : Int32,
      arg2 : Int32,
      a : Float64,
      b : Float64,
      c : Float64,
      d : Float64

    # Parse composite glyph components
    def self.parse_composite_components(glyph_data : Tables::GlyphData) : Array(CompositeComponent)
      return [] of CompositeComponent unless glyph_data.composite?

      data = glyph_data.raw_data
      return [] of CompositeComponent if data.empty?

      io = IO::Memory.new(data)
      components = [] of CompositeComponent

      loop do
        break if io.pos + 4 > data.size

        flags = read_uint16(io)
        glyph_id = read_uint16(io)

        # Read arguments (offsets or point numbers)
        arg1, arg2 = if (flags & Tables::GlyphFlags::ARG_1_AND_2_ARE_WORDS) != 0
                       {read_int16(io).to_i32, read_int16(io).to_i32}
                     else
                       bytes = read_bytes(io, 2)
                       if (flags & Tables::GlyphFlags::ARGS_ARE_XY_VALUES) != 0
                         {bytes[0].to_i8.to_i32, bytes[1].to_i8.to_i32}
                       else
                         {bytes[0].to_i32, bytes[1].to_i32}
                       end
                     end

        # Read transformation matrix components
        a = 1.0
        b = 0.0
        c = 0.0
        d = 1.0

        if (flags & Tables::GlyphFlags::WE_HAVE_A_SCALE) != 0
          scale = read_f2dot14(io)
          a = scale
          d = scale
        elsif (flags & Tables::GlyphFlags::WE_HAVE_AN_X_AND_Y_SCALE) != 0
          a = read_f2dot14(io)
          d = read_f2dot14(io)
        elsif (flags & Tables::GlyphFlags::WE_HAVE_A_TWO_BY_TWO) != 0
          a = read_f2dot14(io)
          b = read_f2dot14(io)
          c = read_f2dot14(io)
          d = read_f2dot14(io)
        end

        components << CompositeComponent.new(glyph_id, flags, arg1, arg2, a, b, c, d)

        break unless (flags & Tables::GlyphFlags::MORE_COMPONENTS) != 0
      end

      components
    rescue
      [] of CompositeComponent
    end

    # Read F2Dot14 fixed-point number
    private def self.read_f2dot14(io : IO) : Float64
      value = read_int16(io)
      value.to_f64 / 16384.0
    end

    # Create an empty outline with the glyph's bounding box
    private def self.empty_outline(glyph_data : Tables::GlyphData) : GlyphOutline
      GlyphOutline.new(
        [] of Contour,
        glyph_data.x_min,
        glyph_data.y_min,
        glyph_data.x_max,
        glyph_data.y_max,
        composite: glyph_data.composite?
      )
    end

    extend IOHelpers
  end
end
