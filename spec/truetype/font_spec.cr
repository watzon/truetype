require "../spec_helper"

describe TrueType::Font do
  describe ".open" do
    it "opens a TTF font file" do
      font = TrueType::Font.open(FONT_PATH)
      font.should be_a(TrueType::Font)
      font.format.should eq(:ttf)
    end

    it "opens an OTF font file" do
      font = TrueType::Font.open(OTF_FONT_PATH)
      font.should be_a(TrueType::Font)
      font.cff?.should be_true
    end

    it "opens a WOFF2 font file" do
      # Check if WOFF2 test file exists
      woff2_path = "spec/fixtures/fonts/DejaVuSans.woff2"
      if File.exists?(woff2_path)
        font = TrueType::Font.open(woff2_path)
        font.should be_a(TrueType::Font)
        font.format.should eq(:woff2)
      end
    end

    it "opens from bytes with auto-detection" do
      data = File.read(FONT_PATH).to_slice
      font = TrueType::Font.open(data)
      font.should be_a(TrueType::Font)
    end

    it "raises for invalid font data" do
      expect_raises(TrueType::ParseError) do
        TrueType::Font.open("invalid data".to_slice)
      end
    end
  end

  describe ".detect_format" do
    it "detects TTF format" do
      data = File.read(FONT_PATH).to_slice
      TrueType::Font.detect_format(data).should eq(:ttf)
    end

    it "detects OTF/CFF format" do
      data = File.read(OTF_FONT_PATH).to_slice
      TrueType::Font.detect_format(data).should eq(:otf)
    end

    it "detects WOFF2 format" do
      woff2_path = "spec/fixtures/fonts/DejaVuSans.woff2"
      if File.exists?(woff2_path)
        data = File.read(woff2_path).to_slice
        TrueType::Font.detect_format(data).should eq(:woff2)
      end
    end

    it "returns unknown for invalid data" do
      TrueType::Font.detect_format("invalid".to_slice).should eq(:unknown)
    end
  end

  describe "font information" do
    it "returns family name" do
      font = TrueType::Font.open(FONT_PATH)
      font.name.should contain("DejaVu")
      font.family_name.should eq(font.name)
    end

    it "returns PostScript name" do
      font = TrueType::Font.open(FONT_PATH)
      font.postscript_name.should contain("DejaVu")
    end

    it "returns style" do
      font = TrueType::Font.open(FONT_PATH)
      font.style.should_not be_empty
    end

    it "returns full name" do
      font = TrueType::Font.open(FONT_PATH)
      font.full_name.should_not be_empty
    end
  end

  describe "font properties" do
    it "returns units per em" do
      font = TrueType::Font.open(FONT_PATH)
      font.units_per_em.should be > 0
    end

    it "returns ascender and descender" do
      font = TrueType::Font.open(FONT_PATH)
      font.ascender.should be > 0
      font.descender.should be < 0
    end

    it "returns cap height" do
      font = TrueType::Font.open(FONT_PATH)
      font.cap_height.should be > 0
    end

    it "returns glyph count" do
      font = TrueType::Font.open(FONT_PATH)
      font.glyph_count.should be > 0
    end

    it "returns bounding box" do
      font = TrueType::Font.open(FONT_PATH)
      bbox = font.bounding_box
      bbox[2].should be > bbox[0] # x_max > x_min
      bbox[3].should be > bbox[1] # y_max > y_min
    end
  end

  describe "font type checks" do
    it "detects TrueType fonts" do
      font = TrueType::Font.open(FONT_PATH)
      font.truetype?.should be_true
      font.cff?.should be_false
    end

    it "detects CFF fonts" do
      font = TrueType::Font.open(OTF_FONT_PATH)
      font.cff?.should be_true
      font.truetype?.should be_false
    end

    it "detects variable fonts" do
      font = TrueType::Font.open(VARIABLE_FONT_PATH)
      font.variable?.should be_true
    end

    it "detects color fonts" do
      font = TrueType::Font.open(COLOR_FONT_PATH)
      font.color?.should be_true
    end
  end

  describe "glyph access" do
    it "returns glyph ID for characters" do
      font = TrueType::Font.open(FONT_PATH)
      glyph_a = font.glyph_id('A')
      glyph_a.should be > 0
    end

    it "returns advance width for glyphs" do
      font = TrueType::Font.open(FONT_PATH)
      width = font.advance_width(font.glyph_id('A'))
      width.should be > 0
    end

    it "returns char width" do
      font = TrueType::Font.open(FONT_PATH)
      width_a = font.char_width('A')
      width_i = font.char_width('i')
      width_a.should be > width_i
    end

    it "returns glyph outline" do
      font = TrueType::Font.open(FONT_PATH)
      outline = font.glyph_outline(font.glyph_id('A'))
      outline.should_not be_nil
      outline.contours.should_not be_empty
    end

    it "returns kerning between glyphs" do
      font = TrueType::Font.open(FONT_PATH)
      # Kerning may or may not exist for a given pair
      kern = font.kerning('A', 'V')
      kern.should be_a(Int16)
    end
  end

  describe "#shape" do
    it "shapes text into positioned glyphs" do
      font = TrueType::Font.open(FONT_PATH)
      glyphs = font.shape("Hello")
      glyphs.size.should eq(5)

      glyphs.each do |g|
        g.id.should be > 0
        g.x_advance.should be > 0
      end
    end

    it "applies kerning to shaped glyphs" do
      font = TrueType::Font.open(FONT_PATH)
      glyphs = font.shape("AV")
      # First glyph has no kerning offset, subsequent may have
      glyphs[0].x_offset.should eq(0)
    end

    it "returns empty array for empty text" do
      font = TrueType::Font.open(FONT_PATH)
      font.shape("").should be_empty
    end

    it "respects shaping options" do
      font = TrueType::Font.open(FONT_PATH)
      options = TrueType::ShapingOptions.new(kerning: false)
      glyphs = font.shape("AV", options)
      # Without kerning, all offsets should be 0
      glyphs.all? { |g| g.x_offset == 0 }.should be_true
    end
  end

  describe "#render" do
    it "renders text with cumulative positions" do
      font = TrueType::Font.open(FONT_PATH)
      glyphs = font.render("Hi")
      
      glyphs.size.should eq(2)
      glyphs[0].x_offset.should eq(0) # First glyph at origin
      glyphs[1].x_offset.should be > 0 # Second glyph after first
    end
  end

  describe "#text_width" do
    it "calculates text width" do
      font = TrueType::Font.open(FONT_PATH)
      width = font.text_width("Hello")
      width.should be > 0
    end

    it "returns 0 for empty text" do
      font = TrueType::Font.open(FONT_PATH)
      font.text_width("").should eq(0)
    end
  end

  describe "variable fonts" do
    it "returns variation axes" do
      font = TrueType::Font.open(VARIABLE_FONT_PATH)
      axes = font.variation_axes
      axes.should_not be_empty
    end

    it "returns named instances" do
      font = TrueType::Font.open(VARIABLE_FONT_PATH)
      instances = font.named_instances
      instances.should_not be_empty
    end

    it "creates instance with axis values" do
      font = TrueType::Font.open(VARIABLE_FONT_PATH)
      instance = font.instance(wght: 700)
      instance.should be_a(TrueType::VariationInstance)
    end

    it "creates instance from hash" do
      font = TrueType::Font.open(VARIABLE_FONT_PATH)
      instance = font.instance({"wght" => 700.0})
      instance.should be_a(TrueType::VariationInstance)
    end

    it "creates instance from named instance index" do
      font = TrueType::Font.open(VARIABLE_FONT_PATH)
      instance = font.instance(0)
      instance.should be_a(TrueType::VariationInstance)
    end
  end

  describe "#subset" do
    it "creates a subset from text" do
      font = TrueType::Font.open(FONT_PATH)
      subset = font.subset("Hello")
      subset.should be_a(Bytes)
      subset.size.should be > 0
      subset.size.should be < font.data.size
    end

    it "creates a subset from character set" do
      font = TrueType::Font.open(FONT_PATH)
      chars = Set{'H', 'e', 'l', 'o'}
      subset = font.subset(chars)
      subset.should be_a(Bytes)
    end

    it "subset can be parsed as a valid font" do
      font = TrueType::Font.open(FONT_PATH)
      subset = font.subset("Hello World!")
      
      # The subset should be parseable
      subset_font = TrueType::Font.open(subset)
      subset_font.glyph_count.should be < font.glyph_count
    end
  end

  describe "#validate" do
    it "validates a valid font" do
      font = TrueType::Font.open(FONT_PATH)
      result = font.validate
      result.valid?.should be_true
    end

    it "returns validation result" do
      font = TrueType::Font.open(FONT_PATH)
      result = font.validate
      result.should be_a(TrueType::ValidationResult)
      result.summary.should contain("valid")
    end
  end

  describe "#valid?" do
    it "returns true for valid fonts" do
      font = TrueType::Font.open(FONT_PATH)
      font.valid?.should be_true
    end
  end
end
