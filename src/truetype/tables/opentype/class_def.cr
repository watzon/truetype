module TrueType
  module Tables
    module OpenType
      # Class Definition table - assigns glyphs to classes
      # Used by GDEF for glyph classification and by GPOS/GSUB for class-based lookups
      abstract class ClassDef
        include IOHelpers
        extend IOHelpers

        # Class 0 is the default class for glyphs not explicitly assigned
        DEFAULT_CLASS = 0_u16

        # Get the class for a glyph ID
        abstract def class_id(glyph_id : UInt16) : UInt16

        # Get all glyphs in a specific class
        abstract def glyphs_in_class(class_id : UInt16) : Array(UInt16)

        # Get the maximum class ID used
        abstract def max_class : UInt16

        # Parse a class definition table from the given offset
        def self.parse(io : IO, offset : UInt32) : ClassDef
          io.seek(offset.to_i64)
          format = read_uint16(io)

          case format
          when 1
            ClassDefFormat1.parse(io)
          when 2
            ClassDefFormat2.parse(io)
          else
            # Return empty classdef for unknown formats rather than crash
            # This allows graceful degradation for edge cases
            ClassDefFormat1.new(0_u16, [] of UInt16)
          end
        end
      end

      # ClassDef Format 1: Array of class values for consecutive glyphs
      class ClassDefFormat1 < ClassDef
        getter start_glyph : UInt16
        getter class_values : Array(UInt16)

        def initialize(@start_glyph : UInt16, @class_values : Array(UInt16))
        end

        def class_id(glyph_id : UInt16) : UInt16
          return DEFAULT_CLASS if glyph_id < @start_glyph
          idx = glyph_id - @start_glyph
          return DEFAULT_CLASS if idx >= @class_values.size
          @class_values[idx]
        end

        def glyphs_in_class(class_id : UInt16) : Array(UInt16)
          result = [] of UInt16
          @class_values.each_with_index do |cls, idx|
            result << (@start_glyph + idx).to_u16 if cls == class_id
          end
          result
        end

        def max_class : UInt16
          @class_values.max? || 0_u16
        end

        def self.parse(io : IO) : ClassDefFormat1
          start_glyph = read_uint16(io)
          glyph_count = read_uint16(io)
          class_values = Array(UInt16).new(glyph_count.to_i)
          glyph_count.times do
            class_values << read_uint16(io)
          end
          new(start_glyph, class_values)
        end
      end

      # ClassDef Format 2: Ranges of glyphs with class values
      class ClassDefFormat2 < ClassDef
        struct ClassRangeRecord
          getter start_glyph : UInt16
          getter end_glyph : UInt16
          getter class_id : UInt16

          def initialize(@start_glyph, @end_glyph, @class_id)
          end
        end

        getter ranges : Array(ClassRangeRecord)

        def initialize(@ranges : Array(ClassRangeRecord))
        end

        def class_id(glyph_id : UInt16) : UInt16
          @ranges.each do |range|
            next if glyph_id < range.start_glyph
            return range.class_id if glyph_id <= range.end_glyph
          end
          DEFAULT_CLASS
        end

        def glyphs_in_class(class_id : UInt16) : Array(UInt16)
          result = [] of UInt16
          @ranges.each do |range|
            if range.class_id == class_id
              (range.start_glyph..range.end_glyph).each do |g|
                result << g.to_u16
              end
            end
          end
          result
        end

        def max_class : UInt16
          @ranges.map(&.class_id).max? || 0_u16
        end

        def self.parse(io : IO) : ClassDefFormat2
          range_count = read_uint16(io)
          ranges = Array(ClassRangeRecord).new(range_count.to_i)
          range_count.times do
            start_glyph = read_uint16(io)
            end_glyph = read_uint16(io)
            class_id = read_uint16(io)
            ranges << ClassRangeRecord.new(start_glyph, end_glyph, class_id)
          end
          new(ranges)
        end
      end
    end
  end
end
