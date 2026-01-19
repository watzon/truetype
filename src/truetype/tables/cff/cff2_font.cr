module TrueType
  module Tables
    # Parsed CFF2 font data for extracting variable font outlines
    class CFF2Font
      include IOHelpers

      getter cff2 : CFF::CFF2Table
      getter top_dict : CFF::Dict
      getter charstrings : CFF::Index?
      getter variation_store : Variations::ItemVariationStore?
      getter fd_array : Array(CFF::Dict)?
      @raw_data : Bytes

      def initialize(
        @cff2 : CFF::CFF2Table,
        @top_dict : CFF::Dict,
        @charstrings : CFF::Index?,
        @variation_store : Variations::ItemVariationStore?,
        @fd_array : Array(CFF::Dict)?,
        @raw_data : Bytes
      )
      end

      def self.parse(data : Bytes) : CFF2Font
        cff2 = CFF::CFF2Table.parse(data)
        top_dict = cff2.top_dict

        # Parse CharStrings INDEX
        charstrings = cff2.charstrings

        # Parse VariationStore if present
        variation_store = parse_variation_store(data, cff2.vstore_offset)

        # Parse FDArray
        fd_array = cff2.fd_array

        new(cff2, top_dict, charstrings, variation_store, fd_array, data)
      end

      private def self.parse_variation_store(data : Bytes, offset : Int32) : Variations::ItemVariationStore?
        return nil if offset <= 0

        Variations::ItemVariationStore.parse(data, offset.to_u32)
      rescue
        nil
      end

      def glyph_count : Int32
        @charstrings.try(&.size) || 0
      end

      def charstring(glyph_id : UInt16) : Bytes
        @charstrings.try(&.[glyph_id.to_i]) || Bytes.empty
      end

      # Get glyph outline without variation (default instance)
      def glyph_outline(glyph_id : UInt16) : GlyphOutline
        glyph_outline(glyph_id, nil)
      end

      # Get glyph outline with variation coordinates applied
      def glyph_outline(glyph_id : UInt16, normalized_coords : Array(Float64)?) : GlyphOutline
        data = charstring(glyph_id)
        return GlyphOutline.new if data.empty?

        interpreter = CFF::CFF2CharstringInterpreter.new(
          variation_store: @variation_store,
          normalized_coords: normalized_coords
        )
        interpreter.execute(data)
      end

      # Check if this is a variable font (has variation store)
      def variable? : Bool
        !@variation_store.nil?
      end

      # Get the number of variation axes from the variation store
      def axis_count : Int32
        @variation_store.try(&.region_list.axis_count.to_i32) || 0
      end

      # Get private dict for a glyph (via FDSelect)
      def private_dict(glyph_id : UInt16) : CFF::Dict?
        # For now, return first FD if available
        # Full implementation would use FDSelect to map glyph to FD
        @fd_array.try(&.first?)
      end

      # Get local subrs for a glyph
      def local_subrs(glyph_id : UInt16) : CFF::Index?
        private_dict = private_dict(glyph_id)
        return nil unless private_dict

        subrs_offset = private_dict.int(CFF::DictOp::SUBRS, 0)
        return nil if subrs_offset <= 0

        # Get private dict offset from FD
        # This is complex as we need to track FD offsets
        # For now, return nil - full implementation would parse subrs
        nil
      end

      extend IOHelpers
    end
  end
end
