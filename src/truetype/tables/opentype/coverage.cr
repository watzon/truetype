module TrueType
  module Tables
    module OpenType
      # Coverage table - maps glyph IDs to coverage indices
      # Used by GSUB and GPOS lookups to identify which glyphs are affected
      abstract class Coverage
        include IOHelpers
        extend IOHelpers

        # Get the coverage index for a glyph, or nil if not covered
        abstract def coverage_index(glyph_id : UInt16) : Int32?

        # Check if a glyph is covered
        def covers?(glyph_id : UInt16) : Bool
          !coverage_index(glyph_id).nil?
        end

        # Get all covered glyph IDs
        abstract def glyph_ids : Array(UInt16)

        # Number of glyphs in coverage
        abstract def count : Int32

        # Parse a coverage table from the given offset
        def self.parse(io : IO, offset : UInt32) : Coverage
          io.seek(offset.to_i64)
          format = read_uint16(io)

          case format
          when 1
            CoverageFormat1.parse(io)
          when 2
            CoverageFormat2.parse(io)
          else
            raise ParseError.new("Unknown coverage format: #{format}")
          end
        end
      end

      # Coverage Format 1: Array of glyph IDs
      class CoverageFormat1 < Coverage
        getter glyphs : Array(UInt16)

        def initialize(@glyphs : Array(UInt16))
        end

        def coverage_index(glyph_id : UInt16) : Int32?
          # Binary search since glyphs are sorted
          idx = @glyphs.bsearch_index { |g| g >= glyph_id }
          return nil if idx.nil?
          return nil if @glyphs[idx] != glyph_id
          idx
        end

        def glyph_ids : Array(UInt16)
          @glyphs
        end

        def count : Int32
          @glyphs.size
        end

        def self.parse(io : IO) : CoverageFormat1
          glyph_count = read_uint16(io)
          glyphs = Array(UInt16).new(glyph_count.to_i)
          glyph_count.times do
            glyphs << read_uint16(io)
          end
          new(glyphs)
        end
      end

      # Coverage Format 2: Ranges of glyph IDs
      class CoverageFormat2 < Coverage
        struct RangeRecord
          getter start_glyph : UInt16
          getter end_glyph : UInt16
          getter start_coverage_index : UInt16

          def initialize(@start_glyph, @end_glyph, @start_coverage_index)
          end
        end

        getter ranges : Array(RangeRecord)

        def initialize(@ranges : Array(RangeRecord))
        end

        def coverage_index(glyph_id : UInt16) : Int32?
          # Binary search for the range containing this glyph
          @ranges.each do |range|
            next if glyph_id < range.start_glyph
            break if glyph_id > range.end_glyph && range == @ranges.last

            if glyph_id >= range.start_glyph && glyph_id <= range.end_glyph
              return range.start_coverage_index.to_i + (glyph_id - range.start_glyph).to_i
            end
          end
          nil
        end

        def glyph_ids : Array(UInt16)
          result = [] of UInt16
          @ranges.each do |range|
            (range.start_glyph..range.end_glyph).each do |glyph|
              result << glyph.to_u16
            end
          end
          result
        end

        def count : Int32
          return 0 if @ranges.empty?
          last = @ranges.last
          last.start_coverage_index.to_i + (last.end_glyph - last.start_glyph).to_i + 1
        end

        def self.parse(io : IO) : CoverageFormat2
          range_count = read_uint16(io)
          ranges = Array(RangeRecord).new(range_count.to_i)
          range_count.times do
            start_glyph = read_uint16(io)
            end_glyph = read_uint16(io)
            start_index = read_uint16(io)
            ranges << RangeRecord.new(start_glyph, end_glyph, start_index)
          end
          new(ranges)
        end
      end
    end
  end
end
