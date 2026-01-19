require "../spec_helper"

describe TrueType::Woff do
  describe ".woff?" do
    it "returns false for TrueType font" do
      data = File.read("spec/fixtures/fonts/DejaVuSans.ttf").to_slice
      TrueType::Woff.woff?(data).should be_false
    end

    it "returns false for too-small data" do
      TrueType::Woff.woff?(Bytes.new(3)).should be_false
    end

    it "returns false for random data" do
      TrueType::Woff.woff?(Bytes.new(100) { |i| i.to_u8 }).should be_false
    end
  end

  describe ".parse" do
    it "raises error for non-WOFF data" do
      data = File.read("spec/fixtures/fonts/DejaVuSans.ttf").to_slice
      expect_raises(TrueType::ParseError, /Invalid WOFF signature/) do
        TrueType::Woff.parse(data)
      end
    end

    it "raises error for data too small" do
      expect_raises(TrueType::ParseError, /too small/) do
        TrueType::Woff.parse(Bytes.new(20))
      end
    end
  end
end

describe TrueType::WoffHeader do
  describe ".parse" do
    it "parses a valid WOFF header" do
      io = IO::Memory.new

      # Write a minimal WOFF header
      io.write(Bytes[0x77, 0x4F, 0x46, 0x46]) # signature 'wOFF'
      io.write(Bytes[0x00, 0x01, 0x00, 0x00]) # flavor (TrueType)
      io.write(Bytes[0x00, 0x00, 0x10, 0x00]) # length = 4096
      io.write(Bytes[0x00, 0x05])             # numTables = 5
      io.write(Bytes[0x00, 0x00])             # reserved = 0
      io.write(Bytes[0x00, 0x00, 0x20, 0x00]) # totalSfntSize = 8192
      io.write(Bytes[0x00, 0x01])             # majorVersion = 1
      io.write(Bytes[0x00, 0x00])             # minorVersion = 0
      io.write(Bytes[0x00, 0x00, 0x00, 0x00]) # metaOffset = 0
      io.write(Bytes[0x00, 0x00, 0x00, 0x00]) # metaLength = 0
      io.write(Bytes[0x00, 0x00, 0x00, 0x00]) # metaOrigLength = 0
      io.write(Bytes[0x00, 0x00, 0x00, 0x00]) # privOffset = 0
      io.write(Bytes[0x00, 0x00, 0x00, 0x00]) # privLength = 0

      io.rewind
      header = TrueType::WoffHeader.parse(io)

      header.signature.should eq(0x774F4646_u32)
      header.flavor.should eq(0x00010000_u32)
      header.num_tables.should eq(5_u16)
      header.major_version.should eq(1_u16)
      header.valid?.should be_true
      header.has_metadata?.should be_false
      header.has_private_data?.should be_false
    end

    it "detects metadata and private data" do
      io = IO::Memory.new

      io.write(Bytes[0x77, 0x4F, 0x46, 0x46]) # signature
      io.write(Bytes[0x00, 0x01, 0x00, 0x00]) # flavor
      io.write(Bytes[0x00, 0x00, 0x10, 0x00]) # length
      io.write(Bytes[0x00, 0x01])             # numTables
      io.write(Bytes[0x00, 0x00])             # reserved
      io.write(Bytes[0x00, 0x00, 0x08, 0x00]) # totalSfntSize
      io.write(Bytes[0x00, 0x01])             # majorVersion
      io.write(Bytes[0x00, 0x00])             # minorVersion
      io.write(Bytes[0x00, 0x00, 0x08, 0x00]) # metaOffset = 2048
      io.write(Bytes[0x00, 0x00, 0x01, 0x00]) # metaLength = 256
      io.write(Bytes[0x00, 0x00, 0x02, 0x00]) # metaOrigLength = 512
      io.write(Bytes[0x00, 0x00, 0x10, 0x00]) # privOffset = 4096
      io.write(Bytes[0x00, 0x00, 0x00, 0x40]) # privLength = 64

      io.rewind
      header = TrueType::WoffHeader.parse(io)

      header.has_metadata?.should be_true
      header.has_private_data?.should be_true
    end
  end
end

describe TrueType::WoffTableEntry do
  describe ".parse" do
    it "parses a table entry" do
      io = IO::Memory.new

      io.write("head".to_slice)              # tag
      io.write(Bytes[0x00, 0x00, 0x00, 0x64]) # offset = 100
      io.write(Bytes[0x00, 0x00, 0x00, 0x30]) # compLength = 48
      io.write(Bytes[0x00, 0x00, 0x00, 0x36]) # origLength = 54
      io.write(Bytes[0x12, 0x34, 0x56, 0x78]) # checksum

      io.rewind
      entry = TrueType::WoffTableEntry.parse(io)

      entry.tag.should eq("head")
      entry.offset.should eq(100_u32)
      entry.comp_length.should eq(48_u32)
      entry.orig_length.should eq(54_u32)
      entry.orig_checksum.should eq(0x12345678_u32)
      entry.compressed?.should be_true
    end

    it "detects uncompressed tables" do
      io = IO::Memory.new

      io.write("cmap".to_slice)
      io.write(Bytes[0x00, 0x00, 0x00, 0x64])
      io.write(Bytes[0x00, 0x00, 0x01, 0x00]) # compLength = 256
      io.write(Bytes[0x00, 0x00, 0x01, 0x00]) # origLength = 256 (same)
      io.write(Bytes[0x00, 0x00, 0x00, 0x00])

      io.rewind
      entry = TrueType::WoffTableEntry.parse(io)

      entry.compressed?.should be_false
    end
  end
end

# Integration tests with real WOFF file (if available)
WOFF_PATH = "spec/fixtures/fonts/test.woff"

if File.exists?(WOFF_PATH)
  describe "WOFF Integration" do
    it "parses a real WOFF file" do
      woff = TrueType::Woff.parse(WOFF_PATH)
      woff.tables.should_not be_empty
    end

    it "converts to sfnt" do
      woff = TrueType::Woff.parse(WOFF_PATH)
      sfnt = woff.to_sfnt
      sfnt.should_not be_empty
    end

    it "converts to Parser" do
      woff = TrueType::Woff.parse(WOFF_PATH)
      parser = woff.to_parser
      parser.should be_a(TrueType::Parser)
      parser.postscript_name.should_not be_empty
    end

    it "extracts table data" do
      woff = TrueType::Woff.parse(WOFF_PATH)
      head_data = woff.table_data("head")
      head_data.should_not be_nil
      head_data.not_nil!.size.should eq(54)
    end
  end
end
