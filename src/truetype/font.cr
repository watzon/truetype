# High-level Font API for TrueType/OpenType fonts.
#
# This module provides a user-friendly, unified interface for working with fonts,
# with automatic format detection and convenient methods for common operations.
#
# ## Quick Start
#
# ```
# require "truetype"
#
# # Open any font format with auto-detection
# font = TrueType::Font.open("path/to/font.ttf") # TTF, OTF, WOFF, WOFF2, TTC/OTC
#
# # Access font information
# puts font.name            # "DejaVu Sans"
# puts font.postscript_name # "DejaVuSans"
# puts font.style           # "Regular"
#
# # Basic text shaping
# glyphs = font.shape("Hello!")
# glyphs.each do |glyph|
#   puts "Glyph #{glyph.id} at (#{glyph.x_offset}, #{glyph.y_offset})"
# end
#
# # Create a variable font instance
# if font.variable?
#   bold = font.instance(weight: 700)
#   puts bold.shape("Bold text")
# end
#
# # Subset for embedding
# subset = font.subset("Hello World!", preserve_hints: true)
# File.write("subset.ttf", subset)
# ```
module TrueType
  # Represents a positioned glyph with shaping/layout information.
  struct PositionedGlyph
    # Glyph ID in the font
    getter id : UInt16

    # Unicode codepoint this glyph represents (may be 0 for ligatures)
    getter codepoint : UInt32

    # Cluster index (character position in original string)
    getter cluster : Int32

    # Horizontal offset from current position (in font units)
    getter x_offset : Int32

    # Vertical offset from current position (in font units)
    getter y_offset : Int32

    # Horizontal advance (in font units)
    getter x_advance : Int32

    # Vertical advance (in font units)
    getter y_advance : Int32

    def initialize(
      @id : UInt16,
      @codepoint : UInt32,
      @cluster : Int32,
      @x_offset : Int32 = 0,
      @y_offset : Int32 = 0,
      @x_advance : Int32 = 0,
      @y_advance : Int32 = 0,
    )
    end

    # Get the glyph outline from a font
    def outline(font : Font) : GlyphOutline
      font.glyph_outline(@id)
    end
  end

  # Options for text shaping
  struct ShapingOptions
    # Enable common ligatures (liga feature)
    property? ligatures : Bool

    # Enable kerning
    property? kerning : Bool

    # Enable contextual alternates (calt feature)
    property? contextual_alternates : Bool

    # Additional OpenType features to enable (e.g., ["smcp", "onum"])
    property features : Array(String)

    # Script tag (e.g., "latn" for Latin)
    property script : String?

    # Language tag (e.g., "ENG" for English)
    property language : String?

    # Text direction: :ltr or :rtl
    property direction : Symbol

    def initialize(
      @ligatures : Bool = true,
      @kerning : Bool = true,
      @contextual_alternates : Bool = true,
      @features : Array(String) = [] of String,
      @script : String? = nil,
      @language : String? = nil,
      @direction : Symbol = :ltr,
    )
    end

    # Default shaping options
    def self.default : ShapingOptions
      new
    end

    # Minimal shaping (no ligatures, just kerning)
    def self.minimal : ShapingOptions
      new(ligatures: false, contextual_alternates: false)
    end

    # No OpenType features (simple character-to-glyph mapping)
    def self.none : ShapingOptions
      new(ligatures: false, kerning: false, contextual_alternates: false)
    end
  end

  # Options for font subsetting
  struct SubsetOptions
    # Preserve TrueType hinting instructions
    property? preserve_hints : Bool

    # Preserve OpenType layout tables (GSUB, GPOS)
    property? preserve_layout : Bool

    # Preserve kerning data
    property? preserve_kerning : Bool

    # Include .notdef glyph (always recommended)
    property? include_notdef : Bool

    # Subset name table (reduce to essential names)
    property? subset_names : Bool

    # Remove digital signature (DSIG)
    property? remove_signature : Bool

    # Output format: :ttf, :otf (match input), :woff, :woff2
    property output_format : Symbol

    def initialize(
      @preserve_hints : Bool = false,
      @preserve_layout : Bool = false,
      @preserve_kerning : Bool = true,
      @include_notdef : Bool = true,
      @subset_names : Bool = true,
      @remove_signature : Bool = true,
      @output_format : Symbol = :ttf,
    )
    end

    def self.default : SubsetOptions
      new
    end

    # For PDF embedding (minimal size)
    def self.pdf : SubsetOptions
      new(preserve_hints: false, preserve_layout: false)
    end

    # For web fonts (preserve layout features)
    def self.web : SubsetOptions
      new(preserve_hints: true, preserve_layout: true, output_format: :woff2)
    end
  end

  # High-level font class providing a unified API for all font operations.
  class Font
    # The underlying parser
    getter parser : Parser

    # Original data bytes (for reference/format detection)
    @original_data : Bytes?

    # Original file path (if opened from file)
    @path : String?

    # Detected format
    @format : Symbol

    # Warnings collected during parsing (when validation enabled)
    @warnings : Array(String)

    protected def initialize(@parser : Parser, @original_data : Bytes? = nil, @path : String? = nil, @format : Symbol = :ttf)
      @warnings = [] of String
    end

    # ===== Factory Methods =====

    # Open a font file with automatic format detection.
    #
    # Supports: .ttf, .otf, .woff, .woff2, .ttc, .otc
    #
    # For font collections (.ttc, .otc), returns the first font.
    # Use `Font.open_collection` for full collection access.
    #
    # ```
    # font = TrueType::Font.open("path/to/font.ttf")
    # font = TrueType::Font.open("path/to/font.woff2")
    # ```
    def self.open(path : String) : Font
      data = File.read(path).to_slice
      open(data, path: path)
    end

    # Open a font from bytes with automatic format detection.
    #
    # ```
    # data = File.read("font.woff2").to_slice
    # font = TrueType::Font.open(data)
    # ```
    def self.open(data : Bytes, path : String? = nil) : Font
      format = detect_format(data)

      parser = case format
               when :woff
                 Woff.parse(data).to_parser
               when :woff2
                 Woff2.parse(data).to_parser
               when :collection
                 FontCollection.parse(data).font(0)
               else
                 Parser.parse(data)
               end

      new(parser, data, path, format)
    end

    # Open a font collection and return all fonts.
    #
    # ```
    # fonts = TrueType::Font.open_collection("path/to/collection.ttc")
    # fonts.each { |font| puts font.name }
    # ```
    def self.open_collection(path : String) : Array(Font)
      data = File.read(path).to_slice
      open_collection(data, path: path)
    end

    # Open a font collection from bytes.
    def self.open_collection(data : Bytes, path : String? = nil) : Array(Font)
      collection = FontCollection.parse(data)
      fonts = [] of Font
      collection.each_with_index do |parser, _i|
        fonts << new(parser, data, path, :collection)
      end
      fonts
    end

    # Create a Font from an existing Parser.
    def self.from_parser(parser : Parser) : Font
      format = parser.cff? ? :otf : :ttf
      new(parser, nil, nil, format)
    end

    # Detect the format of font data.
    def self.detect_format(data : Bytes) : Symbol
      return :unknown if data.size < 4

      # Check magic numbers
      sig = (data[0].to_u32 << 24) | (data[1].to_u32 << 16) | (data[2].to_u32 << 8) | data[3].to_u32

      case sig
      when 0x774F4646 # 'wOFF'
        :woff
      when 0x774F4632 # 'wOF2'
        :woff2
      when 0x74746366 # 'ttcf'
        :collection
      when 0x4F54544F # 'OTTO' (CFF)
        :otf
      when 0x00010000, 0x74727565 # TrueType
        :ttf
      when 0x74797031 # 'typ1'
        :type1
      else
        :unknown
      end
    end

    # Check if the given path/data is a supported font format
    def self.font?(data : Bytes) : Bool
      format = detect_format(data)
      format != :unknown && format != :type1
    end

    def self.font?(path : String) : Bool
      return false unless File.exists?(path)
      File.open(path, "rb") do |file|
        header = Bytes.new(4)
        return false if file.read(header) < 4
        font?(header)
      end
    rescue
      false
    end

    # ===== Font Information =====

    # Font family name (e.g., "DejaVu Sans")
    def name : String
      @parser.family_name
    end

    # Same as #name
    def family_name : String
      name
    end

    # PostScript name (e.g., "DejaVuSans-Bold")
    def postscript_name : String
      @parser.postscript_name
    end

    # Style name (e.g., "Regular", "Bold", "Italic")
    def style : String
      @parser.name.subfamily || "Regular"
    end

    # Full name (e.g., "DejaVu Sans Bold")
    def full_name : String
      @parser.name.full_name || "#{name} #{style}"
    end

    # Version string
    def version : String?
      @parser.name.version
    end

    # Copyright notice
    def copyright : String?
      @parser.name.copyright
    end

    # Detected format (:ttf, :otf, :woff, :woff2, :collection)
    def format : Symbol
      @format
    end

    # Original file path (if opened from file)
    def path : String?
      @path
    end

    # ===== Font Properties =====

    # Units per em
    def units_per_em : UInt16
      @parser.units_per_em
    end

    # Ascender (in font units)
    def ascender : Int16
      @parser.ascender
    end

    # Descender (in font units, typically negative)
    def descender : Int16
      @parser.descender
    end

    # Line gap (in font units)
    def line_gap : Int16
      @parser.hhea.line_gap
    end

    # Cap height (in font units)
    def cap_height : Int16
      @parser.cap_height
    end

    # x-height (in font units)
    def x_height : Int16?
      @parser.os2.try(&.sx_height)
    end

    # Font bounding box: {x_min, y_min, x_max, y_max}
    def bounding_box : Tuple(Int16, Int16, Int16, Int16)
      @parser.bounding_box
    end

    # Number of glyphs
    def glyph_count : UInt16
      @parser.maxp.num_glyphs
    end

    # ===== Font Type Checks =====

    # Is this a TrueType font (glyf outlines)?
    def truetype? : Bool
      @parser.truetype?
    end

    # Is this a CFF/OpenType font?
    def cff? : Bool
      @parser.cff?
    end

    # Is this a variable font?
    def variable? : Bool
      @parser.variable_font?
    end

    # Is this a color font?
    def color? : Bool
      @parser.color_font?
    end

    # Is this a math font?
    def math? : Bool
      @parser.math_font?
    end

    # Does the font support vertical writing?
    def vertical? : Bool
      @parser.vertical_writing?
    end

    # Is the font bold?
    def bold? : Bool
      @parser.bold?
    end

    # Is the font italic?
    def italic? : Bool
      @parser.italic?
    end

    # Is the font monospaced?
    def monospaced? : Bool
      @parser.monospaced?
    end

    # ===== Glyph Access =====

    # Get glyph ID for a character
    def glyph_id(char : Char) : UInt16
      @parser.glyph_id(char)
    end

    # Get glyph ID for a codepoint
    def glyph_id(codepoint : UInt32) : UInt16
      @parser.glyph_id(codepoint)
    end

    # Get advance width for a glyph (in font units)
    def advance_width(glyph_id : UInt16) : UInt16
      @parser.advance_width(glyph_id)
    end

    # Get advance width for a character (in font units)
    def char_width(char : Char) : UInt16
      @parser.char_width(char)
    end

    # Get glyph outline
    def glyph_outline(glyph_id : UInt16) : GlyphOutline
      @parser.glyph_outline(glyph_id)
    end

    # Get glyph outline for a character
    def char_outline(char : Char) : GlyphOutline
      @parser.char_outline(char)
    end

    # Get kerning between two glyphs (in font units)
    def kerning(left : UInt16, right : UInt16) : Int16
      @parser.kerning(left, right)
    end

    # Get kerning between two characters (in font units)
    def kerning(left : Char, right : Char) : Int16
      @parser.kerning(left, right)
    end

    # ===== Text Shaping =====

    # Shape text into positioned glyphs.
    #
    # This is a basic shaping implementation that handles:
    # - Character to glyph mapping
    # - Kerning
    # - Basic ligature substitution (if GSUB is available)
    #
    # For complex scripts (Arabic, Devanagari, etc.), consider
    # integrating with HarfBuzz for full Unicode support.
    #
    # ```
    # glyphs = font.shape("Hello!")
    # glyphs.each do |g|
    #   puts "Glyph #{g.id}: advance=#{g.x_advance}"
    # end
    # ```
    def shape(text : String, options : ShapingOptions = ShapingOptions.default) : Array(PositionedGlyph)
      return [] of PositionedGlyph if text.empty?

      effective_options = options
      effective_options.script ||= infer_script_tag(text)

      slots = text.chars.map_with_index do |char, index|
        ShaperSlot.new(glyph_id(char), index, char.ord.to_u32)
      end

      feature_settings = resolve_feature_settings(effective_options)

      if gsub_table = safe_gsub
        lookup_indices = active_gsub_lookup_indices(gsub_table, effective_options, feature_settings)
        slots = apply_gsub_lookups(slots, lookup_indices, gsub_table) unless lookup_indices.empty?
      end

      initialize_advances!(slots)

      gpos_kern_applied = false
      if gpos_table = safe_gpos
        lookup_indices = active_gpos_lookup_indices(gpos_table, effective_options, feature_settings)
        unless lookup_indices.empty?
          gpos_kern_applied = apply_gpos_lookups!(slots, lookup_indices, gpos_table)
        end
      end

      if feature_enabled?(feature_settings, "kern") && !gpos_kern_applied
        apply_legacy_kerning!(slots)
      end

      slots.map do |slot|
        PositionedGlyph.new(
          id: slot.id,
          codepoint: slot.codepoint,
          cluster: slot.cluster,
          x_offset: slot.x_offset,
          y_offset: slot.y_offset,
          x_advance: slot.x_advance,
          y_advance: slot.y_advance
        )
      end
    end

    # Shape text and render to positioned glyphs with cumulative positions.
    #
    # Unlike `shape`, this returns absolute positions suitable for rendering.
    #
    # ```
    # glyphs = font.render("Hello!")
    # glyphs.each do |g|
    #   puts "Glyph #{g.id} at x=#{g.x_offset}"
    # end
    # ```
    def render(text : String, options : ShapingOptions = ShapingOptions.default) : Array(PositionedGlyph)
      shaped = shape(text, options)
      return [] of PositionedGlyph if shaped.empty?

      result = [] of PositionedGlyph
      current_x = 0
      current_y = 0

      shaped.each do |glyph|
        # Position is cumulative + offset
        x_pos = current_x + glyph.x_offset
        y_pos = current_y + glyph.y_offset

        result << PositionedGlyph.new(
          id: glyph.id,
          codepoint: glyph.codepoint,
          cluster: glyph.cluster,
          x_offset: x_pos,
          y_offset: y_pos,
          x_advance: glyph.x_advance,
          y_advance: glyph.y_advance
        )

        # Advance position
        current_x += glyph.x_advance
        current_y += glyph.y_advance
      end

      result
    end

    # Calculate text width (in font units)
    def text_width(text : String) : Int32
      @parser.text_width(text)
    end

    {% if flag?(:harfbuzz) %}
      # Shape text using HarfBuzz for full OpenType support.
      #
      # This method requires the -Dharfbuzz compile flag and HarfBuzz library.
      # It provides full support for:
      # - Complex scripts (Arabic, Devanagari, Thai, etc.)
      # - OpenType feature application (ligatures, kerning, etc.)
      # - Bidirectional text
      # - Variable font axis settings
      #
      # ```
      # # Basic HarfBuzz shaping
      # glyphs = font.shape_advanced("مرحبا بالعالم")
      #
      # # With specific features
      # options = HarfBuzz::ShapingOptions.new(
      #   features: [HarfBuzz::Features.smcp, HarfBuzz::Features.liga]
      # )
      # glyphs = font.shape_advanced("Hello", options)
      #
      # # For Arabic text (auto-detected, but can be explicit)
      # glyphs = font.shape_advanced("مرحبا", HarfBuzz::ShapingOptions.arabic)
      # ```
      def shape_advanced(text : String, options : HarfBuzz::ShapingOptions = HarfBuzz::ShapingOptions.new) : Array(PositionedGlyph)
        result = HarfBuzz::Shaper.shape(self, text, options)

        # Convert HarfBuzz shaped glyphs to our PositionedGlyph format
        result.glyphs.map do |g|
          PositionedGlyph.new(
            id: g.id.to_u16,
            codepoint: 0_u32, # HarfBuzz doesn't preserve original codepoint
            cluster: g.cluster.to_i32,
            x_offset: g.x_offset,
            y_offset: g.y_offset,
            x_advance: g.x_advance,
            y_advance: g.y_advance
          )
        end
      end

      # Shape text using HarfBuzz and return positioned glyphs with cumulative positions.
      #
      # Unlike `shape_advanced`, this returns absolute positions suitable for rendering.
      def render_advanced(text : String, options : HarfBuzz::ShapingOptions = HarfBuzz::ShapingOptions.new) : Array(PositionedGlyph)
        result = HarfBuzz::Shaper.shape(self, text, options)

        # Convert to absolute positions
        glyphs = [] of PositionedGlyph
        current_x = 0
        current_y = 0

        result.glyphs.each do |g|
          x_pos = current_x + g.x_offset
          y_pos = current_y + g.y_offset

          glyphs << PositionedGlyph.new(
            id: g.id.to_u16,
            codepoint: 0_u32,
            cluster: g.cluster.to_i32,
            x_offset: x_pos,
            y_offset: y_pos,
            x_advance: g.x_advance,
            y_advance: g.y_advance
          )

          current_x += g.x_advance
          current_y += g.y_advance
        end

        glyphs
      end

      # Get the HarfBuzz shaping result directly (for advanced use cases).
      #
      # This returns the full HarfBuzz::ShapingResult which includes
      # additional information like total width/height and direction.
      def shape_harfbuzz(text : String, options : HarfBuzz::ShapingOptions = HarfBuzz::ShapingOptions.new) : HarfBuzz::ShapingResult
        HarfBuzz::Shaper.shape(self, text, options)
      end

      # Create a reusable HarfBuzz font for efficient repeated shaping.
      #
      # Use this when shaping many strings with the same font:
      # ```
      # hb_font = font.harfbuzz_font
      # texts.each do |text|
      #   result = HarfBuzz::Shaper.shape_with_font(hb_font, text)
      # end
      # ```
      def harfbuzz_font : HarfBuzz::Font
        HarfBuzz::Font.new(data)
      end
    {% end %}

    # Shape text with best effort - uses HarfBuzz if available, falls back to basic shaping.
    #
    # This is useful when you want HarfBuzz when available but don't want to
    # require it as a dependency.
    #
    # ```
    # # Uses HarfBuzz if compiled with -Dharfbuzz, otherwise basic shaping
    # glyphs = font.shape_best_effort("Hello مرحبا")
    # ```
    def shape_best_effort(text : String, options : ShapingOptions = ShapingOptions.default) : Array(PositionedGlyph)
      {% if flag?(:harfbuzz) %}
        # Convert ShapingOptions to HarfBuzz::ShapingOptions
        hb_features = [] of HarfBuzz::Feature
        hb_features << HarfBuzz::Features.liga(options.ligatures?)
        hb_features << HarfBuzz::Features.kern(options.kerning?)
        hb_features << HarfBuzz::Features.calt(options.contextual_alternates?)
        options.features.each { |f| hb_features << HarfBuzz::Feature.new(f) }

        direction = case options.direction
                    when :rtl then HarfBuzz::Direction::RTL
                    when :ttb then HarfBuzz::Direction::TTB
                    when :btt then HarfBuzz::Direction::BTT
                    else           HarfBuzz::Direction::LTR
                    end

        hb_options = HarfBuzz::ShapingOptions.new(
          direction: direction,
          script: options.script,
          language: options.language,
          features: hb_features
        )

        shape_advanced(text, hb_options)
      {% else %}
        shape(text, options)
      {% end %}
    end

    # ===== Text Layout =====

    # Create a text layout engine for this font.
    #
    # ```
    # layout = font.layout_engine
    # paragraph = layout.layout("Hello World!", LayoutOptions.new(max_width: 500))
    # ```
    def layout_engine : TextLayout
      TextLayout.new(self)
    end

    # Layout text with optional wrapping and alignment.
    #
    # ```
    # # Simple layout
    # paragraph = font.layout("Hello World!")
    #
    # # With wrapping
    # paragraph = font.layout("Hello World!", LayoutOptions.new(max_width: 500))
    # ```
    def layout(text : String, options : LayoutOptions = LayoutOptions.default) : ParagraphLayout
      layout_engine.layout(text, options)
    end

    # Measure text width without full layout.
    def measure_width(text : String, kerning : Bool = true) : Int32
      layout_engine.measure_width(text, kerning)
    end

    # ===== Variable Fonts =====

    # Get available variation axes.
    def variation_axes : Array(Tables::Variations::VariationAxisRecord)
      @parser.variation_axes
    end

    # Get named instances (preset axis combinations).
    def named_instances : Array(Tables::Variations::InstanceRecord)
      @parser.named_instances
    end

    # Create a variable font instance with specified axis values.
    #
    # Accepts axis values as named parameters or a hash.
    #
    # ```
    # # Using named axis tags
    # bold = font.instance(wght: 700)
    # condensed = font.instance(wght: 700, wdth: 75)
    #
    # # Using a hash
    # bold = font.instance({"wght" => 700.0, "wdth" => 75.0})
    # ```
    def instance(**axes) : VariationInstance
      vi = @parser.variation_instance
      axes.each do |tag, value|
        vi.set(tag.to_s, value.to_f64)
      end
      vi
    end

    # Create a variable font instance from a hash of axis values.
    def instance(axes : Hash(String, Float64)) : VariationInstance
      vi = @parser.variation_instance
      axes.each do |tag, value|
        vi.set(tag, value)
      end
      vi
    end

    # Create a variable font instance from a named instance index.
    def instance(named_instance_index : Int32) : VariationInstance?
      @parser.variation_instance(named_instance_index)
    end

    # ===== Subsetting =====

    # Create a subset font containing only the specified characters.
    #
    # ```
    # # Basic subset
    # subset = font.subset("Hello World!")
    #
    # # With options
    # subset = font.subset("Hello World!", SubsetOptions.web)
    # ```
    def subset(text : String, options : SubsetOptions = SubsetOptions.default) : Bytes
      chars = text.chars.to_set
      subset(chars, options)
    end

    # Create a subset from a set of characters.
    def subset(chars : Set(Char), options : SubsetOptions = SubsetOptions.default) : Bytes
      subsetter = Subsetter.new(@parser, options)

      # Add all characters
      chars.each { |c| subsetter.use(c) }

      subset_data = subsetter.subset
      convert_subset_format(subset_data, options)
    end

    # Create a subset from a set of codepoints.
    def subset(codepoints : Set(UInt32), options : SubsetOptions = SubsetOptions.default) : Bytes
      chars = codepoints.map { |cp| cp.chr rescue nil }.compact.to_set
      subset(chars, options)
    end

    private def convert_subset_format(subset_data : Bytes, options : SubsetOptions) : Bytes
      case options.output_format
      when :ttf
        raise SubsetError.new("Cannot emit :ttf output for a CFF-based subset") unless @parser.truetype?
        subset_data
      when :otf
        raise SubsetError.new("Cannot emit :otf output for a TrueType glyf-based subset") unless @parser.cff?
        subset_data
      when :woff
        Woff.from_sfnt(subset_data)
      when :woff2
        Woff2.from_sfnt(subset_data)
      else
        raise SubsetError.new("Unsupported subset output format: #{options.output_format}")
      end
    end

    # ===== Color Fonts =====

    # Check if a glyph has color data.
    def has_color_glyph?(glyph_id : UInt16) : Bool
      @parser.has_color_glyph?(glyph_id)
    end

    # Get color glyph type for a glyph.
    def color_glyph_type(glyph_id : UInt16) : Parser::ColorGlyphType?
      @parser.color_glyph_type(glyph_id)
    end

    # Get SVG document for a color glyph.
    def color_glyph_svg(glyph_id : UInt16) : String?
      @parser.color_glyph_svg(glyph_id)
    end

    # ===== Validation & Warnings =====

    # Get any warnings collected during parsing.
    def warnings : Array(String)
      @warnings.dup
    end

    # Check if there are any warnings.
    def warnings? : Bool
      !@warnings.empty?
    end

    # Validate the font and return detailed results.
    #
    # ```
    # result = font.validate
    # if result.valid?
    #   puts "Font is valid!"
    # else
    #   result.errors.each { |e| puts "Error: #{e}" }
    # end
    # ```
    def validate : ValidationResult
      validator = Validator.new(@parser)
      validator.validate
    end

    # Check if the font is valid.
    def valid? : Bool
      validate.valid?
    end

    # ===== Export & Conversion =====

    # Export font data as TTF/OTF bytes.
    #
    # For WOFF/WOFF2 fonts, this returns the decompressed sfnt data.
    def to_bytes : Bytes
      @parser.data
    end

    # Get the raw font data.
    def data : Bytes
      @parser.data
    end

    # ===== Private Helpers =====
    private GSUB_LOOKUP_RECURSION_LIMIT = 8
    private GPOS_LOOKUP_RECURSION_LIMIT = 8

    private GPOS_IGNORE_BASE_GLYPHS     = 0x0002_u16
    private GPOS_IGNORE_LIGATURES       = 0x0004_u16
    private GPOS_IGNORE_MARKS           = 0x0008_u16
    private GPOS_USE_MARK_FILTERING_SET = 0x0010_u16
    private MARK_ATTACH_TYPE_MASK       = 0xFF00_u16

    private alias IgnorePredicate = Proc(UInt16, Bool)

    private struct ShaperSlot
      property id : UInt16
      property cluster : Int32
      property codepoint : UInt32
      property x_offset : Int32
      property y_offset : Int32
      property x_advance : Int32
      property y_advance : Int32

      def initialize(@id : UInt16, @cluster : Int32, @codepoint : UInt32)
        @x_offset = 0
        @y_offset = 0
        @x_advance = 0
        @y_advance = 0
      end
    end

    private def resolve_feature_settings(options : ShapingOptions) : Hash(String, Bool)
      settings = Hash(String, Bool).new
      settings["liga"] = options.ligatures?
      settings["clig"] = options.ligatures?
      settings["kern"] = options.kerning?
      settings["calt"] = options.contextual_alternates?
      settings["ccmp"] = true
      settings["mark"] = true
      settings["mkmk"] = true

      if script = options.script
        script_default_features(script).each do |feature_tag|
          settings[feature_tag] = true
        end
      end

      options.features.each do |feature|
        next unless parsed = parse_feature_setting(feature)
        tag, enabled = parsed
        settings[tag] = enabled
      end

      settings
    end

    private def script_default_features(script_tag : String) : Array(String)
      case normalize_script_tag(script_tag)
      when "arab"
        ["ccmp", "init", "medi", "fina", "rlig", "liga"]
      when "hebr"
        ["ccmp", "hlig", "liga"]
      when "thai"
        ["ccmp"]
      when "deva"
        ["ccmp"]
      else
        [] of String
      end
    end

    private def infer_script_tag(text : String) : String?
      text.each_char do |char|
        codepoint = char.ord

        case codepoint
        when 0x0590..0x05FF
          return "hebr"
        when 0x0600..0x06FF, 0x0750..0x077F, 0x08A0..0x08FF
          return "arab"
        when 0x0900..0x097F
          return "deva"
        when 0x0E00..0x0E7F
          return "thai"
        when 0x0041..0x024F
          return "latn"
        end
      end

      nil
    end

    private def parse_feature_setting(feature : String) : Tuple(String, Bool)?
      raw = feature.strip
      return nil if raw.empty?

      enabled = true
      tag = raw

      if raw.starts_with?('-')
        enabled = false
        tag = raw[1..]
      elsif raw.starts_with?('+')
        tag = raw[1..]
      elsif (eq = raw.index('=')) && eq > 0
        tag = raw[0, eq]
        enabled = raw[(eq + 1)..].strip.to_i? != 0
      end

      normalized_tag = normalize_feature_tag(tag)
      return nil if normalized_tag.empty?

      {normalized_tag, enabled}
    end

    private def feature_enabled?(feature_settings : Hash(String, Bool), tag : String) : Bool
      feature_settings[normalize_feature_tag(tag)]? || false
    end

    private def normalize_feature_tag(tag : String) : String
      normalized = tag.strip
      return "" if normalized.empty?
      normalized = normalized[0, 4] if normalized.size > 4
      normalized.downcase
    end

    private def normalize_script_tag(tag : String) : String
      normalized = tag.strip
      return "" if normalized.empty?
      normalized = normalized[0, 4] if normalized.size > 4
      normalized.downcase
    end

    private def normalize_language_tag(tag : String) : String
      normalized = tag.strip
      return "" if normalized.empty?
      normalized = normalized[0, 4] if normalized.size > 4
      normalized.upcase
    end

    private def safe_gsub : Tables::OpenType::GSUB?
      @parser.gsub
    rescue
      nil
    end

    private def safe_gpos : Tables::OpenType::GPOS?
      @parser.gpos
    rescue
      nil
    end

    private def safe_gdef : Tables::OpenType::GDEF?
      @parser.gdef
    rescue
      nil
    end

    private def active_gsub_lookup_indices(gsub : Tables::OpenType::GSUB, options : ShapingOptions, feature_settings : Hash(String, Bool)) : Array(Int32)
      active_lookup_indices(gsub.feature_list, gsub.script_list, options, feature_settings)
    end

    private def active_gpos_lookup_indices(gpos : Tables::OpenType::GPOS, options : ShapingOptions, feature_settings : Hash(String, Bool)) : Array(Int32)
      active_lookup_indices(gpos.feature_list, gpos.script_list, options, feature_settings)
    end

    private def active_lookup_indices(feature_list : Tables::OpenType::FeatureList, script_list : Tables::OpenType::ScriptList, options : ShapingOptions, feature_settings : Hash(String, Bool)) : Array(Int32)
      allowed_feature_indices, required_feature_index = feature_scope_for(script_list, options.script, options.language)
      indices = [] of Int32
      seen = Set(Int32).new

      feature_list.features.each_with_index do |(tag, table), index|
        if allowed = allowed_feature_indices
          next unless allowed.includes?(index) || (required_feature_index && index == required_feature_index)
        end

        enabled = if required_feature_index && index == required_feature_index
                    true
                  else
                    feature_enabled?(feature_settings, tag)
                  end
        next unless enabled

        table.lookup_indices.each do |lookup_index|
          li = lookup_index.to_i
          next if seen.includes?(li)
          seen << li
          indices << li
        end
      end

      indices
    end

    private def feature_scope_for(script_list : Tables::OpenType::ScriptList, script_tag : String?, language_tag : String?) : {Set(Int32)?, Int32?}
      script_table = select_script_table(script_list, script_tag)
      return {nil, nil} unless script_table

      lang_sys = select_lang_sys(script_table, language_tag)
      return {nil, nil} unless lang_sys

      allowed = Set(Int32).new
      lang_sys.feature_indices.each { |index| allowed << index.to_i }

      required = lang_sys.has_required_feature? ? lang_sys.required_feature_index.to_i : nil
      {allowed, required}
    end

    private def select_script_table(script_list : Tables::OpenType::ScriptList, script_tag : String?) : Tables::OpenType::ScriptTable?
      if tag = script_tag
        normalized = normalize_script_tag(tag)
        unless normalized.empty?
          script_list.scripts.each do |script_record_tag, script_table|
            return script_table if normalize_script_tag(script_record_tag) == normalized
          end
        end
      end

      script_list.default_script || script_list.scripts.values.first?
    end

    private def select_lang_sys(script_table : Tables::OpenType::ScriptTable, language_tag : String?) : Tables::OpenType::LangSys?
      if tag = language_tag
        normalized = normalize_language_tag(tag)
        unless normalized.empty?
          script_table.lang_sys_tables.each do |lang_record_tag, lang_sys|
            return lang_sys if normalize_language_tag(lang_record_tag) == normalized
          end
        end
      end

      script_table.default_lang_sys || script_table.lang_sys_tables.values.first?
    end

    private def initialize_advances!(slots : Array(ShaperSlot)) : Nil
      slots.each_with_index do |slot, index|
        slot.x_offset = 0
        slot.y_offset = 0
        slot.x_advance = advance_width(slot.id).to_i32
        slot.y_advance = 0
        slots[index] = slot
      end
    end

    private def apply_legacy_kerning!(slots : Array(ShaperSlot)) : Nil
      return unless kern_table = @parser.kern

      prev_glyph : UInt16? = nil
      slots.each_with_index do |slot, index|
        if previous = prev_glyph
          kern = kern_table.kern(previous, slot.id).to_i32
          if kern != 0
            slot.x_offset += kern
            slots[index] = slot
          end
        end
        prev_glyph = slot.id
      end
    end

    private def apply_gsub_lookups(slots : Array(ShaperSlot), lookup_indices : Array(Int32), gsub : Tables::OpenType::GSUB) : Array(ShaperSlot)
      result = slots
      lookup_indices.each do |lookup_index|
        lookup = gsub.lookup(lookup_index)
        next unless lookup
        result = apply_gsub_lookup(result, lookup, gsub)
      end
      result
    end

    private def apply_gsub_lookup(slots : Array(ShaperSlot), lookup : Tables::OpenType::GSUBLookup, gsub : Tables::OpenType::GSUB, target_index : Int32? = nil, depth : Int32 = 0) : Array(ShaperSlot)
      return slots if depth > GSUB_LOOKUP_RECURSION_LIMIT

      if index = target_index
        return slots if index < 0 || index >= slots.size

        lookup.subtables.each do |subtable|
          applied, updated, _advance = apply_gsub_subtable_at_index(slots, subtable, lookup, gsub, index, depth)
          return updated if applied
        end
        return slots
      end

      result = slots
      i = 0
      while i < result.size
        applied = false

        lookup.subtables.each do |subtable|
          changed, updated, advance = apply_gsub_subtable_at_index(result, subtable, lookup, gsub, i, depth)
          next unless changed

          result = updated
          i += (advance > 0 ? advance : 1)
          applied = true
          break
        end

        i += 1 unless applied
      end

      result
    end

    private def apply_gsub_subtable_at_index(slots : Array(ShaperSlot), subtable : Tables::OpenType::GSUBSubtable, lookup : Tables::OpenType::GSUBLookup, gsub : Tables::OpenType::GSUB, index : Int32, depth : Int32) : {Bool, Array(ShaperSlot), Int32}
      return {false, slots, 1} if index < 0 || index >= slots.size

      slot = slots[index]
      ignore = glyph_ignored_for_gsub_lookup?(lookup, slot.id)

      case subtable
      when Tables::OpenType::SingleSubstFormat1, Tables::OpenType::SingleSubstFormat2
        return {false, slots, 1} if ignore
        if substitute = subtable.substitute(slot.id)
          slot.id = substitute
          slots[index] = slot
          return {true, slots, 1}
        end
      when Tables::OpenType::MultipleSubst
        return {false, slots, 1} if ignore
        if sequence = subtable.substitute(slot.id)
          return {false, slots, 1} if sequence.empty?

          replacement = sequence.map_with_index do |glyph_id, replacement_index|
            codepoint = replacement_index.zero? ? slot.codepoint : 0_u32
            ShaperSlot.new(glyph_id, slot.cluster, codepoint)
          end

          updated = replace_slots(slots, index, 1, replacement)
          return {true, updated, replacement.size}
        end
      when Tables::OpenType::AlternateSubst
        return {false, slots, 1} if ignore
        if alternates = subtable.alternates(slot.id)
          if alternate = alternates.first?
            slot.id = alternate
            slots[index] = slot
            return {true, slots, 1}
          end
        end
      when Tables::OpenType::LigatureSubst
        return {false, slots, 1} if ignore
        if ligatures = subtable.ligatures_for(slot.id)
          best_entry : Tables::OpenType::LigatureEntry? = nil
          best_positions : Array(Int32)? = nil

          ligatures.each do |entry|
            positions = match_ligature_component_positions(slots, index, entry.component_glyphs, lookup)
            next unless positions

            if current_best = best_positions
              next unless positions.size > current_best.size
            end

            best_entry = entry
            best_positions = positions
          end

          if entry = best_entry
            positions = best_positions.not_nil!
            ligature_slot = ShaperSlot.new(entry.ligature_glyph, slot.cluster, 0_u32)
            updated = replace_slots(slots, index, positions.size, [ligature_slot])
            return {true, updated, 1}
          end
        end
      when Tables::OpenType::ContextSubstFormat1
        ignored = ->(gid : UInt16) { glyph_ignored_for_gsub_lookup?(lookup, gid) }
        if rules = subtable.rules_for(slot.id)
          rules.each do |rule|
            positions = match_glyph_sequence_positions(slots, index, rule.glyph_sequence, ignored)
            next unless positions

            updated = apply_gsub_lookup_records(slots, positions, rule.lookup_records, gsub, depth + 1)
            return {true, updated, 1}
          end
        end
      when Tables::OpenType::ContextSubstFormat2
        ignored = ->(gid : UInt16) { glyph_ignored_for_gsub_lookup?(lookup, gid) }
        if rules = subtable.rules_for(slot.id)
          rules.each do |rule|
            positions = match_class_sequence_positions(slots, index, subtable.class_def, rule.class_sequence, ignored)
            next unless positions

            updated = apply_gsub_lookup_records(slots, positions, rule.lookup_records, gsub, depth + 1)
            return {true, updated, 1}
          end
        end
      when Tables::OpenType::ContextSubstFormat3
        ignored = ->(gid : UInt16) { glyph_ignored_for_gsub_lookup?(lookup, gid) }
        if positions = match_coverage_sequence_positions(slots, index, subtable.coverages, ignored)
          updated = apply_gsub_lookup_records(slots, positions, subtable.lookup_records, gsub, depth + 1)
          return {true, updated, 1}
        end
      when Tables::OpenType::ChainedContextSubstFormat1
        ignored = ->(gid : UInt16) { glyph_ignored_for_gsub_lookup?(lookup, gid) }
        if rules = subtable.rules_for(slot.id)
          rules.each do |rule|
            positions = match_chained_glyph_rule_positions(slots, index, rule, ignored)
            next unless positions

            updated = apply_gsub_lookup_records(slots, positions, rule.lookup_records, gsub, depth + 1)
            return {true, updated, 1}
          end
        end
      when Tables::OpenType::ChainedContextSubstFormat2
        ignored = ->(gid : UInt16) { glyph_ignored_for_gsub_lookup?(lookup, gid) }
        if rules = subtable.rules_for(slot.id)
          rules.each do |rule|
            positions = match_chained_class_rule_positions(
              slots,
              index,
              rule,
              subtable.backtrack_class_def,
              subtable.input_class_def,
              subtable.lookahead_class_def,
              ignored
            )
            next unless positions

            updated = apply_gsub_lookup_records(slots, positions, rule.lookup_records, gsub, depth + 1)
            return {true, updated, 1}
          end
        end
      when Tables::OpenType::ChainedContextSubstFormat3
        ignored = ->(gid : UInt16) { glyph_ignored_for_gsub_lookup?(lookup, gid) }
        if positions = match_chained_coverage_positions(
             slots,
             index,
             subtable.backtrack_coverages,
             subtable.input_coverages,
             subtable.lookahead_coverages,
             ignored
           )
          updated = apply_gsub_lookup_records(slots, positions, subtable.lookup_records, gsub, depth + 1)
          return {true, updated, 1}
        end
      when Tables::OpenType::ReverseChainSubst
        ignored = ->(gid : UInt16) { glyph_ignored_for_gsub_lookup?(lookup, gid) }
        return {false, slots, 1} if ignored.call(slot.id)

        if reverse_chaining_match?(slots, index, subtable, ignored)
          if substitute = subtable.substitute(slot.id)
            slot.id = substitute
            slots[index] = slot
            return {true, slots, 1}
          end
        end
      end

      {false, slots, 1}
    end

    private def apply_gsub_lookup_records(slots : Array(ShaperSlot), positions : Array(Int32), records : Array(Tables::OpenType::SequenceLookupRecord), gsub : Tables::OpenType::GSUB, depth : Int32) : Array(ShaperSlot)
      result = slots
      position_map = positions.dup

      records.each do |record|
        sequence_index = record.sequence_index.to_i
        target_index = position_map[sequence_index]?
        next unless target_index

        nested_lookup = gsub.lookup(record.lookup_index.to_i)
        next unless nested_lookup

        before_size = result.size
        result = apply_gsub_lookup(result, nested_lookup, gsub, target_index, depth)
        size_delta = result.size - before_size

        if size_delta != 0
          ((sequence_index + 1)...position_map.size).each do |i|
            position_map[i] += size_delta
          end
        end
      end

      result
    end

    private def apply_gpos_lookups!(slots : Array(ShaperSlot), lookup_indices : Array(Int32), gpos : Tables::OpenType::GPOS) : Bool
      kern_applied = false

      lookup_indices.each do |lookup_index|
        lookup = gpos.lookup(lookup_index)
        next unless lookup

        changed = apply_gpos_lookup!(slots, lookup, gpos)
        if changed && lookup.lookup_type.pair_adjustment?
          kern_applied = true
        end
      end

      kern_applied
    end

    private def apply_gpos_lookup!(slots : Array(ShaperSlot), lookup : Tables::OpenType::GPOSLookup, gpos : Tables::OpenType::GPOS, target_index : Int32? = nil, depth : Int32 = 0) : Bool
      return false if depth > GPOS_LOOKUP_RECURSION_LIMIT

      if index = target_index
        return false if index < 0 || index >= slots.size
        lookup.subtables.each do |subtable|
          return true if apply_gpos_subtable_at_index!(slots, subtable, lookup, gpos, index, depth)
        end
        return false
      end

      changed = false
      i = 0
      while i < slots.size
        lookup.subtables.each do |subtable|
          subtable_changed = apply_gpos_subtable_at_index!(slots, subtable, lookup, gpos, i, depth)
          next unless subtable_changed

          changed = true
          break
        end
        i += 1
      end

      changed
    end

    private def apply_gpos_subtable_at_index!(slots : Array(ShaperSlot), subtable : Tables::OpenType::GPOSSubtable, lookup : Tables::OpenType::GPOSLookup, gpos : Tables::OpenType::GPOS, index : Int32, depth : Int32) : Bool
      return false if index < 0 || index >= slots.size

      slot = slots[index]
      ignored = ->(gid : UInt16) { glyph_ignored_for_gpos_lookup?(lookup, gid) }
      return false if ignored.call(slot.id)

      case subtable
      when Tables::OpenType::SinglePosFormat1, Tables::OpenType::SinglePosFormat2
        if value = subtable.adjustment(slot.id)
          apply_value_record!(slots, index, value)
          return true
        end
      when Tables::OpenType::PairPosFormat1, Tables::OpenType::PairPosFormat2
        second_index = next_relevant_index(slots, index + 1, ignored)
        return false unless second_index

        first = slots[index].id
        second = slots[second_index].id
        if adjustment = subtable.adjustment(first, second)
          apply_value_record!(slots, index, adjustment[0])
          apply_value_record!(slots, second_index, adjustment[1])
          return true
        end
      when Tables::OpenType::CursivePos
        previous_index = prev_relevant_index(slots, index - 1, ignored)
        return false unless previous_index

        prev_record = subtable.entry_exit(slots[previous_index].id)
        current_record = subtable.entry_exit(slot.id)
        return false unless prev_record && current_record

        prev_exit = prev_record.exit_anchor
        current_entry = current_record.entry_anchor
        return false unless prev_exit && current_entry

        slot.x_offset += prev_exit.x.to_i32 - current_entry.x.to_i32
        slot.y_offset += prev_exit.y.to_i32 - current_entry.y.to_i32
        slots[index] = slot
        return true
      when Tables::OpenType::MarkBasePos
        base_index = find_mark_base_index(slots, index, subtable, ignored)
        return false unless base_index

        if attachment = subtable.attachment(slot.id, slots[base_index].id)
          mark_anchor, base_anchor = attachment
          slot.x_offset += base_anchor.x.to_i32 - mark_anchor.x.to_i32
          slot.y_offset += base_anchor.y.to_i32 - mark_anchor.y.to_i32
          slots[index] = slot
          return true
        end
      when Tables::OpenType::MarkMarkPos
        if apply_mark_to_mark!(slots, index, subtable, ignored)
          return true
        end
      when Tables::OpenType::ContextPosFormat1
        if rules = subtable.rules_for(slot.id)
          rules.each do |rule|
            positions = match_glyph_sequence_positions(slots, index, rule.glyph_sequence, ignored)
            next unless positions

            apply_gpos_lookup_records!(slots, positions, rule.lookup_records, gpos, depth + 1)
            return true
          end
        end
      when Tables::OpenType::ContextPosFormat2
        if rules = subtable.rules_for(slot.id)
          rules.each do |rule|
            positions = match_class_sequence_positions(slots, index, subtable.class_def, rule.class_sequence, ignored)
            next unless positions

            apply_gpos_lookup_records!(slots, positions, rule.lookup_records, gpos, depth + 1)
            return true
          end
        end
      when Tables::OpenType::ContextPosFormat3
        if positions = match_coverage_sequence_positions(slots, index, subtable.coverages, ignored)
          apply_gpos_lookup_records!(slots, positions, subtable.lookup_records, gpos, depth + 1)
          return true
        end
      when Tables::OpenType::ChainedContextPosFormat1
        if rules = subtable.rules_for(slot.id)
          rules.each do |rule|
            positions = match_chained_glyph_rule_positions(slots, index, rule, ignored)
            next unless positions

            apply_gpos_lookup_records!(slots, positions, rule.lookup_records, gpos, depth + 1)
            return true
          end
        end
      when Tables::OpenType::ChainedContextPosFormat2
        if rules = subtable.rules_for(slot.id)
          rules.each do |rule|
            positions = match_chained_class_rule_positions(
              slots,
              index,
              rule,
              subtable.backtrack_class_def,
              subtable.input_class_def,
              subtable.lookahead_class_def,
              ignored
            )
            next unless positions

            apply_gpos_lookup_records!(slots, positions, rule.lookup_records, gpos, depth + 1)
            return true
          end
        end
      when Tables::OpenType::ChainedContextPosFormat3
        if positions = match_chained_coverage_positions(
             slots,
             index,
             subtable.backtrack_coverages,
             subtable.input_coverages,
             subtable.lookahead_coverages,
             ignored
           )
          apply_gpos_lookup_records!(slots, positions, subtable.lookup_records, gpos, depth + 1)
          return true
        end
      end

      false
    end

    private def apply_gpos_lookup_records!(slots : Array(ShaperSlot), positions : Array(Int32), records : Array(Tables::OpenType::SequenceLookupRecord), gpos : Tables::OpenType::GPOS, depth : Int32) : Nil
      records.each do |record|
        sequence_index = record.sequence_index.to_i
        target_index = positions[sequence_index]?
        next unless target_index

        lookup = gpos.lookup(record.lookup_index.to_i)
        next unless lookup

        apply_gpos_lookup!(slots, lookup, gpos, target_index, depth)
      end
    end

    private def apply_mark_to_mark!(slots : Array(ShaperSlot), index : Int32, subtable : Tables::OpenType::MarkMarkPos, ignored : IgnorePredicate) : Bool
      mark1_glyph = slots[index].id
      mark1_idx = subtable.mark1_coverage.coverage_index(mark1_glyph)
      return false unless mark1_idx

      mark1_record = subtable.mark1_records[mark1_idx]?
      return false unless mark1_record

      search_index = index - 1
      while mark2_index = prev_relevant_index(slots, search_index, ignored)
        mark2_glyph = slots[mark2_index].id
        mark2_cov_idx = subtable.mark2_coverage.coverage_index(mark2_glyph)
        if mark2_cov_idx
          mark2_record = subtable.mark2_records[mark2_cov_idx]?
          if mark2_record
            base_anchor = mark2_record.base_anchors[mark1_record.mark_class]?
            if base_anchor
              slot = slots[index]
              slot.x_offset += base_anchor.x.to_i32 - mark1_record.mark_anchor.x.to_i32
              slot.y_offset += base_anchor.y.to_i32 - mark1_record.mark_anchor.y.to_i32
              slots[index] = slot
              return true
            end
          end
        end

        search_index = mark2_index - 1
      end

      false
    end

    private def find_mark_base_index(slots : Array(ShaperSlot), mark_index : Int32, subtable : Tables::OpenType::MarkBasePos, ignored : IgnorePredicate) : Int32?
      search_index = mark_index - 1
      while base_index = prev_relevant_index(slots, search_index, ignored)
        return base_index if subtable.base_coverage.covers?(slots[base_index].id)
        search_index = base_index - 1
      end
      nil
    end

    private def apply_value_record!(slots : Array(ShaperSlot), index : Int32, value : Tables::OpenType::ValueRecord) : Nil
      slot = slots[index]
      slot.x_offset += value.x_placement.to_i32
      slot.y_offset += value.y_placement.to_i32
      slot.x_advance += value.x_advance.to_i32
      slot.y_advance += value.y_advance.to_i32
      slots[index] = slot
    end

    private def match_ligature_component_positions(slots : Array(ShaperSlot), start_index : Int32, components : Array(UInt16), lookup : Tables::OpenType::GSUBLookup) : Array(Int32)?
      ignored = ->(gid : UInt16) { glyph_ignored_for_gsub_lookup?(lookup, gid) }
      return nil if ignored.call(slots[start_index].id)

      positions = [start_index]
      current = start_index

      components.each do |expected_glyph|
        next_index = next_relevant_index(slots, current + 1, ignored)
        return nil unless next_index
        return nil unless slots[next_index].id == expected_glyph

        positions << next_index
        current = next_index
      end

      (1...positions.size).each do |i|
        return nil if positions[i] != positions[i - 1] + 1
      end

      positions
    end

    private def match_glyph_sequence_positions(slots : Array(ShaperSlot), start_index : Int32, glyph_sequence : Array(UInt16), ignored : IgnorePredicate) : Array(Int32)?
      return nil if start_index < 0 || start_index >= slots.size
      return nil if ignored.call(slots[start_index].id)

      positions = [start_index]
      current = start_index

      glyph_sequence.each do |expected_glyph|
        next_index = next_relevant_index(slots, current + 1, ignored)
        return nil unless next_index
        return nil unless slots[next_index].id == expected_glyph

        positions << next_index
        current = next_index
      end

      positions
    end

    private def match_class_sequence_positions(slots : Array(ShaperSlot), start_index : Int32, class_def : Tables::OpenType::ClassDef, class_sequence : Array(UInt16), ignored : IgnorePredicate) : Array(Int32)?
      return nil if start_index < 0 || start_index >= slots.size
      return nil if ignored.call(slots[start_index].id)

      positions = [start_index]
      current = start_index

      class_sequence.each do |expected_class|
        next_index = next_relevant_index(slots, current + 1, ignored)
        return nil unless next_index
        return nil unless class_def.class_id(slots[next_index].id) == expected_class

        positions << next_index
        current = next_index
      end

      positions
    end

    private def match_coverage_sequence_positions(slots : Array(ShaperSlot), start_index : Int32, coverages : Array(Tables::OpenType::Coverage), ignored : IgnorePredicate) : Array(Int32)?
      return nil if coverages.empty?
      return nil if start_index < 0 || start_index >= slots.size
      return nil if ignored.call(slots[start_index].id)

      first_coverage = coverages[0]
      return nil unless first_coverage.covers?(slots[start_index].id)

      positions = [start_index]
      current = start_index

      coverages[1..].each do |coverage|
        next_index = next_relevant_index(slots, current + 1, ignored)
        return nil unless next_index
        return nil unless coverage.covers?(slots[next_index].id)

        positions << next_index
        current = next_index
      end

      positions
    end

    private def match_chained_glyph_rule_positions(slots : Array(ShaperSlot), start_index : Int32, rule : Tables::OpenType::ChainedSequenceRule, ignored : IgnorePredicate) : Array(Int32)?
      input_positions = match_glyph_sequence_positions(slots, start_index, rule.input_sequence, ignored)
      return nil unless input_positions

      current = start_index
      rule.backtrack_sequence.each do |expected_glyph|
        prev_index = prev_relevant_index(slots, current - 1, ignored)
        return nil unless prev_index
        return nil unless slots[prev_index].id == expected_glyph
        current = prev_index
      end

      current = input_positions.last
      rule.lookahead_sequence.each do |expected_glyph|
        next_index = next_relevant_index(slots, current + 1, ignored)
        return nil unless next_index
        return nil unless slots[next_index].id == expected_glyph
        current = next_index
      end

      input_positions
    end

    private def match_chained_class_rule_positions(slots : Array(ShaperSlot), start_index : Int32, rule : Tables::OpenType::ChainedClassSequenceRule, backtrack_class_def : Tables::OpenType::ClassDef, input_class_def : Tables::OpenType::ClassDef, lookahead_class_def : Tables::OpenType::ClassDef, ignored : IgnorePredicate) : Array(Int32)?
      input_positions = match_class_sequence_positions(slots, start_index, input_class_def, rule.input_sequence, ignored)
      return nil unless input_positions

      current = start_index
      rule.backtrack_sequence.each do |expected_class|
        prev_index = prev_relevant_index(slots, current - 1, ignored)
        return nil unless prev_index
        return nil unless backtrack_class_def.class_id(slots[prev_index].id) == expected_class
        current = prev_index
      end

      current = input_positions.last
      rule.lookahead_sequence.each do |expected_class|
        next_index = next_relevant_index(slots, current + 1, ignored)
        return nil unless next_index
        return nil unless lookahead_class_def.class_id(slots[next_index].id) == expected_class
        current = next_index
      end

      input_positions
    end

    private def match_chained_coverage_positions(slots : Array(ShaperSlot), start_index : Int32, backtrack_coverages : Array(Tables::OpenType::Coverage), input_coverages : Array(Tables::OpenType::Coverage), lookahead_coverages : Array(Tables::OpenType::Coverage), ignored : IgnorePredicate) : Array(Int32)?
      input_positions = match_coverage_sequence_positions(slots, start_index, input_coverages, ignored)
      return nil unless input_positions

      current = start_index
      backtrack_coverages.each do |coverage|
        prev_index = prev_relevant_index(slots, current - 1, ignored)
        return nil unless prev_index
        return nil unless coverage.covers?(slots[prev_index].id)
        current = prev_index
      end

      current = input_positions.last
      lookahead_coverages.each do |coverage|
        next_index = next_relevant_index(slots, current + 1, ignored)
        return nil unless next_index
        return nil unless coverage.covers?(slots[next_index].id)
        current = next_index
      end

      input_positions
    end

    private def reverse_chaining_match?(slots : Array(ShaperSlot), index : Int32, subtable : Tables::OpenType::ReverseChainSubst, ignored : IgnorePredicate) : Bool
      return false unless subtable.input_coverage.covers?(slots[index].id)

      current = index
      subtable.backtrack_coverages.each do |coverage|
        prev_index = prev_relevant_index(slots, current - 1, ignored)
        return false unless prev_index
        return false unless coverage.covers?(slots[prev_index].id)
        current = prev_index
      end

      current = index
      subtable.lookahead_coverages.each do |coverage|
        next_index = next_relevant_index(slots, current + 1, ignored)
        return false unless next_index
        return false unless coverage.covers?(slots[next_index].id)
        current = next_index
      end

      true
    end

    private def next_relevant_index(slots : Array(ShaperSlot), start_index : Int32, ignored : IgnorePredicate) : Int32?
      index = start_index
      while index < slots.size
        return index unless ignored.call(slots[index].id)
        index += 1
      end
      nil
    end

    private def prev_relevant_index(slots : Array(ShaperSlot), start_index : Int32, ignored : IgnorePredicate) : Int32?
      index = start_index
      while index >= 0
        return index unless ignored.call(slots[index].id)
        index -= 1
      end
      nil
    end

    private def replace_slots(slots : Array(ShaperSlot), start_index : Int32, remove_count : Int32, insert_slots : Array(ShaperSlot)) : Array(ShaperSlot)
      prefix = start_index > 0 ? slots[0, start_index] : ([] of ShaperSlot)

      suffix_start = start_index + remove_count
      suffix_count = slots.size - suffix_start
      suffix = suffix_count > 0 ? slots[suffix_start, suffix_count] : ([] of ShaperSlot)

      prefix + insert_slots + suffix
    end

    private def glyph_ignored_for_gsub_lookup?(lookup : Tables::OpenType::GSUBLookup, glyph_id : UInt16) : Bool
      return false unless gdef = safe_gdef

      return true if lookup.ignore_marks? && gdef.mark?(glyph_id)
      return true if lookup.ignore_ligatures? && gdef.ligature?(glyph_id)
      return true if lookup.ignore_base_glyphs? && gdef.base?(glyph_id)

      mark_attach_type = ((lookup.lookup_flag & MARK_ATTACH_TYPE_MASK) >> 8).to_u16
      if mark_attach_type != 0 && gdef.mark?(glyph_id)
        return true unless gdef.mark_attach_class(glyph_id) == mark_attach_type
      end

      if set = lookup.mark_filtering_set
        if gdef.mark?(glyph_id) && !gdef.in_mark_glyph_set?(glyph_id, set.to_i)
          return true
        end
      end

      false
    end

    private def glyph_ignored_for_gpos_lookup?(lookup : Tables::OpenType::GPOSLookup, glyph_id : UInt16) : Bool
      return false unless gdef = safe_gdef

      return true if (lookup.lookup_flag & GPOS_IGNORE_MARKS) != 0 && gdef.mark?(glyph_id)
      return true if (lookup.lookup_flag & GPOS_IGNORE_LIGATURES) != 0 && gdef.ligature?(glyph_id)
      return true if (lookup.lookup_flag & GPOS_IGNORE_BASE_GLYPHS) != 0 && gdef.base?(glyph_id)

      mark_attach_type = ((lookup.lookup_flag & MARK_ATTACH_TYPE_MASK) >> 8).to_u16
      if mark_attach_type != 0 && gdef.mark?(glyph_id)
        return true unless gdef.mark_attach_class(glyph_id) == mark_attach_type
      end

      if set = lookup.mark_filtering_set
        if (lookup.lookup_flag & GPOS_USE_MARK_FILTERING_SET) != 0
          if gdef.mark?(glyph_id) && !gdef.in_mark_glyph_set?(glyph_id, set.to_i)
            return true
          end
        end
      end

      false
    end
  end
end
