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

      # Context Positioning Format 1: Simple glyph context
      class ContextPosFormat1 < GPOSSubtable
        getter coverage : Coverage
        getter rule_sets : Array(Array(SequenceRule)?)

        def initialize(@coverage : Coverage, @rule_sets : Array(Array(SequenceRule)?))
        end

        def lookup_type : GPOSLookupType
          GPOSLookupType::Context
        end

        # Get rules for a starting glyph
        def rules_for(glyph_id : UInt16) : Array(SequenceRule)?
          idx = @coverage.coverage_index(glyph_id)
          return nil unless idx
          @rule_sets[idx]?
        end
      end

      # Context Positioning Format 2: Class-based context
      class ContextPosFormat2 < GPOSSubtable
        getter coverage : Coverage
        getter class_def : ClassDef
        getter rule_sets : Array(Array(ClassSequenceRule)?)

        def initialize(@coverage : Coverage, @class_def : ClassDef, @rule_sets : Array(Array(ClassSequenceRule)?))
        end

        def lookup_type : GPOSLookupType
          GPOSLookupType::Context
        end

        # Get rules for a starting glyph (by its class)
        def rules_for(glyph_id : UInt16) : Array(ClassSequenceRule)?
          return nil unless @coverage.covers?(glyph_id)
          class_id = @class_def.class_id(glyph_id)
          @rule_sets[class_id]?
        end
      end

      # Context Positioning Format 3: Coverage-based context
      class ContextPosFormat3 < GPOSSubtable
        getter coverages : Array(Coverage)
        getter lookup_records : Array(SequenceLookupRecord)

        def initialize(@coverages : Array(Coverage), @lookup_records : Array(SequenceLookupRecord))
        end

        def lookup_type : GPOSLookupType
          GPOSLookupType::Context
        end

        # Check if a sequence of glyphs matches all coverages
        def matches?(glyphs : Array(UInt16)) : Bool
          return false if glyphs.size < @coverages.size
          @coverages.each_with_index do |cov, i|
            return false unless cov.covers?(glyphs[i])
          end
          true
        end
      end

      # Chained Context Positioning Format 1: Simple glyph chained context
      class ChainedContextPosFormat1 < GPOSSubtable
        getter coverage : Coverage
        getter rule_sets : Array(Array(ChainedSequenceRule)?)

        def initialize(@coverage : Coverage, @rule_sets : Array(Array(ChainedSequenceRule)?))
        end

        def lookup_type : GPOSLookupType
          GPOSLookupType::ChainingContext
        end

        # Get rules for a starting glyph
        def rules_for(glyph_id : UInt16) : Array(ChainedSequenceRule)?
          idx = @coverage.coverage_index(glyph_id)
          return nil unless idx
          @rule_sets[idx]?
        end
      end

      # Chained Context Positioning Format 2: Class-based chained context
      class ChainedContextPosFormat2 < GPOSSubtable
        getter coverage : Coverage
        getter backtrack_class_def : ClassDef
        getter input_class_def : ClassDef
        getter lookahead_class_def : ClassDef
        getter rule_sets : Array(Array(ChainedClassSequenceRule)?)

        def initialize(
          @coverage : Coverage,
          @backtrack_class_def : ClassDef,
          @input_class_def : ClassDef,
          @lookahead_class_def : ClassDef,
          @rule_sets : Array(Array(ChainedClassSequenceRule)?)
        )
        end

        def lookup_type : GPOSLookupType
          GPOSLookupType::ChainingContext
        end

        # Get rules for a starting glyph (by its input class)
        def rules_for(glyph_id : UInt16) : Array(ChainedClassSequenceRule)?
          return nil unless @coverage.covers?(glyph_id)
          class_id = @input_class_def.class_id(glyph_id)
          @rule_sets[class_id]?
        end
      end

      # Chained Context Positioning Format 3: Coverage-based chained context
      class ChainedContextPosFormat3 < GPOSSubtable
        getter backtrack_coverages : Array(Coverage)
        getter input_coverages : Array(Coverage)
        getter lookahead_coverages : Array(Coverage)
        getter lookup_records : Array(SequenceLookupRecord)

        def initialize(
          @backtrack_coverages : Array(Coverage),
          @input_coverages : Array(Coverage),
          @lookahead_coverages : Array(Coverage),
          @lookup_records : Array(SequenceLookupRecord)
        )
        end

        def lookup_type : GPOSLookupType
          GPOSLookupType::ChainingContext
        end

        # Check if input sequence matches all input coverages
        def input_matches?(glyphs : Array(UInt16)) : Bool
          return false if glyphs.size < @input_coverages.size
          @input_coverages.each_with_index do |cov, i|
            return false unless cov.covers?(glyphs[i])
          end
          true
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
          when .mark_to_ligature?
            # Mark-to-ligature has same structure as mark-to-base
            # but with ligature attachment points instead of base anchors
            parse_mark_base_pos(io, offset)
          when .mark_to_mark?
            parse_mark_mark_pos(io, offset)
          when .context?
            parse_context_pos(io, offset)
          when .chaining_context?
            parse_chained_context_pos(io, offset)
          when .extension?
            parse_extension(io, offset, table_data)
          else
            raise ParseError.new("Unknown GPOS lookup type: #{lookup_type}")
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

        private def self.parse_context_pos(io : IO, offset : UInt32) : GPOSSubtable
          format = read_uint16(io)

          case format
          when 1
            parse_context_pos_format1(io, offset)
          when 2
            parse_context_pos_format2(io, offset)
          when 3
            parse_context_pos_format3(io, offset)
          else
            raise ParseError.new("Unknown ContextPos format: #{format}")
          end
        end

        private def self.parse_context_pos_format1(io : IO, offset : UInt32) : ContextPosFormat1
          coverage_offset = read_uint16(io)
          rule_set_count = read_uint16(io)

          rule_set_offsets = Array(UInt16).new(rule_set_count.to_i)
          rule_set_count.times { rule_set_offsets << read_uint16(io) }

          coverage = Coverage.parse(io, offset + coverage_offset)

          rule_sets = rule_set_offsets.map do |rso|
            if rso == 0
              nil
            else
              io.seek((offset + rso).to_i64)
              rule_count = read_uint16(io)
              rule_offsets = Array(UInt16).new(rule_count.to_i)
              rule_count.times { rule_offsets << read_uint16(io) }

              rule_offsets.map do |ro|
                io.seek((offset + rso + ro).to_i64)
                ContextParser.parse_sequence_rule(io)
              end
            end
          end

          ContextPosFormat1.new(coverage, rule_sets)
        end

        private def self.parse_context_pos_format2(io : IO, offset : UInt32) : ContextPosFormat2
          coverage_offset = read_uint16(io)
          class_def_offset = read_uint16(io)
          rule_set_count = read_uint16(io)

          rule_set_offsets = Array(UInt16).new(rule_set_count.to_i)
          rule_set_count.times { rule_set_offsets << read_uint16(io) }

          coverage = Coverage.parse(io, offset + coverage_offset)
          class_def = ClassDef.parse(io, offset + class_def_offset)

          rule_sets = rule_set_offsets.map do |rso|
            if rso == 0
              nil
            else
              io.seek((offset + rso).to_i64)
              rule_count = read_uint16(io)
              rule_offsets = Array(UInt16).new(rule_count.to_i)
              rule_count.times { rule_offsets << read_uint16(io) }

              rule_offsets.map do |ro|
                io.seek((offset + rso + ro).to_i64)
                ContextParser.parse_class_sequence_rule(io)
              end
            end
          end

          ContextPosFormat2.new(coverage, class_def, rule_sets)
        end

        private def self.parse_context_pos_format3(io : IO, offset : UInt32) : ContextPosFormat3
          glyph_count = read_uint16(io)
          lookup_count = read_uint16(io)

          coverage_offsets = Array(UInt16).new(glyph_count.to_i)
          glyph_count.times { coverage_offsets << read_uint16(io) }

          lookup_records = Array(SequenceLookupRecord).new(lookup_count.to_i)
          lookup_count.times do
            seq_idx = read_uint16(io)
            lookup_idx = read_uint16(io)
            lookup_records << SequenceLookupRecord.new(seq_idx, lookup_idx)
          end

          coverages = coverage_offsets.map { |co| Coverage.parse(io, offset + co) }

          ContextPosFormat3.new(coverages, lookup_records)
        end

        private def self.parse_chained_context_pos(io : IO, offset : UInt32) : GPOSSubtable
          format = read_uint16(io)

          case format
          when 1
            parse_chained_context_pos_format1(io, offset)
          when 2
            parse_chained_context_pos_format2(io, offset)
          when 3
            parse_chained_context_pos_format3(io, offset)
          else
            raise ParseError.new("Unknown ChainedContextPos format: #{format}")
          end
        end

        private def self.parse_chained_context_pos_format1(io : IO, offset : UInt32) : ChainedContextPosFormat1
          coverage_offset = read_uint16(io)
          rule_set_count = read_uint16(io)

          rule_set_offsets = Array(UInt16).new(rule_set_count.to_i)
          rule_set_count.times { rule_set_offsets << read_uint16(io) }

          coverage = Coverage.parse(io, offset + coverage_offset)

          rule_sets = rule_set_offsets.map do |rso|
            if rso == 0
              nil
            else
              io.seek((offset + rso).to_i64)
              rule_count = read_uint16(io)
              rule_offsets = Array(UInt16).new(rule_count.to_i)
              rule_count.times { rule_offsets << read_uint16(io) }

              rule_offsets.map do |ro|
                io.seek((offset + rso + ro).to_i64)
                ContextParser.parse_chained_sequence_rule(io)
              end
            end
          end

          ChainedContextPosFormat1.new(coverage, rule_sets)
        end

        private def self.parse_chained_context_pos_format2(io : IO, offset : UInt32) : ChainedContextPosFormat2
          coverage_offset = read_uint16(io)
          backtrack_class_def_offset = read_uint16(io)
          input_class_def_offset = read_uint16(io)
          lookahead_class_def_offset = read_uint16(io)
          rule_set_count = read_uint16(io)

          rule_set_offsets = Array(UInt16).new(rule_set_count.to_i)
          rule_set_count.times { rule_set_offsets << read_uint16(io) }

          coverage = Coverage.parse(io, offset + coverage_offset)
          
          # Handle potentially zero offsets for class definitions
          backtrack_class_def = if backtrack_class_def_offset > 0
                                   ClassDef.parse(io, offset + backtrack_class_def_offset)
                                 else
                                   ClassDefFormat1.new(0_u16, [] of UInt16)
                                 end
          
          input_class_def = if input_class_def_offset > 0
                               ClassDef.parse(io, offset + input_class_def_offset)
                             else
                               ClassDefFormat1.new(0_u16, [] of UInt16)
                             end
          
          lookahead_class_def = if lookahead_class_def_offset > 0
                                   ClassDef.parse(io, offset + lookahead_class_def_offset)
                                 else
                                   ClassDefFormat1.new(0_u16, [] of UInt16)
                                 end

          rule_sets = rule_set_offsets.map do |rso|
            if rso == 0
              nil
            else
              io.seek((offset + rso).to_i64)
              rule_count = read_uint16(io)
              rule_offsets = Array(UInt16).new(rule_count.to_i)
              rule_count.times { rule_offsets << read_uint16(io) }

              rule_offsets.map do |ro|
                io.seek((offset + rso + ro).to_i64)
                ContextParser.parse_chained_class_sequence_rule(io)
              end
            end
          end

          ChainedContextPosFormat2.new(coverage, backtrack_class_def, input_class_def, lookahead_class_def, rule_sets)
        end

        private def self.parse_chained_context_pos_format3(io : IO, offset : UInt32) : ChainedContextPosFormat3
          backtrack_count = read_uint16(io)
          backtrack_offsets = Array(UInt16).new(backtrack_count.to_i)
          backtrack_count.times { backtrack_offsets << read_uint16(io) }

          input_count = read_uint16(io)
          input_offsets = Array(UInt16).new(input_count.to_i)
          input_count.times { input_offsets << read_uint16(io) }

          lookahead_count = read_uint16(io)
          lookahead_offsets = Array(UInt16).new(lookahead_count.to_i)
          lookahead_count.times { lookahead_offsets << read_uint16(io) }

          lookup_count = read_uint16(io)
          lookup_records = Array(SequenceLookupRecord).new(lookup_count.to_i)
          lookup_count.times do
            seq_idx = read_uint16(io)
            lookup_idx = read_uint16(io)
            lookup_records << SequenceLookupRecord.new(seq_idx, lookup_idx)
          end

          backtrack_coverages = backtrack_offsets.map { |o| Coverage.parse(io, offset + o) }
          input_coverages = input_offsets.map { |o| Coverage.parse(io, offset + o) }
          lookahead_coverages = lookahead_offsets.map { |o| Coverage.parse(io, offset + o) }

          ChainedContextPosFormat3.new(backtrack_coverages, input_coverages, lookahead_coverages, lookup_records)
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
