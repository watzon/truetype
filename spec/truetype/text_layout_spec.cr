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
