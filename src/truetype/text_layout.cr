# Text layout module for TrueType fonts.
#
# Provides text layout capabilities including:
# - Text measurement with kerning
# - Line breaking
# - Bidi-aware line shaping and reordering
# - Basic paragraph layout

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

    # Visual index -> logical index (line-local, excludes removed controls)
    getter visual_to_logical_map : Array(Int32)

    # Logical index -> visual index (line-local, -1 for removed controls)
    getter logical_to_visual_map : Array(Int32)

    # Whether this line ends with a hard break (newline)
    getter? hard_break : Bool

    def initialize(
      @glyphs : Array(PositionedGlyph),
      @width : Int32,
      @ascent : Int16,
      @descent : Int16,
      @start_index : Int32,
      @end_index : Int32,
      @hard_break : Bool = false,
      @visual_to_logical_map : Array(Int32) = [] of Int32,
      @logical_to_visual_map : Array(Int32) = [] of Int32,
    )
    end

    # Height of the line (ascent + |descent|)
    def height : Int32
      @ascent.to_i32 + @descent.abs.to_i32
    end

    # Number of visual characters in this line.
    def visual_length : Int32
      @visual_to_logical_map.empty? ? (@end_index - @start_index) : @visual_to_logical_map.size
    end

    # Convert visual index in this line to source logical index.
    def visual_to_logical(visual_index : Int32) : Int32?
      local = if @visual_to_logical_map.empty?
                visual_index
              else
                @visual_to_logical_map[visual_index]?
              end

      return nil unless local
      return nil if local < 0

      @start_index + local
    end

    # Convert source logical index to visual index in this line.
    def logical_to_visual(logical_index : Int32) : Int32?
      local = logical_index - @start_index
      return nil if local < 0 || local >= (@end_index - @start_index)

      visual = if @logical_to_visual_map.empty?
                 local
               else
                 @logical_to_visual_map[local]?
               end

      return nil unless visual
      return nil if visual < 0

      visual
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

    # Paragraph line-height multiplier used to position lines
    getter line_height : Float64

    def initialize(@lines : Array(TextLine), @line_height : Float64 = 1.0)
      @width = @lines.empty? ? 0 : @lines.max_of(&.width)
      @height = compute_total_height
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
      @lines.each_with_index do |line, index|
        y += line.ascent.to_i32
        yield line, y
        y += line.descent.abs.to_i32
        if index < @lines.size - 1
          spacing = (line.height.to_f64 * (@line_height - 1.0)).round.to_i32
          y += spacing
        end
      end
    end

    private def compute_total_height : Int32
      return 0 if @lines.empty?

      total = 0
      @lines.each_with_index do |line, index|
        total += line.height
        next if index == @lines.size - 1

        spacing = (line.height.to_f64 * (@line_height - 1.0)).round.to_i32
        total += spacing
      end

      total
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

    # Paragraph direction override
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
      @hyphen_char : Char? = nil,
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

      layout_single_segment(text, 0, options)
    end

    # Layout text with automatic line breaking
    def layout(text : String, options : LayoutOptions = LayoutOptions.default) : ParagraphLayout
      return ParagraphLayout.new([] of TextLine) if text.empty?

      max_width = options.max_width

      # If no max width, return single line per paragraph
      if max_width.nil?
        lines = layout_without_wrapping(text, options)
        return ParagraphLayout.new(lines, options.line_height)
      end

      lines = layout_with_wrapping(text, max_width, options)
      ParagraphLayout.new(lines, options.line_height)
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
        if break_chars.includes?(char) && width <= max_width
          last_break_point = i + 1
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

    # Move cursor one visual position to the left for a laid-out line.
    def move_cursor_left(line : TextLine, logical_index : Int32) : Int32
      move_cursor(line, logical_index, -1)
    end

    # Move cursor one visual position to the right for a laid-out line.
    def move_cursor_right(line : TextLine, logical_index : Int32) : Int32
      move_cursor(line, logical_index, +1)
    end

    # Convert a visual selection range into a logical range in source text.
    def logical_selection_for_visual_range(line : TextLine, visual_start : Int32, visual_end : Int32) : Range(Int32, Int32)
      return line.start_index...line.start_index if line.visual_length <= 0

      from = {visual_start, visual_end}.min
      to = {visual_start, visual_end}.max
      from = from.clamp(0, line.visual_length)
      to = to.clamp(0, line.visual_length)

      return line.start_index...line.start_index if from == to

      logical_indices = [] of Int32
      (from...to).each do |visual_index|
        if logical = line.visual_to_logical(visual_index)
          logical_indices << logical
        end
      end

      return line.start_index...line.start_index if logical_indices.empty?

      logical_start = logical_indices.min
      logical_end = logical_indices.max + 1
      logical_start...logical_end
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
          source_length = segment.size
          is_last_segment = break_point >= remaining.size

          unless is_last_segment
            if hyphenated = maybe_hyphenate_segment(remaining, break_point, segment, max_width, options)
              segment = hyphenated
            end
          end

          line = layout_single_segment(
            segment,
            char_offset + segment_offset,
            options,
            source_length: source_length,
            allow_justify: !is_last_segment,
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

    private def layout_single_segment(
      text : String,
      start_index : Int32,
      options : LayoutOptions,
      source_length : Int32 = text.size,
      allow_justify : Bool = false,
      hard_break : Bool = false,
    ) : TextLine
      if text.empty?
        return empty_line(start_index, start_index + source_length, hard_break)
      end

      glyphs, width, visual_to_logical, logical_to_visual = shape_with_bidi(text, options)
      glyphs, width = apply_alignment(glyphs, width, options, allow_justify, hard_break)

      TextLine.new(
        glyphs: glyphs,
        width: width,
        ascent: @font.ascender,
        descent: @font.descender,
        start_index: start_index,
        end_index: start_index + source_length,
        hard_break: hard_break,
        visual_to_logical_map: visual_to_logical,
        logical_to_visual_map: logical_to_visual
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
        hard_break: hard_break,
        visual_to_logical_map: [] of Int32,
        logical_to_visual_map: [] of Int32
      )
    end

    private def move_cursor(line : TextLine, logical_index : Int32, delta : Int32) : Int32
      visual_length = line.visual_length
      return line.start_index if visual_length <= 0

      local_length = line.end_index - line.start_index
      return line.start_index if local_length <= 0

      local_logical = (logical_index - line.start_index).clamp(0, local_length - 1)
      source_logical = line.start_index + local_logical

      visual_index = line.logical_to_visual(source_logical) || local_logical
      target_visual = (visual_index + delta).clamp(0, visual_length - 1)

      line.visual_to_logical(target_visual) || source_logical
    end

    private def shape_with_bidi(text : String, options : LayoutOptions) : Tuple(Array(PositionedGlyph), Int32, Array(Int32), Array(Int32))
      paragraph_direction = case options.direction
                            when TextDirection::RightToLeft
                              Bidi::ParagraphDirection::RightToLeft
                            else
                              Bidi::ParagraphDirection::LeftToRight
                            end

      bidi_result = Bidi.resolve(text, paragraph_direction)
      chars = text.chars
      visual_indices = bidi_result.display_visual_to_logical

      if visual_indices.empty?
        return {
          [] of PositionedGlyph,
          0,
          bidi_result.display_visual_to_logical,
          bidi_result.display_logical_to_visual,
        }
      end

      glyphs = [] of PositionedGlyph
      run_start = 0

      while run_start < visual_indices.size
        first_logical = visual_indices[run_start]
        rtl = bidi_result.levels[first_logical].odd?
        expected_step = rtl ? -1 : 1

        run_end = run_start + 1
        prev_logical = first_logical

        while run_end < visual_indices.size
          current_logical = visual_indices[run_end]
          break unless bidi_result.levels[current_logical].odd? == rtl
          break unless current_logical - prev_logical == expected_step

          prev_logical = current_logical
          run_end += 1
        end

        run_visual_indices = visual_indices[run_start, run_end - run_start]
        append_shaped_run!(glyphs, chars, run_visual_indices, rtl, options)

        run_start = run_end
      end

      width = glyphs.sum(&.x_advance)
      {
        glyphs,
        width,
        bidi_result.display_visual_to_logical,
        bidi_result.display_logical_to_visual,
      }
    end

    private def maybe_hyphenate_segment(
      remaining : String,
      break_point : Int32,
      segment : String,
      max_width : Int32,
      options : LayoutOptions,
    ) : String?
      hyphen_char = options.hyphen_char
      return nil unless hyphen_char
      return nil if break_point <= 0 || break_point >= remaining.size

      boundary_left = remaining[break_point - 1]?
      boundary_right = remaining[break_point]?
      return nil unless boundary_left && boundary_right

      break_chars = options.word_break_chars
      return nil if break_chars.includes?(boundary_left)
      return nil if break_chars.includes?(boundary_right)

      candidate = "#{segment}#{hyphen_char}"
      width = measure_width(candidate, kerning: options.kerning?)
      width <= max_width ? candidate : nil
    end

    private def apply_alignment(
      glyphs : Array(PositionedGlyph),
      width : Int32,
      options : LayoutOptions,
      allow_justify : Bool,
      hard_break : Bool,
    ) : Tuple(Array(PositionedGlyph), Int32)
      max_width = options.max_width
      return {glyphs, width} unless max_width
      return {glyphs, width} if glyphs.empty?

      case options.align
      when TextAlign::Left
        {glyphs, width}
      when TextAlign::Center
        offset = (max_width - width) // 2
        {shift_glyphs(glyphs, offset), width}
      when TextAlign::Right
        offset = max_width - width
        {shift_glyphs(glyphs, offset), width}
      when TextAlign::Justify
        return {glyphs, width} unless allow_justify
        justify_glyphs(glyphs, width, max_width, hard_break)
      else
        {glyphs, width}
      end
    end

    private def shift_glyphs(glyphs : Array(PositionedGlyph), delta_x : Int32) : Array(PositionedGlyph)
      return glyphs if delta_x == 0

      glyphs.map do |glyph|
        PositionedGlyph.new(
          id: glyph.id,
          codepoint: glyph.codepoint,
          cluster: glyph.cluster,
          x_offset: glyph.x_offset + delta_x,
          y_offset: glyph.y_offset,
          x_advance: glyph.x_advance,
          y_advance: glyph.y_advance
        )
      end
    end

    private def justify_glyphs(
      glyphs : Array(PositionedGlyph),
      width : Int32,
      max_width : Int32,
      hard_break : Bool,
    ) : Tuple(Array(PositionedGlyph), Int32)
      return {glyphs, width} if hard_break || width >= max_width

      spaces = glyphs.count { |glyph| glyph.codepoint == ' '.ord.to_u32 }
      return {glyphs, width} if spaces == 0

      extra = max_width - width
      per_space = extra // spaces
      remainder = extra % spaces
      space_index = 0

      justified = glyphs.map do |glyph|
        if glyph.codepoint == ' '.ord.to_u32
          addition = per_space + (space_index < remainder ? 1 : 0)
          space_index += 1
          PositionedGlyph.new(
            id: glyph.id,
            codepoint: glyph.codepoint,
            cluster: glyph.cluster,
            x_offset: glyph.x_offset,
            y_offset: glyph.y_offset,
            x_advance: glyph.x_advance + addition,
            y_advance: glyph.y_advance
          )
        else
          glyph
        end
      end

      {justified, width + extra}
    end

    private def append_shaped_run!(
      output : Array(PositionedGlyph),
      chars : Array(Char),
      visual_indices : Array(Int32),
      rtl : Bool,
      options : LayoutOptions,
    )
      logical_indices = rtl ? visual_indices.reverse : visual_indices

      run_text = String.build do |io|
        logical_indices.each { |logical_index| io << chars[logical_index] }
      end
      return if run_text.empty?

      shaping_options = ShapingOptions.new(
        kerning: options.kerning?,
        ligatures: options.ligatures?,
        direction: rtl ? :rtl : :ltr
      )

      shaped = @font.shape(run_text, shaping_options)
      shaped = shaped.reverse if rtl

      shaped.each do |glyph|
        local_cluster = glyph.cluster
        mapped_cluster = if local_cluster >= 0 && local_cluster < logical_indices.size
                           logical_indices[local_cluster]
                         else
                           logical_indices.first
                         end

        output << PositionedGlyph.new(
          id: glyph.id,
          codepoint: glyph.codepoint,
          cluster: mapped_cluster,
          x_offset: glyph.x_offset,
          y_offset: glyph.y_offset,
          x_advance: glyph.x_advance,
          y_advance: glyph.y_advance
        )
      end
    end
  end
end
