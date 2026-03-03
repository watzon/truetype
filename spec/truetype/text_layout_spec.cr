require "../spec_helper"

describe TrueType::TextLayout do
  describe "#measure_width" do
    it "measures text width" do
      font = TrueType::Font.open(FONT_PATH)
      layout = TrueType::TextLayout.new(font)
      width = layout.measure_width("Hello")
      width.should be > 0
    end

    it "returns 0 for empty text" do
      font = TrueType::Font.open(FONT_PATH)
      layout = TrueType::TextLayout.new(font)
      layout.measure_width("").should eq(0)
    end

    it "respects kerning option" do
      font = TrueType::Font.open(FONT_PATH)
      layout = TrueType::TextLayout.new(font)

      width_with_kern = layout.measure_width("AV", kerning: true)
      width_no_kern = layout.measure_width("AV", kerning: false)

      # With kerning, width may be slightly different (usually smaller for AV)
      # Both should be positive
      width_with_kern.should be > 0
      width_no_kern.should be > 0
    end
  end

  describe "#measure_height" do
    it "measures height for lines" do
      font = TrueType::Font.open(FONT_PATH)
      layout = TrueType::TextLayout.new(font)

      height = layout.measure_height(1)
      height.should be > 0
    end

    it "height increases with line count" do
      font = TrueType::Font.open(FONT_PATH)
      layout = TrueType::TextLayout.new(font)

      h1 = layout.measure_height(1)
      h2 = layout.measure_height(2)
      h3 = layout.measure_height(3)

      h2.should be > h1
      h3.should be > h2
    end
  end

  describe "#layout_line" do
    it "layouts a single line" do
      font = TrueType::Font.open(FONT_PATH)
      layout = TrueType::TextLayout.new(font)

      line = layout.layout_line("Hello")
      line.glyphs.size.should eq(5)
      line.width.should be > 0
    end

    it "returns empty line for empty text" do
      font = TrueType::Font.open(FONT_PATH)
      layout = TrueType::TextLayout.new(font)

      line = layout.layout_line("")
      line.empty?.should be_true
      line.width.should eq(0)
    end

    it "builds visual and logical index maps for bidi text" do
      font = TrueType::Font.open(FONT_PATH)
      layout = TrueType::TextLayout.new(font)

      line = layout.layout_line("abc אבג")
      line.visual_length.should eq(7)
      line.visual_to_logical_map.should eq([0, 1, 2, 3, 6, 5, 4])
      line.logical_to_visual_map.should eq([0, 1, 2, 3, 6, 5, 4])
      line.visual_to_logical(4).should eq(6)
      line.logical_to_visual(4).should eq(6)
    end
  end

  describe "#layout" do
    it "layouts text without wrapping" do
      font = TrueType::Font.open(FONT_PATH)
      layout = TrueType::TextLayout.new(font)

      options = TrueType::LayoutOptions.single_line
      para = layout.layout("Hello World", options)

      para.line_count.should eq(1)
    end

    it "wraps text at max width" do
      font = TrueType::Font.open(FONT_PATH)
      layout = TrueType::TextLayout.new(font)

      # Use a small max width to force wrapping
      options = TrueType::LayoutOptions.new(max_width: 1000)
      para = layout.layout("Hello World, this is a long sentence that should wrap", options)

      para.line_count.should be > 1
    end

    it "splits on newlines" do
      font = TrueType::Font.open(FONT_PATH)
      layout = TrueType::TextLayout.new(font)

      para = layout.layout("Line 1\nLine 2\nLine 3")
      para.line_count.should eq(3)
    end

    it "handles empty text" do
      font = TrueType::Font.open(FONT_PATH)
      layout = TrueType::TextLayout.new(font)

      para = layout.layout("")
      para.empty?.should be_true
    end

    it "handles consecutive newlines" do
      font = TrueType::Font.open(FONT_PATH)
      layout = TrueType::TextLayout.new(font)

      para = layout.layout("A\n\nB")
      para.line_count.should eq(3) # "A", empty line, "B"
    end

    it "applies right alignment offsets when max_width is larger than line width" do
      font = TrueType::Font.open(FONT_PATH)
      layout = TrueType::TextLayout.new(font)
      text = "Hello"
      max_width = layout.measure_width(text) + 500

      para = layout.layout(text, TrueType::LayoutOptions.new(max_width: max_width, align: TrueType::TextAlign::Right))
      line = para.lines.first

      line.glyphs.first.x_offset.should eq(max_width - line.width)
    end

    it "applies center alignment offsets when max_width is larger than line width" do
      font = TrueType::Font.open(FONT_PATH)
      layout = TrueType::TextLayout.new(font)
      text = "Hello"
      max_width = layout.measure_width(text) + 600

      para = layout.layout(text, TrueType::LayoutOptions.new(max_width: max_width, align: TrueType::TextAlign::Center))
      line = para.lines.first

      line.glyphs.first.x_offset.should eq((max_width - line.width) // 2)
    end

    it "supports justified alignment for wrapped lines" do
      font = TrueType::Font.open(FONT_PATH)
      layout = TrueType::TextLayout.new(font)
      text = "A B C D E F"
      max_width = layout.measure_width("A B C")

      para = layout.layout(text, TrueType::LayoutOptions.new(max_width: max_width, align: TrueType::TextAlign::Justify))
      para.line_count.should be > 1
      para.lines.first.width.should eq(max_width)
    end

    it "applies line_height to paragraph height and line positioning" do
      font = TrueType::Font.open(FONT_PATH)
      layout = TrueType::TextLayout.new(font)
      text = "Line1\nLine2"

      normal = layout.layout(text, TrueType::LayoutOptions.new(line_height: 1.0))
      expanded = layout.layout(text, TrueType::LayoutOptions.new(line_height: 1.6))

      expanded.height.should be > normal.height

      normal_positions = [] of Int32
      normal.each_line_with_position { |_line, y| normal_positions << y }

      expanded_positions = [] of Int32
      expanded.each_line_with_position { |_line, y| expanded_positions << y }

      (expanded_positions[1] - expanded_positions[0]).should be > (normal_positions[1] - normal_positions[0])
    end

    it "applies hyphen_char when wrapping breaks inside a word" do
      font = TrueType::Font.open(FONT_PATH)
      layout = TrueType::TextLayout.new(font)
      text = "supercalifragilisticexpialidocious"
      hyphenated = false

      200.step(to: 3000, by: 100) do |width|
        options = TrueType::LayoutOptions.new(max_width: width, word_wrap: false, hyphen_char: '-')
        para = layout.layout(text, options)
        next unless para.line_count > 1

        if para.lines.first.glyphs.any? { |glyph| glyph.codepoint == '-'.ord.to_u32 }
          hyphenated = true
          break
        end
      end

      hyphenated.should be_true
    end
  end

  describe "#find_break_point" do
    it "finds word break point" do
      font = TrueType::Font.open(FONT_PATH)
      layout = TrueType::TextLayout.new(font)

      # Set max_width to fit "Hello " approximately
      first_word_width = layout.measure_width("Hello ")
      options = TrueType::LayoutOptions.new(max_width: first_word_width + 100)

      break_point = layout.find_break_point("Hello World", first_word_width + 100, options)
      break_point.should be > 0
    end

    it "returns full length when text fits" do
      font = TrueType::Font.open(FONT_PATH)
      layout = TrueType::TextLayout.new(font)

      options = TrueType::LayoutOptions.default
      text = "Short"
      break_point = layout.find_break_point(text, 10000, options)
      break_point.should eq(text.size)
    end
  end
end

describe TrueType::TextLayout do
  describe "bidi cursor and selection helpers" do
    it "moves cursor in visual order for mixed-direction text" do
      font = TrueType::Font.open(FONT_PATH)
      layout = TrueType::TextLayout.new(font)
      line = layout.layout_line("abc אבג")

      layout.move_cursor_right(line, 3).should eq(6)
      layout.move_cursor_left(line, 6).should eq(3)
    end

    it "maps visual selection to logical source range" do
      font = TrueType::Font.open(FONT_PATH)
      layout = TrueType::TextLayout.new(font)
      line = layout.layout_line("abc אבג")

      layout.logical_selection_for_visual_range(line, 4, 7).should eq(4...7)
    end
  end
end

describe TrueType::LayoutOptions do
  describe ".default" do
    it "creates default options" do
      opts = TrueType::LayoutOptions.default
      opts.kerning?.should be_true
      opts.ligatures?.should be_true
      opts.word_wrap?.should be_true
    end
  end

  describe ".single_line" do
    it "creates single line options" do
      opts = TrueType::LayoutOptions.single_line
      opts.max_width.should be_nil
    end
  end
end

describe TrueType::TextLine do
  describe "#height" do
    it "calculates height from ascent and descent" do
      line = TrueType::TextLine.new(
        glyphs: [] of TrueType::PositionedGlyph,
        width: 100,
        ascent: 800_i16,
        descent: -200_i16,
        start_index: 0,
        end_index: 5
      )
      line.height.should eq(1000)
    end
  end
end

describe TrueType::ParagraphLayout do
  describe "#width" do
    it "returns max line width" do
      font = TrueType::Font.open(FONT_PATH)
      layout = TrueType::TextLayout.new(font)

      para = layout.layout("Short\nLonger line here")
      para.width.should be > 0
    end
  end

  describe "#height" do
    it "returns total height" do
      font = TrueType::Font.open(FONT_PATH)
      layout = TrueType::TextLayout.new(font)

      para = layout.layout("Line1\nLine2")
      para.height.should be > 0
    end
  end

  describe "#each_line_with_position" do
    it "iterates with y positions" do
      font = TrueType::Font.open(FONT_PATH)
      layout = TrueType::TextLayout.new(font)

      para = layout.layout("Line1\nLine2")
      positions = [] of Int32

      para.each_line_with_position do |line, y|
        positions << y
      end

      positions.size.should eq(2)
      positions[1].should be > positions[0]
    end
  end
end
