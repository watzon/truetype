module TrueType
  # WOFF2 glyf/loca table transform decoder
  # Implements the W3C WOFF2 specification section 5.1-5.3
  # https://www.w3.org/TR/WOFF2/#glyf_table_format
  class Woff2GlyfTransform
    include IOHelpers

    # Transform header format (36 bytes):
    # - version: UInt16 (must be 0)
    # - optionFlags: UInt16 (bit 0: overlapSimpleBitmap present)
    # - numGlyphs: UInt16
    # - indexFormat: UInt16 (0=short loca, 1=long loca)
    # - nContourStreamSize: UInt32
    # - nPointsStreamSize: UInt32
    # - flagStreamSize: UInt32
    # - glyphStreamSize: UInt32
    # - compositeStreamSize: UInt32
    # - bboxStreamSize: UInt32
    # - instructionStreamSize: UInt32
    # Total: 4*UInt16 + 7*UInt32 = 8 + 28 = 36 bytes
    HEADER_SIZE = 36

    # Option flags
    OVERLAP_SIMPLE_BITMAP_FLAG = 0x0001_u16

    # Simple glyph flags for output
    GLYF_ON_CURVE      = 0x01_u8
    GLYF_X_SHORT       = 0x02_u8
    GLYF_Y_SHORT       = 0x04_u8
    GLYF_REPEAT        = 0x08_u8
    GLYF_THIS_X_IS_SAME = 0x10_u8
    GLYF_THIS_Y_IS_SAME = 0x20_u8
    GLYF_OVERLAP_SIMPLE = 0x40_u8

    # Composite glyph flags
    FLAG_ARG_1_AND_2_ARE_WORDS   = 0x0001_u16
    FLAG_WE_HAVE_A_SCALE         = 0x0008_u16
    FLAG_MORE_COMPONENTS         = 0x0020_u16
    FLAG_WE_HAVE_AN_X_AND_Y_SCALE = 0x0040_u16
    FLAG_WE_HAVE_A_TWO_BY_TWO    = 0x0080_u16
    FLAG_WE_HAVE_INSTRUCTIONS    = 0x0100_u16

    # Point structure for decoded coordinates
    struct Point
      property x : Int32
      property y : Int32
      property on_curve : Bool

      def initialize(@x = 0, @y = 0, @on_curve = true)
      end
    end

    # Header fields
    getter version : UInt16 = 0
    getter option_flags : UInt16 = 0
    getter num_glyphs : UInt16 = 0
    getter index_format : UInt16 = 0

    # Stream sizes
    getter n_contour_stream_size : UInt32 = 0
    getter n_points_stream_size : UInt32 = 0
    getter flag_stream_size : UInt32 = 0
    getter glyph_stream_size : UInt32 = 0
    getter composite_stream_size : UInt32 = 0
    getter bbox_stream_size : UInt32 = 0
    getter instruction_stream_size : UInt32 = 0

    # Streams (as byte slices)
    @n_contour_stream : Bytes = Bytes.empty
    @n_points_stream : Bytes = Bytes.empty
    @flag_stream : Bytes = Bytes.empty
    @glyph_stream : Bytes = Bytes.empty
    @composite_stream : Bytes = Bytes.empty
    @bbox_stream : Bytes = Bytes.empty
    @instruction_stream : Bytes = Bytes.empty
    @overlap_simple_bitmap : Bytes = Bytes.empty

    # Parsed data
    @n_contours : Array(Int16) = [] of Int16
    @bbox_bitmap : Bytes = Bytes.empty
    @bbox_data : Bytes = Bytes.empty

    # Stream offsets for consumption during reconstruction
    @n_points_offset : Int32 = 0
    @flag_offset : Int32 = 0
    @glyph_offset : Int32 = 0
    @composite_offset : Int32 = 0
    @bbox_offset : Int32 = 0
    @instruction_offset : Int32 = 0

    def initialize
    end

    # Reconstruct glyf and loca tables from transformed WOFF2 data
    # Returns {glyf_data, loca_data}
    def reconstruct(data : Bytes) : Tuple(Bytes, Bytes)
      raise ParseError.new("Transform data too small") if data.size < HEADER_SIZE

      io = IO::Memory.new(data)
      parse_header(io)

      # Validate header
      raise ParseError.new("Invalid transform version: #{@version}") if @version != 0

      # Extract all substreams
      extract_streams(data)

      # Parse nContour stream (array of Int16, big-endian)
      parse_n_contour_stream

      # Split bbox stream into bitmap + data
      split_bbox_stream

      # Reconstruct each glyph
      glyf_io = IO::Memory.new
      loca_values = [] of UInt32

      @num_glyphs.times do |glyph_id|
        loca_values << glyf_io.pos.to_u32
        reconstruct_glyph(glyph_id.to_u16, glyf_io)

        # Pad to 4-byte boundary (optional but recommended)
        pad_to_boundary(glyf_io, 4)
      end

      # Final loca entry = total glyf size
      loca_values << glyf_io.pos.to_u32

      glyf_data = glyf_io.to_slice

      # Build loca table
      loca_data = build_loca(loca_values)

      {glyf_data, loca_data}
    end

    private def parse_header(io : IO) : Nil
      @version = read_uint16(io)
      @option_flags = read_uint16(io)
      @num_glyphs = read_uint16(io)
      @index_format = read_uint16(io)
      @n_contour_stream_size = read_uint32(io)
      @n_points_stream_size = read_uint32(io)
      @flag_stream_size = read_uint32(io)
      @glyph_stream_size = read_uint32(io)
      @composite_stream_size = read_uint32(io)
      @bbox_stream_size = read_uint32(io)
      @instruction_stream_size = read_uint32(io)
    end

    private def extract_streams(data : Bytes) : Nil
      offset = HEADER_SIZE

      # Extract each stream based on sizes from header
      @n_contour_stream = extract_stream(data, offset, @n_contour_stream_size)
      offset += @n_contour_stream_size.to_i

      @n_points_stream = extract_stream(data, offset, @n_points_stream_size)
      offset += @n_points_stream_size.to_i

      @flag_stream = extract_stream(data, offset, @flag_stream_size)
      offset += @flag_stream_size.to_i

      @glyph_stream = extract_stream(data, offset, @glyph_stream_size)
      offset += @glyph_stream_size.to_i

      @composite_stream = extract_stream(data, offset, @composite_stream_size)
      offset += @composite_stream_size.to_i

      @bbox_stream = extract_stream(data, offset, @bbox_stream_size)
      offset += @bbox_stream_size.to_i

      @instruction_stream = extract_stream(data, offset, @instruction_stream_size)
      offset += @instruction_stream_size.to_i

      # Optional overlapSimpleBitmap
      if (@option_flags & OVERLAP_SIMPLE_BITMAP_FLAG) != 0
        overlap_size = (@num_glyphs.to_i + 7) >> 3
        @overlap_simple_bitmap = extract_stream(data, offset, overlap_size.to_u32)
      end
    end

    private def extract_stream(data : Bytes, offset : Int32, size : UInt32) : Bytes
      return Bytes.empty if size == 0
      end_offset = offset + size.to_i
      raise ParseError.new("Stream extends beyond data") if end_offset > data.size
      data[offset, size.to_i]
    end

    private def parse_n_contour_stream : Nil
      @n_contours = Array(Int16).new(@num_glyphs.to_i)
      io = IO::Memory.new(@n_contour_stream)

      @num_glyphs.times do
        @n_contours << read_int16(io)
      end
    end

    private def split_bbox_stream : Nil
      # bboxBitmap size: ((numGlyphs + 31) >> 5) << 2 bytes (4-byte aligned)
      bitmap_size = ((@num_glyphs.to_i + 31) >> 5) << 2
      @bbox_bitmap = @bbox_stream[0, bitmap_size]
      @bbox_data = @bbox_stream[bitmap_size..]
    end

    private def reconstruct_glyph(glyph_id : UInt16, output : IO) : Nil
      n_contours = @n_contours[glyph_id.to_i]

      if n_contours == 0
        # Empty glyph - no data
        return
      elsif n_contours < 0
        # Composite glyph
        reconstruct_composite_glyph(glyph_id, output)
      else
        # Simple glyph
        reconstruct_simple_glyph(glyph_id, n_contours.to_u16, output)
      end
    end

    private def reconstruct_simple_glyph(glyph_id : UInt16, n_contours : UInt16, output : IO) : Nil
      # Read number of points per contour
      n_points_per_contour = [] of UInt16
      total_points = 0_u32

      n_contours.times do
        pts = read_255_ushort
        n_points_per_contour << pts
        total_points += pts.to_u32
      end

      # Read point flags and decode triplets
      raise ParseError.new("Not enough flag data") if @flag_offset + total_points.to_i > @flag_stream.size

      flags = @flag_stream[@flag_offset, total_points.to_i]
      @flag_offset += total_points.to_i

      points = decode_triplets(flags, total_points)

      # Read instruction length
      instruction_length = read_255_ushort_from_glyph_stream

      # Check for explicit bbox
      has_bbox = has_explicit_bbox?(glyph_id)

      # Compute or read bounding box
      x_min, y_min, x_max, y_max = if has_bbox
        read_explicit_bbox
      else
        compute_bbox(points)
      end

      # Read instructions
      instructions = read_instructions(instruction_length)

      # Check overlap simple flag
      has_overlap = has_overlap_simple?(glyph_id)

      # Write glyph data
      write_simple_glyph(output, n_contours, x_min, y_min, x_max, y_max,
                         n_points_per_contour, points, instructions, has_overlap)
    end

    private def reconstruct_composite_glyph(glyph_id : UInt16, output : IO) : Nil
      # Composite glyphs MUST have explicit bbox
      raise ParseError.new("Composite glyph #{glyph_id} missing bbox") unless has_explicit_bbox?(glyph_id)

      x_min, y_min, x_max, y_max = read_explicit_bbox

      # Read composite data
      composite_data, have_instructions = read_composite_data
      instruction_length = 0_u16
      instructions = Bytes.empty

      if have_instructions
        instruction_length = read_255_ushort_from_glyph_stream
        instructions = read_instructions(instruction_length)
      end

      # Write composite glyph
      write_composite_glyph(output, x_min, y_min, x_max, y_max,
                           composite_data, instruction_length, instructions)
    end

    # Read 255UInt16 from nPoints stream
    private def read_255_ushort : UInt16
      raise ParseError.new("nPoints stream exhausted") if @n_points_offset >= @n_points_stream.size

      code = @n_points_stream[@n_points_offset]
      @n_points_offset += 1

      case code
      when 253 # wordCode
        raise ParseError.new("nPoints stream exhausted") if @n_points_offset + 1 >= @n_points_stream.size
        high = @n_points_stream[@n_points_offset].to_u16
        low = @n_points_stream[@n_points_offset + 1].to_u16
        @n_points_offset += 2
        (high << 8) | low
      when 254 # oneMoreByteCode2
        raise ParseError.new("nPoints stream exhausted") if @n_points_offset >= @n_points_stream.size
        value = @n_points_stream[@n_points_offset].to_u16
        @n_points_offset += 1
        value + 506 # 253 * 2
      when 255 # oneMoreByteCode1
        raise ParseError.new("nPoints stream exhausted") if @n_points_offset >= @n_points_stream.size
        value = @n_points_stream[@n_points_offset].to_u16
        @n_points_offset += 1
        value + 253
      else
        code.to_u16
      end
    end

    # Read 255UInt16 from glyph stream (for instruction length)
    private def read_255_ushort_from_glyph_stream : UInt16
      raise ParseError.new("glyph stream exhausted") if @glyph_offset >= @glyph_stream.size

      code = @glyph_stream[@glyph_offset]
      @glyph_offset += 1

      case code
      when 253 # wordCode
        raise ParseError.new("glyph stream exhausted") if @glyph_offset + 1 >= @glyph_stream.size
        high = @glyph_stream[@glyph_offset].to_u16
        low = @glyph_stream[@glyph_offset + 1].to_u16
        @glyph_offset += 2
        (high << 8) | low
      when 254 # oneMoreByteCode2
        raise ParseError.new("glyph stream exhausted") if @glyph_offset >= @glyph_stream.size
        value = @glyph_stream[@glyph_offset].to_u16
        @glyph_offset += 1
        value + 506 # 253 * 2
      when 255 # oneMoreByteCode1
        raise ParseError.new("glyph stream exhausted") if @glyph_offset >= @glyph_stream.size
        value = @glyph_stream[@glyph_offset].to_u16
        @glyph_offset += 1
        value + 253
      else
        code.to_u16
      end
    end

    # Decode triplet-encoded coordinates
    private def decode_triplets(flags : Bytes, n_points : UInt32) : Array(Point)
      points = Array(Point).new(n_points.to_i)
      x = 0
      y = 0

      triplet_data = @glyph_stream[@glyph_offset..]
      triplet_index = 0

      n_points.times do |i|
        flag = flags[i]
        on_curve = (flag & 0x80) == 0
        flag_value = flag & 0x7F

        # Determine number of bytes and decode dx, dy
        n_bytes, dx, dy = decode_triplet(flag_value, triplet_data, triplet_index)
        triplet_index += n_bytes

        x += dx
        y += dy
        points << Point.new(x, y, on_curve)
      end

      @glyph_offset += triplet_index
      points
    end

    # Decode a single triplet based on flag value
    # Returns {n_bytes, dx, dy}
    private def decode_triplet(flag : UInt8, data : Bytes, offset : Int32) : Tuple(Int32, Int32, Int32)
      # Determine number of bytes based on flag
      n_bytes = if flag < 84
        1
      elsif flag < 120
        2
      elsif flag < 124
        3
      else
        4
      end

      raise ParseError.new("Triplet data exhausted") if offset + n_bytes > data.size

      dx, dy = case flag
      when 0...10
        # dx = 0, dy from flag and one byte
        dy_val = with_sign(flag, ((flag & 14).to_i << 7) + data[offset].to_i)
        {0, dy_val}
      when 10...20
        # dy = 0, dx from flag and one byte
        dx_val = with_sign(flag, (((flag - 10) & 14).to_i << 7) + data[offset].to_i)
        {dx_val, 0}
      when 20...84
        # Both dx and dy from flag and one byte
        b0 = (flag - 20).to_i
        b1 = data[offset].to_i
        dx_val = with_sign(flag, 1 + (b0 & 0x30) + (b1 >> 4))
        dy_val = with_sign(flag >> 1, 1 + ((b0 & 0x0c) << 2) + (b1 & 0x0f))
        {dx_val, dy_val}
      when 84...120
        # dx and dy from flag and two bytes
        b0 = (flag - 84).to_i
        dx_val = with_sign(flag, 1 + ((b0 // 12) << 8) + data[offset].to_i)
        dy_val = with_sign(flag >> 1, 1 + (((b0 % 12) >> 2) << 8) + data[offset + 1].to_i)
        {dx_val, dy_val}
      when 120...124
        # dx from two bytes, dy from one byte (with nibble split)
        b2 = data[offset + 1].to_i
        dx_val = with_sign(flag, (data[offset].to_i << 4) + (b2 >> 4))
        dy_val = with_sign(flag >> 1, ((b2 & 0x0f) << 8) + data[offset + 2].to_i)
        {dx_val, dy_val}
      else # 124...128
        # dx and dy each from two bytes
        dx_val = with_sign(flag, (data[offset].to_i << 8) + data[offset + 1].to_i)
        dy_val = with_sign(flag >> 1, (data[offset + 2].to_i << 8) + data[offset + 3].to_i)
        {dx_val, dy_val}
      end

      {n_bytes, dx, dy}
    end

    # Apply sign based on flag bit
    private def with_sign(flag : UInt8, base_val : Int32) : Int32
      (flag & 1) != 0 ? base_val : -base_val
    end

    # Check if glyph has explicit bounding box
    private def has_explicit_bbox?(glyph_id : UInt16) : Bool
      byte_index = glyph_id.to_i >> 3
      bit_index = glyph_id.to_i & 7
      return false if byte_index >= @bbox_bitmap.size
      (@bbox_bitmap[byte_index] & (0x80 >> bit_index)) != 0
    end

    # Check if glyph has overlap simple flag
    private def has_overlap_simple?(glyph_id : UInt16) : Bool
      return false if @overlap_simple_bitmap.empty?
      byte_index = glyph_id.to_i >> 3
      bit_index = glyph_id.to_i & 7
      return false if byte_index >= @overlap_simple_bitmap.size
      (@overlap_simple_bitmap[byte_index] & (0x80 >> bit_index)) != 0
    end

    # Read explicit bounding box from bbox stream
    private def read_explicit_bbox : Tuple(Int16, Int16, Int16, Int16)
      raise ParseError.new("bbox data exhausted") if @bbox_offset + 8 > @bbox_data.size

      io = IO::Memory.new(@bbox_data[@bbox_offset, 8])
      x_min = read_int16(io)
      y_min = read_int16(io)
      x_max = read_int16(io)
      y_max = read_int16(io)
      @bbox_offset += 8

      {x_min, y_min, x_max, y_max}
    end

    # Compute bounding box from points
    private def compute_bbox(points : Array(Point)) : Tuple(Int16, Int16, Int16, Int16)
      return {0_i16, 0_i16, 0_i16, 0_i16} if points.empty?

      x_min = points[0].x
      y_min = points[0].y
      x_max = points[0].x
      y_max = points[0].y

      points.each do |pt|
        x_min = pt.x if pt.x < x_min
        y_min = pt.y if pt.y < y_min
        x_max = pt.x if pt.x > x_max
        y_max = pt.y if pt.y > y_max
      end

      {x_min.to_i16, y_min.to_i16, x_max.to_i16, y_max.to_i16}
    end

    # Read instructions from instruction stream
    private def read_instructions(length : UInt16) : Bytes
      return Bytes.empty if length == 0
      raise ParseError.new("instruction stream exhausted") if @instruction_offset + length.to_i > @instruction_stream.size

      result = @instruction_stream[@instruction_offset, length.to_i]
      @instruction_offset += length.to_i
      result
    end

    # Read composite glyph data from composite stream
    # Returns {data, have_instructions}
    private def read_composite_data : Tuple(Bytes, Bool)
      start_offset = @composite_offset
      have_instructions = false

      flags = FLAG_MORE_COMPONENTS
      while (flags & FLAG_MORE_COMPONENTS) != 0
        raise ParseError.new("composite stream exhausted") if @composite_offset + 4 > @composite_stream.size

        # Read flags
        io = IO::Memory.new(@composite_stream[@composite_offset, 2])
        flags = read_uint16(io)
        @composite_offset += 2

        have_instructions = true if (flags & FLAG_WE_HAVE_INSTRUCTIONS) != 0

        # Skip glyph index
        @composite_offset += 2

        # Skip arguments
        arg_size = if (flags & FLAG_ARG_1_AND_2_ARE_WORDS) != 0
          4
        else
          2
        end
        @composite_offset += arg_size

        # Skip transformation
        if (flags & FLAG_WE_HAVE_A_SCALE) != 0
          @composite_offset += 2
        elsif (flags & FLAG_WE_HAVE_AN_X_AND_Y_SCALE) != 0
          @composite_offset += 4
        elsif (flags & FLAG_WE_HAVE_A_TWO_BY_TWO) != 0
          @composite_offset += 8
        end
      end

      data = @composite_stream[start_offset, @composite_offset - start_offset]
      {data, have_instructions}
    end

    # Write a reconstructed simple glyph
    private def write_simple_glyph(
      output : IO,
      n_contours : UInt16,
      x_min : Int16, y_min : Int16, x_max : Int16, y_max : Int16,
      n_points_per_contour : Array(UInt16),
      points : Array(Point),
      instructions : Bytes,
      has_overlap : Bool
    ) : Nil
      # Write glyph header
      write_int16(output, n_contours.to_i16)
      write_int16(output, x_min)
      write_int16(output, y_min)
      write_int16(output, x_max)
      write_int16(output, y_max)

      # Write endPtsOfContours
      end_point = -1
      n_points_per_contour.each do |pts|
        end_point += pts.to_i
        write_uint16(output, end_point.to_u16)
      end

      # Write instruction length and instructions
      write_uint16(output, instructions.size.to_u16)
      output.write(instructions)

      # Encode and write flags and coordinates
      write_point_data(output, points, has_overlap)
    end

    # Write a reconstructed composite glyph
    private def write_composite_glyph(
      output : IO,
      x_min : Int16, y_min : Int16, x_max : Int16, y_max : Int16,
      composite_data : Bytes,
      instruction_length : UInt16,
      instructions : Bytes
    ) : Nil
      # Write glyph header (numberOfContours = -1 for composite)
      write_int16(output, -1_i16)
      write_int16(output, x_min)
      write_int16(output, y_min)
      write_int16(output, x_max)
      write_int16(output, y_max)

      # Write composite data
      output.write(composite_data)

      # Write instructions if present
      if instruction_length > 0
        write_uint16(output, instruction_length)
        output.write(instructions)
      end
    end

    # Encode and write point flags and coordinates
    private def write_point_data(output : IO, points : Array(Point), has_overlap : Bool) : Nil
      return if points.empty?

      # First pass: compute flags for each point
      flags = Array(UInt8).new(points.size)
      last_x = 0
      last_y = 0

      points.each do |pt|
        flag = pt.on_curve ? GLYF_ON_CURVE : 0_u8
        dx = pt.x - last_x
        dy = pt.y - last_y

        # X coordinate encoding
        if dx == 0
          flag |= GLYF_THIS_X_IS_SAME
        elsif dx.abs < 256
          flag |= GLYF_X_SHORT
          flag |= GLYF_THIS_X_IS_SAME if dx > 0
        end

        # Y coordinate encoding
        if dy == 0
          flag |= GLYF_THIS_Y_IS_SAME
        elsif dy.abs < 256
          flag |= GLYF_Y_SHORT
          flag |= GLYF_THIS_Y_IS_SAME if dy > 0
        end

        flags << flag
        last_x = pt.x
        last_y = pt.y
      end

      # Apply overlap simple flag to first point
      flags[0] |= GLYF_OVERLAP_SIMPLE if has_overlap && !flags.empty?

      # Write flags with run-length encoding
      i = 0
      while i < flags.size
        flag = flags[i]
        repeat_count = 0

        # Count consecutive identical flags
        while i + 1 + repeat_count < flags.size &&
              flags[i + 1 + repeat_count] == flag &&
              repeat_count < 255
          repeat_count += 1
        end

        if repeat_count > 0
          output.write_byte(flag | GLYF_REPEAT)
          output.write_byte(repeat_count.to_u8)
          i += 1 + repeat_count
        else
          output.write_byte(flag)
          i += 1
        end
      end

      # Write X coordinates
      last_x = 0
      points.each_with_index do |pt, idx|
        dx = pt.x - last_x
        flag = flags[idx]

        if (flag & GLYF_X_SHORT) != 0
          output.write_byte(dx.abs.to_u8)
        elsif dx != 0
          write_int16(output, dx.to_i16)
        end
        # If dx == 0 and X_SHORT is not set, nothing is written

        last_x = pt.x
      end

      # Write Y coordinates
      last_y = 0
      points.each_with_index do |pt, idx|
        dy = pt.y - last_y
        flag = flags[idx]

        if (flag & GLYF_Y_SHORT) != 0
          output.write_byte(dy.abs.to_u8)
        elsif dy != 0
          write_int16(output, dy.to_i16)
        end
        # If dy == 0 and Y_SHORT is not set, nothing is written

        last_y = pt.y
      end
    end

    # Build loca table from glyph offsets
    private def build_loca(loca_values : Array(UInt32)) : Bytes
      io = IO::Memory.new

      if @index_format == 0
        # Short format: offsets divided by 2
        loca_values.each do |offset|
          write_uint16(io, (offset >> 1).to_u16)
        end
      else
        # Long format: actual 32-bit offsets
        loca_values.each do |offset|
          write_uint32(io, offset)
        end
      end

      io.to_slice
    end

    # Pad output to specified boundary
    private def pad_to_boundary(io : IO, boundary : Int32) : Nil
      padding = (boundary - (io.pos % boundary)) % boundary
      padding.times { io.write_byte(0_u8) }
    end

    extend IOHelpers
  end
end
