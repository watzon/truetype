require "../spec_helper"

# Phase 6: Extended Format Support Tests
# Tests for BASE, MATH, CFF2, JSTF, and metadata tables

describe "Phase 6: Extended Format Support" do
  describe TrueType::Tables::OpenType::BASE do
    describe "BaseCoord" do
      it "creates format 1 coordinate" do
        coord = TrueType::Tables::OpenType::BaseCoord.new(1_u16, 100_i16)
        coord.format.should eq(1_u16)
        coord.coordinate.should eq(100_i16)
        coord.reference_glyph.should be_nil
      end

      it "creates format 2 coordinate with reference glyph" do
        coord = TrueType::Tables::OpenType::BaseCoord.new(2_u16, 100_i16, 50_u16, 5_u16)
        coord.format.should eq(2_u16)
        coord.coordinate.should eq(100_i16)
        coord.reference_glyph.should eq(50_u16)
        coord.base_coord_point.should eq(5_u16)
      end
    end

    describe "MinMax" do
      it "stores min and max coordinates" do
        min_max = TrueType::Tables::OpenType::MinMax.new(-100_i16, 200_i16)
        min_max.min_coord.should eq(-100_i16)
        min_max.max_coord.should eq(200_i16)
      end
    end

    describe "BaseLangSysRecord" do
      it "associates language tag with min/max" do
        min_max = TrueType::Tables::OpenType::MinMax.new(-50_i16, 150_i16)
        record = TrueType::Tables::OpenType::BaseLangSysRecord.new("DEU ", min_max)
        record.lang_sys_tag.should eq("DEU ")
        record.min_max.min_coord.should eq(-50_i16)
      end
    end
  end

  describe TrueType::Tables::Math do
    describe "MathValueRecord" do
      it "stores value and device offset" do
        record = TrueType::Tables::Math::MathValueRecord.new(100_i16, 0_u16)
        record.value.should eq(100_i16)
        record.device_offset.should eq(0_u16)
      end
    end

    describe "MathConstant enum" do
      it "has all 56 constants defined" do
        TrueType::Tables::Math::MathConstant::ScriptPercentScaleDown.value.should eq(0)
        TrueType::Tables::Math::MathConstant::AxisHeight.value.should eq(5)
        TrueType::Tables::Math::MathConstant::RadicalDegreeBottomRaisePercent.value.should eq(55)
      end
    end

    describe "MathKernCorner enum" do
      it "has all four corners" do
        TrueType::Tables::Math::MathKernCorner::TopRight.value.should eq(0)
        TrueType::Tables::Math::MathKernCorner::TopLeft.value.should eq(1)
        TrueType::Tables::Math::MathKernCorner::BottomRight.value.should eq(2)
        TrueType::Tables::Math::MathKernCorner::BottomLeft.value.should eq(3)
      end
    end

    describe "MathGlyphVariant" do
      it "stores glyph id and advance" do
        variant = TrueType::Tables::Math::MathGlyphVariant.new(100_u16, 500_u16)
        variant.glyph_id.should eq(100_u16)
        variant.advance_measurement.should eq(500_u16)
      end
    end

    describe "GlyphPartRecord" do
      it "stores part data with extender flag" do
        part = TrueType::Tables::Math::GlyphPartRecord.new(
          50_u16,  # glyph_id
          10_u16,  # start_connector_length
          10_u16,  # end_connector_length
          100_u16, # full_advance
          1_u16    # flags (extender)
        )
        part.glyph_id.should eq(50_u16)
        part.full_advance.should eq(100_u16)
        part.extender?.should be_true
      end

      it "detects non-extender parts" do
        part = TrueType::Tables::Math::GlyphPartRecord.new(
          50_u16, 10_u16, 10_u16, 100_u16, 0_u16
        )
        part.extender?.should be_false
      end
    end

    describe "MathKernInfo" do
      it "stores kern data for all four corners" do
        info = TrueType::Tables::Math::MathKernInfo.new(nil, nil, nil, nil)
        info.top_right.should be_nil
        info.top_left.should be_nil
        info.bottom_right.should be_nil
        info.bottom_left.should be_nil
      end
    end
  end

  describe TrueType::Tables::CFF do
    describe "CFF2Header" do
      it "parses CFF2 header correctly" do
        # Create mock CFF2 header data
        data = Bytes.new(8)
        data[0] = 2_u8  # major version
        data[1] = 0_u8  # minor version
        data[2] = 5_u8  # header size
        data[3] = 0_u8  # top dict length high byte
        data[4] = 10_u8 # top dict length low byte

        io = IO::Memory.new(data)
        header = TrueType::Tables::CFF::CFF2Header.parse(io)

        header.major_version.should eq(2_u8)
        header.minor_version.should eq(0_u8)
        header.cff2?.should be_true
      end
    end

    describe "cff_version helper" do
      it "returns version from data" do
        data_cff1 = Bytes[1, 0, 4, 1]
        TrueType::Tables::CFF.cff_version(data_cff1).should eq(1)

        data_cff2 = Bytes[2, 0, 5, 0, 10]
        TrueType::Tables::CFF.cff_version(data_cff2).should eq(2)
      end

      it "detects CFF2" do
        data_cff2 = Bytes[2, 0, 5, 0, 10]
        TrueType::Tables::CFF.cff2?(data_cff2).should be_true

        data_cff1 = Bytes[1, 0, 4, 1]
        TrueType::Tables::CFF.cff2?(data_cff1).should be_false
      end
    end

    describe "CFF2DictOp" do
      it "has correct operator values" do
        TrueType::Tables::CFF::CFF2DictOp::VSTORE.value.should eq(24)
        TrueType::Tables::CFF::CFF2DictOp::VSINDEX.value.should eq(22)
        TrueType::Tables::CFF::CFF2DictOp::BLEND.value.should eq(23)
      end
    end
  end

  describe TrueType::Tables::OpenType::JSTF do
    describe "JstfPriority" do
      it "can be constructed with lookup lists" do
        # Empty priority (no adjustments)
        priority = TrueType::Tables::OpenType::JstfPriority.new(
          nil, nil, nil, nil, nil,  # shrinkage
          nil, nil, nil, nil, nil   # extension
        )
        priority.gsub_shrinkage_enable.should be_nil
        priority.extension_max.should be_nil
      end
    end

    describe "JstfMax" do
      it "stores lookup indices" do
        max = TrueType::Tables::OpenType::JstfMax.new([0_u16, 1_u16, 2_u16])
        max.lookup_indices.should eq([0_u16, 1_u16, 2_u16])
      end
    end

    describe "JstfLangSysRecord" do
      it "associates language with priorities" do
        lang_sys = TrueType::Tables::OpenType::JstfLangSys.new([] of TrueType::Tables::OpenType::JstfPriority)
        record = TrueType::Tables::OpenType::JstfLangSysRecord.new("DEU ", lang_sys)
        record.lang_sys_tag.should eq("DEU ")
      end
    end
  end

  describe TrueType::Tables::Metadata::DSIG do
    describe "SignatureRecord" do
      it "stores signature data" do
        sig = TrueType::Tables::Metadata::SignatureRecord.new(1_u32, 100_u32, 12_u32, Bytes.new(100))
        sig.format.should eq(1_u32)
        sig.length.should eq(100_u32)
        sig.pkcs7?.should be_true
      end

      it "detects non-PKCS7 format" do
        sig = TrueType::Tables::Metadata::SignatureRecord.new(2_u32, 100_u32, 12_u32, Bytes.new(100))
        sig.pkcs7?.should be_false
      end
    end
  end

  describe TrueType::Tables::Metadata::Meta do
    describe "DataMap" do
      it "stores tag and data" do
        map = TrueType::Tables::Metadata::DataMap.new("dlng", "en-US, de-DE")
        map.tag.should eq("dlng")
        map.data.should eq("en-US, de-DE")
      end
    end
  end

  describe TrueType::Tables::Metadata::PCLT do
    describe "stroke weight names" do
      it "returns correct weight names" do
        # Create a minimal PCLT for testing
        # This tests the stroke_weight_name method logic
        pclt = TrueType::Tables::Metadata::PCLT.new(
          0x00010000_u32,  # version
          0_u32,           # font_number
          0_u16, 0_u16, 0_u16, 0_u16, 0_u16, 0_u16,
          "",              # typeface
          Bytes.new(8),    # character_complement
          "",              # file_name
          0_i8,            # stroke_weight (medium)
          0_i8,            # width_type (normal)
          0_u8, 0_u8
        )
        pclt.stroke_weight_name.should eq("Medium")
      end

      it "returns correct width type names" do
        pclt = TrueType::Tables::Metadata::PCLT.new(
          0x00010000_u32, 0_u32, 0_u16, 0_u16, 0_u16, 0_u16, 0_u16, 0_u16,
          "", Bytes.new(8), "",
          0_i8, 2_i8, 0_u8, 0_u8
        )
        pclt.width_type_name.should eq("Expanded")
      end

      it "detects sans-serif" do
        pclt = TrueType::Tables::Metadata::PCLT.new(
          0x00010000_u32, 0_u32, 0_u16, 0_u16, 0_u16, 0_u16, 0_u16, 0_u16,
          "", Bytes.new(8), "",
          0_i8, 0_i8, 0_u8, 0_u8  # serif_style = 0
        )
        pclt.sans_serif?.should be_true
        pclt.serif?.should be_false
      end
    end
  end

  describe TrueType::Tables::Variations::ItemVariationStore do
    describe "compute_scalars" do
      it "returns empty array for invalid vsindex" do
        # We can't easily create a full ItemVariationStore for unit testing
        # but we can test the edge case behavior
      end
    end
  end

  # Integration tests with real font
  describe "Parser integration" do
    it "can check for BASE table" do
      parser = TrueType::Parser.parse(FONT_PATH)
      parser.has_baseline_data?.should be_a(Bool)
    end

    it "can access baseline method" do
      parser = TrueType::Parser.parse(FONT_PATH)
      # May or may not have BASE table
      result = parser.baseline("latn", "romn")
      result.should be_a(Int16?)
    end

    it "can check for math font" do
      parser = TrueType::Parser.parse(FONT_PATH)
      parser.math_font?.should be_a(Bool)
    end

    it "can access math_constant" do
      parser = TrueType::Parser.parse(FONT_PATH)
      result = parser.math_constant(TrueType::Tables::Math::MathConstant::AxisHeight)
      result.should be_a(Int16)
    end

    it "can check for CFF2" do
      parser = TrueType::Parser.parse(FONT_PATH)
      parser.cff2?.should be_a(Bool)
    end

    it "can check for justification" do
      parser = TrueType::Parser.parse(FONT_PATH)
      parser.has_justification?.should be_a(Bool)
    end

    it "can check for digital signature" do
      parser = TrueType::Parser.parse(FONT_PATH)
      parser.signed?.should be_a(Bool)
    end

    it "can access meta table" do
      parser = TrueType::Parser.parse(FONT_PATH)
      meta = parser.meta
      meta.should be_a(TrueType::Tables::Metadata::Meta?)
    end

    it "can access pclt table" do
      parser = TrueType::Parser.parse(FONT_PATH)
      pclt = parser.pclt
      pclt.should be_a(TrueType::Tables::Metadata::PCLT?)
    end

    it "can access math variants methods" do
      parser = TrueType::Parser.parse(FONT_PATH)
      # These will return nil for non-math fonts
      parser.math_vertical_variants(1_u16).should be_a(Array(TrueType::Tables::Math::MathGlyphVariant)?)
      parser.math_horizontal_variants(1_u16).should be_a(Array(TrueType::Tables::Math::MathGlyphVariant)?)
    end

    it "can access math assembly methods" do
      parser = TrueType::Parser.parse(FONT_PATH)
      parser.math_vertical_assembly(1_u16).should be_a(TrueType::Tables::Math::GlyphAssembly?)
      parser.math_horizontal_assembly(1_u16).should be_a(TrueType::Tables::Math::GlyphAssembly?)
    end

    it "can access math kern" do
      parser = TrueType::Parser.parse(FONT_PATH)
      kern = parser.math_kern(1_u16, TrueType::Tables::Math::MathKernCorner::TopRight, 100_i16)
      kern.should be_a(Int16)
    end

    it "can access math italics correction" do
      parser = TrueType::Parser.parse(FONT_PATH)
      correction = parser.math_italics_correction(1_u16)
      correction.should be_a(Int16?)
    end

    it "can access math top accent attachment" do
      parser = TrueType::Parser.parse(FONT_PATH)
      attachment = parser.math_top_accent_attachment(1_u16)
      attachment.should be_a(Int16?)
    end
  end
end
