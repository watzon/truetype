require "../spec_helper"
require "../support/malformed_font_helpers"

describe TrueType::Font do
  describe "fallback shaper parity" do
    it "implements ligature substitution in the default shaping path" do
      font = TrueType::Font.open(FONT_PATH)
      with_liga = font.shape("ffi", TrueType::ShapingOptions.new(script: "latn", features: ["liga"] of String))
      without_liga = font.shape("ffi", TrueType::ShapingOptions.new(script: "latn", ligatures: false, features: ["-liga"] of String))

      with_liga.map(&.id).should_not eq(without_liga.map(&.id))
      with_liga.size.should be < without_liga.size
    end

    it "honors ShapingOptions#features overrides" do
      font = TrueType::Font.open(FONT_PATH)

      forced_liga = font.shape("ffi", TrueType::ShapingOptions.new(script: "latn", ligatures: false, features: ["liga"] of String))
      disabled_liga = font.shape("ffi", TrueType::ShapingOptions.new(script: "latn", ligatures: true, features: ["-liga"] of String))
      no_liga = font.shape("ffi", TrueType::ShapingOptions.new(script: "latn", ligatures: false, features: ["-liga"] of String))

      forced_liga.size.should be < no_liga.size
      disabled_liga.map(&.id).should eq(no_liga.map(&.id))
    end

    it "honors script selection in the default shaping path" do
      font = TrueType::Font.open(FONT_PATH)
      text = "سلام"

      arab = font.shape(text, TrueType::ShapingOptions.new(script: "arab", features: ["init", "medi", "fina", "rlig"] of String))
      latn = font.shape(text, TrueType::ShapingOptions.new(script: "latn", features: ["init", "medi", "fina", "rlig"] of String))

      arab.map(&.id).should_not eq(latn.map(&.id))
    end

    it "honors language selection in the default shaping path" do
      font = TrueType::Font.open(FONT_PATH)
      text = "ٍّ"

      kur = font.shape(text, TrueType::ShapingOptions.new(script: "arab", language: "KUR", features: ["init", "medi", "fina", "rlig", "mark", "mkmk"] of String))
      urd = font.shape(text, TrueType::ShapingOptions.new(script: "arab", language: "URD", features: ["init", "medi", "fina", "rlig", "mark", "mkmk"] of String))

      kur.map(&.id).should_not eq(urd.map(&.id))
    end

    it "applies GSUB/GPOS lookup chains in the fallback path" do
      font = TrueType::Font.open(FONT_PATH)
      text = "سَلَام"

      shaped = font.shape(text)
      unmapped = text.chars.map { |char| font.glyph_id(char) }

      shaped.map(&.id).should_not eq(unmapped)
      shaped.any? { |glyph| glyph.x_offset != 0 || glyph.y_offset != 0 }.should be_true
    end

    it "applies Latin shaping behavior and stays resilient if legacy kern is malformed" do
      pristine_font = TrueType::Font.open(FONT_PATH)

      with_kern = pristine_font.shape("AV", TrueType::ShapingOptions.new(script: "latn", kerning: true, features: ["kern"] of String))
      without_kern = pristine_font.shape("AV", TrueType::ShapingOptions.new(script: "latn", kerning: false, features: ["-kern"] of String))
      with_kern.map { |g| {g.id, g.cluster, g.x_offset, g.y_offset, g.x_advance, g.y_advance} }
        .should_not eq(without_kern.map { |g| {g.id, g.cluster, g.x_offset, g.y_offset, g.x_advance, g.y_advance} })

      raw = File.read(FONT_PATH).to_slice
      broken = MalformedFontHelpers.mutate_table_length(raw, "kern", 2_u32)
      broken.should_not be_nil

      font = TrueType::Font.open(broken.not_nil!)

      with_liga = font.shape("office", TrueType::ShapingOptions.new(script: "latn", features: ["liga"] of String))
      without_liga = font.shape("office", TrueType::ShapingOptions.new(script: "latn", ligatures: false, features: ["-liga"] of String))
      with_liga.size.should be < without_liga.size

      font.shape("AV", TrueType::ShapingOptions.new(script: "latn", kerning: true, features: ["kern"] of String)).size.should eq(2)
    end

    it "keeps shaping deterministic across fonts with and without optional layout tables" do
      fonts = {
        :full_layout    => TrueType::Font.open(FONT_PATH),
        :no_gpos        => TrueType::Font.open(COLOR_FONT_PATH),
        :malformed_gpos => TrueType::Font.open(VARIABLE_FONT_PATH),
      }

      text = "office"

      fonts.each_value do |font|
        first = font.shape(text).map { |g| {g.id, g.cluster, g.x_offset, g.y_offset, g.x_advance, g.y_advance} }
        second = font.shape(text).map { |g| {g.id, g.cluster, g.x_offset, g.y_offset, g.x_advance, g.y_advance} }
        first.should eq(second)
      end
    end

    it "has stable fallback behavior for Arabic, Hebrew, Indic, and Thai samples" do
      font = TrueType::Font.open(FONT_PATH)
      samples = {
        :arabic => "سلام",
        :hebrew => "שלום",
        :indic  => "नमस्ते",
        :thai   => "ภาษาไทย",
      }

      samples.each_value do |text|
        first = font.shape(text).map { |g| {g.id, g.cluster, g.x_offset, g.y_offset, g.x_advance, g.y_advance} }
        second = font.shape(text).map { |g| {g.id, g.cluster, g.x_offset, g.y_offset, g.x_advance, g.y_advance} }
        first.should eq(second)
      end
    end
  end
end
