require "../spec_helper"
require "../support/malformed_font_helpers"

private def exercise_default_api_paths(font : TrueType::Font, sample : String) : Nil
  font.shape(sample)
  font.render(sample)
  font.measure_width(sample)
  font.layout(
    "#{sample} #{sample}",
    TrueType::LayoutOptions.new(
      max_width: font.units_per_em.to_i32 * 2,
      line_height: 1.2,
      align: TrueType::TextAlign::Justify,
      hyphen_char: '-'
    )
  )
  font.validate
  {% unless flag?(:harfbuzz) %}
    font.shape_best_effort(sample)
  {% end %}
end

describe TrueType::Font do
  describe "malformed optional-table resilience" do
    fixture_paths = [FONT_PATH, VARIABLE_FONT_PATH, COLOR_FONT_PATH] of String
    sample_text = "office AV fi"

    it "handles corpus mutations across default API paths without crashing" do
      failures = [] of String

      fixture_paths.each do |path|
        raw = File.read(path).to_slice
        mutations = MalformedFontHelpers.corpus_mutations(raw)

        mutations.each do |label, mutated|
          begin
            font = TrueType::Font.open(mutated)
            exercise_default_api_paths(font, sample_text)
          rescue ex
            failures << "#{File.basename(path)} [#{label}] => #{ex.class}: #{ex.message}"
          end
        end
      end

      fail failures.join("\n") unless failures.empty?
    end

    it "handles deterministic fuzz mutations for optional tables without crashers" do
      failures = [] of String

      fixture_paths.each do |path|
        raw = File.read(path).to_slice
        seed = path.each_char.reduce(0_u64) { |acc, char| (acc &* 131_u64) &+ char.ord.to_u64 }
        mutations = MalformedFontHelpers.fuzz_mutations(raw, 32, seed)

        mutations.each do |label, mutated|
          begin
            font = TrueType::Font.open(mutated)
            exercise_default_api_paths(font, sample_text)
          rescue ex
            failures << "#{File.basename(path)} [#{label}] => #{ex.class}: #{ex.message}"
          end
        end
      end

      fail failures.join("\n") unless failures.empty?
    end
  end
end
