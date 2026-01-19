require "../spec_helper"

# These tests run only if a CFF-based OTF is present
if File.exists?(OTF_FONT_PATH)
  describe "CFF parsing" do
    it "parses CFF table from OTF" do
      parser = TrueType::Parser.parse(OTF_FONT_PATH)
      parser.cff?.should be_true
      parser.has_table?("CFF ").should be_true

      cff = parser.cff_font
      cff.should_not be_nil
      cff.not_nil!.glyph_count.should be > 0
    end

    it "extracts CFF glyph outline" do
      parser = TrueType::Parser.parse(OTF_FONT_PATH)
      outline = parser.glyph_outline(0_u16)
      outline.should be_a(TrueType::GlyphOutline)
    end
  end

  describe "CFF subsetting" do
    it "creates a subset font with used characters" do
      parser = TrueType::Parser.parse(OTF_FONT_PATH)
      subsetter = TrueType::Subsetter.new(parser)

      subsetter.use("Hello")
      subset_data = subsetter.subset

      subset_data.should_not be_empty
      # Subset should be smaller than original
      subset_data.size.should be < parser.data.size
    end

    it "produces a valid OTF font structure" do
      parser = TrueType::Parser.parse(OTF_FONT_PATH)
      subsetter = TrueType::Subsetter.new(parser)

      subsetter.use("A")
      subset_data = subsetter.subset

      # Parse the subset to verify structure
      subset_parser = TrueType::Parser.parse(subset_data)
      subset_parser.cff?.should be_true
      subset_parser.has_table?("CFF ").should be_true
      subset_parser.maxp.num_glyphs.should be >= 2 # At least .notdef and 'A'
    end

    it "maintains glyph ID mapping" do
      parser = TrueType::Parser.parse(OTF_FONT_PATH)
      subsetter = TrueType::Subsetter.new(parser)

      subsetter.use("ABC")
      subsetter.subset

      mapping = subsetter.unicode_to_glyph_map
      mapping.should_not be_empty
      mapping['A'.ord.to_u32]?.should_not be_nil
      mapping['B'.ord.to_u32]?.should_not be_nil
      mapping['C'.ord.to_u32]?.should_not be_nil
    end

    it "preserves font metrics" do
      parser = TrueType::Parser.parse(OTF_FONT_PATH)
      subsetter = TrueType::Subsetter.new(parser)

      subsetter.use("A")
      subset_data = subsetter.subset
      subset_parser = TrueType::Parser.parse(subset_data)

      # Basic metrics should be preserved
      subset_parser.units_per_em.should eq(parser.units_per_em)
      subset_parser.ascender.should eq(parser.ascender)
      subset_parser.descender.should eq(parser.descender)
    end

    it "subsets a longer string" do
      parser = TrueType::Parser.parse(OTF_FONT_PATH)
      subsetter = TrueType::Subsetter.new(parser)

      subsetter.use("The quick brown fox jumps over the lazy dog.")
      subset_data = subsetter.subset

      # Parse and verify
      subset_parser = TrueType::Parser.parse(subset_data)
      subset_parser.maxp.num_glyphs.should be > 0
      subset_parser.cff?.should be_true
    end

    it "handles CFF glyph outline extraction after subsetting" do
      parser = TrueType::Parser.parse(OTF_FONT_PATH)
      subsetter = TrueType::Subsetter.new(parser)

      subsetter.use("A")
      subset_data = subsetter.subset
      subset_parser = TrueType::Parser.parse(subset_data)

      # Get outline for 'A' in the subset
      new_glyph_id = subsetter.unicode_to_glyph_map['A'.ord.to_u32]
      outline = subset_parser.glyph_outline(new_glyph_id)
      outline.should be_a(TrueType::GlyphOutline)
    end
  end
end

describe "CFF core structures" do
  it "parses empty INDEX" do
    io = IO::Memory.new(Bytes[0x00, 0x00])
    index = TrueType::Tables::CFF::Index.parse(io)
    index.count.should eq(0_u16)
    index.size.should eq(0)
  end

  it "parses a simple INDEX" do
    io = IO::Memory.new
    io.write(Bytes[0x00, 0x01]) # count = 1
    io.write(Bytes[0x01])       # offSize = 1
    io.write(Bytes[0x01])       # offset 1
    io.write(Bytes[0x05])       # offset 2
    io.write(Bytes[0x41, 0x42, 0x43, 0x44]) # data
    io.rewind

    index = TrueType::Tables::CFF::Index.parse(io)
    index.size.should eq(1)
    index[0].size.should eq(4)
    String.new(index[0]).should eq("ABCD")
  end

  it "parses a simple DICT" do
    # DICT: operands 100, operator 17
    # 100 encoded as 239 (100 + 139)
    data = Bytes[0xEF_u8, 0x11_u8]
    dict = TrueType::Tables::CFF::Dict.parse(data)
    dict.int(TrueType::Tables::CFF::DictOp::CHAR_STRINGS).should eq(100)
  end

  it "parses a simple CFF header" do
    io = IO::Memory.new
    io.write(Bytes[0x01, 0x00, 0x04, 0x04]) # major, minor, headerSize, offSize
    io.write(Bytes[0x00, 0x00])             # name INDEX count 0
    io.write(Bytes[0x00, 0x00])             # top dict INDEX count 0
    io.write(Bytes[0x00, 0x00])             # string INDEX count 0
    io.write(Bytes[0x00, 0x00])             # global subrs INDEX count 0
    io.rewind

    table = TrueType::Tables::CFF::Table.parse(io.to_slice)
    table.major.should eq(1_u8)
    table.minor.should eq(0_u8)
    table.header_size.should eq(4_u8)
    table.off_size.should eq(4_u8)
  end
end
