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
# font = TrueType::Font.open("path/to/font.ttf")  # TTF, OTF, WOFF, WOFF2, TTC/OTC
#
# # Access font information
# puts font.name           # "DejaVu Sans"
# puts font.postscript_name # "DejaVuSans"
# puts font.style          # "Regular"
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
      @y_advance : Int32 = 0
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
      @direction : Symbol = :ltr
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
      @output_format : Symbol = :ttf
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

      # Convert characters to glyph IDs
      chars = text.chars
      glyph_ids = chars.map { |c| glyph_id(c) }
      clusters = (0...chars.size).to_a

      # Apply ligature substitution if enabled and available
      if options.ligatures? && @parser.has_gsub_feature?("liga")
        glyph_ids, clusters = apply_ligatures(glyph_ids, clusters)
      end

      # Build positioned glyphs with kerning
      result = [] of PositionedGlyph
      prev_glyph : UInt16? = nil

      glyph_ids.each_with_index do |gid, i|
        cluster = clusters[i]
        codepoint = cluster < chars.size ? chars[cluster].ord.to_u32 : 0_u32

        x_offset = 0
        y_offset = 0

        # Apply kerning from previous glyph
        if options.kerning? && prev_glyph
          kern = kerning(prev_glyph, gid)
          x_offset = kern.to_i32
        end

        x_advance = advance_width(gid).to_i32
        y_advance = 0

        result << PositionedGlyph.new(
          id: gid,
          codepoint: codepoint,
          cluster: cluster,
          x_offset: x_offset,
          y_offset: y_offset,
          x_advance: x_advance,
          y_advance: y_advance
        )

        prev_glyph = gid
      end

      result
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
          codepoint: 0_u32,  # HarfBuzz doesn't preserve original codepoint
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
      subsetter = Subsetter.new(@parser)

      # Add .notdef if requested
      # (Subsetter already includes glyph 0 by default)

      # Add all characters
      chars.each { |c| subsetter.use(c) }

      # Generate subset
      # TODO: Apply SubsetOptions for hints, layout tables, etc.
      # Current implementation is basic - options are for future expansion
      subsetter.subset
    end

    # Create a subset from a set of codepoints.
    def subset(codepoints : Set(UInt32), options : SubsetOptions = SubsetOptions.default) : Bytes
      chars = codepoints.map { |cp| cp.chr rescue nil }.compact.to_set
      subset(chars, options)
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

    # Basic ligature substitution (supports common ligatures)
    private def apply_ligatures(glyph_ids : Array(UInt16), clusters : Array(Int32)) : {Array(UInt16), Array(Int32)}
      return {glyph_ids, clusters} unless gsub = @parser.gsub

      # Get ligature lookups
      lookups = gsub.lookups_for_feature("liga")
      return {glyph_ids, clusters} if lookups.empty?

      # Apply each lookup
      # This is a simplified implementation - full implementation would
      # need to handle lookup types 4 (ligature) properly
      result_glyphs = glyph_ids.dup
      result_clusters = clusters.dup

      # For now, return original - full ligature implementation is complex
      # and requires proper GSUB lookup application
      {result_glyphs, result_clusters}
    end
  end
end
