# Text layout module for TrueType fonts.
#
# Provides basic text layout capabilities including:
# - Text measurement with kerning
# - Line breaking
# - Text alignment
# - Basic paragraph layout
#
# For full international text support (bidi, complex scripts),
# consider integrating with HarfBuzz and ICU.

module TrueType
  # Text alignment options
  enum TextAlign
    Left
    Center
    Right
    Justify
  end

  # Text direction
  enum TextDirection
    LeftToRight
    RightToLeft
  end

  # A laid-out line of text
  struct TextLine
    # Glyphs in this line
    getter glyphs : Array(PositionedGlyph)

    # Width of the line in font units
    getter width : Int32

    # Ascent of the line (max ascent of all glyphs)
    getter ascent : Int16

    # Descent of the line (max descent of all glyphs)
    getter descent : Int16

    # Original text range: start index in source string
    getter start_index : Int32

    # Original text range: end index in source string
    getter end_index : Int32

    # Whether this line ends with a hard break (newline)
    getter? hard_break : Bool

    def initialize(
      @glyphs : Array(PositionedGlyph),
      @width : Int32,
      @ascent : Int16,
      @descent : Int16,
      @start_index : Int32,
      @end_index : Int32,
      @hard_break : Bool = false
    )
    end

    # Height of the line (ascent + |descent|)
    def height : Int32
      @ascent.to_i32 + @descent.abs.to_i32
    end

    # Check if line is empty
    def empty? : Bool
      @glyphs.empty?
    end
  end

  # Result of a paragraph layout
  struct ParagraphLayout
    # Lines of text
    getter lines : Array(TextLine)

    # Total width (max line width)
    getter width : Int32

    # Total height
    getter height : Int32

    # Number of lines
    getter line_count : Int32

    def initialize(@lines : Array(TextLine))
      @width = @lines.empty? ? 0 : @lines.max_of(&.width)
      @height = @lines.sum(&.height)
      @line_count = @lines.size
    end

    # Check if empty
    def empty? : Bool
      @lines.empty?
    end

    # Iterate over lines
    def each_line(& : TextLine ->)
      @lines.each { |line| yield line }
    end

    # Iterate over lines with y position
    def each_line_with_position(& : TextLine, Int32 ->)
      y = 0
      @lines.each do |line|
        y += line.ascent.to_i32
        yield line, y
        y += line.descent.abs.to_i32
      end
    end
  end

  # Options for text layout
  struct LayoutOptions
    # Maximum width for line breaking (nil = no wrapping)
    property max_width : Int32?

    # Line height multiplier (1.0 = single spaced)
    property line_height : Float64

    # Text alignment
    property align : TextAlign

    # Text direction
    property direction : TextDirection

    # Enable kerning
    property? kerning : Bool

    # Enable ligatures
    property? ligatures : Bool

    # Word wrap mode: true = break at word boundaries, false = break anywhere
    property? word_wrap : Bool

    # Characters to treat as word break opportunities
    property word_break_chars : String

    # Hyphenation character (nil = no hyphenation)
    property hyphen_char : Char?

    def initialize(
      @max_width : Int32? = nil,
      @line_height : Float64 = 1.0,
      @align : TextAlign = TextAlign::Left,
      @direction : TextDirection = TextDirection::LeftToRight,
      @kerning : Bool = true,
      @ligatures : Bool = true,
      @word_wrap : Bool = true,
      @word_break_chars : String = " \t-",
      @hyphen_char : Char? = nil
    )
    end

    def self.default : LayoutOptions
      new
    end

    def self.single_line : LayoutOptions
      new(max_width: nil)
    end
  end

  # Text layout engine for a font
  class TextLayout
    getter font : Font

    def initialize(@font : Font)
    end

    # Measure the width of a text string (in font units)
    def measure_width(text : String, kerning : Bool = true) : Int32
      return 0 if text.empty?

      width = 0
      prev_glyph : UInt16? = nil

      text.each_char do |char|
        glyph = @font.glyph_id(char)

        # Add kerning
        if kerning && prev_glyph
          width += @font.kerning(prev_glyph, glyph).to_i32
        end

        # Add advance width
        width += @font.advance_width(glyph).to_i32
        prev_glyph = glyph
      end

      width
    end

    # Measure the height of text (in font units) for a given number of lines
    def measure_height(line_count : Int32, line_height : Float64 = 1.0) : Int32
      return 0 if line_count <= 0

      base_height = @font.ascender.to_i32 + @font.descender.abs.to_i32
      first_line = base_height
      additional_lines = (line_count - 1) * (base_height * line_height).to_i32

      first_line + additional_lines
    end

    # Layout a single line of text (no wrapping)
    def layout_line(text : String, options : LayoutOptions = LayoutOptions.default) : TextLine
      return empty_line(0, 0) if text.empty?

      shaping_options = ShapingOptions.new(
        kerning: options.kerning?,
        ligatures: options.ligatures?
      )

      glyphs = @font.shape(text, shaping_options)
      width = glyphs.sum(&.x_advance)

      TextLine.new(
        glyphs: glyphs,
        width: width,
        ascent: @font.ascender,
        descent: @font.descender,
        start_index: 0,
        end_index: text.size,
        hard_break: false
      )
    end

    # Layout text with automatic line breaking
    def layout(text : String, options : LayoutOptions = LayoutOptions.default) : ParagraphLayout
      return ParagraphLayout.new([] of TextLine) if text.empty?

      max_width = options.max_width

      # If no max width, return single line per paragraph
      if max_width.nil?
        lines = layout_without_wrapping(text, options)
        return ParagraphLayout.new(lines)
      end

      lines = layout_with_wrapping(text, max_width, options)
      ParagraphLayout.new(lines)
    end

    # Find the best break point in text to fit within max_width
    def find_break_point(text : String, max_width : Int32, options : LayoutOptions) : Int32
      return 0 if text.empty?

      width = 0
      prev_glyph : UInt16? = nil
      last_break_point = 0
      break_chars = options.word_break_chars

      text.each_char_with_index do |char, i|
        glyph = @font.glyph_id(char)

        # Calculate width at this point
        if options.kerning? && prev_glyph
          width += @font.kerning(prev_glyph, glyph).to_i32
        end
        width += @font.advance_width(glyph).to_i32

        # Track potential break points
        if break_chars.includes?(char)
          if width <= max_width
            last_break_point = i + 1
          end
        end

        # Check if we've exceeded max width
        if width > max_width
          if options.word_wrap? && last_break_point > 0
            return last_break_point
          else
            # Break at current position if word wrap disabled or no break found
            return i > 0 ? i : 1
          end
        end

        prev_glyph = glyph
      end

      # Entire text fits
      text.size
    end

    private def layout_without_wrapping(text : String, options : LayoutOptions) : Array(TextLine)
      lines = [] of TextLine

      # Split by newlines
      paragraphs = text.split('\n', remove_empty: false)
      char_offset = 0

      paragraphs.each_with_index do |para, para_index|
        is_last = para_index == paragraphs.size - 1
        line = layout_single_segment(para, char_offset, options, hard_break: !is_last)
        lines << line
        char_offset += para.size + 1 # +1 for newline
      end

      lines
    end

    private def layout_with_wrapping(text : String, max_width : Int32, options : LayoutOptions) : Array(TextLine)
      lines = [] of TextLine

      # Split by newlines first
      paragraphs = text.split('\n', remove_empty: false)
      char_offset = 0

      paragraphs.each_with_index do |para, para_index|
        is_last_para = para_index == paragraphs.size - 1

        if para.empty?
          lines << empty_line(char_offset, char_offset, hard_break: !is_last_para)
          char_offset += 1
          next
        end

        remaining = para
        segment_offset = 0

        while !remaining.empty?
          break_point = find_break_point(remaining, max_width, options)
          break_point = remaining.size if break_point <= 0

          segment = remaining[0, break_point].rstrip
          is_last_segment = break_point >= remaining.size

          line = layout_single_segment(
            segment,
            char_offset + segment_offset,
            options,
            hard_break: !is_last_para && is_last_segment
          )
          lines << line

          segment_offset += break_point
          remaining = remaining[break_point..].lstrip
        end

        char_offset += para.size + 1
      end

      lines
    end

    private def layout_single_segment(text : String, start_index : Int32, options : LayoutOptions, hard_break : Bool = false) : TextLine
      if text.empty?
        return empty_line(start_index, start_index, hard_break)
      end

      shaping_options = ShapingOptions.new(
        kerning: options.kerning?,
        ligatures: options.ligatures?
      )

      glyphs = @font.shape(text, shaping_options)
      width = glyphs.sum(&.x_advance)

      TextLine.new(
        glyphs: glyphs,
        width: width,
        ascent: @font.ascender,
        descent: @font.descender,
        start_index: start_index,
        end_index: start_index + text.size,
        hard_break: hard_break
      )
    end

    private def empty_line(start_index : Int32, end_index : Int32, hard_break : Bool = false) : TextLine
      TextLine.new(
        glyphs: [] of PositionedGlyph,
        width: 0,
        ascent: @font.ascender,
        descent: @font.descender,
        start_index: start_index,
        end_index: end_index,
        hard_break: hard_break
      )
    end
  end
end
