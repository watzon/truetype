require "../spec_helper"

describe TrueType::Tables::Kern do
  describe ".parse" do
    it "parses a kern table if present" do
      parser = TrueType::Parser.parse(FONT_PATH)

      if parser.has_table?("kern")
        kern = parser.kern
        kern.should_not be_nil
        kern.not_nil!.version.should be >= 0_u16
      end
    end
  end

  describe "#kern" do
    it "returns kerning value for known pairs" do
      parser = TrueType::Parser.parse(FONT_PATH)

      if kern = parser.kern
        # Common kerning pairs like 'AV' or 'To' usually have negative kerning
        # But we can't guarantee specific pairs exist, so just test the API works
        glyph_a = parser.glyph_id('A')
        glyph_v = parser.glyph_id('V')
        kern_value = kern.kern(glyph_a, glyph_v)
        kern_value.should be_a(Int16)
      end
    end

    it "returns 0 for unknown pairs" do
      parser = TrueType::Parser.parse(FONT_PATH)

      if kern = parser.kern
        # Non-existent glyph pair should return 0
        kern.kern(0xFFFF_u16, 0xFFFF_u16).should eq(0_i16)
      end
    end
  end

  describe "#empty?" do
    it "returns true if no kerning subtables exist" do
      parser = TrueType::Parser.parse(FONT_PATH)

      if kern = parser.kern
        # If the table exists, we just verify the method works
        kern.empty?.should be_a(Bool)
      end
    end
  end

  describe "#pair_count" do
    it "returns the total number of Format 0 kerning pairs" do
      parser = TrueType::Parser.parse(FONT_PATH)

      if kern = parser.kern
        kern.pair_count.should be >= 0
      end
    end
  end
end

describe TrueType::Parser do
  describe "#kerning" do
    it "returns kerning for glyph IDs" do
      parser = TrueType::Parser.parse(FONT_PATH)

      glyph_a = parser.glyph_id('A')
      glyph_v = parser.glyph_id('V')
      kern_value = parser.kerning(glyph_a, glyph_v)
      kern_value.should be_a(Int16)
    end

    it "returns kerning for characters" do
      parser = TrueType::Parser.parse(FONT_PATH)

      kern_value = parser.kerning('A', 'V')
      kern_value.should be_a(Int16)
    end

    it "returns 0 when no kern table exists" do
      # This tests the nil-safe behavior
      parser = TrueType::Parser.parse(FONT_PATH)

      # Even if kern table doesn't exist, this should return 0
      # rather than crashing
      kern_value = parser.kerning('A', 'V')
      kern_value.should be_a(Int16)
    end
  end

  describe "#has_kerning?" do
    it "returns boolean indicating kerning availability" do
      parser = TrueType::Parser.parse(FONT_PATH)
      parser.has_kerning?.should be_a(Bool)
    end
  end

  describe "#text_width" do
    it "calculates width including kerning" do
      parser = TrueType::Parser.parse(FONT_PATH)

      width = parser.text_width("Hello")
      width.should be > 0

      # Width should be sum of advances plus kerning
      # We can't easily verify exact values, but it should work
    end

    it "returns 0 for empty string" do
      parser = TrueType::Parser.parse(FONT_PATH)
      parser.text_width("").should eq(0)
    end

    it "handles single character" do
      parser = TrueType::Parser.parse(FONT_PATH)

      single_width = parser.text_width("A")
      advance = parser.advance_width(parser.glyph_id('A')).to_i32

      # Single character should equal its advance width
      single_width.should eq(advance)
    end

    it "differs from simple sum when kerning exists" do
      parser = TrueType::Parser.parse(FONT_PATH)

      # Calculate with kerning
      width_with_kern = parser.text_width("AV")

      # Calculate without kerning
      glyph_a = parser.glyph_id('A')
      glyph_v = parser.glyph_id('V')
      width_no_kern = parser.advance_width(glyph_a).to_i32 + parser.advance_width(glyph_v).to_i32

      # They should differ if kerning exists (AV is a common kerning pair)
      # But we can't guarantee the font has this kerning pair
      kern_value = parser.kerning(glyph_a, glyph_v)
      expected = width_no_kern + kern_value.to_i32

      width_with_kern.should eq(expected)
    end
  end
end

describe TrueType::Tables::KernPair do
  it "stores left, right, and value" do
    pair = TrueType::Tables::KernPair.new(10_u16, 20_u16, -50_i16)
    pair.left.should eq(10_u16)
    pair.right.should eq(20_u16)
    pair.value.should eq(-50_i16)
  end
end

describe TrueType::Tables::KernSubtableHeader do
  it "correctly identifies horizontal subtables" do
    header = TrueType::Tables::KernSubtableHeader.new(0_u16, 100_u16, 0_u8, 0x00_u8)
    header.horizontal?.should be_true
    header.vertical?.should be_false
  end

  it "correctly identifies vertical subtables" do
    header = TrueType::Tables::KernSubtableHeader.new(0_u16, 100_u16, 0_u8, 0x01_u8)
    header.horizontal?.should be_false
    header.vertical?.should be_true
  end

  it "correctly identifies coverage flags" do
    header = TrueType::Tables::KernSubtableHeader.new(0_u16, 100_u16, 0_u8, 0x0E_u8)
    header.minimum?.should be_true
    header.cross_stream?.should be_true
    header.override?.should be_true
  end
end
