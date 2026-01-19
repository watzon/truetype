# MVAR table - Metrics Variations
# Contains variation data for font-wide metrics like ascender, descender, etc.
#
# Reference: https://learn.microsoft.com/en-us/typography/opentype/spec/mvar

module TrueType
  module Tables
    module Variations
      # Represents a single value record in the MVAR table.
      struct MvarValueRecord
        # 4-byte tag identifying the metric value
        getter value_tag : String

        # Outer index into ItemVariationStore
        getter delta_set_outer_index : UInt16

        # Inner index into ItemVariationStore
        getter delta_set_inner_index : UInt16

        def initialize(@value_tag : String, @delta_set_outer_index : UInt16, @delta_set_inner_index : UInt16)
        end
      end

      # The MVAR table stores variation data for font-wide metrics.
      # These metrics affect the overall layout of text rather than individual glyphs.
      class Mvar
        include IOHelpers

        # Table version (major.minor)
        getter major_version : UInt16
        getter minor_version : UInt16

        # Size of value record (must be 8)
        getter value_record_size : UInt16

        # Number of value records
        getter value_record_count : UInt16

        # Offset to item variation store
        getter item_variation_store_offset : UInt16

        # The item variation store
        getter item_variation_store : ItemVariationStore

        # Value records (metric tag -> indices)
        getter value_records : Array(MvarValueRecord)

        # Pre-built lookup for fast access by tag
        @value_record_map : Hash(String, MvarValueRecord)

        def initialize(
          @major_version : UInt16,
          @minor_version : UInt16,
          @value_record_size : UInt16,
          @value_record_count : UInt16,
          @item_variation_store_offset : UInt16,
          @item_variation_store : ItemVariationStore,
          @value_records : Array(MvarValueRecord)
        )
          @value_record_map = {} of String => MvarValueRecord
          @value_records.each { |vr| @value_record_map[vr.value_tag] = vr }
        end

        def self.parse(data : Bytes) : Mvar
          io = IO::Memory.new(data)

          major_version = read_uint16(io)
          minor_version = read_uint16(io)
          _reserved = read_uint16(io) # Reserved, set to 0
          value_record_size = read_uint16(io)
          value_record_count = read_uint16(io)
          item_variation_store_offset = read_uint16(io)

          # Parse value records
          value_records = Array(MvarValueRecord).new(value_record_count.to_i)
          value_record_count.times do
            tag_bytes = Bytes.new(4)
            io.read_fully(tag_bytes)
            value_tag = String.new(tag_bytes)
            delta_set_outer_index = read_uint16(io)
            delta_set_inner_index = read_uint16(io)
            value_records << MvarValueRecord.new(value_tag, delta_set_outer_index, delta_set_inner_index)
          end

          # Parse item variation store
          item_variation_store = ItemVariationStore.parse(data, item_variation_store_offset.to_u32)

          new(
            major_version,
            minor_version,
            value_record_size,
            value_record_count,
            item_variation_store_offset,
            item_variation_store,
            value_records
          )
        end

        # Get the delta for a metric at the given normalized coordinates.
        # Common metric tags:
        #   hasc - horizontal ascender (OS/2.sTypoAscender)
        #   hdsc - horizontal descender (OS/2.sTypoDescender)
        #   hlgp - horizontal line gap (OS/2.sTypoLineGap)
        #   hcla - horizontal clipping ascent (OS/2.usWinAscent)
        #   hcld - horizontal clipping descent (OS/2.usWinDescent)
        #   vasc - vertical ascender (vhea.ascent)
        #   vdsc - vertical descender (vhea.descent)
        #   vlgp - vertical line gap (vhea.lineGap)
        #   hcrs - horizontal caret rise (hhea.caretSlopeRise)
        #   hcrn - horizontal caret run (hhea.caretSlopeRun)
        #   hcof - horizontal caret offset (hhea.caretOffset)
        #   vcrs - vertical caret rise (vhea.caretSlopeRise)
        #   vcrn - vertical caret run (vhea.caretSlopeRun)
        #   vcof - vertical caret offset (vhea.caretOffset)
        #   xhgt - x height (OS/2.sxHeight)
        #   cpht - cap height (OS/2.sCapHeight)
        #   sbxs - subscript em x size (OS/2.ySubscriptXSize)
        #   sbys - subscript em y size (OS/2.ySubscriptYSize)
        #   sbxo - subscript em x offset (OS/2.ySubscriptXOffset)
        #   sbyo - subscript em y offset (OS/2.ySubscriptYOffset)
        #   spxs - superscript em x size (OS/2.ySuperscriptXSize)
        #   spys - superscript em y size (OS/2.ySuperscriptYSize)
        #   spxo - superscript em x offset (OS/2.ySuperscriptXOffset)
        #   spyo - superscript em y offset (OS/2.ySuperscriptYOffset)
        #   strs - strikeout size (OS/2.yStrikeoutSize)
        #   stro - strikeout offset (OS/2.yStrikeoutPosition)
        #   unds - underline size (post.underlineThickness)
        #   undo - underline offset (post.underlinePosition)
        #   gsp0-gsp9 - glyph-specific adjustments (gasp.gaspRange)
        def metric_delta(tag : String, normalized_coords : Array(Float64)) : Float64
          if record = @value_record_map[tag]?
            @item_variation_store.get_delta(
              record.delta_set_outer_index,
              record.delta_set_inner_index,
              normalized_coords
            )
          else
            0.0
          end
        end

        # Check if a metric has variation data
        def has_metric?(tag : String) : Bool
          @value_record_map.has_key?(tag)
        end

        # Get all available metric tags
        def available_metrics : Array(String)
          @value_records.map(&.value_tag)
        end

        extend IOHelpers
      end
    end
  end
end
