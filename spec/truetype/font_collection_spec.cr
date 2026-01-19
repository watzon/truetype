require "../spec_helper"

describe TrueType::FontCollection do
  describe ".collection?" do
    it "returns false for regular TrueType font" do
      TrueType::FontCollection.collection?("spec/fixtures/fonts/DejaVuSans.ttf").should be_false
    end

    it "returns false for non-existent file" do
      TrueType::FontCollection.collection?("non-existent-file.ttc").should be_false
    end

    it "returns false for non-TTC bytes" do
      data = File.read("spec/fixtures/fonts/DejaVuSans.ttf").to_slice
      TrueType::FontCollection.collection?(data).should be_false
    end
  end

  describe ".parse" do
    it "raises error for non-TTC data" do
      data = File.read("spec/fixtures/fonts/DejaVuSans.ttf").to_slice
      expect_raises(TrueType::ParseError, /Invalid TTC tag/) do
        TrueType::FontCollection.parse(data)
      end
    end

    it "raises error for data too small" do
      expect_raises(TrueType::ParseError, /too small/) do
        TrueType::FontCollection.parse(Bytes.new(5))
      end
    end
  end
end

describe TrueType::FontCollectionHeader do
  describe ".parse" do
    it "parses a valid TTC header" do
      # Create a minimal valid TTC header
      io = IO::Memory.new
      io.write("ttcf".to_slice)   # ttc_tag
      io.write(Bytes[0, 2])       # major_version = 2
      io.write(Bytes[0, 0])       # minor_version = 0
      io.write(Bytes[0, 0, 0, 2]) # num_fonts = 2
      io.write(Bytes[0, 0, 0, 32]) # offset 1 = 32
      io.write(Bytes[0, 0, 0, 64]) # offset 2 = 64
      io.write(Bytes[0x44, 0x53, 0x49, 0x47]) # dsig_tag = 'DSIG'
      io.write(Bytes[0, 0, 0, 100]) # dsig_length = 100
      io.write(Bytes[0, 0, 0, 200]) # dsig_offset = 200

      header = TrueType::FontCollectionHeader.parse(io.to_slice)

      header.ttc_tag.should eq("ttcf")
      header.major_version.should eq(2_u16)
      header.minor_version.should eq(0_u16)
      header.num_fonts.should eq(2_u32)
      header.offset_table_offsets.size.should eq(2)
      header.offset_table_offsets[0].should eq(32_u32)
      header.offset_table_offsets[1].should eq(64_u32)
      header.dsig_tag.should eq(0x44534947_u32)
      header.dsig_length.should eq(100_u32)
      header.dsig_offset.should eq(200_u32)
    end

    it "parses version 1 header without DSIG" do
      io = IO::Memory.new
      io.write("ttcf".to_slice)
      io.write(Bytes[0, 1])       # major_version = 1
      io.write(Bytes[0, 0])       # minor_version = 0
      io.write(Bytes[0, 0, 0, 1]) # num_fonts = 1
      io.write(Bytes[0, 0, 0, 16]) # offset 1 = 16

      header = TrueType::FontCollectionHeader.parse(io.to_slice)

      header.ttc_tag.should eq("ttcf")
      header.major_version.should eq(1_u16)
      header.num_fonts.should eq(1_u32)
      header.dsig_tag.should be_nil
      header.dsig_length.should be_nil
      header.dsig_offset.should be_nil
    end
  end
end

# Integration tests with real TTC file (if available)
# To run these tests, place a TTC file at spec/fixtures/fonts/collection.ttc
TTC_PATH = "spec/fixtures/fonts/collection.ttc"

if File.exists?(TTC_PATH)
  describe "FontCollection Integration" do
    it "parses a real TTC file" do
      collection = TrueType::FontCollection.parse(TTC_PATH)
      collection.size.should be > 0
    end

    it "accesses fonts by index" do
      collection = TrueType::FontCollection.parse(TTC_PATH)
      font = collection[0]
      font.should be_a(TrueType::Parser)
      font.postscript_name.should_not be_empty
    end

    it "iterates over fonts" do
      collection = TrueType::FontCollection.parse(TTC_PATH)
      names = collection.font_names
      names.should_not be_empty
      names.all?(&.size.> 0).should be_true
    end

    it "finds font by name" do
      collection = TrueType::FontCollection.parse(TTC_PATH)
      first_name = collection[0].postscript_name
      found = collection.find_by_name(first_name)
      found.should_not be_nil
      found.not_nil!.postscript_name.should eq(first_name)
    end
  end
end
