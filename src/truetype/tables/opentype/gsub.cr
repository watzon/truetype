module TrueType
  module Tables
    module OpenType
      # GSUB lookup types
      enum GSUBLookupType : UInt16
        Single              = 1 # Replace single glyph with another
        Multiple            = 2 # Replace single glyph with multiple
        Alternate           = 3 # Replace single glyph with one of several
        Ligature            = 4 # Replace multiple glyphs with one
        Context             = 5 # Context-dependent substitution
        ChainingContext     = 6 # Chained context substitution
        ExtensionSubst      = 7 # Extension mechanism
        ReverseChainingCtx  = 8 # Reverse chaining context
      end

      # Abstract base for all GSUB subtables
      abstract class GSUBSubtable
        include IOHelpers
        extend IOHelpers

        abstract def lookup_type : GSUBLookupType
      end

      # Single Substitution Format 1: Add delta to glyph ID
      class SingleSubstFormat1 < GSUBSubtable
        getter coverage : Coverage
        getter delta : Int16

        def initialize(@coverage : Coverage, @delta : Int16)
        end

        def lookup_type : GSUBLookupType
          GSUBLookupType::Single
        end

        def substitute(glyph_id : UInt16) : UInt16?
          return nil unless @coverage.covers?(glyph_id)
          (glyph_id.to_i32 + @delta.to_i32).to_u16
        end
      end

      # Single Substitution Format 2: Direct mapping array
      class SingleSubstFormat2 < GSUBSubtable
        getter coverage : Coverage
        getter substitutes : Array(UInt16)

        def initialize(@coverage : Coverage, @substitutes : Array(UInt16))
        end

        def lookup_type : GSUBLookupType
          GSUBLookupType::Single
        end

        def substitute(glyph_id : UInt16) : UInt16?
          idx = @coverage.coverage_index(glyph_id)
          return nil unless idx
          @substitutes[idx]?
        end
      end

      # Multiple Substitution: One glyph to many
      class MultipleSubst < GSUBSubtable
        getter coverage : Coverage
        getter sequences : Array(Array(UInt16))

        def initialize(@coverage : Coverage, @sequences : Array(Array(UInt16)))
        end

        def lookup_type : GSUBLookupType
          GSUBLookupType::Multiple
        end

        def substitute(glyph_id : UInt16) : Array(UInt16)?
          idx = @coverage.coverage_index(glyph_id)
          return nil unless idx
          @sequences[idx]?
        end
      end

      # Alternate Substitution: One glyph to one of several alternates
      class AlternateSubst < GSUBSubtable
        getter coverage : Coverage
        getter alternate_sets : Array(Array(UInt16))

        def initialize(@coverage : Coverage, @alternate_sets : Array(Array(UInt16)))
        end

        def lookup_type : GSUBLookupType
          GSUBLookupType::Alternate
        end

        def alternates(glyph_id : UInt16) : Array(UInt16)?
          idx = @coverage.coverage_index(glyph_id)
          return nil unless idx
          @alternate_sets[idx]?
        end
      end

      # Ligature component
      struct LigatureEntry
        getter ligature_glyph : UInt16
        getter component_glyphs : Array(UInt16) # Excludes first glyph

        def initialize(@ligature_glyph : UInt16, @component_glyphs : Array(UInt16))
        end
      end

      # Ligature Substitution: Multiple glyphs to one
      class LigatureSubst < GSUBSubtable
        getter coverage : Coverage
        getter ligature_sets : Array(Array(LigatureEntry))

        def initialize(@coverage : Coverage, @ligature_sets : Array(Array(LigatureEntry)))
        end

        def lookup_type : GSUBLookupType
          GSUBLookupType::Ligature
        end

        # Get ligatures starting with a given glyph
        def ligatures_for(first_glyph : UInt16) : Array(LigatureEntry)?
          idx = @coverage.coverage_index(first_glyph)
          return nil unless idx
          @ligature_sets[idx]?
        end
      end

      # Context Substitution Format 1: Simple glyph context
      class ContextSubstFormat1 < GSUBSubtable
        getter coverage : Coverage
        getter rule_sets : Array(Array(SequenceRule)?)

        def initialize(@coverage : Coverage, @rule_sets : Array(Array(SequenceRule)?))
        end

        def lookup_type : GSUBLookupType
          GSUBLookupType::Context
        end

        # Get rules for a starting glyph
        def rules_for(glyph_id : UInt16) : Array(SequenceRule)?
          idx = @coverage.coverage_index(glyph_id)
          return nil unless idx
          @rule_sets[idx]?
        end
      end

      # Context Substitution Format 2: Class-based context
      class ContextSubstFormat2 < GSUBSubtable
        getter coverage : Coverage
        getter class_def : ClassDef
        getter rule_sets : Array(Array(ClassSequenceRule)?)

        def initialize(@coverage : Coverage, @class_def : ClassDef, @rule_sets : Array(Array(ClassSequenceRule)?))
        end

        def lookup_type : GSUBLookupType
          GSUBLookupType::Context
        end

        # Get rules for a starting glyph (by its class)
        def rules_for(glyph_id : UInt16) : Array(ClassSequenceRule)?
          return nil unless @coverage.covers?(glyph_id)
          class_id = @class_def.class_id(glyph_id)
          @rule_sets[class_id]?
        end
      end

      # Context Substitution Format 3: Coverage-based context
      class ContextSubstFormat3 < GSUBSubtable
        getter coverages : Array(Coverage)
        getter lookup_records : Array(SequenceLookupRecord)

        def initialize(@coverages : Array(Coverage), @lookup_records : Array(SequenceLookupRecord))
        end

        def lookup_type : GSUBLookupType
          GSUBLookupType::Context
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

      # Chained Context Substitution Format 1: Simple glyph chained context
      class ChainedContextSubstFormat1 < GSUBSubtable
        getter coverage : Coverage
        getter rule_sets : Array(Array(ChainedSequenceRule)?)

        def initialize(@coverage : Coverage, @rule_sets : Array(Array(ChainedSequenceRule)?))
        end

        def lookup_type : GSUBLookupType
          GSUBLookupType::ChainingContext
        end

        # Get rules for a starting glyph
        def rules_for(glyph_id : UInt16) : Array(ChainedSequenceRule)?
          idx = @coverage.coverage_index(glyph_id)
          return nil unless idx
          @rule_sets[idx]?
        end
      end

      # Chained Context Substitution Format 2: Class-based chained context
      class ChainedContextSubstFormat2 < GSUBSubtable
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

        def lookup_type : GSUBLookupType
          GSUBLookupType::ChainingContext
        end

        # Get rules for a starting glyph (by its input class)
        def rules_for(glyph_id : UInt16) : Array(ChainedClassSequenceRule)?
          return nil unless @coverage.covers?(glyph_id)
          class_id = @input_class_def.class_id(glyph_id)
          @rule_sets[class_id]?
        end
      end

      # Chained Context Substitution Format 3: Coverage-based chained context
      class ChainedContextSubstFormat3 < GSUBSubtable
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

        def lookup_type : GSUBLookupType
          GSUBLookupType::ChainingContext
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

      # Reverse Chaining Context Substitution (Type 8)
      # Processes glyphs from end to beginning
      class ReverseChainSubst < GSUBSubtable
        getter backtrack_coverages : Array(Coverage)
        getter input_coverage : Coverage
        getter lookahead_coverages : Array(Coverage)
        getter substitute_glyphs : Array(UInt16)

        def initialize(
          @backtrack_coverages : Array(Coverage),
          @input_coverage : Coverage,
          @lookahead_coverages : Array(Coverage),
          @substitute_glyphs : Array(UInt16)
        )
        end

        def lookup_type : GSUBLookupType
          GSUBLookupType::ReverseChainingCtx
        end

        # Get substitute glyph for input glyph
        def substitute(glyph_id : UInt16) : UInt16?
          idx = @input_coverage.coverage_index(glyph_id)
          return nil unless idx
          @substitute_glyphs[idx]?
        end
      end

      # GSUB Lookup table
      class GSUBLookup
        include IOHelpers
        extend IOHelpers

        getter lookup_type : GSUBLookupType
        getter lookup_flag : UInt16
        getter subtables : Array(GSUBSubtable)
        getter mark_filtering_set : UInt16?

        # Lookup flag bits
        RIGHT_TO_LEFT         = 0x0001_u16
        IGNORE_BASE_GLYPHS    = 0x0002_u16
        IGNORE_LIGATURES      = 0x0004_u16
        IGNORE_MARKS          = 0x0008_u16
        USE_MARK_FILTERING_SET = 0x0010_u16
        MARK_ATTACH_TYPE_MASK = 0xFF00_u16

        def initialize(@lookup_type : GSUBLookupType, @lookup_flag : UInt16,
                       @subtables : Array(GSUBSubtable), @mark_filtering_set : UInt16?)
        end

        def right_to_left? : Bool
          (@lookup_flag & RIGHT_TO_LEFT) != 0
        end

        def ignore_base_glyphs? : Bool
          (@lookup_flag & IGNORE_BASE_GLYPHS) != 0
        end

        def ignore_ligatures? : Bool
          (@lookup_flag & IGNORE_LIGATURES) != 0
        end

        def ignore_marks? : Bool
          (@lookup_flag & IGNORE_MARKS) != 0
        end

        def self.parse(io : IO, offset : UInt32, table_data : Bytes) : GSUBLookup
          io.seek(offset.to_i64)
          base_offset = offset

          lookup_type_raw = read_uint16(io)
          lookup_type = GSUBLookupType.from_value(lookup_type_raw)
          lookup_flag = read_uint16(io)
          subtable_count = read_uint16(io)

          subtable_offsets = Array(UInt16).new(subtable_count.to_i)
          subtable_count.times do
            subtable_offsets << read_uint16(io)
          end

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

        private def self.parse_subtable(io : IO, offset : UInt32, lookup_type : GSUBLookupType, table_data : Bytes) : GSUBSubtable
          io.seek(offset.to_i64)
          base_offset = offset

          case lookup_type
          when .single?
            parse_single_subst(io, base_offset)
          when .multiple?
            parse_multiple_subst(io, base_offset)
          when .alternate?
            parse_alternate_subst(io, base_offset)
          when .ligature?
            parse_ligature_subst(io, base_offset)
          when .context?
            parse_context_subst(io, base_offset)
          when .chaining_context?
            parse_chained_context_subst(io, base_offset)
          when .extension_subst?
            parse_extension_subst(io, base_offset, table_data)
          when .reverse_chaining_ctx?
            parse_reverse_chain_subst(io, base_offset)
          else
            raise ParseError.new("Unknown GSUB lookup type: #{lookup_type}")
          end
        end

        private def self.parse_single_subst(io : IO, offset : UInt32) : GSUBSubtable
          format = read_uint16(io)
          coverage_offset = read_uint16(io)
          coverage = Coverage.parse(io, offset + coverage_offset)

          case format
          when 1
            io.seek((offset + 4).to_i64)
            delta = read_int16(io)
            SingleSubstFormat1.new(coverage, delta)
          when 2
            io.seek((offset + 4).to_i64)
            glyph_count = read_uint16(io)
            substitutes = Array(UInt16).new(glyph_count.to_i)
            glyph_count.times { substitutes << read_uint16(io) }
            SingleSubstFormat2.new(coverage, substitutes)
          else
            raise ParseError.new("Unknown SingleSubst format: #{format}")
          end
        end

        private def self.parse_multiple_subst(io : IO, offset : UInt32) : GSUBSubtable
          format = read_uint16(io)
          coverage_offset = read_uint16(io)
          sequence_count = read_uint16(io)

          sequence_offsets = Array(UInt16).new(sequence_count.to_i)
          sequence_count.times { sequence_offsets << read_uint16(io) }

          coverage = Coverage.parse(io, offset + coverage_offset)

          sequences = sequence_offsets.map do |so|
            io.seek((offset + so).to_i64)
            glyph_count = read_uint16(io)
            glyphs = Array(UInt16).new(glyph_count.to_i)
            glyph_count.times { glyphs << read_uint16(io) }
            glyphs
          end

          MultipleSubst.new(coverage, sequences)
        end

        private def self.parse_alternate_subst(io : IO, offset : UInt32) : GSUBSubtable
          format = read_uint16(io)
          coverage_offset = read_uint16(io)
          alt_set_count = read_uint16(io)

          alt_set_offsets = Array(UInt16).new(alt_set_count.to_i)
          alt_set_count.times { alt_set_offsets << read_uint16(io) }

          coverage = Coverage.parse(io, offset + coverage_offset)

          alternate_sets = alt_set_offsets.map do |aso|
            io.seek((offset + aso).to_i64)
            glyph_count = read_uint16(io)
            glyphs = Array(UInt16).new(glyph_count.to_i)
            glyph_count.times { glyphs << read_uint16(io) }
            glyphs
          end

          AlternateSubst.new(coverage, alternate_sets)
        end

        private def self.parse_ligature_subst(io : IO, offset : UInt32) : GSUBSubtable
          format = read_uint16(io)
          coverage_offset = read_uint16(io)
          lig_set_count = read_uint16(io)

          lig_set_offsets = Array(UInt16).new(lig_set_count.to_i)
          lig_set_count.times { lig_set_offsets << read_uint16(io) }

          coverage = Coverage.parse(io, offset + coverage_offset)

          ligature_sets = lig_set_offsets.map do |lso|
            io.seek((offset + lso).to_i64)
            lig_count = read_uint16(io)
            lig_offsets = Array(UInt16).new(lig_count.to_i)
            lig_count.times { lig_offsets << read_uint16(io) }

            lig_offsets.map do |lo|
              io.seek((offset + lso + lo).to_i64)
              lig_glyph = read_uint16(io)
              comp_count = read_uint16(io)
              components = Array(UInt16).new((comp_count - 1).to_i.clamp(0, Int32::MAX))
              (comp_count - 1).times { components << read_uint16(io) } if comp_count > 1
              LigatureEntry.new(lig_glyph, components)
            end
          end

          LigatureSubst.new(coverage, ligature_sets)
        end

        private def self.parse_extension_subst(io : IO, offset : UInt32, table_data : Bytes) : GSUBSubtable
          format = read_uint16(io)
          extension_lookup_type = GSUBLookupType.from_value(read_uint16(io))
          extension_offset = read_uint32(io)

          parse_subtable(io, offset + extension_offset, extension_lookup_type, table_data)
        end

        private def self.parse_context_subst(io : IO, offset : UInt32) : GSUBSubtable
          format = read_uint16(io)

          case format
          when 1
            parse_context_subst_format1(io, offset)
          when 2
            parse_context_subst_format2(io, offset)
          when 3
            parse_context_subst_format3(io, offset)
          else
            raise ParseError.new("Unknown ContextSubst format: #{format}")
          end
        end

        private def self.parse_context_subst_format1(io : IO, offset : UInt32) : ContextSubstFormat1
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

          ContextSubstFormat1.new(coverage, rule_sets)
        end

        private def self.parse_context_subst_format2(io : IO, offset : UInt32) : ContextSubstFormat2
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

          ContextSubstFormat2.new(coverage, class_def, rule_sets)
        end

        private def self.parse_context_subst_format3(io : IO, offset : UInt32) : ContextSubstFormat3
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

          ContextSubstFormat3.new(coverages, lookup_records)
        end

        private def self.parse_chained_context_subst(io : IO, offset : UInt32) : GSUBSubtable
          format = read_uint16(io)

          case format
          when 1
            parse_chained_context_subst_format1(io, offset)
          when 2
            parse_chained_context_subst_format2(io, offset)
          when 3
            parse_chained_context_subst_format3(io, offset)
          else
            raise ParseError.new("Unknown ChainedContextSubst format: #{format}")
          end
        end

        private def self.parse_chained_context_subst_format1(io : IO, offset : UInt32) : ChainedContextSubstFormat1
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

          ChainedContextSubstFormat1.new(coverage, rule_sets)
        end

        private def self.parse_chained_context_subst_format2(io : IO, offset : UInt32) : ChainedContextSubstFormat2
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

          ChainedContextSubstFormat2.new(coverage, backtrack_class_def, input_class_def, lookahead_class_def, rule_sets)
        end

        private def self.parse_chained_context_subst_format3(io : IO, offset : UInt32) : ChainedContextSubstFormat3
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

          ChainedContextSubstFormat3.new(backtrack_coverages, input_coverages, lookahead_coverages, lookup_records)
        end

        private def self.parse_reverse_chain_subst(io : IO, offset : UInt32) : ReverseChainSubst
          format = read_uint16(io)
          # Only format 1 exists for reverse chain
          coverage_offset = read_uint16(io)

          backtrack_count = read_uint16(io)
          backtrack_offsets = Array(UInt16).new(backtrack_count.to_i)
          backtrack_count.times { backtrack_offsets << read_uint16(io) }

          lookahead_count = read_uint16(io)
          lookahead_offsets = Array(UInt16).new(lookahead_count.to_i)
          lookahead_count.times { lookahead_offsets << read_uint16(io) }

          substitute_count = read_uint16(io)
          substitute_glyphs = Array(UInt16).new(substitute_count.to_i)
          substitute_count.times { substitute_glyphs << read_uint16(io) }

          input_coverage = Coverage.parse(io, offset + coverage_offset)
          backtrack_coverages = backtrack_offsets.map { |o| Coverage.parse(io, offset + o) }
          lookahead_coverages = lookahead_offsets.map { |o| Coverage.parse(io, offset + o) }

          ReverseChainSubst.new(backtrack_coverages, input_coverage, lookahead_coverages, substitute_glyphs)
        end
      end

      # GSUB (Glyph Substitution) table
      class GSUB
        include IOHelpers
        extend IOHelpers

        getter version_major : UInt16
        getter version_minor : UInt16
        getter script_list : ScriptList
        getter feature_list : FeatureList
        getter lookups : Array(GSUBLookup)

        def initialize(
          @version_major : UInt16,
          @version_minor : UInt16,
          @script_list : ScriptList,
          @feature_list : FeatureList,
          @lookups : Array(GSUBLookup)
        )
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
        def lookup(index : Int32) : GSUBLookup?
          @lookups[index]?
        end

        def self.parse(data : Bytes, offset : UInt32, length : UInt32) : GSUB
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
            GSUBLookup.parse(io, lookup_list_offset.to_u32 + lo, table_data)
          end

          new(version_major, version_minor, script_list, feature_list, lookups)
        end
      end
    end
  end
end
