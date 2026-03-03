require "../spec_helper"

private def glyph_state(glyphs : Array(TrueType::PositionedGlyph)) : Array(Tuple(UInt16, Int32, Int32, Int32, Int32, Int32))
  glyphs.map { |g| {g.id, g.cluster, g.x_offset, g.y_offset, g.x_advance, g.y_advance} }
end

describe TrueType::Font do
  describe "#shape_best_effort predictability" do
    it "is deterministic across repeated calls" do
      font = TrueType::Font.open(FONT_PATH)
      text = "office AV"
      options = TrueType::ShapingOptions.new(
        script: "latn",
        language: "ENG",
        features: ["liga", "kern", "calt"] of String
      )

      snapshots = 6.times.map do
        glyph_state(font.shape_best_effort(text, options))
      end

      snapshots.uniq.size.should eq(1)
    end

    {% if flag?(:harfbuzz) %}
      it "matches the HarfBuzz shaping path when HarfBuzz is enabled" do
        font = TrueType::Font.open(FONT_PATH)
        text = "office AV"
        options = TrueType::ShapingOptions.new(
          direction: :ltr,
          script: "latn",
          language: "ENG",
          ligatures: true,
          kerning: true,
          contextual_alternates: true,
          features: ["liga", "kern", "calt"] of String
        )

        hb_features = [] of TrueType::HarfBuzz::Feature
        hb_features << TrueType::HarfBuzz::Features.liga(options.ligatures?)
        hb_features << TrueType::HarfBuzz::Features.kern(options.kerning?)
        hb_features << TrueType::HarfBuzz::Features.calt(options.contextual_alternates?)
        options.features.each { |feature| hb_features << TrueType::HarfBuzz::Feature.new(feature) }

        hb_options = TrueType::HarfBuzz::ShapingOptions.new(
          direction: TrueType::HarfBuzz::Direction::LTR,
          script: options.script,
          language: options.language,
          features: hb_features
        )

        best_effort = glyph_state(font.shape_best_effort(text, options))
        advanced = glyph_state(font.shape_advanced(text, hb_options))

        best_effort.should eq(advanced)
      end
    {% else %}
      it "matches fallback shaping when HarfBuzz is disabled" do
        font = TrueType::Font.open(FONT_PATH)
        text = "office AV"
        options = TrueType::ShapingOptions.new(
          direction: :ltr,
          script: "latn",
          language: "ENG",
          ligatures: true,
          kerning: true,
          contextual_alternates: true,
          features: ["liga", "kern", "calt"] of String
        )

        best_effort = glyph_state(font.shape_best_effort(text, options))
        fallback = glyph_state(font.shape(text, options))

        best_effort.should eq(fallback)
      end
    {% end %}
  end
end
