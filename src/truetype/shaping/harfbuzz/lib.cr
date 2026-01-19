# Low-level FFI bindings for HarfBuzz
#
# This file contains the raw C function bindings. Higher-level Crystal
# wrappers are in the other files in this directory.

@[Link("harfbuzz")]
lib LibHarfBuzz
  # Type aliases matching HarfBuzz's types
  alias HbBool = LibC::Int
  alias HbCodepoint = UInt32
  alias HbPosition = Int32
  alias HbMask = UInt32
  alias HbTag = UInt32

  # Opaque pointer types
  type HbBlob = Void*
  type HbFace = Void*
  type HbFont = Void*
  type HbBuffer = Void*
  type HbLanguage = Void*

  # Enums
  enum HbMemoryMode
    Duplicate
    Readonly
    WriteableReadonly
    Writeable
  end

  enum HbDirection : UInt32
    Invalid = 0
    Ltr     = 4
    Rtl     = 5
    Ttb     = 6
    Btt     = 7
  end

  enum HbBufferContentType : UInt32
    Invalid    = 0
    Unicode    = 1
    Glyphs     = 2
  end

  enum HbBufferClusterLevel : UInt32
    MonotoneGraphemes  = 0
    MonotoneCharacters = 1
    Characters         = 2
    Default            = 0
  end

  enum HbBufferFlags : UInt32
    Default                      = 0x00000000
    Bot                          = 0x00000001  # Beginning of text
    Eot                          = 0x00000002  # End of text
    PreserveDefaultIgnorables    = 0x00000004
    RemoveDefaultIgnorables      = 0x00000008
    DoNotInsertDottedCircle      = 0x00000010
    VerifyUnicode                = 0x00000020
    ProduceSafeToInsertTatweel   = 0x00000040
    Defined                      = 0x0000007F
  end

  # Structures
  struct HbFeature
    tag : HbTag
    value : UInt32
    start : UInt32
    _end : UInt32  # 'end' is a Crystal keyword
  end

  struct HbVariation
    tag : HbTag
    value : Float32
  end

  struct HbGlyphInfo
    codepoint : HbCodepoint
    mask : HbMask
    cluster : UInt32
    var1 : UInt32  # Private
    var2 : UInt32  # Private
  end

  struct HbGlyphPosition
    x_advance : HbPosition
    y_advance : HbPosition
    x_offset : HbPosition
    y_offset : HbPosition
    var : UInt32  # Private
  end

  # ============================================
  # Tag functions
  # ============================================

  fun hb_tag_from_string(str : LibC::Char*, len : LibC::Int) : HbTag
  fun hb_tag_to_string(tag : HbTag, buf : LibC::Char*)

  # ============================================
  # Direction functions
  # ============================================

  fun hb_direction_from_string(str : LibC::Char*, len : LibC::Int) : HbDirection
  fun hb_direction_to_string(direction : HbDirection) : LibC::Char*

  # ============================================
  # Language functions
  # ============================================

  fun hb_language_from_string(str : LibC::Char*, len : LibC::Int) : HbLanguage
  fun hb_language_to_string(language : HbLanguage) : LibC::Char*
  fun hb_language_get_default : HbLanguage

  # ============================================
  # Script functions
  # ============================================

  fun hb_script_from_string(str : LibC::Char*, len : LibC::Int) : HbTag
  fun hb_script_get_horizontal_direction(script : HbTag) : HbDirection

  # ============================================
  # Feature functions
  # ============================================

  fun hb_feature_from_string(str : LibC::Char*, len : LibC::Int, feature : HbFeature*) : HbBool
  fun hb_feature_to_string(feature : HbFeature*, buf : LibC::Char*, size : UInt32)

  # ============================================
  # Blob functions
  # ============================================

  fun hb_blob_create(
    data : LibC::Char*,
    length : UInt32,
    mode : HbMemoryMode,
    user_data : Void*,
    destroy : Void*
  ) : HbBlob

  # HarfBuzz 8.0+: renamed to hb_blob_create_from_file_or_fail
  fun hb_blob_create_from_file_or_fail(filename : LibC::Char*) : HbBlob
  fun hb_blob_create_sub_blob(parent : HbBlob, offset : UInt32, length : UInt32) : HbBlob
  fun hb_blob_get_empty : HbBlob
  fun hb_blob_reference(blob : HbBlob) : HbBlob
  fun hb_blob_destroy(blob : HbBlob)
  fun hb_blob_get_length(blob : HbBlob) : UInt32
  fun hb_blob_get_data(blob : HbBlob, length : UInt32*) : LibC::Char*
  fun hb_blob_is_immutable(blob : HbBlob) : HbBool
  fun hb_blob_make_immutable(blob : HbBlob)

  # ============================================
  # Face functions
  # ============================================

  fun hb_face_create(blob : HbBlob, index : UInt32) : HbFace
  # HarfBuzz 8.0+: renamed to hb_face_create_from_file_or_fail
  fun hb_face_create_from_file_or_fail(filename : LibC::Char*, index : UInt32) : HbFace
  fun hb_face_get_empty : HbFace
  fun hb_face_reference(face : HbFace) : HbFace
  fun hb_face_destroy(face : HbFace)
  fun hb_face_get_upem(face : HbFace) : UInt32
  fun hb_face_get_glyph_count(face : HbFace) : UInt32
  fun hb_face_get_index(face : HbFace) : UInt32
  fun hb_face_is_immutable(face : HbFace) : HbBool
  fun hb_face_make_immutable(face : HbFace)

  # Face table access
  fun hb_face_reference_table(face : HbFace, tag : HbTag) : HbBlob
  fun hb_face_reference_blob(face : HbFace) : HbBlob

  # ============================================
  # Font functions
  # ============================================

  fun hb_font_create(face : HbFace) : HbFont
  fun hb_font_get_empty : HbFont
  fun hb_font_reference(font : HbFont) : HbFont
  fun hb_font_destroy(font : HbFont)
  fun hb_font_get_face(font : HbFont) : HbFace
  fun hb_font_is_immutable(font : HbFont) : HbBool
  fun hb_font_make_immutable(font : HbFont)

  # Font scale (in 26.6 fixed-point)
  fun hb_font_set_scale(font : HbFont, x_scale : LibC::Int, y_scale : LibC::Int)
  fun hb_font_get_scale(font : HbFont, x_scale : LibC::Int*, y_scale : LibC::Int*)

  # Font PPEM (pixels per em)
  fun hb_font_set_ppem(font : HbFont, x_ppem : UInt32, y_ppem : UInt32)
  fun hb_font_get_ppem(font : HbFont, x_ppem : UInt32*, y_ppem : UInt32*)

  # Font point size (for optical size feature)
  fun hb_font_set_ptem(font : HbFont, ptem : Float32)
  fun hb_font_get_ptem(font : HbFont) : Float32

  # Variable font variations
  fun hb_font_set_variations(font : HbFont, variations : HbVariation*, variations_count : UInt32)
  fun hb_font_set_var_coords_design(font : HbFont, coords : Float32*, coords_count : UInt32)
  fun hb_font_set_var_coords_normalized(font : HbFont, coords : LibC::Int*, coords_count : UInt32)

  # Glyph functions
  fun hb_font_get_glyph(font : HbFont, unicode : HbCodepoint, variation_selector : HbCodepoint, glyph : HbCodepoint*) : HbBool
  fun hb_font_get_nominal_glyph(font : HbFont, unicode : HbCodepoint, glyph : HbCodepoint*) : HbBool
  fun hb_font_get_glyph_h_advance(font : HbFont, glyph : HbCodepoint) : HbPosition
  fun hb_font_get_glyph_v_advance(font : HbFont, glyph : HbCodepoint) : HbPosition
  fun hb_font_get_glyph_h_kerning(font : HbFont, left_glyph : HbCodepoint, right_glyph : HbCodepoint) : HbPosition
  fun hb_font_get_glyph_name(font : HbFont, glyph : HbCodepoint, name : LibC::Char*, size : UInt32) : HbBool

  # ============================================
  # Buffer functions
  # ============================================

  fun hb_buffer_create : HbBuffer
  fun hb_buffer_get_empty : HbBuffer
  fun hb_buffer_reference(buffer : HbBuffer) : HbBuffer
  fun hb_buffer_destroy(buffer : HbBuffer)
  fun hb_buffer_reset(buffer : HbBuffer)
  fun hb_buffer_clear_contents(buffer : HbBuffer)

  # Pre-allocation
  fun hb_buffer_pre_allocate(buffer : HbBuffer, size : UInt32) : HbBool
  fun hb_buffer_allocation_successful(buffer : HbBuffer) : HbBool

  # Adding text
  fun hb_buffer_add(buffer : HbBuffer, codepoint : HbCodepoint, cluster : UInt32)
  fun hb_buffer_add_utf8(buffer : HbBuffer, text : LibC::Char*, text_length : LibC::Int, item_offset : UInt32, item_length : LibC::Int)
  fun hb_buffer_add_utf16(buffer : HbBuffer, text : UInt16*, text_length : LibC::Int, item_offset : UInt32, item_length : LibC::Int)
  fun hb_buffer_add_utf32(buffer : HbBuffer, text : UInt32*, text_length : LibC::Int, item_offset : UInt32, item_length : LibC::Int)
  fun hb_buffer_add_latin1(buffer : HbBuffer, text : UInt8*, text_length : LibC::Int, item_offset : UInt32, item_length : LibC::Int)
  fun hb_buffer_add_codepoints(buffer : HbBuffer, text : HbCodepoint*, text_length : LibC::Int, item_offset : UInt32, item_length : LibC::Int)

  # Text properties
  fun hb_buffer_set_content_type(buffer : HbBuffer, content_type : HbBufferContentType)
  fun hb_buffer_get_content_type(buffer : HbBuffer) : HbBufferContentType
  fun hb_buffer_set_direction(buffer : HbBuffer, direction : HbDirection)
  fun hb_buffer_get_direction(buffer : HbBuffer) : HbDirection
  fun hb_buffer_set_script(buffer : HbBuffer, script : HbTag)
  fun hb_buffer_get_script(buffer : HbBuffer) : HbTag
  fun hb_buffer_set_language(buffer : HbBuffer, language : HbLanguage)
  fun hb_buffer_get_language(buffer : HbBuffer) : HbLanguage
  fun hb_buffer_set_flags(buffer : HbBuffer, flags : HbBufferFlags)
  fun hb_buffer_get_flags(buffer : HbBuffer) : HbBufferFlags
  fun hb_buffer_set_cluster_level(buffer : HbBuffer, cluster_level : HbBufferClusterLevel)
  fun hb_buffer_get_cluster_level(buffer : HbBuffer) : HbBufferClusterLevel

  # Guess segment properties from buffer contents
  fun hb_buffer_guess_segment_properties(buffer : HbBuffer)

  # Output
  fun hb_buffer_get_length(buffer : HbBuffer) : UInt32
  fun hb_buffer_get_glyph_infos(buffer : HbBuffer, length : UInt32*) : HbGlyphInfo*
  fun hb_buffer_get_glyph_positions(buffer : HbBuffer, length : UInt32*) : HbGlyphPosition*

  # Serialization (for debugging)
  fun hb_buffer_serialize_glyphs(
    buffer : HbBuffer,
    start : UInt32,
    _end : UInt32,
    buf : LibC::Char*,
    buf_size : UInt32,
    buf_consumed : UInt32*,
    font : HbFont,
    format : UInt32,
    flags : UInt32
  ) : UInt32

  # Normalization
  fun hb_buffer_normalize_glyphs(buffer : HbBuffer)

  # Reverse
  fun hb_buffer_reverse(buffer : HbBuffer)
  fun hb_buffer_reverse_range(buffer : HbBuffer, start : UInt32, _end : UInt32)
  fun hb_buffer_reverse_clusters(buffer : HbBuffer)

  # ============================================
  # Shape functions
  # ============================================

  fun hb_shape(font : HbFont, buffer : HbBuffer, features : HbFeature*, num_features : UInt32)
  fun hb_shape_full(font : HbFont, buffer : HbBuffer, features : HbFeature*, num_features : UInt32, shaper_list : LibC::Char**) : HbBool

  # ============================================
  # Version functions
  # ============================================

  fun hb_version(major : UInt32*, minor : UInt32*, micro : UInt32*)
  fun hb_version_string : LibC::Char*
  fun hb_version_atleast(major : UInt32, minor : UInt32, micro : UInt32) : HbBool
end

module TrueType
  module HarfBuzz
    # Create a tag from a 4-character string
    def self.tag(str : String) : UInt32
      LibHarfBuzz.hb_tag_from_string(str.to_unsafe, str.bytesize)
    end

    # Convert a tag to a 4-character string
    def self.tag_to_string(tag : UInt32) : String
      buf = uninitialized UInt8[5]
      LibHarfBuzz.hb_tag_to_string(tag, buf.to_unsafe.as(LibC::Char*))
      buf[4] = 0_u8
      String.new(buf.to_unsafe)
    end

    # Get HarfBuzz version string
    def self.version_string : String
      String.new(LibHarfBuzz.hb_version_string)
    end

    # Get HarfBuzz version as tuple
    def self.version : {UInt32, UInt32, UInt32}
      major = uninitialized UInt32
      minor = uninitialized UInt32
      micro = uninitialized UInt32
      LibHarfBuzz.hb_version(pointerof(major), pointerof(minor), pointerof(micro))
      {major, minor, micro}
    end

    # Check if HarfBuzz is at least a certain version
    def self.version_atleast?(major : UInt32, minor : UInt32, micro : UInt32) : Bool
      LibHarfBuzz.hb_version_atleast(major, minor, micro) != 0
    end
  end
end
