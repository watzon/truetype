# HVAR table - Horizontal Metrics Variations
# Contains variation data for horizontal advance widths and left side bearings.
#
# Reference: https://learn.microsoft.com/en-us/typography/opentype/spec/hvar

module TrueType
  module Tables
    module Variations
      # The HVAR table stores variation data for horizontal glyph metrics.
      class Hvar
        include IOHelpers

        # Table version (major.minor)
        getter major_version : UInt16
        getter minor_version : UInt16

        # Offset to item variation store
        getter item_variation_store_offset : UInt32

        # Offset to advance width mapping (0 if not present - identity mapping)
        getter advance_width_mapping_offset : UInt32

        # Offset to left side bearing mapping (0 if not present)
        getter lsb_mapping_offset : UInt32

        # Offset to right side bearing mapping (0 if not present)
        getter rsb_mapping_offset : UInt32

        # The item variation store
        getter item_variation_store : ItemVariationStore

        # Advance width delta set index map (nil if identity mapping)
        getter advance_width_map : DeltaSetIndexMap?

        # Left side bearing delta set index map (nil if not present)
        getter lsb_map : DeltaSetIndexMap?

        # Right side bearing delta set index map (nil if not present)
        getter rsb_map : DeltaSetIndexMap?

        def initialize(
          @major_version : UInt16,
          @minor_version : UInt16,
          @item_variation_store_offset : UInt32,
          @advance_width_mapping_offset : UInt32,
          @lsb_mapping_offset : UInt32,
          @rsb_mapping_offset : UInt32,
          @item_variation_store : ItemVariationStore,
          @advance_width_map : DeltaSetIndexMap?,
          @lsb_map : DeltaSetIndexMap?,
          @rsb_map : DeltaSetIndexMap?
        )
        end

        def self.parse(data : Bytes) : Hvar
          io = IO::Memory.new(data)

          major_version = read_uint16(io)
          minor_version = read_uint16(io)
          item_variation_store_offset = read_uint32(io)
          advance_width_mapping_offset = read_uint32(io)
          lsb_mapping_offset = read_uint32(io)
          rsb_mapping_offset = read_uint32(io)

          # Parse item variation store
          item_variation_store = ItemVariationStore.parse(data, item_variation_store_offset)

          # Parse advance width mapping if present
          advance_width_map = if advance_width_mapping_offset != 0
                                DeltaSetIndexMap.parse(io, advance_width_mapping_offset)
                              else
                                nil
                              end

          # Parse LSB mapping if present
          lsb_map = if lsb_mapping_offset != 0
                      DeltaSetIndexMap.parse(io, lsb_mapping_offset)
                    else
                      nil
                    end

          # Parse RSB mapping if present
          rsb_map = if rsb_mapping_offset != 0
                      DeltaSetIndexMap.parse(io, rsb_mapping_offset)
                    else
                      nil
                    end

          new(
            major_version,
            minor_version,
            item_variation_store_offset,
            advance_width_mapping_offset,
            lsb_mapping_offset,
            rsb_mapping_offset,
            item_variation_store,
            advance_width_map,
            lsb_map,
            rsb_map
          )
        end

        # Get the advance width delta for a glyph at the given normalized coordinates
        def advance_width_delta(glyph_id : UInt16, normalized_coords : Array(Float64)) : Float64
          outer, inner = if map = @advance_width_map
                           map.get_indices(glyph_id.to_u32)
                         else
                           # Identity mapping: outer = 0, inner = glyph_id
                           {0_u16, glyph_id}
                         end
          @item_variation_store.get_delta(outer, inner, normalized_coords)
        end

        # Get the left side bearing delta for a glyph at the given normalized coordinates
        def lsb_delta(glyph_id : UInt16, normalized_coords : Array(Float64)) : Float64
          return 0.0 unless map = @lsb_map
          outer, inner = map.get_indices(glyph_id.to_u32)
          @item_variation_store.get_delta(outer, inner, normalized_coords)
        end

        # Get the right side bearing delta for a glyph at the given normalized coordinates
        def rsb_delta(glyph_id : UInt16, normalized_coords : Array(Float64)) : Float64
          return 0.0 unless map = @rsb_map
          outer, inner = map.get_indices(glyph_id.to_u32)
          @item_variation_store.get_delta(outer, inner, normalized_coords)
        end

        extend IOHelpers
      end
    end
  end
end
