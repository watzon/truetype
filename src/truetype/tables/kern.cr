module TrueType
  module Tables
    # Kerning pair for Format 0
    struct KernPair
      # Left glyph ID
      getter left : UInt16

      # Right glyph ID
      getter right : UInt16

      # Kerning value in font units (positive = move apart, negative = move together)
      getter value : Int16

      def initialize(@left : UInt16, @right : UInt16, @value : Int16)
      end
    end

    # Kerning subtable header
    struct KernSubtableHeader
      # Subtable version (0 for Windows, may differ for Mac)
      getter version : UInt16

      # Length of subtable in bytes (including header)
      getter length : UInt16

      # Format of subtable (0 or 2)
      getter format : UInt8

      # Coverage flags
      getter coverage : UInt8

      def initialize(@version : UInt16, @length : UInt16, @format : UInt8, @coverage : UInt8)
      end

      # Check if this subtable applies horizontally
      def horizontal? : Bool
        (@coverage & 0x01) == 0
      end

      # Check if this subtable applies vertically
      def vertical? : Bool
        (@coverage & 0x01) != 0
      end

      # Check if this subtable has minimum values (not kerning values)
      def minimum? : Bool
        (@coverage & 0x02) != 0
      end

      # Check if this subtable contains cross-stream values
      def cross_stream? : Bool
        (@coverage & 0x04) != 0
      end

      # Check if this subtable overrides previous subtables
      def override? : Bool
        (@coverage & 0x08) != 0
      end
    end

    # Format 0 kerning subtable (ordered pairs)
    class KernFormat0
      include IOHelpers

      # All kerning pairs in this subtable
      getter pairs : Array(KernPair)

      # Binary search acceleration
      @search_range : UInt16
      @entry_selector : UInt16
      @range_shift : UInt16

      def initialize(@pairs : Array(KernPair), @search_range : UInt16, @entry_selector : UInt16, @range_shift : UInt16)
      end

      # Parse Format 0 subtable from IO
      def self.parse(io : IO) : KernFormat0
        n_pairs = read_uint16(io)
        search_range = read_uint16(io)
        entry_selector = read_uint16(io)
        range_shift = read_uint16(io)

        pairs = Array(KernPair).new(n_pairs.to_i)
        n_pairs.times do
          left = read_uint16(io)
          right = read_uint16(io)
          value = read_int16(io)
          pairs << KernPair.new(left, right, value)
        end

        new(pairs, search_range, entry_selector, range_shift)
      end

      # Get kerning value for a pair of glyphs using binary search
      def kern(left : UInt16, right : UInt16) : Int16
        # Create search key
        key = (left.to_u32 << 16) | right.to_u32

        # Binary search
        low = 0
        high = @pairs.size - 1

        while low <= high
          mid = (low + high) // 2
          pair = @pairs[mid]
          pair_key = (pair.left.to_u32 << 16) | pair.right.to_u32

          if pair_key < key
            low = mid + 1
          elsif pair_key > key
            high = mid - 1
          else
            return pair.value
          end
        end

        0_i16
      end

      extend IOHelpers
    end

    # Format 2 kerning subtable (class-based)
    class KernFormat2
      include IOHelpers

      # Row width in bytes
      getter row_width : UInt16

      # Offset to left class table
      getter left_class_offset : UInt16

      # Offset to right class table
      getter right_class_offset : UInt16

      # Offset to kerning array
      getter array_offset : UInt16

      # Raw subtable data for class lookups
      @data : Bytes

      # Subtable start position
      @subtable_start : Int32

      def initialize(@row_width : UInt16, @left_class_offset : UInt16, @right_class_offset : UInt16, @array_offset : UInt16, @data : Bytes, @subtable_start : Int32)
      end

      # Parse Format 2 subtable from IO
      def self.parse(io : IO, data : Bytes, subtable_start : Int32) : KernFormat2
        row_width = read_uint16(io)
        left_class_offset = read_uint16(io)
        right_class_offset = read_uint16(io)
        array_offset = read_uint16(io)

        new(row_width, left_class_offset, right_class_offset, array_offset, data, subtable_start)
      end

      # Get kerning value for a pair of glyphs
      def kern(left : UInt16, right : UInt16) : Int16
        left_class = get_class(left, @left_class_offset)
        right_class = get_class(right, @right_class_offset)

        return 0_i16 if left_class == 0 || right_class == 0

        # Calculate offset into kerning array
        offset = @subtable_start + @array_offset + left_class + right_class
        return 0_i16 if offset + 1 >= @data.size

        # Read kerning value
        io = IO::Memory.new(@data[offset..])
        read_int16(io)
      rescue
        0_i16
      end

      private def get_class(glyph : UInt16, class_offset : UInt16) : UInt16
        offset = @subtable_start + class_offset
        return 0_u16 if offset + 4 > @data.size

        io = IO::Memory.new(@data[offset..])

        first_glyph = read_uint16(io)
        n_glyphs = read_uint16(io)

        # Check if glyph is in range
        return 0_u16 if glyph < first_glyph
        index = glyph - first_glyph
        return 0_u16 if index >= n_glyphs

        # Read class value
        class_offset_in_array = offset + 4 + (index * 2)
        return 0_u16 if class_offset_in_array + 1 >= @data.size

        class_io = IO::Memory.new(@data[class_offset_in_array..])
        read_uint16(class_io)
      rescue
        0_u16
      end

      extend IOHelpers
    end

    # The 'kern' table contains kerning pairs for adjusting glyph spacing.
    # This table is optional but common in many fonts.
    class Kern
      include IOHelpers

      # Table version (0 for Windows format)
      getter version : UInt16

      # Number of subtables
      getter num_subtables : UInt16

      # Format 0 subtables (horizontal kerning pairs)
      getter format0_subtables : Array(KernFormat0)

      # Format 2 subtables (class-based kerning)
      getter format2_subtables : Array(KernFormat2)

      # Raw table data
      @data : Bytes

      def initialize(@version : UInt16, @num_subtables : UInt16, @format0_subtables : Array(KernFormat0), @format2_subtables : Array(KernFormat2), @data : Bytes)
      end

      # Parse the kern table from raw bytes
      def self.parse(data : Bytes) : Kern
        io = IO::Memory.new(data)

        version = read_uint16(io)
        num_subtables = read_uint16(io)

        format0_subtables = [] of KernFormat0
        format2_subtables = [] of KernFormat2

        # Handle different table versions
        if version == 0
          # Windows/OpenType format
          num_subtables.times do
            subtable_start = io.pos.to_i32
            subtable_version = read_uint16(io)
            subtable_length = read_uint16(io)
            format = read_uint8(io)
            coverage = read_uint8(io)

            # Calculate end of subtable
            subtable_end = subtable_start + subtable_length

            case format
            when 0
              format0_subtables << KernFormat0.parse(io)
            when 2
              format2_subtables << KernFormat2.parse(io, data, subtable_start + 6)
            end

            # Skip to next subtable
            if io.pos < subtable_end
              io.skip(subtable_end - io.pos)
            end
          end
        elsif version == 1
          # Mac AAT format - has different header structure
          # The 'nTables' field is at a different offset
          io.seek(0)
          _version_fixed = read_uint32(io) # 0x00010000
          n_tables = read_uint32(io)

          n_tables.times do
            subtable_start = io.pos.to_i32
            _length = read_uint32(io)
            coverage = read_uint16(io)
            _tuple_index = read_uint16(io)

            format = (coverage >> 8) & 0xFF

            case format
            when 0
              format0_subtables << KernFormat0.parse(io)
            when 2
              format2_subtables << KernFormat2.parse(io, data, subtable_start + 8)
            end
          end
        end

        new(version, num_subtables, format0_subtables, format2_subtables, data)
      end

      # Get the kerning adjustment for a pair of glyphs
      # Returns the kerning value in font units
      def kern(left : UInt16, right : UInt16) : Int16
        value = 0_i16

        # Check format 0 subtables first
        @format0_subtables.each do |subtable|
          kern_value = subtable.kern(left, right)
          if kern_value != 0
            value = kern_value
          end
        end

        # Check format 2 subtables
        @format2_subtables.each do |subtable|
          kern_value = subtable.kern(left, right)
          if kern_value != 0
            value = kern_value
          end
        end

        value
      end

      # Check if there are any kerning pairs
      def empty? : Bool
        @format0_subtables.empty? && @format2_subtables.empty?
      end

      # Get total number of Format 0 kerning pairs
      def pair_count : Int32
        @format0_subtables.sum(&.pairs.size)
      end

      # Iterate over all Format 0 kerning pairs
      def each_pair(&)
        @format0_subtables.each do |subtable|
          subtable.pairs.each do |pair|
            yield pair
          end
        end
      end

      extend IOHelpers
    end
  end
end
