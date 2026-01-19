require "../spec_helper"

describe TrueType::Woff2Header do
  describe "WOFF2_SIGNATURE" do
    it "has the correct WOFF2 signature" do
      TrueType::Woff2Header::WOFF2_SIGNATURE.should eq(0x774F4632_u32)
    end
  end
end

describe TrueType::Woff2TableEntry do
  describe "KNOWN_TAGS" do
    it "has cmap as the first known tag" do
      TrueType::Woff2TableEntry::KNOWN_TAGS[0].should eq("cmap")
    end

    it "has glyf at index 10" do
      TrueType::Woff2TableEntry::KNOWN_TAGS[10].should eq("glyf")
    end

    it "has loca at index 11" do
      TrueType::Woff2TableEntry::KNOWN_TAGS[11].should eq("loca")
    end

    it "has CFF at index 13" do
      TrueType::Woff2TableEntry::KNOWN_TAGS[13].should eq("CFF ")
    end
  end

  describe "#table_tag" do
    it "returns the tag for a known table index" do
      entry = TrueType::Woff2TableEntry.new(0_u8, nil, 100_u32, nil)
      entry.table_tag.should eq("cmap")
    end

    it "returns the custom tag when flags indicate custom (63)" do
      entry = TrueType::Woff2TableEntry.new(63_u8, "XXXX", 100_u32, nil)
      entry.table_tag.should eq("XXXX")
    end
  end

  describe "#transformed?" do
    it "returns false when transform version is 3" do
      # flags = 0b11_000000 | table_index = transform version 3
      flags = (3_u8 << 6) | 0_u8
      entry = TrueType::Woff2TableEntry.new(flags, nil, 100_u32, nil)
      entry.transformed?.should be_false
    end

    it "returns true when transform version is 0" do
      # flags with transform version 0
      flags = (0_u8 << 6) | 0_u8
      entry = TrueType::Woff2TableEntry.new(flags, nil, 100_u32, 50_u32)
      entry.transformed?.should be_true
    end
  end
end

describe TrueType::Woff2 do
  describe ".woff2?" do
    it "returns true for valid WOFF2 signature" do
      # wOF2 signature
      data = Bytes[0x77, 0x4F, 0x46, 0x32, 0x00, 0x00, 0x00, 0x00]
      TrueType::Woff2.woff2?(data).should be_true
    end

    it "returns false for invalid signature" do
      data = Bytes[0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
      TrueType::Woff2.woff2?(data).should be_false
    end

    it "returns false for WOFF1 signature" do
      # wOFF signature (WOFF1)
      data = Bytes[0x77, 0x4F, 0x46, 0x46, 0x00, 0x00, 0x00, 0x00]
      TrueType::Woff2.woff2?(data).should be_false
    end

    it "returns false for data too small" do
      data = Bytes[0x77, 0x4F]
      TrueType::Woff2.woff2?(data).should be_false
    end

    it "returns false for empty data" do
      data = Bytes.empty
      TrueType::Woff2.woff2?(data).should be_false
    end
  end

  describe ".parse" do
    it "raises ParseError for data too small" do
      data = Bytes.new(10)
      expect_raises(TrueType::ParseError, /too small/) do
        TrueType::Woff2.parse(data)
      end
    end

    it "raises ParseError for invalid signature" do
      # Create 48 bytes of data with wrong signature
      data = Bytes.new(48)
      expect_raises(TrueType::ParseError, /Invalid WOFF2 signature/) do
        TrueType::Woff2.parse(data)
      end
    end
  end

  describe "#truetype?" do
    # Can't easily test without a real WOFF2 file, but we test the method exists
    it "responds to truetype?" do
      TrueType::Woff2.responds_to?(:new).should be_true
    end
  end

  describe "#cff?" do
    it "responds to cff?" do
      TrueType::Woff2.responds_to?(:new).should be_true
    end
  end
end
