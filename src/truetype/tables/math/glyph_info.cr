module TrueType
  module Tables
    module Math
      # Corners for math kerning
      enum MathKernCorner
        TopRight
        TopLeft
        BottomRight
        BottomLeft
      end

      # Math kern info table - per-corner kerning for super/subscripts
      class MathKernInfoTable
        include IOHelpers

        # Mapping from glyph ID to MathKernInfo (via coverage)
        @coverage : OpenType::Coverage
        @kern_info : Array(MathKernInfo)

        def initialize(@coverage : OpenType::Coverage, @kern_info : Array(MathKernInfo))
        end

        def self.parse(data : Bytes, offset : UInt32) : MathKernInfoTable
          io = IO::Memory.new(data[offset.to_i..])

          coverage_offset = read_uint16(io)
          kern_info_count = read_uint16(io)

          # Read offsets to MathKernInfoRecords
          kern_offsets = Array(UInt16).new(kern_info_count.to_i)
          kern_info_count.times do
            # Each record has 4 offsets (one per corner)
            top_right = read_uint16(io)
            top_left = read_uint16(io)
            bottom_right = read_uint16(io)
            bottom_left = read_uint16(io)
            kern_offsets << top_right  # Store just the first for indexing
          end

          # Re-read to get full records
          io.seek(4)  # After coverage_offset and count
          kern_info = Array(MathKernInfo).new(kern_info_count.to_i)
          kern_info_count.times do
            top_right_off = read_uint16(io)
            top_left_off = read_uint16(io)
            bottom_right_off = read_uint16(io)
            bottom_left_off = read_uint16(io)

            top_right = top_right_off != 0 ? MathKern.parse(data, offset + top_right_off) : nil
            top_left = top_left_off != 0 ? MathKern.parse(data, offset + top_left_off) : nil
            bottom_right = bottom_right_off != 0 ? MathKern.parse(data, offset + bottom_right_off) : nil
            bottom_left = bottom_left_off != 0 ? MathKern.parse(data, offset + bottom_left_off) : nil

            kern_info << MathKernInfo.new(top_right, top_left, bottom_right, bottom_left)
          end

          # Parse coverage
          data_io = IO::Memory.new(data)
          coverage = OpenType::Coverage.parse(data_io, offset + coverage_offset)

          new(coverage, kern_info)
        end

        # Get kern value for glyph at corner and height
        def kern(glyph_id : UInt16, corner : MathKernCorner, height : Int16) : Int16
          index = @coverage.coverage_index(glyph_id)
          return 0_i16 unless index
          return 0_i16 if index >= @kern_info.size

          info = @kern_info[index]
          kern = case corner
                 when .top_right?    then info.top_right
                 when .top_left?     then info.top_left
                 when .bottom_right? then info.bottom_right
                 when .bottom_left?  then info.bottom_left
                 end
          kern.try(&.kern_at(height)) || 0_i16
        end

        extend IOHelpers
      end

      # MathKernInfo for a single glyph - has 4 corners
      struct MathKernInfo
        getter top_right : MathKern?
        getter top_left : MathKern?
        getter bottom_right : MathKern?
        getter bottom_left : MathKern?

        def initialize(
          @top_right : MathKern?,
          @top_left : MathKern?,
          @bottom_right : MathKern?,
          @bottom_left : MathKern?
        )
        end
      end

      # MathKern table - defines staircase kern at different heights
      class MathKern
        include IOHelpers

        # Heights at which kern changes
        getter correction_heights : Array(MathValueRecord)

        # Kern values (one more than heights)
        getter kern_values : Array(MathValueRecord)

        def initialize(
          @correction_heights : Array(MathValueRecord),
          @kern_values : Array(MathValueRecord)
        )
        end

        def self.parse(data : Bytes, offset : UInt32) : MathKern
          io = IO::Memory.new(data[offset.to_i..])

          height_count = read_uint16(io)

          # Read height correction values
          correction_heights = Array(MathValueRecord).new(height_count.to_i)
          height_count.times do
            correction_heights << MathValueRecord.parse(io)
          end

          # Kern values (one more than heights)
          kern_values = Array(MathValueRecord).new(height_count.to_i + 1)
          (height_count + 1).times do
            kern_values << MathValueRecord.parse(io)
          end

          new(correction_heights, kern_values)
        end

        # Get kern value at given height using binary search
        def kern_at(height : Int16) : Int16
          return @kern_values[0]?.try(&.value) || 0_i16 if @correction_heights.empty?

          # Find first height > given height
          idx = @correction_heights.bsearch_index { |h| h.value > height }

          if idx
            @kern_values[idx].value
          else
            @kern_values.last?.try(&.value) || 0_i16
          end
        end

        extend IOHelpers
      end

      # MathGlyphInfo subtable - contains per-glyph math info
      class MathGlyphInfo
        include IOHelpers

        # Italics correction per glyph
        @italics_correction_coverage : OpenType::Coverage?
        @italics_corrections : Array(MathValueRecord)

        # Top accent attachment points
        @top_accent_coverage : OpenType::Coverage?
        @top_accent_attachments : Array(MathValueRecord)

        # Extended shape coverage (no values, just presence)
        @extended_shape_coverage : OpenType::Coverage?

        # Math kern info table
        getter math_kern_info : MathKernInfoTable?

        def initialize(
          @italics_correction_coverage : OpenType::Coverage?,
          @italics_corrections : Array(MathValueRecord),
          @top_accent_coverage : OpenType::Coverage?,
          @top_accent_attachments : Array(MathValueRecord),
          @extended_shape_coverage : OpenType::Coverage?,
          @math_kern_info : MathKernInfoTable?
        )
        end

        def self.parse(data : Bytes, offset : UInt32) : MathGlyphInfo
          io = IO::Memory.new(data[offset.to_i..])

          italics_correction_offset = read_uint16(io)
          top_accent_offset = read_uint16(io)
          extended_shape_offset = read_uint16(io)
          kern_info_offset = read_uint16(io)

          # Create IO for coverage parsing
          data_io = IO::Memory.new(data)

          # Parse italics correction info
          italics_coverage : OpenType::Coverage? = nil
          italics_corrections = [] of MathValueRecord
          if italics_correction_offset != 0
            ic_offset = offset + italics_correction_offset
            ic_io = IO::Memory.new(data[ic_offset.to_i..])
            coverage_off = read_uint16(ic_io)
            count = read_uint16(ic_io)
            italics_coverage = OpenType::Coverage.parse(data_io, (ic_offset + coverage_off).to_u32)
            count.times { italics_corrections << MathValueRecord.parse(ic_io) }
          end

          # Parse top accent attachment info
          top_accent_coverage : OpenType::Coverage? = nil
          top_accent_attachments = [] of MathValueRecord
          if top_accent_offset != 0
            ta_offset = offset + top_accent_offset
            ta_io = IO::Memory.new(data[ta_offset.to_i..])
            coverage_off = read_uint16(ta_io)
            count = read_uint16(ta_io)
            top_accent_coverage = OpenType::Coverage.parse(data_io, (ta_offset + coverage_off).to_u32)
            count.times { top_accent_attachments << MathValueRecord.parse(ta_io) }
          end

          # Parse extended shape coverage
          extended_shape_coverage : OpenType::Coverage? = nil
          if extended_shape_offset != 0
            extended_shape_coverage = OpenType::Coverage.parse(data_io, (offset + extended_shape_offset).to_u32)
          end

          # Parse math kern info
          math_kern_info : MathKernInfoTable? = nil
          if kern_info_offset != 0
            math_kern_info = MathKernInfoTable.parse(data, offset + kern_info_offset)
          end

          new(
            italics_coverage,
            italics_corrections,
            top_accent_coverage,
            top_accent_attachments,
            extended_shape_coverage,
            math_kern_info
          )
        end

        # Get italics correction for glyph
        def italics_correction(glyph_id : UInt16) : Int16?
          return nil unless coverage = @italics_correction_coverage
          index = coverage.coverage_index(glyph_id)
          return nil unless index
          return nil if index >= @italics_corrections.size
          @italics_corrections[index].value
        end

        # Get top accent attachment point for glyph
        def top_accent_attachment(glyph_id : UInt16) : Int16?
          return nil unless coverage = @top_accent_coverage
          index = coverage.coverage_index(glyph_id)
          return nil unless index
          return nil if index >= @top_accent_attachments.size
          @top_accent_attachments[index].value
        end

        # Check if glyph is an extended shape
        def extended_shape?(glyph_id : UInt16) : Bool
          @extended_shape_coverage.try(&.covers?(glyph_id)) || false
        end

        # Get math kern at corner and height
        def kern(glyph_id : UInt16, corner : MathKernCorner, height : Int16) : Int16
          @math_kern_info.try(&.kern(glyph_id, corner, height)) || 0_i16
        end

        extend IOHelpers
      end
    end
  end
end
