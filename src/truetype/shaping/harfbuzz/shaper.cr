# HarfBuzz Shaper - High-level shaping interface
#
# This module provides convenient methods for text shaping that integrate
# with the TrueType::Font class.

module TrueType
  module HarfBuzz
    # Options for text shaping
    struct ShapingOptions
      # Text direction (nil = auto-detect)
      property direction : Direction?

      # Script (ISO 15924 tag, nil = auto-detect)
      property script : String?

      # Language (BCP 47 tag, nil = default)
      property language : String?

      # OpenType features to apply
      property features : Array(Feature)

      # Font size in points (for proper scaling)
      property size : Float32?

      # Variation axis settings (for variable fonts)
      property variations : Hash(String, Float32)?

      def initialize(
        @direction : Direction? = nil,
        @script : String? = nil,
        @language : String? = nil,
        @features : Array(Feature) = Features.defaults,
        @size : Float32? = nil,
        @variations : Hash(String, Float32)? = nil
      )
      end

      # Creates options with kerning only
      def self.kerning_only : ShapingOptions
        new(features: [Features.kern])
      end

      # Creates options for Latin text
      def self.latin : ShapingOptions
        new(
          direction: Direction::LTR,
          script: "Latn",
          features: Features.defaults
        )
      end

      # Creates options for Arabic text
      def self.arabic : ShapingOptions
        new(
          direction: Direction::RTL,
          script: "Arab",
          features: Features.defaults
        )
      end

      # Creates options for Hebrew text
      def self.hebrew : ShapingOptions
        new(
          direction: Direction::RTL,
          script: "Hebr",
          features: Features.defaults
        )
      end

      # Creates options for CJK text
      def self.cjk : ShapingOptions
        new(
          direction: Direction::LTR,
          script: "Hani",
          features: [Features.kern]
        )
      end

      # Creates options for vertical CJK text
      def self.cjk_vertical : ShapingOptions
        new(
          direction: Direction::TTB,
          script: "Hani",
          features: [Feature.new("vert", 1_u32)]
        )
      end
    end

    # Result of shaping a single run of text
    struct ShapingResult
      # Shaped glyphs with positioning
      getter glyphs : Array(ShapedGlyph)

      # Total advance width (horizontal shaping)
      getter width : Int32

      # Total advance height (vertical shaping)
      getter height : Int32

      # The direction used for shaping
      getter direction : Direction

      def initialize(@glyphs, @width, @height, @direction)
      end

      # Iterates over glyphs with cumulative positions
      def each_with_position(& : ShapedGlyph, Int32, Int32 ->)
        x = 0
        y = 0
        @glyphs.each do |glyph|
          yield glyph, x + glyph.x_offset, y + glyph.y_offset
          x += glyph.x_advance
          y += glyph.y_advance
        end
      end

      # Returns glyphs with absolute x/y positions
      def positioned_glyphs : Array(PositionedGlyph)
        result = [] of PositionedGlyph
        x = 0
        y = 0
        @glyphs.each do |glyph|
          result << PositionedGlyph.new(
            glyph.id,
            glyph.cluster,
            x + glyph.x_offset,
            y + glyph.y_offset,
            glyph.x_advance,
            glyph.y_advance
          )
          x += glyph.x_advance
          y += glyph.y_advance
        end
        result
      end
    end

    # A glyph with its absolute position
    struct PositionedGlyph
      getter id : UInt32
      getter cluster : UInt32
      getter x : Int32
      getter y : Int32
      getter x_advance : Int32
      getter y_advance : Int32

      def initialize(@id, @cluster, @x, @y, @x_advance, @y_advance)
      end
    end

    # High-level shaping API
    module Shaper
      # Shapes text using a TrueType::Font
      #
      # This creates a HarfBuzz font from the TrueType parser data and
      # shapes the text with full OpenType feature support.
      def self.shape(tt_font : TrueType::Font, text : String, options : ShapingOptions = ShapingOptions.new) : ShapingResult
        # Create HarfBuzz font from raw data
        hb_font = Font.new(tt_font.data)

        # Configure size if specified
        if size = options.size
          # Scale = size * 64 (26.6 fixed point)
          scale = (size * 64).to_i32
          hb_font.set_scale(scale, scale)
        end

        # Configure variations if specified
        if variations = options.variations
          hb_font.set_variations(variations.transform_values(&.to_f32))
        end

        # Create and configure buffer
        buffer = Buffer.new
        buffer.add_utf8(text)

        # Set direction, script, language
        if dir = options.direction
          buffer.direction = dir
        end
        if script = options.script
          buffer.script = script
        end
        if lang = options.language
          buffer.language = lang
        end

        # Auto-detect properties if not specified
        buffer.guess_segment_properties

        # Shape!
        buffer.shape(hb_font, options.features.empty? ? nil : options.features)

        # Collect results
        glyphs = buffer.glyphs
        direction = buffer.direction

        # Calculate total advance
        width = 0
        height = 0
        glyphs.each do |g|
          width += g.x_advance
          height += g.y_advance
        end

        ShapingResult.new(glyphs, width, height, direction)
      end

      # Shapes text and returns just the shaped glyphs
      def self.shape_glyphs(tt_font : TrueType::Font, text : String, options : ShapingOptions = ShapingOptions.new) : Array(ShapedGlyph)
        shape(tt_font, text, options).glyphs
      end

      # Shapes text using a pre-created HarfBuzz font (more efficient for repeated use)
      def self.shape_with_font(hb_font : Font, text : String, options : ShapingOptions = ShapingOptions.new) : ShapingResult
        buffer = Buffer.new
        buffer.add_utf8(text)

        if dir = options.direction
          buffer.direction = dir
        end
        if script = options.script
          buffer.script = script
        end
        if lang = options.language
          buffer.language = lang
        end

        buffer.guess_segment_properties
        buffer.shape(hb_font, options.features.empty? ? nil : options.features)

        glyphs = buffer.glyphs
        direction = buffer.direction

        width = glyphs.sum(&.x_advance)
        height = glyphs.sum(&.y_advance)

        ShapingResult.new(glyphs, width, height, direction)
      end
    end
  end
end
