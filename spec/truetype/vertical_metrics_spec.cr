require "../spec_helper"

describe TrueType::Tables::Vhea do
  describe ".parse" do
    it "parses a vhea table if present" do
      parser = TrueType::Parser.parse(FONT_PATH)

      if parser.has_table?("vhea")
        vhea = parser.vhea
        vhea.should_not be_nil

        vhea_table = vhea.not_nil!
        vhea_table.major_version.should eq(1_u16)
        vhea_table.number_of_v_metrics.should be > 0_u16
      end
    end
  end
end

describe TrueType::Tables::Vmtx do
  describe ".parse" do
    it "parses a vmtx table if present" do
      parser = TrueType::Parser.parse(FONT_PATH)

      if parser.vertical_writing?
        vmtx = parser.vmtx
        vmtx.should_not be_nil
      end
    end
  end

  describe "#advance_height" do
    it "returns advance height for glyphs" do
      parser = TrueType::Parser.parse(FONT_PATH)

      if vmtx = parser.vmtx
        glyph_a = parser.glyph_id('A')
        height = vmtx.advance_height(glyph_a)
        height.should be_a(UInt16)
      end
    end
  end

  describe "#top_side_bearing" do
    it "returns top side bearing for glyphs" do
      parser = TrueType::Parser.parse(FONT_PATH)

      if vmtx = parser.vmtx
        glyph_a = parser.glyph_id('A')
        tsb = vmtx.top_side_bearing(glyph_a)
        tsb.should be_a(Int16)
      end
    end
  end
end

describe TrueType::Tables::Vorg do
  describe ".parse" do
    it "parses a VORG table if present" do
      parser = TrueType::Parser.parse(FONT_PATH)

      if parser.has_table?("VORG")
        vorg = parser.vorg
        vorg.should_not be_nil

        vorg_table = vorg.not_nil!
        vorg_table.major_version.should eq(1_u16)
      end
    end
  end

  describe "#vert_origin_y" do
    it "returns vertical origin for glyphs" do
      parser = TrueType::Parser.parse(FONT_PATH)

      if vorg = parser.vorg
        glyph_a = parser.glyph_id('A')
        origin = vorg.vert_origin_y(glyph_a)
        origin.should be_a(Int16)
      end
    end
  end
end

describe TrueType::Parser do
  describe "#vertical_writing?" do
    it "returns true if font has vertical metrics" do
      parser = TrueType::Parser.parse(FONT_PATH)
      result = parser.vertical_writing?
      result.should be_a(Bool)
    end
  end

  describe "#advance_height" do
    it "returns advance height for glyph" do
      parser = TrueType::Parser.parse(FONT_PATH)

      glyph_a = parser.glyph_id('A')
      height = parser.advance_height(glyph_a)
      height.should be_a(UInt16)

      # If vertical metrics don't exist, should be 0
      unless parser.vertical_writing?
        height.should eq(0_u16)
      end
    end
  end

  describe "#char_height" do
    it "returns advance height for character" do
      parser = TrueType::Parser.parse(FONT_PATH)

      height = parser.char_height('A')
      height.should be_a(UInt16)
    end
  end

  describe "#left_side_bearing" do
    it "returns left side bearing for glyph" do
      parser = TrueType::Parser.parse(FONT_PATH)

      glyph_a = parser.glyph_id('A')
      lsb = parser.left_side_bearing(glyph_a)
      lsb.should be_a(Int16)
    end
  end

  describe "#top_side_bearing" do
    it "returns top side bearing for glyph" do
      parser = TrueType::Parser.parse(FONT_PATH)

      glyph_a = parser.glyph_id('A')
      tsb = parser.top_side_bearing(glyph_a)
      tsb.should be_a(Int16)

      # If vertical metrics don't exist, should be 0
      unless parser.vertical_writing?
        tsb.should eq(0_i16)
      end
    end
  end

  describe "#vert_origin_y" do
    it "returns vertical origin for glyph" do
      parser = TrueType::Parser.parse(FONT_PATH)

      glyph_a = parser.glyph_id('A')
      origin = parser.vert_origin_y(glyph_a)
      origin.should be_a(Int16)

      # Without VORG table, should fall back to ascender
      unless parser.has_table?("VORG")
        origin.should eq(parser.ascender)
      end
    end
  end
end

describe TrueType::Tables::VMetric do
  it "stores advance_height and top_side_bearing" do
    metric = TrueType::Tables::VMetric.new(1000_u16, 100_i16)
    metric.advance_height.should eq(1000_u16)
    metric.top_side_bearing.should eq(100_i16)
  end
end

describe TrueType::Tables::VertOriginYMetric do
  it "stores glyph_index and vert_origin_y" do
    metric = TrueType::Tables::VertOriginYMetric.new(5_u16, 880_i16)
    metric.glyph_index.should eq(5_u16)
    metric.vert_origin_y.should eq(880_i16)
  end
end
