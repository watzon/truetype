module TrueType
  module Tables
    module Math
      # A single glyph variant (e.g., larger parenthesis)
      struct MathGlyphVariant
        include IOHelpers

        # Glyph ID of the variant
        getter glyph_id : UInt16

        # Advance measurement (width or height depending on axis)
        getter advance_measurement : UInt16

        def initialize(@glyph_id : UInt16, @advance_measurement : UInt16)
        end

        def self.parse(io : IO::Memory) : MathGlyphVariant
          glyph_id = read_uint16(io)
          advance = read_uint16(io)
          new(glyph_id, advance)
        end

        extend IOHelpers
      end

      # A part of a glyph assembly (for building stretchy glyphs)
      struct GlyphPartRecord
        include IOHelpers

        # Glyph ID for this part
        getter glyph_id : UInt16

        # Length of connector at start of part
        getter start_connector_length : UInt16

        # Length of connector at end of part
        getter end_connector_length : UInt16

        # Full advance of the part
        getter full_advance : UInt16

        # Part flags (bit 0 = extender flag)
        getter part_flags : UInt16

        def initialize(
          @glyph_id : UInt16,
          @start_connector_length : UInt16,
          @end_connector_length : UInt16,
          @full_advance : UInt16,
          @part_flags : UInt16
        )
        end

        def self.parse(io : IO::Memory) : GlyphPartRecord
          glyph_id = read_uint16(io)
          start_conn = read_uint16(io)
          end_conn = read_uint16(io)
          full_adv = read_uint16(io)
          flags = read_uint16(io)
          new(glyph_id, start_conn, end_conn, full_adv, flags)
        end

        # Check if this part is an extender (can be repeated)
        def extender? : Bool
          (@part_flags & 0x0001) != 0
        end

        extend IOHelpers
      end

      # Assembly instructions for building a stretchy glyph from parts
      class GlyphAssembly
        include IOHelpers

        # Italics correction for the assembled glyph
        getter italics_correction : MathValueRecord

        # Parts to assemble the glyph
        getter parts : Array(GlyphPartRecord)

        def initialize(@italics_correction : MathValueRecord, @parts : Array(GlyphPartRecord))
        end

        def self.parse(data : Bytes, offset : UInt32) : GlyphAssembly
          io = IO::Memory.new(data[offset.to_i..])

          italics_correction = MathValueRecord.parse(io)
          part_count = read_uint16(io)

          parts = Array(GlyphPartRecord).new(part_count.to_i)
          part_count.times do
            parts << GlyphPartRecord.parse(io)
          end

          new(italics_correction, parts)
        end

        # Get the minimum overlap required between parts
        # (Caller should provide minConnectorOverlap from MathVariants)
        def min_connector_overlap(table_min : UInt16) : UInt16
          # The minimum overlap is the minimum of all start/end connectors
          min = table_min.to_u32
          @parts.each_with_index do |part, i|
            if i > 0
              prev_end = @parts[i - 1].end_connector_length.to_u32
              curr_start = part.start_connector_length.to_u32
              connector_min = ::Math.min(prev_end, curr_start)
              min = ::Math.min(min, connector_min) if connector_min > 0
            end
          end
          min.to_u16
        end

        extend IOHelpers
      end

      # Glyph construction data - variants and optional assembly
      class MathGlyphConstruction
        include IOHelpers

        # Assembly for building stretchy glyph (optional)
        getter glyph_assembly : GlyphAssembly?

        # Pre-defined size variants (smallest first)
        getter variants : Array(MathGlyphVariant)

        def initialize(@glyph_assembly : GlyphAssembly?, @variants : Array(MathGlyphVariant))
        end

        def self.parse(data : Bytes, offset : UInt32) : MathGlyphConstruction
          io = IO::Memory.new(data[offset.to_i..])

          assembly_offset = read_uint16(io)
          variant_count = read_uint16(io)

          # Read variants
          variants = Array(MathGlyphVariant).new(variant_count.to_i)
          variant_count.times do
            variants << MathGlyphVariant.parse(io)
          end

          # Parse assembly if present
          assembly : GlyphAssembly? = nil
          if assembly_offset != 0
            assembly = GlyphAssembly.parse(data, offset + assembly_offset)
          end

          new(assembly, variants)
        end

        # Check if this glyph can be assembled from parts
        def has_assembly? : Bool
          !@glyph_assembly.nil?
        end

        # Get the best variant for a given target size
        def variant_for_size(target_size : UInt16) : MathGlyphVariant?
          # Return the smallest variant that is >= target size
          # or the largest variant if none meet the target
          @variants.find { |v| v.advance_measurement >= target_size } || @variants.last?
        end

        extend IOHelpers
      end

      # MathVariants subtable - glyph variants for stretchy characters
      class MathVariants
        include IOHelpers

        # Minimum overlap for connectors in glyph assembly
        getter min_connector_overlap : UInt16

        # Coverage for vertical variants (brackets, integrals, etc.)
        @vert_coverage : OpenType::Coverage?

        # Coverage for horizontal variants (arrows, overbars, etc.)
        @horiz_coverage : OpenType::Coverage?

        # Vertical glyph constructions
        getter vert_constructions : Array(MathGlyphConstruction)

        # Horizontal glyph constructions
        getter horiz_constructions : Array(MathGlyphConstruction)

        def initialize(
          @min_connector_overlap : UInt16,
          @vert_coverage : OpenType::Coverage?,
          @horiz_coverage : OpenType::Coverage?,
          @vert_constructions : Array(MathGlyphConstruction),
          @horiz_constructions : Array(MathGlyphConstruction)
        )
        end

        def self.parse(data : Bytes, offset : UInt32) : MathVariants
          io = IO::Memory.new(data[offset.to_i..])

          min_connector_overlap = read_uint16(io)
          vert_coverage_offset = read_uint16(io)
          horiz_coverage_offset = read_uint16(io)
          vert_count = read_uint16(io)
          horiz_count = read_uint16(io)

          # Read construction offsets
          vert_offsets = Array(UInt16).new(vert_count.to_i)
          vert_count.times { vert_offsets << read_uint16(io) }

          horiz_offsets = Array(UInt16).new(horiz_count.to_i)
          horiz_count.times { horiz_offsets << read_uint16(io) }

          # Parse coverages
          data_io = IO::Memory.new(data)
          vert_coverage : OpenType::Coverage? = nil
          if vert_coverage_offset != 0
            vert_coverage = OpenType::Coverage.parse(data_io, offset + vert_coverage_offset)
          end

          horiz_coverage : OpenType::Coverage? = nil
          if horiz_coverage_offset != 0
            horiz_coverage = OpenType::Coverage.parse(data_io, offset + horiz_coverage_offset)
          end

          # Parse constructions
          vert_constructions = vert_offsets.map do |off|
            MathGlyphConstruction.parse(data, offset + off)
          end

          horiz_constructions = horiz_offsets.map do |off|
            MathGlyphConstruction.parse(data, offset + off)
          end

          new(
            min_connector_overlap,
            vert_coverage,
            horiz_coverage,
            vert_constructions,
            horiz_constructions
          )
        end

        # Check if glyph has vertical variants
        def has_vertical_variants?(glyph_id : UInt16) : Bool
          @vert_coverage.try(&.covers?(glyph_id)) || false
        end

        # Check if glyph has horizontal variants
        def has_horizontal_variants?(glyph_id : UInt16) : Bool
          @horiz_coverage.try(&.covers?(glyph_id)) || false
        end

        # Get vertical construction for glyph
        def vertical_construction(glyph_id : UInt16) : MathGlyphConstruction?
          return nil unless coverage = @vert_coverage
          index = coverage.coverage_index(glyph_id)
          return nil unless index
          return nil if index >= @vert_constructions.size
          @vert_constructions[index]
        end

        # Get horizontal construction for glyph
        def horizontal_construction(glyph_id : UInt16) : MathGlyphConstruction?
          return nil unless coverage = @horiz_coverage
          index = coverage.coverage_index(glyph_id)
          return nil unless index
          return nil if index >= @horiz_constructions.size
          @horiz_constructions[index]
        end

        # Get vertical variants for glyph
        def vertical_variants(glyph_id : UInt16) : Array(MathGlyphVariant)?
          vertical_construction(glyph_id).try(&.variants)
        end

        # Get horizontal variants for glyph
        def horizontal_variants(glyph_id : UInt16) : Array(MathGlyphVariant)?
          horizontal_construction(glyph_id).try(&.variants)
        end

        # Get vertical assembly for glyph
        def vertical_assembly(glyph_id : UInt16) : GlyphAssembly?
          vertical_construction(glyph_id).try(&.glyph_assembly)
        end

        # Get horizontal assembly for glyph
        def horizontal_assembly(glyph_id : UInt16) : GlyphAssembly?
          horizontal_construction(glyph_id).try(&.glyph_assembly)
        end

        extend IOHelpers
      end
    end
  end
end
