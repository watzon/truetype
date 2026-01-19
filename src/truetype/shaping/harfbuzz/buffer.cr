# HarfBuzz Buffer wrapper
#
# A buffer holds the input text and, after shaping, the output glyphs.
# This is the primary interface for text shaping.

module TrueType
  module HarfBuzz
    # Text direction enum
    enum Direction
      Invalid = 0
      LTR     = 4  # Left to Right
      RTL     = 5  # Right to Left
      TTB     = 6  # Top to Bottom
      BTT     = 7  # Bottom to Top

      def horizontal? : Bool
        self == LTR || self == RTL
      end

      def vertical? : Bool
        self == TTB || self == BTT
      end

      def backward? : Bool
        self == RTL || self == BTT
      end

      def forward? : Bool
        self == LTR || self == TTB
      end

      def to_harfbuzz : LibHarfBuzz::HbDirection
        LibHarfBuzz::HbDirection.new(value.to_u32)
      end

      def self.from_string(str : String) : Direction
        val = LibHarfBuzz.hb_direction_from_string(str.to_unsafe, str.bytesize)
        Direction.new(val.value.to_i32)
      end
    end

    # Glyph info after shaping
    struct GlyphInfo
      # Glyph ID in the font
      getter id : UInt32

      # Cluster index - maps back to original text position
      getter cluster : UInt32

      def initialize(@id : UInt32, @cluster : UInt32)
      end
    end

    # Glyph position after shaping
    struct GlyphPosition
      # Horizontal advance (how far to move for next glyph)
      getter x_advance : Int32

      # Vertical advance
      getter y_advance : Int32

      # Horizontal offset from current position
      getter x_offset : Int32

      # Vertical offset from current position
      getter y_offset : Int32

      def initialize(@x_advance : Int32, @y_advance : Int32, @x_offset : Int32, @y_offset : Int32)
      end
    end

    # Combined glyph info and position
    struct ShapedGlyph
      getter id : UInt32
      getter cluster : UInt32
      getter x_advance : Int32
      getter y_advance : Int32
      getter x_offset : Int32
      getter y_offset : Int32

      def initialize(info : GlyphInfo, pos : GlyphPosition)
        @id = info.id
        @cluster = info.cluster
        @x_advance = pos.x_advance
        @y_advance = pos.y_advance
        @x_offset = pos.x_offset
        @y_offset = pos.y_offset
      end

      def initialize(@id, @cluster, @x_advance, @y_advance, @x_offset, @y_offset)
      end
    end

    # Wraps an hb_buffer_t for text input and shaped glyph output.
    #
    # Basic usage:
    # ```
    # buffer = HarfBuzz::Buffer.new
    # buffer.add_utf8("Hello, World!")
    # buffer.guess_segment_properties
    # buffer.shape(font)
    # buffer.glyphs.each { |g| puts g }
    # ```
    class Buffer
      @ptr : LibHarfBuzz::HbBuffer

      # Creates a new empty buffer.
      def initialize
        @ptr = LibHarfBuzz.hb_buffer_create
      end

      # Creates an empty buffer (singleton).
      def self.empty : Buffer
        buffer = Buffer.allocate
        buffer.initialize_empty
        buffer
      end

      protected def initialize_empty
        @ptr = LibHarfBuzz.hb_buffer_get_empty
      end

      def finalize
        LibHarfBuzz.hb_buffer_destroy(@ptr)
      end

      # Returns the raw pointer for FFI calls.
      def to_unsafe : LibHarfBuzz::HbBuffer
        @ptr
      end

      # Resets the buffer to its initial state (keeps allocations).
      def reset!
        LibHarfBuzz.hb_buffer_reset(@ptr)
      end

      # Clears the buffer contents but keeps properties.
      def clear!
        LibHarfBuzz.hb_buffer_clear_contents(@ptr)
      end

      # Pre-allocates space for the given number of glyphs.
      def pre_allocate(size : UInt32) : Bool
        LibHarfBuzz.hb_buffer_pre_allocate(@ptr, size) != 0
      end

      # Returns true if all allocations succeeded.
      def allocation_successful? : Bool
        LibHarfBuzz.hb_buffer_allocation_successful(@ptr) != 0
      end

      # ============================================
      # Adding text
      # ============================================

      # Adds a single codepoint with a cluster index.
      def add(codepoint : UInt32, cluster : UInt32)
        LibHarfBuzz.hb_buffer_add(@ptr, codepoint, cluster)
      end

      # Adds UTF-8 text to the buffer.
      def add_utf8(text : String)
        LibHarfBuzz.hb_buffer_add_utf8(@ptr, text.to_unsafe, text.bytesize, 0, text.bytesize)
      end

      # Adds a portion of UTF-8 text to the buffer.
      def add_utf8(text : String, item_offset : UInt32, item_length : Int32)
        LibHarfBuzz.hb_buffer_add_utf8(@ptr, text.to_unsafe, text.bytesize, item_offset, item_length)
      end

      # Adds UTF-32 codepoints to the buffer.
      def add_codepoints(codepoints : Array(UInt32))
        LibHarfBuzz.hb_buffer_add_codepoints(
          @ptr,
          codepoints.to_unsafe,
          codepoints.size,
          0,
          codepoints.size
        )
      end

      # Adds Latin-1 text to the buffer.
      def add_latin1(text : Bytes)
        LibHarfBuzz.hb_buffer_add_latin1(@ptr, text.to_unsafe, text.size, 0, text.size)
      end

      # ============================================
      # Text properties
      # ============================================

      # Sets the text direction.
      def direction=(direction : Direction)
        LibHarfBuzz.hb_buffer_set_direction(@ptr, direction.to_harfbuzz)
      end

      # Gets the text direction.
      def direction : Direction
        val = LibHarfBuzz.hb_buffer_get_direction(@ptr)
        Direction.new(val.value.to_i32)
      end

      # Sets the script (ISO 15924 tag).
      def script=(script : String)
        tag = LibHarfBuzz.hb_script_from_string(script.to_unsafe, script.bytesize)
        LibHarfBuzz.hb_buffer_set_script(@ptr, tag)
      end

      # Sets the script by tag.
      def script=(tag : UInt32)
        LibHarfBuzz.hb_buffer_set_script(@ptr, tag)
      end

      # Gets the script tag.
      def script : UInt32
        LibHarfBuzz.hb_buffer_get_script(@ptr)
      end

      # Sets the language (BCP 47 tag).
      def language=(language : String)
        lang = LibHarfBuzz.hb_language_from_string(language.to_unsafe, language.bytesize)
        LibHarfBuzz.hb_buffer_set_language(@ptr, lang)
      end

      # Gets the language.
      def language : String?
        lang = LibHarfBuzz.hb_buffer_get_language(@ptr)
        if lang.address != 0
          ptr = LibHarfBuzz.hb_language_to_string(lang)
          String.new(ptr) if ptr.address != 0
        end
      end

      # Sets buffer flags.
      def flags=(flags : LibHarfBuzz::HbBufferFlags)
        LibHarfBuzz.hb_buffer_set_flags(@ptr, flags)
      end

      # Gets buffer flags.
      def flags : LibHarfBuzz::HbBufferFlags
        LibHarfBuzz.hb_buffer_get_flags(@ptr)
      end

      # Sets the cluster level.
      def cluster_level=(level : LibHarfBuzz::HbBufferClusterLevel)
        LibHarfBuzz.hb_buffer_set_cluster_level(@ptr, level)
      end

      # Gets the cluster level.
      def cluster_level : LibHarfBuzz::HbBufferClusterLevel
        LibHarfBuzz.hb_buffer_get_cluster_level(@ptr)
      end

      # Guesses segment properties (direction, script, language) from buffer contents.
      #
      # This is useful when you don't know the properties ahead of time.
      # Call this after adding text but before shaping.
      def guess_segment_properties
        LibHarfBuzz.hb_buffer_guess_segment_properties(@ptr)
      end

      # ============================================
      # Output
      # ============================================

      # Returns the number of items in the buffer.
      def length : UInt32
        LibHarfBuzz.hb_buffer_get_length(@ptr)
      end

      # Returns the number of glyphs (alias for length).
      def size : UInt32
        length
      end

      # Returns true if the buffer is empty.
      def empty? : Bool
        length == 0
      end

      # Returns glyph info array.
      #
      # Call this after shaping to get glyph IDs and cluster indices.
      def glyph_infos : Array(GlyphInfo)
        len = uninitialized UInt32
        ptr = LibHarfBuzz.hb_buffer_get_glyph_infos(@ptr, pointerof(len))
        return [] of GlyphInfo if len == 0

        Array(GlyphInfo).new(len.to_i32) do |i|
          info = ptr[i]
          GlyphInfo.new(info.codepoint, info.cluster)
        end
      end

      # Returns glyph position array.
      #
      # Call this after shaping to get glyph positioning.
      def glyph_positions : Array(GlyphPosition)
        len = uninitialized UInt32
        ptr = LibHarfBuzz.hb_buffer_get_glyph_positions(@ptr, pointerof(len))
        return [] of GlyphPosition if len == 0

        Array(GlyphPosition).new(len.to_i32) do |i|
          pos = ptr[i]
          GlyphPosition.new(pos.x_advance, pos.y_advance, pos.x_offset, pos.y_offset)
        end
      end

      # Returns combined glyph info and positions.
      #
      # This is the most convenient way to get shaping results.
      def glyphs : Array(ShapedGlyph)
        info_len = uninitialized UInt32
        pos_len = uninitialized UInt32
        info_ptr = LibHarfBuzz.hb_buffer_get_glyph_infos(@ptr, pointerof(info_len))
        pos_ptr = LibHarfBuzz.hb_buffer_get_glyph_positions(@ptr, pointerof(pos_len))

        return [] of ShapedGlyph if info_len == 0

        Array(ShapedGlyph).new(info_len.to_i32) do |i|
          info = info_ptr[i]
          pos = pos_ptr[i]
          ShapedGlyph.new(
            info.codepoint,
            info.cluster,
            pos.x_advance,
            pos.y_advance,
            pos.x_offset,
            pos.y_offset
          )
        end
      end

      # ============================================
      # Manipulation
      # ============================================

      # Reverses the buffer contents.
      def reverse!
        LibHarfBuzz.hb_buffer_reverse(@ptr)
      end

      # Reverses a range of the buffer.
      def reverse!(start : UInt32, end_pos : UInt32)
        LibHarfBuzz.hb_buffer_reverse_range(@ptr, start, end_pos)
      end

      # Reverses clusters.
      def reverse_clusters!
        LibHarfBuzz.hb_buffer_reverse_clusters(@ptr)
      end

      # Normalizes glyph clusters.
      def normalize_glyphs!
        LibHarfBuzz.hb_buffer_normalize_glyphs(@ptr)
      end

      # ============================================
      # Shaping
      # ============================================

      # Shapes the buffer using the given font.
      #
      # This is the main shaping function. After calling this,
      # use `glyphs` to get the results.
      def shape(font : Font, features : Array(Feature)? = nil)
        if features && !features.empty?
          hb_features = features.map(&.to_harfbuzz)
          LibHarfBuzz.hb_shape(font.to_unsafe, @ptr, hb_features.to_unsafe, hb_features.size.to_u32)
        else
          LibHarfBuzz.hb_shape(font.to_unsafe, @ptr, nil, 0)
        end
      end

      # Shapes with a specific list of shapers.
      #
      # Shapers are tried in order. Examples: "ot", "fallback", "graphite2"
      def shape_full(font : Font, features : Array(Feature)?, shapers : Array(String)) : Bool
        shaper_list = shapers.map(&.to_unsafe) + [Pointer(LibC::Char).null]

        hb_features = features.try(&.map(&.to_harfbuzz))
        features_ptr = hb_features.try(&.to_unsafe) || Pointer(LibHarfBuzz::HbFeature).null
        features_count = hb_features.try(&.size.to_u32) || 0_u32

        LibHarfBuzz.hb_shape_full(
          font.to_unsafe,
          @ptr,
          features_ptr,
          features_count,
          shaper_list.to_unsafe
        ) != 0
      end

      # Increments the reference count and returns self.
      def reference : Buffer
        LibHarfBuzz.hb_buffer_reference(@ptr)
        self
      end
    end
  end
end
