# VVAR table - Vertical Metrics Variations
# Contains variation data for vertical advance heights and top/bottom side bearings.
#
# Reference: https://learn.microsoft.com/en-us/typography/opentype/spec/vvar

module TrueType
  module Tables
    module Variations
      # The VVAR table stores variation data for vertical glyph metrics.
      # This table is optional and only present in fonts with vertical metrics.
      class Vvar
        include IOHelpers

        # Table version (major.minor)
        getter major_version : UInt16
        getter minor_version : UInt16

        # Offset to item variation store
        getter item_variation_store_offset : UInt32

        # Offset to advance height mapping (0 if not present - identity mapping)
        getter advance_height_mapping_offset : UInt32

        # Offset to top side bearing mapping (0 if not present)
        getter tsb_mapping_offset : UInt32

        # Offset to bottom side bearing mapping (0 if not present)
        getter bsb_mapping_offset : UInt32

        # Offset to vertical origin mapping (0 if not present)
        getter v_org_mapping_offset : UInt32

        # The item variation store
        getter item_variation_store : ItemVariationStore

        # Advance height delta set index map (nil if identity mapping)
        getter advance_height_map : DeltaSetIndexMap?

        # Top side bearing delta set index map (nil if not present)
        getter tsb_map : DeltaSetIndexMap?

        # Bottom side bearing delta set index map (nil if not present)
        getter bsb_map : DeltaSetIndexMap?

        # Vertical origin delta set index map (nil if not present)
        getter v_org_map : DeltaSetIndexMap?

        def initialize(
          @major_version : UInt16,
          @minor_version : UInt16,
          @item_variation_store_offset : UInt32,
          @advance_height_mapping_offset : UInt32,
          @tsb_mapping_offset : UInt32,
          @bsb_mapping_offset : UInt32,
          @v_org_mapping_offset : UInt32,
          @item_variation_store : ItemVariationStore,
          @advance_height_map : DeltaSetIndexMap?,
          @tsb_map : DeltaSetIndexMap?,
          @bsb_map : DeltaSetIndexMap?,
          @v_org_map : DeltaSetIndexMap?
        )
        end

        def self.parse(data : Bytes) : Vvar
          io = IO::Memory.new(data)

          major_version = read_uint16(io)
          minor_version = read_uint16(io)
          item_variation_store_offset = read_uint32(io)
          advance_height_mapping_offset = read_uint32(io)
          tsb_mapping_offset = read_uint32(io)
          bsb_mapping_offset = read_uint32(io)
          v_org_mapping_offset = read_uint32(io)

          # Parse item variation store
          item_variation_store = ItemVariationStore.parse(data, item_variation_store_offset)

          # Parse advance height mapping if present
          advance_height_map = if advance_height_mapping_offset != 0
                                  DeltaSetIndexMap.parse(io, advance_height_mapping_offset)
                                else
                                  nil
                                end

          # Parse TSB mapping if present
          tsb_map = if tsb_mapping_offset != 0
                      DeltaSetIndexMap.parse(io, tsb_mapping_offset)
                    else
                      nil
                    end

          # Parse BSB mapping if present
          bsb_map = if bsb_mapping_offset != 0
                      DeltaSetIndexMap.parse(io, bsb_mapping_offset)
                    else
                      nil
                    end

          # Parse vertical origin mapping if present
          v_org_map = if v_org_mapping_offset != 0
                        DeltaSetIndexMap.parse(io, v_org_mapping_offset)
                      else
                        nil
                      end

          new(
            major_version,
            minor_version,
            item_variation_store_offset,
            advance_height_mapping_offset,
            tsb_mapping_offset,
            bsb_mapping_offset,
            v_org_mapping_offset,
            item_variation_store,
            advance_height_map,
            tsb_map,
            bsb_map,
            v_org_map
          )
        end

        # Get the advance height delta for a glyph at the given normalized coordinates
        def advance_height_delta(glyph_id : UInt16, normalized_coords : Array(Float64)) : Float64
          outer, inner = if map = @advance_height_map
                           map.get_indices(glyph_id.to_u32)
                         else
                           # Identity mapping: outer = 0, inner = glyph_id
                           {0_u16, glyph_id}
                         end
          @item_variation_store.get_delta(outer, inner, normalized_coords)
        end

        # Get the top side bearing delta for a glyph at the given normalized coordinates
        def tsb_delta(glyph_id : UInt16, normalized_coords : Array(Float64)) : Float64
          return 0.0 unless map = @tsb_map
          outer, inner = map.get_indices(glyph_id.to_u32)
          @item_variation_store.get_delta(outer, inner, normalized_coords)
        end

        # Get the bottom side bearing delta for a glyph at the given normalized coordinates
        def bsb_delta(glyph_id : UInt16, normalized_coords : Array(Float64)) : Float64
          return 0.0 unless map = @bsb_map
          outer, inner = map.get_indices(glyph_id.to_u32)
          @item_variation_store.get_delta(outer, inner, normalized_coords)
        end

        # Get the vertical origin delta for a glyph at the given normalized coordinates
        def v_org_delta(glyph_id : UInt16, normalized_coords : Array(Float64)) : Float64
          return 0.0 unless map = @v_org_map
          outer, inner = map.get_indices(glyph_id.to_u32)
          @item_variation_store.get_delta(outer, inner, normalized_coords)
        end

        extend IOHelpers
      end
    end
  end
end
