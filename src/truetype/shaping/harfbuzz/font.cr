# HarfBuzz Font wrapper
#
# A font represents a face at a particular size and with specific
# variation settings. This is what you use for actual text shaping.

module TrueType
  module HarfBuzz
    # Wraps an hb_font_t, which represents a font at a specific size.
    #
    # A font is created from a face and can have its size, ppem, and
    # variation coordinates configured. Use this with a Buffer to shape text.
    class Font
      @ptr : LibHarfBuzz::HbFont
      @face : Face?

      # Creates a font from a face.
      #
      # The font will be at the face's design units size by default.
      # Call `set_scale` or `set_ppem` to configure the size.
      def initialize(face : Face)
        @face = face
        @ptr = LibHarfBuzz.hb_font_create(face.to_unsafe)
      end

      # Creates a font from raw font data.
      def initialize(data : Bytes, index : UInt32 = 0)
        @face = Face.new(data, index)
        @ptr = LibHarfBuzz.hb_font_create(@face.not_nil!.to_unsafe)
      end

      # Creates a font from a file path.
      def self.from_file(path : String, index : UInt32 = 0) : Font
        face = Face.from_file(path, index)
        new(face)
      end

      # Creates an empty font.
      def self.empty : Font
        font = Font.allocate
        font.initialize_empty
        font
      end

      protected def initialize_empty
        @face = nil
        @ptr = LibHarfBuzz.hb_font_get_empty
      end

      def finalize
        LibHarfBuzz.hb_font_destroy(@ptr)
      end

      # Returns the raw pointer for FFI calls.
      def to_unsafe : LibHarfBuzz::HbFont
        @ptr
      end

      # Returns the underlying face.
      def face : Face
        @face || begin
          ptr = LibHarfBuzz.hb_font_get_face(@ptr)
          # Don't destroy this face - it's owned by the font
          face = Face.allocate
          face.as({LibHarfBuzz::HbFace, Blob?}*).value = {ptr, nil}
          face
        end
      end

      # Returns true if the font is immutable.
      def immutable? : Bool
        LibHarfBuzz.hb_font_is_immutable(@ptr) != 0
      end

      # Makes the font immutable.
      def make_immutable!
        LibHarfBuzz.hb_font_make_immutable(@ptr)
      end

      # Sets the font scale (in 26.6 fixed-point format).
      #
      # The scale is used to convert from font units to user-space coordinates.
      # For example, to set a font size of 12pt at 72dpi:
      #   font.set_scale(12 * 64, 12 * 64)
      def set_scale(x_scale : Int32, y_scale : Int32)
        LibHarfBuzz.hb_font_set_scale(@ptr, x_scale, y_scale)
      end

      # Sets uniform scale.
      def scale=(scale : Int32)
        set_scale(scale, scale)
      end

      # Gets the font scale.
      def scale : {Int32, Int32}
        x = uninitialized LibC::Int
        y = uninitialized LibC::Int
        LibHarfBuzz.hb_font_get_scale(@ptr, pointerof(x), pointerof(y))
        {x.to_i32, y.to_i32}
      end

      # Sets the pixels per em (PPEM).
      #
      # PPEM is used for hinting and device-specific adjustments.
      def set_ppem(x_ppem : UInt32, y_ppem : UInt32)
        LibHarfBuzz.hb_font_set_ppem(@ptr, x_ppem, y_ppem)
      end

      # Sets uniform PPEM.
      def ppem=(ppem : UInt32)
        set_ppem(ppem, ppem)
      end

      # Gets the PPEM.
      def ppem : {UInt32, UInt32}
        x = uninitialized UInt32
        y = uninitialized UInt32
        LibHarfBuzz.hb_font_get_ppem(@ptr, pointerof(x), pointerof(y))
        {x, y}
      end

      # Sets the point size.
      #
      # Point size is used for optical size feature selection.
      def ptem=(ptem : Float32)
        LibHarfBuzz.hb_font_set_ptem(@ptr, ptem)
      end

      # Gets the point size.
      def ptem : Float32
        LibHarfBuzz.hb_font_get_ptem(@ptr)
      end

      # Sets variation coordinates using design-space values.
      #
      # Example:
      #   font.set_variations({"wght" => 700.0, "wdth" => 75.0})
      def set_variations(variations : Hash(String, Float32))
        return if variations.empty?

        hb_variations = variations.map do |tag, value|
          LibHarfBuzz::HbVariation.new(
            tag: HarfBuzz.tag(tag),
            value: value
          )
        end

        LibHarfBuzz.hb_font_set_variations(
          @ptr,
          hb_variations.to_unsafe,
          hb_variations.size.to_u32
        )
      end

      # Sets variation coordinates using design-space values (array form).
      def set_variations(variations : Array(LibHarfBuzz::HbVariation))
        return if variations.empty?
        LibHarfBuzz.hb_font_set_variations(@ptr, variations.to_unsafe, variations.size.to_u32)
      end

      # Sets variation coordinates from axis order.
      #
      # The coords array should have one value per axis in the font.
      def set_var_coords_design(coords : Array(Float32))
        return if coords.empty?
        LibHarfBuzz.hb_font_set_var_coords_design(@ptr, coords.to_unsafe, coords.size.to_u32)
      end

      # Sets variation coordinates using normalized values (-1.0 to 1.0 mapped to -16384 to 16384).
      def set_var_coords_normalized(coords : Array(Int32))
        return if coords.empty?
        LibHarfBuzz.hb_font_set_var_coords_normalized(@ptr, coords.to_unsafe.as(LibC::Int*), coords.size.to_u32)
      end

      # Gets a glyph ID for a Unicode codepoint.
      def glyph(codepoint : UInt32, variation_selector : UInt32 = 0) : UInt32?
        glyph_id = uninitialized UInt32
        if LibHarfBuzz.hb_font_get_glyph(@ptr, codepoint, variation_selector, pointerof(glyph_id)) != 0
          glyph_id
        else
          nil
        end
      end

      # Gets a glyph ID for a Unicode codepoint (no variation selector).
      def nominal_glyph(codepoint : UInt32) : UInt32?
        glyph_id = uninitialized UInt32
        if LibHarfBuzz.hb_font_get_nominal_glyph(@ptr, codepoint, pointerof(glyph_id)) != 0
          glyph_id
        else
          nil
        end
      end

      # Gets the horizontal advance for a glyph.
      def h_advance(glyph : UInt32) : Int32
        LibHarfBuzz.hb_font_get_glyph_h_advance(@ptr, glyph)
      end

      # Gets the vertical advance for a glyph.
      def v_advance(glyph : UInt32) : Int32
        LibHarfBuzz.hb_font_get_glyph_v_advance(@ptr, glyph)
      end

      # Gets the horizontal kerning between two glyphs.
      def h_kerning(left_glyph : UInt32, right_glyph : UInt32) : Int32
        LibHarfBuzz.hb_font_get_glyph_h_kerning(@ptr, left_glyph, right_glyph)
      end

      # Gets a glyph name.
      def glyph_name(glyph : UInt32) : String?
        buf = uninitialized UInt8[64]
        if LibHarfBuzz.hb_font_get_glyph_name(@ptr, glyph, buf.to_unsafe.as(LibC::Char*), 64) != 0
          String.new(buf.to_unsafe)
        else
          nil
        end
      end

      # Increments the reference count and returns self.
      def reference : Font
        LibHarfBuzz.hb_font_reference(@ptr)
        self
      end
    end
  end
end
