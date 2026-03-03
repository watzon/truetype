require "../spec_helper"

describe TrueType::Bidi do
  describe ".bidi_class" do
    it "classifies strong, weak, neutral, and explicit formatting types" do
      TrueType::Bidi.bidi_class('A').should eq(TrueType::Bidi::CharClass::L)
      TrueType::Bidi.bidi_class('א').should eq(TrueType::Bidi::CharClass::R)
      TrueType::Bidi.bidi_class('ش').should eq(TrueType::Bidi::CharClass::AL)
      TrueType::Bidi.bidi_class('1').should eq(TrueType::Bidi::CharClass::EN)
      TrueType::Bidi.bidi_class('\u0661').should eq(TrueType::Bidi::CharClass::AN)
      TrueType::Bidi.bidi_class(' ').should eq(TrueType::Bidi::CharClass::WS)
      TrueType::Bidi.bidi_class('\u202A').should eq(TrueType::Bidi::CharClass::LRE)
      TrueType::Bidi.bidi_class('\u202B').should eq(TrueType::Bidi::CharClass::RLE)
      TrueType::Bidi.bidi_class('\u2066').should eq(TrueType::Bidi::CharClass::LRI)
      TrueType::Bidi.bidi_class('\u2067').should eq(TrueType::Bidi::CharClass::RLI)
      TrueType::Bidi.bidi_class('\u2068').should eq(TrueType::Bidi::CharClass::FSI)
      TrueType::Bidi.bidi_class('\u2069').should eq(TrueType::Bidi::CharClass::PDI)
    end
  end

  describe ".paired_bracket and .paired_bracket_type" do
    it "returns paired bracket metadata" do
      TrueType::Bidi.paired_bracket('(').should eq(')')
      TrueType::Bidi.paired_bracket(')').should eq('(')
      TrueType::Bidi.paired_bracket('A').should be_nil

      TrueType::Bidi.paired_bracket_type('(').should eq(TrueType::Bidi::PairedBracketType::Open)
      TrueType::Bidi.paired_bracket_type(')').should eq(TrueType::Bidi::PairedBracketType::Close)
      TrueType::Bidi.paired_bracket_type('A').should eq(TrueType::Bidi::PairedBracketType::None)
    end
  end

  describe ".resolve" do
    it "determines paragraph direction from first strong character" do
      ltr = TrueType::Bidi.resolve("abc אבג", TrueType::Bidi::ParagraphDirection::Auto)
      rtl = TrueType::Bidi.resolve("אבג abc", TrueType::Bidi::ParagraphDirection::Auto)

      ltr.base_level.should eq(0)
      rtl.base_level.should eq(1)
    end

    it "supports explicit paragraph direction override" do
      forced_ltr = TrueType::Bidi.resolve("אבג", TrueType::Bidi::ParagraphDirection::LeftToRight)
      forced_rtl = TrueType::Bidi.resolve("abc", TrueType::Bidi::ParagraphDirection::RightToLeft)

      forced_ltr.base_level.should eq(0)
      forced_rtl.base_level.should eq(1)
    end

    it "builds visual/logical index mappings for mixed-direction text" do
      result = TrueType::Bidi.resolve("abc אבג", TrueType::Bidi::ParagraphDirection::LeftToRight)

      result.display_visual_to_logical.should eq([0, 1, 2, 3, 6, 5, 4])
      result.display_logical_to_visual.should eq([0, 1, 2, 3, 6, 5, 4])
      result.visual_text.should eq("abc גבא")
    end

    it "removes explicit formatting controls from display mapping" do
      text = "abc\u2067אבג\u2069"
      result = TrueType::Bidi.resolve(text, TrueType::Bidi::ParagraphDirection::LeftToRight)

      result.chars.size.should eq(8)
      result.display_visual_to_logical.size.should eq(6)
      result.visual_text.should eq("abcגבא")
    end
  end
end
