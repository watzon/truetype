require "../spec_helper"

describe TrueType::Tables::OpenType::Coverage do
  describe TrueType::Tables::OpenType::CoverageFormat1 do
    it "creates coverage with glyph array" do
      glyphs = [10_u16, 20_u16, 30_u16, 40_u16]
      coverage = TrueType::Tables::OpenType::CoverageFormat1.new(glyphs)

      coverage.count.should eq(4)
      coverage.glyph_ids.should eq(glyphs)
    end

    it "returns correct coverage index" do
      glyphs = [10_u16, 20_u16, 30_u16, 40_u16]
      coverage = TrueType::Tables::OpenType::CoverageFormat1.new(glyphs)

      coverage.coverage_index(10_u16).should eq(0)
      coverage.coverage_index(20_u16).should eq(1)
      coverage.coverage_index(30_u16).should eq(2)
      coverage.coverage_index(40_u16).should eq(3)
    end

    it "returns nil for uncovered glyph" do
      glyphs = [10_u16, 20_u16, 30_u16]
      coverage = TrueType::Tables::OpenType::CoverageFormat1.new(glyphs)

      coverage.coverage_index(15_u16).should be_nil
      coverage.coverage_index(5_u16).should be_nil
      coverage.coverage_index(100_u16).should be_nil
    end

    it "checks if glyph is covered" do
      glyphs = [10_u16, 20_u16, 30_u16]
      coverage = TrueType::Tables::OpenType::CoverageFormat1.new(glyphs)

      coverage.covers?(10_u16).should be_true
      coverage.covers?(15_u16).should be_false
    end
  end

  describe TrueType::Tables::OpenType::CoverageFormat2 do
    it "creates coverage with ranges" do
      ranges = [
        TrueType::Tables::OpenType::CoverageFormat2::RangeRecord.new(10_u16, 15_u16, 0_u16),
        TrueType::Tables::OpenType::CoverageFormat2::RangeRecord.new(20_u16, 25_u16, 6_u16),
      ]
      coverage = TrueType::Tables::OpenType::CoverageFormat2.new(ranges)

      coverage.count.should eq(12) # 6 + 6 glyphs
    end

    it "returns correct coverage index for ranges" do
      ranges = [
        TrueType::Tables::OpenType::CoverageFormat2::RangeRecord.new(10_u16, 12_u16, 0_u16),
        TrueType::Tables::OpenType::CoverageFormat2::RangeRecord.new(20_u16, 22_u16, 3_u16),
      ]
      coverage = TrueType::Tables::OpenType::CoverageFormat2.new(ranges)

      coverage.coverage_index(10_u16).should eq(0)
      coverage.coverage_index(11_u16).should eq(1)
      coverage.coverage_index(12_u16).should eq(2)
      coverage.coverage_index(20_u16).should eq(3)
      coverage.coverage_index(21_u16).should eq(4)
      coverage.coverage_index(22_u16).should eq(5)
    end

    it "returns nil for uncovered glyph" do
      ranges = [
        TrueType::Tables::OpenType::CoverageFormat2::RangeRecord.new(10_u16, 15_u16, 0_u16),
      ]
      coverage = TrueType::Tables::OpenType::CoverageFormat2.new(ranges)

      coverage.coverage_index(5_u16).should be_nil
      coverage.coverage_index(16_u16).should be_nil
    end

    it "returns all glyph ids" do
      ranges = [
        TrueType::Tables::OpenType::CoverageFormat2::RangeRecord.new(10_u16, 12_u16, 0_u16),
      ]
      coverage = TrueType::Tables::OpenType::CoverageFormat2.new(ranges)

      coverage.glyph_ids.should eq([10_u16, 11_u16, 12_u16])
    end
  end
end

describe TrueType::Tables::OpenType::ClassDef do
  describe TrueType::Tables::OpenType::ClassDefFormat1 do
    it "returns class for glyph in range" do
      class_def = TrueType::Tables::OpenType::ClassDefFormat1.new(10_u16, [1_u16, 2_u16, 1_u16, 3_u16])

      class_def.class_id(10_u16).should eq(1_u16)
      class_def.class_id(11_u16).should eq(2_u16)
      class_def.class_id(12_u16).should eq(1_u16)
      class_def.class_id(13_u16).should eq(3_u16)
    end

    it "returns default class 0 for glyph outside range" do
      class_def = TrueType::Tables::OpenType::ClassDefFormat1.new(10_u16, [1_u16, 2_u16])

      class_def.class_id(5_u16).should eq(0_u16)
      class_def.class_id(100_u16).should eq(0_u16)
    end

    it "returns max class" do
      class_def = TrueType::Tables::OpenType::ClassDefFormat1.new(10_u16, [1_u16, 5_u16, 3_u16])
      class_def.max_class.should eq(5_u16)
    end

    it "finds glyphs in a class" do
      class_def = TrueType::Tables::OpenType::ClassDefFormat1.new(10_u16, [1_u16, 2_u16, 1_u16, 3_u16])
      class_def.glyphs_in_class(1_u16).should eq([10_u16, 12_u16])
    end
  end

  describe TrueType::Tables::OpenType::ClassDefFormat2 do
    it "returns class for glyph in range" do
      ranges = [
        TrueType::Tables::OpenType::ClassDefFormat2::ClassRangeRecord.new(10_u16, 15_u16, 1_u16),
        TrueType::Tables::OpenType::ClassDefFormat2::ClassRangeRecord.new(20_u16, 25_u16, 2_u16),
      ]
      class_def = TrueType::Tables::OpenType::ClassDefFormat2.new(ranges)

      class_def.class_id(10_u16).should eq(1_u16)
      class_def.class_id(15_u16).should eq(1_u16)
      class_def.class_id(20_u16).should eq(2_u16)
    end

    it "returns default class 0 for glyph outside ranges" do
      ranges = [
        TrueType::Tables::OpenType::ClassDefFormat2::ClassRangeRecord.new(10_u16, 15_u16, 1_u16),
      ]
      class_def = TrueType::Tables::OpenType::ClassDefFormat2.new(ranges)

      class_def.class_id(5_u16).should eq(0_u16)
      class_def.class_id(16_u16).should eq(0_u16)
    end
  end
end

describe TrueType::Tables::OpenType::GDEF do
  describe TrueType::Tables::OpenType::GDEF::GlyphClass do
    it "has correct enum values" do
      TrueType::Tables::OpenType::GDEF::GlyphClass::Base.value.should eq(1)
      TrueType::Tables::OpenType::GDEF::GlyphClass::Ligature.value.should eq(2)
      TrueType::Tables::OpenType::GDEF::GlyphClass::Mark.value.should eq(3)
      TrueType::Tables::OpenType::GDEF::GlyphClass::Component.value.should eq(4)
    end
  end
end

describe TrueType::Tables::OpenType::ValueFormat do
  it "has correct flag values" do
    TrueType::Tables::OpenType::ValueFormat::XPlacement.value.should eq(0x0001)
    TrueType::Tables::OpenType::ValueFormat::YPlacement.value.should eq(0x0002)
    TrueType::Tables::OpenType::ValueFormat::XAdvance.value.should eq(0x0004)
    TrueType::Tables::OpenType::ValueFormat::YAdvance.value.should eq(0x0008)
  end
end

describe TrueType::Tables::OpenType::ValueRecord do
  it "calculates size based on format" do
    none = TrueType::Tables::OpenType::ValueFormat::None
    TrueType::Tables::OpenType::ValueRecord.size(none).should eq(0)

    x_adv = TrueType::Tables::OpenType::ValueFormat::XAdvance
    TrueType::Tables::OpenType::ValueRecord.size(x_adv).should eq(2)

    full = TrueType::Tables::OpenType::ValueFormat::XPlacement |
           TrueType::Tables::OpenType::ValueFormat::YPlacement |
           TrueType::Tables::OpenType::ValueFormat::XAdvance |
           TrueType::Tables::OpenType::ValueFormat::YAdvance
    TrueType::Tables::OpenType::ValueRecord.size(full).should eq(8)
  end
end

describe TrueType::Tables::OpenType::LangSys do
  it "detects required feature" do
    lang_sys = TrueType::Tables::OpenType::LangSys.new(0_u16, 5_u16, [0_u16, 1_u16])
    lang_sys.has_required_feature?.should be_true

    lang_sys_no_req = TrueType::Tables::OpenType::LangSys.new(0_u16, 0xFFFF_u16, [0_u16])
    lang_sys_no_req.has_required_feature?.should be_false
  end
end

describe TrueType::Tables::OpenType::GSUBLookupType do
  it "has correct enum values" do
    TrueType::Tables::OpenType::GSUBLookupType::Single.value.should eq(1)
    TrueType::Tables::OpenType::GSUBLookupType::Multiple.value.should eq(2)
    TrueType::Tables::OpenType::GSUBLookupType::Alternate.value.should eq(3)
    TrueType::Tables::OpenType::GSUBLookupType::Ligature.value.should eq(4)
    TrueType::Tables::OpenType::GSUBLookupType::Context.value.should eq(5)
    TrueType::Tables::OpenType::GSUBLookupType::ChainingContext.value.should eq(6)
    TrueType::Tables::OpenType::GSUBLookupType::ExtensionSubst.value.should eq(7)
    TrueType::Tables::OpenType::GSUBLookupType::ReverseChainingCtx.value.should eq(8)
  end
end

describe TrueType::Tables::OpenType::GPOSLookupType do
  it "has correct enum values" do
    TrueType::Tables::OpenType::GPOSLookupType::SingleAdjustment.value.should eq(1)
    TrueType::Tables::OpenType::GPOSLookupType::PairAdjustment.value.should eq(2)
    TrueType::Tables::OpenType::GPOSLookupType::CursiveAttachment.value.should eq(3)
    TrueType::Tables::OpenType::GPOSLookupType::MarkToBase.value.should eq(4)
    TrueType::Tables::OpenType::GPOSLookupType::MarkToLigature.value.should eq(5)
    TrueType::Tables::OpenType::GPOSLookupType::MarkToMark.value.should eq(6)
    TrueType::Tables::OpenType::GPOSLookupType::Context.value.should eq(7)
    TrueType::Tables::OpenType::GPOSLookupType::ChainingContext.value.should eq(8)
    TrueType::Tables::OpenType::GPOSLookupType::Extension.value.should eq(9)
  end
end

describe TrueType::Tables::OpenType::SingleSubstFormat1 do
  it "substitutes glyphs with delta" do
    coverage = TrueType::Tables::OpenType::CoverageFormat1.new([10_u16, 20_u16, 30_u16])
    subst = TrueType::Tables::OpenType::SingleSubstFormat1.new(coverage, 100_i16)

    subst.substitute(10_u16).should eq(110_u16)
    subst.substitute(20_u16).should eq(120_u16)
    subst.substitute(5_u16).should be_nil # not covered
  end
end

describe TrueType::Tables::OpenType::SingleSubstFormat2 do
  it "substitutes glyphs with mapping" do
    coverage = TrueType::Tables::OpenType::CoverageFormat1.new([10_u16, 20_u16, 30_u16])
    subst = TrueType::Tables::OpenType::SingleSubstFormat2.new(coverage, [100_u16, 200_u16, 300_u16])

    subst.substitute(10_u16).should eq(100_u16)
    subst.substitute(20_u16).should eq(200_u16)
    subst.substitute(30_u16).should eq(300_u16)
    subst.substitute(5_u16).should be_nil # not covered
  end
end

describe TrueType::Tables::OpenType::MultipleSubst do
  it "substitutes one glyph to multiple" do
    coverage = TrueType::Tables::OpenType::CoverageFormat1.new([10_u16])
    subst = TrueType::Tables::OpenType::MultipleSubst.new(coverage, [[100_u16, 101_u16, 102_u16]])

    subst.substitute(10_u16).should eq([100_u16, 101_u16, 102_u16])
    subst.substitute(5_u16).should be_nil
  end
end

describe TrueType::Tables::OpenType::AlternateSubst do
  it "returns alternates for a glyph" do
    coverage = TrueType::Tables::OpenType::CoverageFormat1.new([10_u16])
    subst = TrueType::Tables::OpenType::AlternateSubst.new(coverage, [[100_u16, 101_u16]])

    subst.alternates(10_u16).should eq([100_u16, 101_u16])
    subst.alternates(5_u16).should be_nil
  end
end

describe TrueType::Tables::OpenType::LigatureSubst do
  it "returns ligatures starting with a glyph" do
    coverage = TrueType::Tables::OpenType::CoverageFormat1.new([10_u16]) # 'f'
    lig_entry = TrueType::Tables::OpenType::LigatureEntry.new(100_u16, [20_u16]) # 'fi' ligature
    subst = TrueType::Tables::OpenType::LigatureSubst.new(coverage, [[lig_entry]])

    ligs = subst.ligatures_for(10_u16)
    ligs.should_not be_nil
    ligs.not_nil!.size.should eq(1)
    ligs.not_nil![0].ligature_glyph.should eq(100_u16)
    ligs.not_nil![0].component_glyphs.should eq([20_u16])
  end
end

describe TrueType::Tables::OpenType::SinglePosFormat1 do
  it "returns same adjustment for all covered glyphs" do
    coverage = TrueType::Tables::OpenType::CoverageFormat1.new([10_u16, 20_u16])
    value_format = TrueType::Tables::OpenType::ValueFormat::XAdvance
    value_record = TrueType::Tables::OpenType::ValueRecord.new(x_advance: 50_i16)
    pos = TrueType::Tables::OpenType::SinglePosFormat1.new(coverage, value_format, value_record)

    adj = pos.adjustment(10_u16)
    adj.should_not be_nil
    adj.not_nil!.x_advance.should eq(50_i16)

    adj2 = pos.adjustment(20_u16)
    adj2.should_not be_nil
    adj2.not_nil!.x_advance.should eq(50_i16)

    pos.adjustment(5_u16).should be_nil
  end
end

describe TrueType::Tables::OpenType::PairPosFormat1 do
  it "returns adjustment for specific glyph pair" do
    coverage = TrueType::Tables::OpenType::CoverageFormat1.new([10_u16])
    value_format1 = TrueType::Tables::OpenType::ValueFormat::XAdvance
    value_format2 = TrueType::Tables::OpenType::ValueFormat::None

    pair = TrueType::Tables::OpenType::PairValueRecord.new(
      20_u16,
      TrueType::Tables::OpenType::ValueRecord.new(x_advance: -50_i16),
      TrueType::Tables::OpenType::ValueRecord.new
    )

    pos = TrueType::Tables::OpenType::PairPosFormat1.new(coverage, value_format1, value_format2, [[pair]])

    adj = pos.adjustment(10_u16, 20_u16)
    adj.should_not be_nil
    adj.not_nil![0].x_advance.should eq(-50_i16)

    pos.adjustment(10_u16, 30_u16).should be_nil
    pos.adjustment(5_u16, 20_u16).should be_nil
  end
end

# Context lookup structures
describe TrueType::Tables::OpenType::SequenceRule do
  it "stores glyph sequence and lookup records" do
    lookup_record = TrueType::Tables::OpenType::SequenceLookupRecord.new(0_u16, 1_u16)
    rule = TrueType::Tables::OpenType::SequenceRule.new([20_u16, 30_u16], [lookup_record])

    rule.glyph_sequence.should eq([20_u16, 30_u16])
    rule.lookup_records.size.should eq(1)
    rule.glyph_count.should eq(3) # Including first glyph matched by coverage
  end
end

describe TrueType::Tables::OpenType::ClassSequenceRule do
  it "stores class sequence and lookup records" do
    lookup_record = TrueType::Tables::OpenType::SequenceLookupRecord.new(1_u16, 2_u16)
    rule = TrueType::Tables::OpenType::ClassSequenceRule.new([1_u16, 2_u16], [lookup_record])

    rule.class_sequence.should eq([1_u16, 2_u16])
    rule.glyph_count.should eq(3)
  end
end

describe TrueType::Tables::OpenType::ChainedSequenceRule do
  it "stores backtrack, input, lookahead and lookup records" do
    lookup_record = TrueType::Tables::OpenType::SequenceLookupRecord.new(0_u16, 0_u16)
    rule = TrueType::Tables::OpenType::ChainedSequenceRule.new(
      [5_u16],           # backtrack
      [20_u16, 30_u16],  # input (excluding first)
      [40_u16],          # lookahead
      [lookup_record]
    )

    rule.backtrack_sequence.should eq([5_u16])
    rule.input_sequence.should eq([20_u16, 30_u16])
    rule.lookahead_sequence.should eq([40_u16])
    rule.input_glyph_count.should eq(3)
  end
end

describe TrueType::Tables::OpenType::SequenceLookupRecord do
  it "stores sequence index and lookup index" do
    record = TrueType::Tables::OpenType::SequenceLookupRecord.new(2_u16, 5_u16)

    record.sequence_index.should eq(2_u16)
    record.lookup_index.should eq(5_u16)
  end
end

# Context Positioning subtables
describe TrueType::Tables::OpenType::ContextPosFormat1 do
  it "returns correct lookup type" do
    coverage = TrueType::Tables::OpenType::CoverageFormat1.new([10_u16])
    rule_sets = Array(Array(TrueType::Tables::OpenType::SequenceRule)?).new
    rule_sets << nil
    subtable = TrueType::Tables::OpenType::ContextPosFormat1.new(coverage, rule_sets)

    subtable.lookup_type.should eq(TrueType::Tables::OpenType::GPOSLookupType::Context)
  end

  it "returns rules for covered glyph" do
    coverage = TrueType::Tables::OpenType::CoverageFormat1.new([10_u16])
    lookup_record = TrueType::Tables::OpenType::SequenceLookupRecord.new(0_u16, 1_u16)
    rule = TrueType::Tables::OpenType::SequenceRule.new([20_u16], [lookup_record])

    rule_sets = Array(Array(TrueType::Tables::OpenType::SequenceRule)?).new
    rule_sets << [rule]
    subtable = TrueType::Tables::OpenType::ContextPosFormat1.new(coverage, rule_sets)

    rules = subtable.rules_for(10_u16)
    rules.should_not be_nil
    rules.not_nil!.size.should eq(1)

    subtable.rules_for(99_u16).should be_nil
  end
end

describe TrueType::Tables::OpenType::ContextPosFormat3 do
  it "matches glyph sequence against coverages" do
    cov1 = TrueType::Tables::OpenType::CoverageFormat1.new([10_u16]).as(TrueType::Tables::OpenType::Coverage)
    cov2 = TrueType::Tables::OpenType::CoverageFormat1.new([20_u16]).as(TrueType::Tables::OpenType::Coverage)
    lookup_record = TrueType::Tables::OpenType::SequenceLookupRecord.new(0_u16, 0_u16)

    subtable = TrueType::Tables::OpenType::ContextPosFormat3.new([cov1, cov2], [lookup_record])

    subtable.matches?([10_u16, 20_u16]).should be_true
    subtable.matches?([10_u16, 30_u16]).should be_false
    subtable.matches?([10_u16]).should be_false # too short
  end
end

# Chained Context Positioning subtables
describe TrueType::Tables::OpenType::ChainedContextPosFormat3 do
  it "checks input sequence against coverages" do
    input_cov1 = TrueType::Tables::OpenType::CoverageFormat1.new([10_u16]).as(TrueType::Tables::OpenType::Coverage)
    input_cov2 = TrueType::Tables::OpenType::CoverageFormat1.new([20_u16]).as(TrueType::Tables::OpenType::Coverage)
    lookup_record = TrueType::Tables::OpenType::SequenceLookupRecord.new(0_u16, 0_u16)

    subtable = TrueType::Tables::OpenType::ChainedContextPosFormat3.new(
      [] of TrueType::Tables::OpenType::Coverage, # backtrack
      [input_cov1, input_cov2],                   # input
      [] of TrueType::Tables::OpenType::Coverage, # lookahead
      [lookup_record]
    )

    subtable.input_matches?([10_u16, 20_u16]).should be_true
    subtable.input_matches?([10_u16, 99_u16]).should be_false
  end
end

# Context Substitution subtables
describe TrueType::Tables::OpenType::ContextSubstFormat1 do
  it "returns correct lookup type" do
    coverage = TrueType::Tables::OpenType::CoverageFormat1.new([10_u16])
    rule_sets = Array(Array(TrueType::Tables::OpenType::SequenceRule)?).new
    rule_sets << nil
    subtable = TrueType::Tables::OpenType::ContextSubstFormat1.new(coverage, rule_sets)

    subtable.lookup_type.should eq(TrueType::Tables::OpenType::GSUBLookupType::Context)
  end

  it "returns rules for covered glyph" do
    coverage = TrueType::Tables::OpenType::CoverageFormat1.new([10_u16])
    lookup_record = TrueType::Tables::OpenType::SequenceLookupRecord.new(0_u16, 1_u16)
    rule = TrueType::Tables::OpenType::SequenceRule.new([20_u16], [lookup_record])

    rule_sets = Array(Array(TrueType::Tables::OpenType::SequenceRule)?).new
    rule_sets << [rule]
    subtable = TrueType::Tables::OpenType::ContextSubstFormat1.new(coverage, rule_sets)

    rules = subtable.rules_for(10_u16)
    rules.should_not be_nil
    rules.not_nil!.size.should eq(1)
  end
end

describe TrueType::Tables::OpenType::ChainedContextSubstFormat3 do
  it "checks input sequence against coverages" do
    input_cov = TrueType::Tables::OpenType::CoverageFormat1.new([10_u16, 20_u16]).as(TrueType::Tables::OpenType::Coverage)
    lookup_record = TrueType::Tables::OpenType::SequenceLookupRecord.new(0_u16, 0_u16)

    subtable = TrueType::Tables::OpenType::ChainedContextSubstFormat3.new(
      [] of TrueType::Tables::OpenType::Coverage,
      [input_cov],
      [] of TrueType::Tables::OpenType::Coverage,
      [lookup_record]
    )

    subtable.input_matches?([10_u16]).should be_true
    subtable.input_matches?([20_u16]).should be_true
    subtable.input_matches?([99_u16]).should be_false
  end
end

# Reverse Chaining Substitution
describe TrueType::Tables::OpenType::ReverseChainSubst do
  it "returns correct lookup type" do
    coverage = TrueType::Tables::OpenType::CoverageFormat1.new([10_u16])
    subtable = TrueType::Tables::OpenType::ReverseChainSubst.new(
      [] of TrueType::Tables::OpenType::Coverage,
      coverage,
      [] of TrueType::Tables::OpenType::Coverage,
      [100_u16]
    )

    subtable.lookup_type.should eq(TrueType::Tables::OpenType::GSUBLookupType::ReverseChainingCtx)
  end

  it "substitutes covered glyph" do
    coverage = TrueType::Tables::OpenType::CoverageFormat1.new([10_u16, 20_u16])
    subtable = TrueType::Tables::OpenType::ReverseChainSubst.new(
      [] of TrueType::Tables::OpenType::Coverage,
      coverage,
      [] of TrueType::Tables::OpenType::Coverage,
      [100_u16, 200_u16]
    )

    subtable.substitute(10_u16).should eq(100_u16)
    subtable.substitute(20_u16).should eq(200_u16)
    subtable.substitute(99_u16).should be_nil
  end
end

# Integration tests with real font file
describe "OpenType layout with real font" do
  it "can check for OpenType layout tables" do
    parser = TrueType::Parser.parse(FONT_PATH)
    # DejaVuSans may or may not have these tables
    parser.has_opentype_layout?.should be_a(Bool)
  end

  it "can parse GDEF table if present" do
    parser = TrueType::Parser.parse(FONT_PATH)
    if parser.has_table?("GDEF")
      gdef = parser.gdef
      gdef.should_not be_nil
    end
  end

  it "can parse GSUB table if present" do
    parser = TrueType::Parser.parse(FONT_PATH)
    if parser.has_table?("GSUB")
      gsub = parser.gsub
      gsub.should_not be_nil
    end
  end

  it "can parse GPOS table if present" do
    parser = TrueType::Parser.parse(FONT_PATH)
    if parser.has_table?("GPOS")
      gpos = parser.gpos
      gpos.should_not be_nil
    end
  end

  it "can check for ligature support" do
    parser = TrueType::Parser.parse(FONT_PATH)
    parser.has_ligatures?.should be_a(Bool)
  end

  it "can get glyph class" do
    parser = TrueType::Parser.parse(FONT_PATH)
    if parser.has_table?("GDEF")
      # Just check it doesn't crash, class might be nil
      parser.glyph_class(1_u16)
    end
  end

  it "kerning method checks both GPOS and kern tables" do
    parser = TrueType::Parser.parse(FONT_PATH)
    # Should work regardless of which kerning source is present
    kern_value = parser.kerning('A', 'V')
    kern_value.should be_a(Int16)
  end
end
