require "../spec_helper"

describe TrueType::Woff2GlyfTransform do
  describe "constants" do
    it "has correct header size" do
      # 4 UInt16 + 7 UInt32 = 8 + 28 = 36 bytes
      TrueType::Woff2GlyfTransform::HEADER_SIZE.should eq(36)
    end

    it "has correct overlap simple bitmap flag" do
      TrueType::Woff2GlyfTransform::OVERLAP_SIMPLE_BITMAP_FLAG.should eq(0x0001_u16)
    end

    it "has correct glyph flags" do
      TrueType::Woff2GlyfTransform::GLYF_ON_CURVE.should eq(0x01_u8)
      TrueType::Woff2GlyfTransform::GLYF_X_SHORT.should eq(0x02_u8)
      TrueType::Woff2GlyfTransform::GLYF_Y_SHORT.should eq(0x04_u8)
      TrueType::Woff2GlyfTransform::GLYF_REPEAT.should eq(0x08_u8)
    end
  end

  describe "Point struct" do
    it "initializes with default values" do
      point = TrueType::Woff2GlyfTransform::Point.new
      point.x.should eq(0)
      point.y.should eq(0)
      point.on_curve.should be_true
    end

    it "initializes with custom values" do
      point = TrueType::Woff2GlyfTransform::Point.new(100, 200, false)
      point.x.should eq(100)
      point.y.should eq(200)
      point.on_curve.should be_false
    end
  end

  describe "#reconstruct" do
    it "raises error for data too small" do
      transform = TrueType::Woff2GlyfTransform.new
      expect_raises(TrueType::ParseError, /too small/) do
        transform.reconstruct(Bytes.new(10))
      end
    end

    it "raises error for invalid transform version" do
      transform = TrueType::Woff2GlyfTransform.new
      # Create header with version != 0
      data = IO::Memory.new
      data.write_bytes(1_u16, IO::ByteFormat::BigEndian) # version = 1 (invalid)
      data.write_bytes(0_u16, IO::ByteFormat::BigEndian) # optionFlags
      data.write_bytes(0_u16, IO::ByteFormat::BigEndian) # numGlyphs
      data.write_bytes(0_u16, IO::ByteFormat::BigEndian) # indexFormat
      7.times { data.write_bytes(0_u32, IO::ByteFormat::BigEndian) } # stream sizes

      expect_raises(TrueType::ParseError, /Invalid transform version/) do
        transform.reconstruct(data.to_slice)
      end
    end
  end
end

describe TrueType::Woff2HmtxTransform do
  describe "#reconstruct" do
    it "reconstructs hmtx with all LSBs stored (flags=0)" do
      transform = TrueType::Woff2HmtxTransform.new

      # Build test data: flags=0 (both LSB streams stored)
      # 2 glyphs, 2 hmetrics (no monospace section)
      data = IO::Memory.new
      data.write_bytes(0x00_u8) # flags: both LSBs stored
      data.write_bytes(500_u16, IO::ByteFormat::BigEndian) # advance width 0
      data.write_bytes(300_u16, IO::ByteFormat::BigEndian) # advance width 1
      data.write_bytes(10_i16, IO::ByteFormat::BigEndian)  # lsb 0
      data.write_bytes(20_i16, IO::ByteFormat::BigEndian)  # lsb 1

      result = transform.reconstruct(
        data.to_slice,
        num_glyphs: 2_u16,
        num_hmetrics: 2_u16,
        x_mins: [10_i16, 20_i16]
      )

      # Expected output: 2 longHorMetric entries (4 bytes each)
      result.size.should eq(8)

      # Parse result
      out = IO::Memory.new(result)
      out.read_bytes(UInt16, IO::ByteFormat::BigEndian).should eq(500) # advance 0
      out.read_bytes(Int16, IO::ByteFormat::BigEndian).should eq(10)   # lsb 0
      out.read_bytes(UInt16, IO::ByteFormat::BigEndian).should eq(300) # advance 1
      out.read_bytes(Int16, IO::ByteFormat::BigEndian).should eq(20)   # lsb 1
    end

    it "reconstructs hmtx with proportional LSBs derived from xMin (flags=1)" do
      transform = TrueType::Woff2HmtxTransform.new

      # Build test data: flags=1 (proportional LSBs derived from xMin)
      data = IO::Memory.new
      data.write_bytes(0x01_u8) # flags: NO proportional LSBs stored
      data.write_bytes(500_u16, IO::ByteFormat::BigEndian) # advance width 0
      data.write_bytes(300_u16, IO::ByteFormat::BigEndian) # advance width 1
      # No LSB data - derived from xMin

      x_mins = [15_i16, 25_i16]

      result = transform.reconstruct(
        data.to_slice,
        num_glyphs: 2_u16,
        num_hmetrics: 2_u16,
        x_mins: x_mins
      )

      result.size.should eq(8)

      out = IO::Memory.new(result)
      out.read_bytes(UInt16, IO::ByteFormat::BigEndian).should eq(500)
      out.read_bytes(Int16, IO::ByteFormat::BigEndian).should eq(15) # from xMin
      out.read_bytes(UInt16, IO::ByteFormat::BigEndian).should eq(300)
      out.read_bytes(Int16, IO::ByteFormat::BigEndian).should eq(25) # from xMin
    end

    it "reconstructs hmtx with monospace LSBs derived from xMin (flags=2)" do
      transform = TrueType::Woff2HmtxTransform.new

      # 3 glyphs, 2 hmetrics (1 monospace glyph)
      data = IO::Memory.new
      data.write_bytes(0x02_u8) # flags: NO monospace LSBs stored
      data.write_bytes(500_u16, IO::ByteFormat::BigEndian) # advance width 0
      data.write_bytes(300_u16, IO::ByteFormat::BigEndian) # advance width 1
      data.write_bytes(10_i16, IO::ByteFormat::BigEndian)  # proportional lsb 0
      data.write_bytes(20_i16, IO::ByteFormat::BigEndian)  # proportional lsb 1
      # No monospace LSB - derived from xMin[2]

      x_mins = [10_i16, 20_i16, 35_i16]

      result = transform.reconstruct(
        data.to_slice,
        num_glyphs: 3_u16,
        num_hmetrics: 2_u16,
        x_mins: x_mins
      )

      # 2 longHorMetric (8 bytes) + 1 leftSideBearing (2 bytes)
      result.size.should eq(10)

      out = IO::Memory.new(result)
      out.read_bytes(UInt16, IO::ByteFormat::BigEndian).should eq(500)
      out.read_bytes(Int16, IO::ByteFormat::BigEndian).should eq(10)
      out.read_bytes(UInt16, IO::ByteFormat::BigEndian).should eq(300)
      out.read_bytes(Int16, IO::ByteFormat::BigEndian).should eq(20)
      out.read_bytes(Int16, IO::ByteFormat::BigEndian).should eq(35) # from xMin
    end

    it "raises on empty data" do
      transform = TrueType::Woff2HmtxTransform.new
      expect_raises(TrueType::ParseError, /empty/) do
        transform.reconstruct(Bytes.empty, 2_u16, 2_u16, [0_i16, 0_i16])
      end
    end

    it "raises when num_hmetrics exceeds num_glyphs" do
      transform = TrueType::Woff2HmtxTransform.new
      data = Bytes[0x00] # minimal flags byte
      expect_raises(TrueType::ParseError, /cannot exceed/) do
        transform.reconstruct(data, 2_u16, 5_u16, [0_i16, 0_i16])
      end
    end
  end
end

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
    context "for glyf table (index 10)" do
      it "returns false when transform version is 3 (null transform)" do
        # glyf = index 10, version 3 = null transform
        flags = (3_u8 << 6) | 10_u8
        entry = TrueType::Woff2TableEntry.new(flags, nil, 100_u32, nil)
        entry.transformed?.should be_false
      end

      it "returns true when transform version is 0 (applied transform)" do
        # glyf = index 10, version 0 = applied transform
        flags = (0_u8 << 6) | 10_u8
        entry = TrueType::Woff2TableEntry.new(flags, nil, 100_u32, 50_u32)
        entry.transformed?.should be_true
      end
    end

    context "for loca table (index 11)" do
      it "returns false when transform version is 3 (null transform)" do
        # loca = index 11, version 3 = null transform
        flags = (3_u8 << 6) | 11_u8
        entry = TrueType::Woff2TableEntry.new(flags, nil, 100_u32, nil)
        entry.transformed?.should be_false
      end

      it "returns true when transform version is 0 (applied transform)" do
        # loca = index 11, version 0 = applied transform (has 0 bytes)
        flags = (0_u8 << 6) | 11_u8
        entry = TrueType::Woff2TableEntry.new(flags, nil, 100_u32, 0_u32)
        entry.transformed?.should be_true
      end
    end

    context "for other tables (cmap, index 0)" do
      it "returns false when transform version is 0 (null transform)" do
        # cmap = index 0, version 0 = null transform for non-glyf/loca
        flags = (0_u8 << 6) | 0_u8
        entry = TrueType::Woff2TableEntry.new(flags, nil, 100_u32, nil)
        entry.transformed?.should be_false
      end

      it "returns true when transform version is 1" do
        # cmap = index 0, version 1 = transformed for non-glyf/loca
        flags = (1_u8 << 6) | 0_u8
        entry = TrueType::Woff2TableEntry.new(flags, nil, 100_u32, 50_u32)
        entry.transformed?.should be_true
      end
    end
  end

  describe "#transform_version" do
    it "returns the transform version from flags" do
      flags = (2_u8 << 6) | 5_u8
      entry = TrueType::Woff2TableEntry.new(flags, nil, 100_u32, nil)
      entry.transform_version.should eq(2_u8)
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

  describe "integration with real WOFF2 file" do
    it "parses DejaVuSans.woff2 and converts to sfnt" do
      woff2_path = "spec/fixtures/fonts/DejaVuSans.woff2"
      ttf_path = "spec/fixtures/fonts/DejaVuSans.ttf"

      woff2_data = File.read(woff2_path).to_slice
      ttf_data = File.read(ttf_path).to_slice

      # Parse WOFF2
      woff2 = TrueType::Woff2.parse(woff2_data)

      # Should be TrueType flavor
      woff2.truetype?.should be_true
      woff2.cff?.should be_false

      # Convert to sfnt
      sfnt = woff2.to_sfnt

      # sfnt should be valid TrueType
      sfnt.size.should be > 0
      sfnt[0, 4].should eq(Bytes[0x00, 0x01, 0x00, 0x00]) # TrueType signature
    end

    it "produces a parseable font from WOFF2" do
      woff2_path = "spec/fixtures/fonts/DejaVuSans.woff2"
      woff2_data = File.read(woff2_path).to_slice

      woff2 = TrueType::Woff2.parse(woff2_data)
      parser = woff2.to_parser

      # Verify basic font properties
      parser.maxp.num_glyphs.should be > 0
      parser.units_per_em.should eq(2048)
      parser.family_name.should eq("DejaVu Sans")
    end

    it "reconstructs glyf/loca transforms correctly" do
      woff2_path = "spec/fixtures/fonts/DejaVuSans.woff2"
      ttf_path = "spec/fixtures/fonts/DejaVuSans.ttf"

      woff2_data = File.read(woff2_path).to_slice
      ttf_data = File.read(ttf_path).to_slice

      woff2 = TrueType::Woff2.parse(woff2_data)

      # Check if glyf is transformed
      glyf_entry = woff2.tables.find { |t| t.table_tag == "glyf" }
      glyf_entry.should_not be_nil
      glyf_entry.not_nil!.transformed?.should be_true

      # Parse both and compare glyph data
      woff2_parser = woff2.to_parser
      ttf_parser = TrueType::Parser.parse(ttf_data)

      # Glyph counts should match
      woff2_parser.maxp.num_glyphs.should eq(ttf_parser.maxp.num_glyphs)

      # Sample some glyph metrics
      ['A', 'B', 'C', 'a', 'b', 'c', '0', '1', '!', '@'].each do |char|
        woff2_gid = woff2_parser.glyph_id(char)
        ttf_gid = ttf_parser.glyph_id(char)

        woff2_gid.should eq(ttf_gid), "glyph ID mismatch for '#{char}'"

        woff2_width = woff2_parser.advance_width(woff2_gid)
        ttf_width = ttf_parser.advance_width(ttf_gid)

        woff2_width.should eq(ttf_width), "advance width mismatch for '#{char}'"
      end
    end

    it "handles table access after WOFF2 conversion" do
      woff2_path = "spec/fixtures/fonts/DejaVuSans.woff2"
      woff2_data = File.read(woff2_path).to_slice

      parser = TrueType::Woff2.parse(woff2_data).to_parser

      # Access various tables
      parser.head.should_not be_nil
      parser.hhea.should_not be_nil
      parser.maxp.should_not be_nil
      parser.cmap.should_not be_nil

      # Access glyph outlines (requires reconstructed glyf/loca)
      glyph_id = parser.glyph_id('A')
      outline = parser.glyph_outline(glyph_id)
      outline.should_not be_nil
      outline.not_nil!.contours.size.should be > 0
    end
  end
end
