require "../spec_helper"

CFF_FONT_PATH = "spec/fixtures/fonts/otf_sample.otf"

# These tests run only if a CFF-based OTF is present
if File.exists?(CFF_FONT_PATH)
  describe "CFF parsing" do
    it "parses CFF table from OTF" do
      parser = TrueType::Parser.parse(CFF_FONT_PATH)
      parser.cff?.should be_true
      parser.has_table?("CFF ").should be_true

      cff = parser.cff_font
      cff.should_not be_nil
      cff.not_nil!.glyph_count.should be > 0
    end

    it "extracts CFF glyph outline" do
      parser = TrueType::Parser.parse(CFF_FONT_PATH)
      outline = parser.glyph_outline(0_u16)
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
