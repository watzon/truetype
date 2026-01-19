module TrueType
  module Tables
    module OpenType
      # GPOS lookup types
      enum GPOSLookupType : UInt16
        SingleAdjustment    = 1 # Adjust position of single glyph
        PairAdjustment      = 2 # Adjust position of glyph pair (kerning)
        CursiveAttachment   = 3 # Attach cursive glyphs
        MarkToBase          = 4 # Attach mark to base glyph
        MarkToLigature      = 5 # Attach mark to ligature
        MarkToMark          = 6 # Attach mark to mark
        Context             = 7 # Context positioning
        ChainingContext     = 8 # Chained context positioning
        Extension           = 9 # Extension mechanism
      end

      # Abstract base for all GPOS subtables
      abstract class GPOSSubtable
        include IOHelpers
        extend IOHelpers

        abstract def lookup_type : GPOSLookupType
      end

      # Single Adjustment Format 1: Same adjustment for all covered glyphs
      class SinglePosFormat1 < GPOSSubtable
        getter coverage : Coverage
        getter value_format : ValueFormat
        getter value_record : ValueRecord

        def initialize(@coverage : Coverage, @value_format : ValueFormat, @value_record : ValueRecord)
        end

        def lookup_type : GPOSLookupType
          GPOSLookupType::SingleAdjustment
        end

        def adjustment(glyph_id : UInt16) : ValueRecord?
          return nil unless @coverage.covers?(glyph_id)
          @value_record
        end
      end

      # Single Adjustment Format 2: Different adjustment per glyph
      class SinglePosFormat2 < GPOSSubtable
        getter coverage : Coverage
        getter value_format : ValueFormat
        getter value_records : Array(ValueRecord)

        def initialize(@coverage : Coverage, @value_format : ValueFormat, @value_records : Array(ValueRecord))
        end

        def lookup_type : GPOSLookupType
          GPOSLookupType::SingleAdjustment
        end

        def adjustment(glyph_id : UInt16) : ValueRecord?
          idx = @coverage.coverage_index(glyph_id)
          return nil unless idx
          @value_records[idx]?
        end
      end

      # Pair value record for pair positioning
      struct PairValueRecord
        getter second_glyph : UInt16
        getter value1 : ValueRecord
        getter value2 : ValueRecord

        def initialize(@second_glyph : UInt16, @value1 : ValueRecord, @value2 : ValueRecord)
        end
      end

      # Pair Adjustment Format 1: Specific glyph pairs
      class PairPosFormat1 < GPOSSubtable
        getter coverage : Coverage
        getter value_format1 : ValueFormat
        getter value_format2 : ValueFormat
        getter pair_sets : Array(Array(PairValueRecord))

        def initialize(@coverage : Coverage, @value_format1 : ValueFormat,
                       @value_format2 : ValueFormat, @pair_sets : Array(Array(PairValueRecord)))
        end

        def lookup_type : GPOSLookupType
          GPOSLookupType::PairAdjustment
        end

        def adjustment(first : UInt16, second : UInt16) : Tuple(ValueRecord, ValueRecord)?
          idx = @coverage.coverage_index(first)
          return nil unless idx
          pair_set = @pair_sets[idx]?
          return nil unless pair_set

          pair_set.each do |pvr|
            if pvr.second_glyph == second
              return {pvr.value1, pvr.value2}
            end
          end
          nil
        end
      end

      # Class2 record for class-based pair adjustment
      struct Class2Record
        getter value1 : ValueRecord
        getter value2 : ValueRecord

        def initialize(@value1 : ValueRecord, @value2 : ValueRecord)
        end
      end

      # Pair Adjustment Format 2: Class-based pairs
      class PairPosFormat2 < GPOSSubtable
        getter coverage : Coverage
        getter value_format1 : ValueFormat
        getter value_format2 : ValueFormat
        getter class_def1 : ClassDef
        getter class_def2 : ClassDef
        getter class1_records : Array(Array(Class2Record))

        def initialize(@coverage : Coverage, @value_format1 : ValueFormat, @value_format2 : ValueFormat,
                       @class_def1 : ClassDef, @class_def2 : ClassDef,
                       @class1_records : Array(Array(Class2Record)))
        end

        def lookup_type : GPOSLookupType
          GPOSLookupType::PairAdjustment
        end

        def adjustment(first : UInt16, second : UInt16) : Tuple(ValueRecord, ValueRecord)?
          return nil unless @coverage.covers?(first)

          class1 = @class_def1.class_id(first)
          class2 = @class_def2.class_id(second)

          class1_record = @class1_records[class1]?
          return nil unless class1_record

          class2_record = class1_record[class2]?
          return nil unless class2_record

          {class2_record.value1, class2_record.value2}
        end
      end

      # Entry/Exit record for cursive attachment
      struct EntryExitRecord
        getter entry_anchor : Anchor?
        getter exit_anchor : Anchor?

        def initialize(@entry_anchor : Anchor?, @exit_anchor : Anchor?)
        end
      end

      # Cursive Attachment
      class CursivePos < GPOSSubtable
        getter coverage : Coverage
        getter entry_exit_records : Array(EntryExitRecord)

        def initialize(@coverage : Coverage, @entry_exit_records : Array(EntryExitRecord))
        end

        def lookup_type : GPOSLookupType
          GPOSLookupType::CursiveAttachment
        end

        def entry_exit(glyph_id : UInt16) : EntryExitRecord?
          idx = @coverage.coverage_index(glyph_id)
          return nil unless idx
          @entry_exit_records[idx]?
        end
      end

      # Mark record
      struct MarkRecord
        getter mark_class : UInt16
        getter mark_anchor : Anchor

        def initialize(@mark_class : UInt16, @mark_anchor : Anchor)
        end
      end

      # Base record (array of anchors, one per mark class)
      struct BaseRecord
        getter base_anchors : Array(Anchor?)

        def initialize(@base_anchors : Array(Anchor?))
        end
      end

      # Mark-to-Base Attachment
      class MarkBasePos < GPOSSubtable
        getter mark_coverage : Coverage
        getter base_coverage : Coverage
        getter mark_class_count : UInt16
        getter mark_records : Array(MarkRecord)
        getter base_records : Array(BaseRecord)

        def initialize(@mark_coverage : Coverage, @base_coverage : Coverage,
                       @mark_class_count : UInt16, @mark_records : Array(MarkRecord),
                       @base_records : Array(BaseRecord))
        end

        def lookup_type : GPOSLookupType
          GPOSLookupType::MarkToBase
        end

        def attachment(mark_glyph : UInt16, base_glyph : UInt16) : Tuple(Anchor, Anchor)?
          mark_idx = @mark_coverage.coverage_index(mark_glyph)
          return nil unless mark_idx

          base_idx = @base_coverage.coverage_index(base_glyph)
          return nil unless base_idx

          mark_record = @mark_records[mark_idx]?
          return nil unless mark_record

          base_record = @base_records[base_idx]?
          return nil unless base_record

          base_anchor = base_record.base_anchors[mark_record.mark_class]?
          return nil unless base_anchor

          {mark_record.mark_anchor, base_anchor}
        end
      end

      # Mark-to-Mark Attachment
      class MarkMarkPos < GPOSSubtable
        getter mark1_coverage : Coverage
        getter mark2_coverage : Coverage
        getter mark_class_count : UInt16
        getter mark1_records : Array(MarkRecord)
        getter mark2_records : Array(BaseRecord) # Same structure as base records

        def initialize(@mark1_coverage : Coverage, @mark2_coverage : Coverage,
                       @mark_class_count : UInt16, @mark1_records : Array(MarkRecord),
                       @mark2_records : Array(BaseRecord))
        end

        def lookup_type : GPOSLookupType
          GPOSLookupType::MarkToMark
        end
      end

      # GPOS Lookup table
      class GPOSLookup
        include IOHelpers
        extend IOHelpers

        getter lookup_type : GPOSLookupType
        getter lookup_flag : UInt16
        getter subtables : Array(GPOSSubtable)
        getter mark_filtering_set : UInt16?

        USE_MARK_FILTERING_SET = 0x0010_u16

        def initialize(@lookup_type : GPOSLookupType, @lookup_flag : UInt16,
                       @subtables : Array(GPOSSubtable), @mark_filtering_set : UInt16?)
        end

        def self.parse(io : IO, offset : UInt32, table_data : Bytes) : GPOSLookup
          io.seek(offset.to_i64)
          base_offset = offset

          lookup_type_raw = read_uint16(io)
          lookup_type = GPOSLookupType.from_value(lookup_type_raw)
          lookup_flag = read_uint16(io)
          subtable_count = read_uint16(io)

          subtable_offsets = Array(UInt16).new(subtable_count.to_i)
          subtable_count.times { subtable_offsets << read_uint16(io) }

          mark_filtering_set = if (lookup_flag & USE_MARK_FILTERING_SET) != 0
                                 read_uint16(io)
                               else
                                 nil
                               end

          subtables = subtable_offsets.map do |so|
            parse_subtable(io, base_offset + so, lookup_type, table_data)
          end

          new(lookup_type, lookup_flag, subtables, mark_filtering_set)
        end

        private def self.parse_subtable(io : IO, offset : UInt32, lookup_type : GPOSLookupType, table_data : Bytes) : GPOSSubtable
          io.seek(offset.to_i64)

          case lookup_type
          when .single_adjustment?
            parse_single_pos(io, offset)
          when .pair_adjustment?
            parse_pair_pos(io, offset)
          when .cursive_attachment?
            parse_cursive_pos(io, offset)
          when .mark_to_base?
            parse_mark_base_pos(io, offset)
          when .mark_to_mark?
            parse_mark_mark_pos(io, offset)
          when .extension?
            parse_extension(io, offset, table_data)
          else
            # Placeholder for complex context lookups
            SinglePosFormat1.new(CoverageFormat1.new([] of UInt16), ValueFormat::None, ValueRecord.new)
          end
        end

        private def self.parse_single_pos(io : IO, offset : UInt32) : GPOSSubtable
          format = read_uint16(io)
          coverage_offset = read_uint16(io)
          value_format = ValueFormat.from_value(read_uint16(io))

          coverage = Coverage.parse(io, offset + coverage_offset)

          case format
          when 1
            io.seek((offset + 6).to_i64)
            value_record = ValueRecord.parse(io, value_format)
            SinglePosFormat1.new(coverage, value_format, value_record)
          when 2
            io.seek((offset + 6).to_i64)
            value_count = read_uint16(io)
            value_records = Array(ValueRecord).new(value_count.to_i)
            value_count.times { value_records << ValueRecord.parse(io, value_format) }
            SinglePosFormat2.new(coverage, value_format, value_records)
          else
            raise ParseError.new("Unknown SinglePos format: #{format}")
          end
        end

        private def self.parse_pair_pos(io : IO, offset : UInt32) : GPOSSubtable
          format = read_uint16(io)
          coverage_offset = read_uint16(io)
          value_format1 = ValueFormat.from_value(read_uint16(io))
          value_format2 = ValueFormat.from_value(read_uint16(io))

          coverage = Coverage.parse(io, offset + coverage_offset)

          case format
          when 1
            io.seek((offset + 10).to_i64)
            pair_set_count = read_uint16(io)
            pair_set_offsets = Array(UInt16).new(pair_set_count.to_i)
            pair_set_count.times { pair_set_offsets << read_uint16(io) }

            pair_sets = pair_set_offsets.map do |pso|
              io.seek((offset + pso).to_i64)
              pair_value_count = read_uint16(io)
              pairs = Array(PairValueRecord).new(pair_value_count.to_i)
              pair_value_count.times do
                second_glyph = read_uint16(io)
                value1 = ValueRecord.parse(io, value_format1)
                value2 = ValueRecord.parse(io, value_format2)
                pairs << PairValueRecord.new(second_glyph, value1, value2)
              end
              pairs
            end

            PairPosFormat1.new(coverage, value_format1, value_format2, pair_sets)
          when 2
            io.seek((offset + 10).to_i64)
            class_def1_offset = read_uint16(io)
            class_def2_offset = read_uint16(io)
            class1_count = read_uint16(io)
            class2_count = read_uint16(io)

            # Parse class definitions - offsets are relative to subtable start
            class_def1 = if class_def1_offset > 0
                           ClassDef.parse(io, offset + class_def1_offset)
                         else
                           # Empty class def - all glyphs are class 0
                           ClassDefFormat1.new(0_u16, [] of UInt16)
                         end

            class_def2 = if class_def2_offset > 0
                           ClassDef.parse(io, offset + class_def2_offset)
                         else
                           ClassDefFormat1.new(0_u16, [] of UInt16)
                         end

            # Read class1 records starting after the header (18 bytes)
            io.seek((offset + 18).to_i64)
            class1_records = Array(Array(Class2Record)).new(class1_count.to_i)
            class1_count.times do
              class2_records = Array(Class2Record).new(class2_count.to_i)
              class2_count.times do
                value1 = ValueRecord.parse(io, value_format1)
                value2 = ValueRecord.parse(io, value_format2)
                class2_records << Class2Record.new(value1, value2)
              end
              class1_records << class2_records
            end

            PairPosFormat2.new(coverage, value_format1, value_format2, class_def1, class_def2, class1_records)
          else
            raise ParseError.new("Unknown PairPos format: #{format}")
          end
        end

        private def self.parse_cursive_pos(io : IO, offset : UInt32) : GPOSSubtable
          format = read_uint16(io)
          coverage_offset = read_uint16(io)
          entry_exit_count = read_uint16(io)

          coverage = Coverage.parse(io, offset + coverage_offset)

          io.seek((offset + 6).to_i64)
          entry_exit_records = Array(EntryExitRecord).new(entry_exit_count.to_i)
          entry_exit_count.times do
            entry_anchor_offset = read_uint16(io)
            exit_anchor_offset = read_uint16(io)
            pos = io.pos

            entry_anchor = entry_anchor_offset > 0 ? Anchor.parse(io, offset + entry_anchor_offset) : nil
            exit_anchor = exit_anchor_offset > 0 ? Anchor.parse(io, offset + exit_anchor_offset) : nil

            io.seek(pos)
            entry_exit_records << EntryExitRecord.new(entry_anchor, exit_anchor)
          end

          CursivePos.new(coverage, entry_exit_records)
        end

        private def self.parse_mark_base_pos(io : IO, offset : UInt32) : GPOSSubtable
          format = read_uint16(io)
          mark_coverage_offset = read_uint16(io)
          base_coverage_offset = read_uint16(io)
          mark_class_count = read_uint16(io)
          mark_array_offset = read_uint16(io)
          base_array_offset = read_uint16(io)

          mark_coverage = Coverage.parse(io, offset + mark_coverage_offset)
          base_coverage = Coverage.parse(io, offset + base_coverage_offset)

          # Parse mark array
          io.seek((offset + mark_array_offset).to_i64)
          mark_count = read_uint16(io)
          mark_records = Array(MarkRecord).new(mark_count.to_i)
          mark_record_data = Array(Tuple(UInt16, UInt16)).new(mark_count.to_i)
          mark_count.times do
            mark_class = read_uint16(io)
            mark_anchor_offset = read_uint16(io)
            mark_record_data << {mark_class, mark_anchor_offset}
          end
          mark_record_data.each do |(mark_class, anchor_offset)|
            anchor = Anchor.parse(io, offset + mark_array_offset + anchor_offset)
            mark_records << MarkRecord.new(mark_class, anchor)
          end

          # Parse base array
          io.seek((offset + base_array_offset).to_i64)
          base_count = read_uint16(io)
          base_records = Array(BaseRecord).new(base_count.to_i)
          base_count.times do
            base_anchor_offsets = Array(UInt16).new(mark_class_count.to_i)
            mark_class_count.times { base_anchor_offsets << read_uint16(io) }
            pos = io.pos

            base_anchors = base_anchor_offsets.map do |bao|
              if bao > 0
                Anchor.parse(io, offset + base_array_offset + bao)
              else
                nil
              end
            end

            io.seek(pos)
            base_records << BaseRecord.new(base_anchors)
          end

          MarkBasePos.new(mark_coverage, base_coverage, mark_class_count, mark_records, base_records)
        end

        private def self.parse_mark_mark_pos(io : IO, offset : UInt32) : GPOSSubtable
          format = read_uint16(io)
          mark1_coverage_offset = read_uint16(io)
          mark2_coverage_offset = read_uint16(io)
          mark_class_count = read_uint16(io)
          mark1_array_offset = read_uint16(io)
          mark2_array_offset = read_uint16(io)

          mark1_coverage = Coverage.parse(io, offset + mark1_coverage_offset)
          mark2_coverage = Coverage.parse(io, offset + mark2_coverage_offset)

          # Parse mark1 array
          io.seek((offset + mark1_array_offset).to_i64)
          mark1_count = read_uint16(io)
          mark1_records = Array(MarkRecord).new(mark1_count.to_i)
          mark1_data = Array(Tuple(UInt16, UInt16)).new(mark1_count.to_i)
          mark1_count.times do
            mark_class = read_uint16(io)
            anchor_offset = read_uint16(io)
            mark1_data << {mark_class, anchor_offset}
          end
          mark1_data.each do |(mark_class, anchor_offset)|
            anchor = Anchor.parse(io, offset + mark1_array_offset + anchor_offset)
            mark1_records << MarkRecord.new(mark_class, anchor)
          end

          # Parse mark2 array (same structure as base array)
          io.seek((offset + mark2_array_offset).to_i64)
          mark2_count = read_uint16(io)
          mark2_records = Array(BaseRecord).new(mark2_count.to_i)
          mark2_count.times do
            anchor_offsets = Array(UInt16).new(mark_class_count.to_i)
            mark_class_count.times { anchor_offsets << read_uint16(io) }
            pos = io.pos

            anchors = anchor_offsets.map do |ao|
              if ao > 0
                Anchor.parse(io, offset + mark2_array_offset + ao)
              else
                nil
              end
            end

            io.seek(pos)
            mark2_records << BaseRecord.new(anchors)
          end

          MarkMarkPos.new(mark1_coverage, mark2_coverage, mark_class_count, mark1_records, mark2_records)
        end

        private def self.parse_extension(io : IO, offset : UInt32, table_data : Bytes) : GPOSSubtable
          format = read_uint16(io)
          extension_lookup_type = GPOSLookupType.from_value(read_uint16(io))
          extension_offset = read_uint32(io)

          parse_subtable(io, offset + extension_offset, extension_lookup_type, table_data)
        end
      end

      # GPOS (Glyph Positioning) table
      class GPOS
        include IOHelpers
        extend IOHelpers

        getter version_major : UInt16
        getter version_minor : UInt16
        getter script_list : ScriptList
        getter feature_list : FeatureList
        getter lookups : Array(GPOSLookup)

        def initialize(
          @version_major : UInt16,
          @version_minor : UInt16,
          @script_list : ScriptList,
          @feature_list : FeatureList,
          @lookups : Array(GPOSLookup)
        )
        end

        # Get kerning adjustment for a pair of glyphs
        def kern(first : UInt16, second : UInt16) : Int16
          lookups_for_feature("kern").each do |lookup_idx|
            lookup = @lookups[lookup_idx]?
            next unless lookup
            next unless lookup.lookup_type.pair_adjustment?

            lookup.subtables.each do |subtable|
              case subtable
              when PairPosFormat1
                if result = subtable.adjustment(first, second)
                  return result[0].x_advance
                end
              when PairPosFormat2
                if result = subtable.adjustment(first, second)
                  return result[0].x_advance
                end
              end
            end
          end
          0_i16
        end

        # Get lookup indices for a feature tag
        def lookups_for_feature(tag : String) : Array(Int32)
          indices = [] of Int32
          @feature_list.features_by_tag(tag).each do |(_idx, ft)|
            ft.lookup_indices.each { |li| indices << li.to_i }
          end
          indices
        end

        # Get a specific lookup
        def lookup(index : Int32) : GPOSLookup?
          @lookups[index]?
        end

        def self.parse(data : Bytes, offset : UInt32, length : UInt32) : GPOS
          table_data = data[offset, length]
          io = IO::Memory.new(table_data)

          version_major = read_uint16(io)
          version_minor = read_uint16(io)
          script_list_offset = read_uint16(io)
          feature_list_offset = read_uint16(io)
          lookup_list_offset = read_uint16(io)

          script_list = ScriptList.parse(io, script_list_offset.to_u32)
          feature_list = FeatureList.parse(io, feature_list_offset.to_u32)

          # Parse lookup list
          io.seek(lookup_list_offset.to_i64)
          lookup_count = read_uint16(io)
          lookup_offsets = Array(UInt16).new(lookup_count.to_i)
          lookup_count.times { lookup_offsets << read_uint16(io) }

          lookups = lookup_offsets.map do |lo|
            GPOSLookup.parse(io, lookup_list_offset.to_u32 + lo, table_data)
          end

          new(version_major, version_minor, script_list, feature_list, lookups)
        end
      end
    end
  end
end
