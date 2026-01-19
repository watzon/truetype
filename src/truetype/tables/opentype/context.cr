module TrueType
  module Tables
    module OpenType
      # Sequence Rule for context lookups (simple context)
      # Matches a sequence of glyphs and applies nested lookups
      struct SequenceRule
        # Glyph IDs to match (excluding first glyph which is matched by coverage)
        getter glyph_sequence : Array(UInt16)
        # Lookup records to apply when matched
        getter lookup_records : Array(SequenceLookupRecord)

        def initialize(@glyph_sequence : Array(UInt16), @lookup_records : Array(SequenceLookupRecord))
        end

        # Number of glyphs in the input sequence (including first glyph)
        def glyph_count : Int32
          @glyph_sequence.size + 1
        end
      end

      # Class-based sequence rule
      struct ClassSequenceRule
        # Class IDs to match (excluding first which is matched by coverage/class)
        getter class_sequence : Array(UInt16)
        # Lookup records to apply when matched
        getter lookup_records : Array(SequenceLookupRecord)

        def initialize(@class_sequence : Array(UInt16), @lookup_records : Array(SequenceLookupRecord))
        end

        # Number of glyphs in the input sequence (including first glyph)
        def glyph_count : Int32
          @class_sequence.size + 1
        end
      end

      # Lookup record specifying which lookup to apply at which position
      struct SequenceLookupRecord
        # Index into the input glyph sequence (0 = first glyph)
        getter sequence_index : UInt16
        # Index into the lookup list
        getter lookup_index : UInt16

        def initialize(@sequence_index : UInt16, @lookup_index : UInt16)
        end
      end

      # Chained Sequence Rule - matches backtrack, input, and lookahead sequences
      struct ChainedSequenceRule
        # Glyphs that must precede the input (in reverse order - closest first)
        getter backtrack_sequence : Array(UInt16)
        # Input glyphs to match (excluding first which is matched by coverage)
        getter input_sequence : Array(UInt16)
        # Glyphs that must follow the input
        getter lookahead_sequence : Array(UInt16)
        # Lookup records to apply when matched
        getter lookup_records : Array(SequenceLookupRecord)

        def initialize(
          @backtrack_sequence : Array(UInt16),
          @input_sequence : Array(UInt16),
          @lookahead_sequence : Array(UInt16),
          @lookup_records : Array(SequenceLookupRecord)
        )
        end

        # Number of input glyphs (including first glyph)
        def input_glyph_count : Int32
          @input_sequence.size + 1
        end
      end

      # Chained class-based sequence rule
      struct ChainedClassSequenceRule
        # Class IDs that must precede the input (in reverse order - closest first)
        getter backtrack_sequence : Array(UInt16)
        # Input class IDs to match (excluding first which is matched by coverage)
        getter input_sequence : Array(UInt16)
        # Class IDs that must follow the input
        getter lookahead_sequence : Array(UInt16)
        # Lookup records to apply when matched
        getter lookup_records : Array(SequenceLookupRecord)

        def initialize(
          @backtrack_sequence : Array(UInt16),
          @input_sequence : Array(UInt16),
          @lookahead_sequence : Array(UInt16),
          @lookup_records : Array(SequenceLookupRecord)
        )
        end

        # Number of input glyphs (including first glyph)
        def input_glyph_count : Int32
          @input_sequence.size + 1
        end
      end

      # Helper module for parsing context lookup data
      module ContextParser
        extend IOHelpers

        # Parse a SequenceRule
        def self.parse_sequence_rule(io : IO) : SequenceRule
          glyph_count = read_uint16(io)
          lookup_count = read_uint16(io)

          # Glyph sequence (glyph_count - 1 glyphs, first is matched by coverage)
          glyph_sequence = Array(UInt16).new((glyph_count - 1).clamp(0, 0xFFFF).to_i)
          (glyph_count - 1).times { glyph_sequence << read_uint16(io) } if glyph_count > 1

          # Lookup records
          lookup_records = Array(SequenceLookupRecord).new(lookup_count.to_i)
          lookup_count.times do
            seq_idx = read_uint16(io)
            lookup_idx = read_uint16(io)
            lookup_records << SequenceLookupRecord.new(seq_idx, lookup_idx)
          end

          SequenceRule.new(glyph_sequence, lookup_records)
        end

        # Parse a ClassSequenceRule
        def self.parse_class_sequence_rule(io : IO) : ClassSequenceRule
          glyph_count = read_uint16(io)
          lookup_count = read_uint16(io)

          # Class sequence (glyph_count - 1 classes)
          class_sequence = Array(UInt16).new((glyph_count - 1).clamp(0, 0xFFFF).to_i)
          (glyph_count - 1).times { class_sequence << read_uint16(io) } if glyph_count > 1

          # Lookup records
          lookup_records = Array(SequenceLookupRecord).new(lookup_count.to_i)
          lookup_count.times do
            seq_idx = read_uint16(io)
            lookup_idx = read_uint16(io)
            lookup_records << SequenceLookupRecord.new(seq_idx, lookup_idx)
          end

          ClassSequenceRule.new(class_sequence, lookup_records)
        end

        # Parse a ChainedSequenceRule
        def self.parse_chained_sequence_rule(io : IO) : ChainedSequenceRule
          # Backtrack sequence
          backtrack_count = read_uint16(io)
          backtrack_sequence = Array(UInt16).new(backtrack_count.to_i)
          backtrack_count.times { backtrack_sequence << read_uint16(io) }

          # Input sequence
          input_count = read_uint16(io)
          input_sequence = Array(UInt16).new((input_count - 1).clamp(0, 0xFFFF).to_i)
          (input_count - 1).times { input_sequence << read_uint16(io) } if input_count > 1

          # Lookahead sequence
          lookahead_count = read_uint16(io)
          lookahead_sequence = Array(UInt16).new(lookahead_count.to_i)
          lookahead_count.times { lookahead_sequence << read_uint16(io) }

          # Lookup records
          lookup_count = read_uint16(io)
          lookup_records = Array(SequenceLookupRecord).new(lookup_count.to_i)
          lookup_count.times do
            seq_idx = read_uint16(io)
            lookup_idx = read_uint16(io)
            lookup_records << SequenceLookupRecord.new(seq_idx, lookup_idx)
          end

          ChainedSequenceRule.new(backtrack_sequence, input_sequence, lookahead_sequence, lookup_records)
        end

        # Parse a ChainedClassSequenceRule
        def self.parse_chained_class_sequence_rule(io : IO) : ChainedClassSequenceRule
          # Backtrack sequence
          backtrack_count = read_uint16(io)
          backtrack_sequence = Array(UInt16).new(backtrack_count.to_i)
          backtrack_count.times { backtrack_sequence << read_uint16(io) }

          # Input sequence
          input_count = read_uint16(io)
          input_sequence = Array(UInt16).new((input_count - 1).clamp(0, 0xFFFF).to_i)
          (input_count - 1).times { input_sequence << read_uint16(io) } if input_count > 1

          # Lookahead sequence
          lookahead_count = read_uint16(io)
          lookahead_sequence = Array(UInt16).new(lookahead_count.to_i)
          lookahead_count.times { lookahead_sequence << read_uint16(io) }

          # Lookup records
          lookup_count = read_uint16(io)
          lookup_records = Array(SequenceLookupRecord).new(lookup_count.to_i)
          lookup_count.times do
            seq_idx = read_uint16(io)
            lookup_idx = read_uint16(io)
            lookup_records << SequenceLookupRecord.new(seq_idx, lookup_idx)
          end

          ChainedClassSequenceRule.new(backtrack_sequence, input_sequence, lookahead_sequence, lookup_records)
        end
      end
    end
  end
end
