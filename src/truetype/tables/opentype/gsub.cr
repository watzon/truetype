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
          when .extension_subst?
            parse_extension_subst(io, base_offset, table_data)
          else
            # Context and chaining context are complex - placeholder
            SingleSubstFormat1.new(CoverageFormat1.new([] of UInt16), 0_i16)
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
