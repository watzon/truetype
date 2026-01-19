module TrueType
  module Tables
    module Bitmap
      # The 'EBLC' table (Embedded Bitmap Location) provides location info for
      # embedded bitmap glyph data stored in the EBDT table.
      # This is the legacy version of CBLC (Color Bitmap Location).
      #
      # Structure is identical to CBLC but with version 2.0 instead of 3.0.
      class EBLC
        include IOHelpers

        # Major version (2 for EBLC)
        getter major_version : UInt16

        # Minor version (0)
        getter minor_version : UInt16

        # Bitmap size records
        getter bitmap_sizes : Array(BitmapSize)

        # Raw table data for index subtable parsing
        @data : Bytes

        def initialize(
          @major_version : UInt16,
          @minor_version : UInt16,
          @bitmap_sizes : Array(BitmapSize),
          @data : Bytes
        )
        end

        # Parse EBLC table from raw bytes
        def self.parse(data : Bytes) : EBLC
          io = IO::Memory.new(data)

          major_version = read_uint16(io)
          minor_version = read_uint16(io)
          num_sizes = read_uint32(io)

          bitmap_sizes = Array(BitmapSize).new(num_sizes.to_i)
          num_sizes.times do
            bitmap_sizes << BitmapSize.parse(io)
          end

          new(major_version, minor_version, bitmap_sizes, data)
        end

        # Get all available PPEM sizes
        def available_sizes : Array(UInt8)
          @bitmap_sizes.map(&.ppem).uniq.sort
        end

        # Find the bitmap size record for a given PPEM
        def bitmap_size(ppem : UInt8) : BitmapSize?
          @bitmap_sizes.find { |s| s.ppem_x == ppem || s.ppem_y == ppem }
        end

        # Find the bitmap size record for a given PPEM and glyph
        def bitmap_size_for_glyph(ppem : UInt8, glyph_id : UInt16) : BitmapSize?
          @bitmap_sizes.find { |s| (s.ppem_x == ppem || s.ppem_y == ppem) && s.covers?(glyph_id) }
        end

        # Check if a glyph has bitmap data at a given PPEM
        def has_bitmap?(glyph_id : UInt16, ppem : UInt8) : Bool
          size = bitmap_size_for_glyph(ppem, glyph_id)
          return false unless size
          find_glyph_location(size, glyph_id) != nil
        end

        # Get the bitmap location for a glyph at a given PPEM
        def glyph_location(glyph_id : UInt16, ppem : UInt8) : GlyphBitmapLocation?
          size = bitmap_size_for_glyph(ppem, glyph_id)
          return nil unless size
          find_glyph_location(size, glyph_id)
        end

        # Find glyph location within a bitmap size
        private def find_glyph_location(size : BitmapSize, glyph_id : UInt16) : GlyphBitmapLocation?
          # Parse index subtable array
          io = IO::Memory.new(@data[size.index_subtable_array_offset.to_i..])

          # Read index subtable array entries
          entries = Array(IndexSubtableArrayEntry).new(size.number_of_index_subtables.to_i)
          size.number_of_index_subtables.times do
            entries << IndexSubtableArrayEntry.parse(io)
          end

          # Find the entry covering this glyph
          entry = entries.find { |e| e.covers?(glyph_id) }
          return nil unless entry

          # Parse the index subtable
          subtable_offset = size.index_subtable_array_offset + entry.additional_offset_to_index_subtable
          subtable_io = IO::Memory.new(@data[subtable_offset.to_i..])
          header = IndexSubtableHeader.parse(subtable_io)

          parse_glyph_from_index_subtable(subtable_io, header, entry, glyph_id)
        end

        # Parse glyph location from index subtable
        private def parse_glyph_from_index_subtable(
          io : IO,
          header : IndexSubtableHeader,
          entry : IndexSubtableArrayEntry,
          glyph_id : UInt16
        ) : GlyphBitmapLocation?
          glyph_index = glyph_id - entry.first_glyph_index

          case header.index_format
          when 1
            # Format 1: Variable metrics, 4-byte offsets
            io.skip(glyph_index * 4)
            offset1 = read_uint32(io)
            offset2 = read_uint32(io)
            length = offset2 - offset1
            GlyphBitmapLocation.new(
              header.image_data_offset + offset1,
              length,
              header.image_format
            )
          when 2
            # Format 2: All glyphs have same size
            image_size = read_uint32(io)
            metrics = BigGlyphMetrics.parse(io)
            GlyphBitmapLocation.new(
              header.image_data_offset + (glyph_index.to_u32 * image_size),
              image_size,
              header.image_format,
              metrics
            )
          when 3
            # Format 3: Variable metrics, 2-byte offsets
            io.skip(glyph_index * 2)
            offset1 = read_uint16(io).to_u32
            offset2 = read_uint16(io).to_u32
            length = offset2 - offset1
            GlyphBitmapLocation.new(
              header.image_data_offset + offset1,
              length,
              header.image_format
            )
          when 4
            # Format 4: Sparse glyph codes with 4-byte offsets
            num_glyphs = read_uint32(io)
            num_glyphs.times do
              code = read_uint16(io)
              offset = read_uint16(io)
              if code == glyph_id
                # Need to read next entry for length
                next_offset = if io.pos < @data.size - 2
                                read_uint16(io).to_u32
                              else
                                offset.to_u32 + 1 # Estimate
                              end
                return GlyphBitmapLocation.new(
                  header.image_data_offset + offset,
                  next_offset - offset.to_u32,
                  header.image_format
                )
              end
            end
            nil
          when 5
            # Format 5: Constant metrics, sparse glyph codes
            image_size = read_uint32(io)
            metrics = BigGlyphMetrics.parse(io)
            num_glyphs = read_uint32(io)

            # Read glyph code array
            num_glyphs.times do |i|
              code = read_uint16(io)
              if code == glyph_id
                return GlyphBitmapLocation.new(
                  header.image_data_offset + (i.to_u32 * image_size),
                  image_size,
                  header.image_format,
                  metrics
                )
              end
            end
            nil
          else
            nil
          end
        rescue
          nil
        end

        extend IOHelpers
      end

      # Small glyph metrics (5 bytes)
      struct SmallGlyphMetrics
        getter height : UInt8
        getter width : UInt8
        getter bearing_x : Int8
        getter bearing_y : Int8
        getter advance : UInt8

        def initialize(
          @height : UInt8,
          @width : UInt8,
          @bearing_x : Int8,
          @bearing_y : Int8,
          @advance : UInt8
        )
        end

        def self.parse(io : IO) : SmallGlyphMetrics
          height = io.read_byte.not_nil!
          width = io.read_byte.not_nil!
          bearing_x = io.read_byte.not_nil!.to_i8!
          bearing_y = io.read_byte.not_nil!.to_i8!
          advance = io.read_byte.not_nil!
          new(height, width, bearing_x, bearing_y, advance)
        end
      end

      # Big glyph metrics (8 bytes)
      struct BigGlyphMetrics
        getter height : UInt8
        getter width : UInt8
        getter hori_bearing_x : Int8
        getter hori_bearing_y : Int8
        getter hori_advance : UInt8
        getter vert_bearing_x : Int8
        getter vert_bearing_y : Int8
        getter vert_advance : UInt8

        def initialize(
          @height : UInt8,
          @width : UInt8,
          @hori_bearing_x : Int8,
          @hori_bearing_y : Int8,
          @hori_advance : UInt8,
          @vert_bearing_x : Int8,
          @vert_bearing_y : Int8,
          @vert_advance : UInt8
        )
        end

        def self.parse(io : IO) : BigGlyphMetrics
          height = io.read_byte.not_nil!
          width = io.read_byte.not_nil!
          hori_bearing_x = io.read_byte.not_nil!.to_i8!
          hori_bearing_y = io.read_byte.not_nil!.to_i8!
          hori_advance = io.read_byte.not_nil!
          vert_bearing_x = io.read_byte.not_nil!.to_i8!
          vert_bearing_y = io.read_byte.not_nil!.to_i8!
          vert_advance = io.read_byte.not_nil!
          new(height, width, hori_bearing_x, hori_bearing_y, hori_advance,
            vert_bearing_x, vert_bearing_y, vert_advance)
        end
      end

      # SbitLineMetrics for horizontal/vertical metrics
      struct SbitLineMetrics
        include IOHelpers

        getter ascender : Int8
        getter descender : Int8
        getter width_max : UInt8
        getter caret_slope_numerator : Int8
        getter caret_slope_denominator : Int8
        getter caret_offset : Int8
        getter min_origin_sb : Int8
        getter min_advance_sb : Int8
        getter max_before_bl : Int8
        getter min_after_bl : Int8

        def initialize(
          @ascender : Int8,
          @descender : Int8,
          @width_max : UInt8,
          @caret_slope_numerator : Int8,
          @caret_slope_denominator : Int8,
          @caret_offset : Int8,
          @min_origin_sb : Int8,
          @min_advance_sb : Int8,
          @max_before_bl : Int8,
          @min_after_bl : Int8
        )
        end

        def self.parse(io : IO) : SbitLineMetrics
          ascender = io.read_byte.not_nil!.to_i8!
          descender = io.read_byte.not_nil!.to_i8!
          width_max = io.read_byte.not_nil!
          caret_slope_numerator = io.read_byte.not_nil!.to_i8!
          caret_slope_denominator = io.read_byte.not_nil!.to_i8!
          caret_offset = io.read_byte.not_nil!.to_i8!
          min_origin_sb = io.read_byte.not_nil!.to_i8!
          min_advance_sb = io.read_byte.not_nil!.to_i8!
          max_before_bl = io.read_byte.not_nil!.to_i8!
          min_after_bl = io.read_byte.not_nil!.to_i8!
          # Skip 2 reserved bytes
          io.skip(2)
          new(ascender, descender, width_max, caret_slope_numerator,
            caret_slope_denominator, caret_offset, min_origin_sb,
            min_advance_sb, max_before_bl, min_after_bl)
        end

        extend IOHelpers
      end

      # Bitmap size record
      struct BitmapSize
        include IOHelpers
        extend IOHelpers

        getter index_subtable_array_offset : UInt32
        getter index_tables_size : UInt32
        getter number_of_index_subtables : UInt32
        getter color_ref : UInt32
        getter hori : SbitLineMetrics
        getter vert : SbitLineMetrics
        getter start_glyph_index : UInt16
        getter end_glyph_index : UInt16
        getter ppem_x : UInt8
        getter ppem_y : UInt8
        getter bit_depth : UInt8
        getter flags : Int8

        def initialize(
          @index_subtable_array_offset : UInt32,
          @index_tables_size : UInt32,
          @number_of_index_subtables : UInt32,
          @color_ref : UInt32,
          @hori : SbitLineMetrics,
          @vert : SbitLineMetrics,
          @start_glyph_index : UInt16,
          @end_glyph_index : UInt16,
          @ppem_x : UInt8,
          @ppem_y : UInt8,
          @bit_depth : UInt8,
          @flags : Int8
        )
        end

        def self.parse(io : IO) : BitmapSize
          index_subtable_array_offset = read_uint32(io)
          index_tables_size = read_uint32(io)
          number_of_index_subtables = read_uint32(io)
          color_ref = read_uint32(io)
          hori = SbitLineMetrics.parse(io)
          vert = SbitLineMetrics.parse(io)
          start_glyph_index = read_uint16(io)
          end_glyph_index = read_uint16(io)
          ppem_x = io.read_byte.not_nil!
          ppem_y = io.read_byte.not_nil!
          bit_depth = io.read_byte.not_nil!
          flags = io.read_byte.not_nil!.to_i8!

          new(index_subtable_array_offset, index_tables_size, number_of_index_subtables,
            color_ref, hori, vert, start_glyph_index, end_glyph_index,
            ppem_x, ppem_y, bit_depth, flags)
        end

        # Check if a glyph is in this size range
        def covers?(glyph_id : UInt16) : Bool
          glyph_id >= @start_glyph_index && glyph_id <= @end_glyph_index
        end

        # PPEM (pixels per em) - typically same for X and Y
        def ppem : UInt8
          @ppem_x
        end
      end

      # Index subtable array entry
      struct IndexSubtableArrayEntry
        include IOHelpers
        extend IOHelpers

        getter first_glyph_index : UInt16
        getter last_glyph_index : UInt16
        getter additional_offset_to_index_subtable : UInt32

        def initialize(
          @first_glyph_index : UInt16,
          @last_glyph_index : UInt16,
          @additional_offset_to_index_subtable : UInt32
        )
        end

        def self.parse(io : IO) : IndexSubtableArrayEntry
          first_glyph_index = read_uint16(io)
          last_glyph_index = read_uint16(io)
          additional_offset = read_uint32(io)
          new(first_glyph_index, last_glyph_index, additional_offset)
        end

        def covers?(glyph_id : UInt16) : Bool
          glyph_id >= @first_glyph_index && glyph_id <= @last_glyph_index
        end
      end

      # Index subtable header (common to all formats)
      struct IndexSubtableHeader
        include IOHelpers
        extend IOHelpers

        getter index_format : UInt16
        getter image_format : UInt16
        getter image_data_offset : UInt32

        def initialize(
          @index_format : UInt16,
          @image_format : UInt16,
          @image_data_offset : UInt32
        )
        end

        def self.parse(io : IO) : IndexSubtableHeader
          index_format = read_uint16(io)
          image_format = read_uint16(io)
          image_data_offset = read_uint32(io)
          new(index_format, image_format, image_data_offset)
        end
      end

      # Glyph bitmap location info
      struct GlyphBitmapLocation
        getter image_data_offset : UInt32
        getter image_data_length : UInt32
        getter image_format : UInt16
        getter metrics : BigGlyphMetrics?

        def initialize(
          @image_data_offset : UInt32,
          @image_data_length : UInt32,
          @image_format : UInt16,
          @metrics : BigGlyphMetrics? = nil
        )
        end
      end
    end
  end
end
