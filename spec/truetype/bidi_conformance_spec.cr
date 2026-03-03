require "../spec_helper"

# Full Unicode bidi conformance checks.
#
# To run:
#   TRUETYPE_RUN_BIDI_CONFORMANCE=1 TRUETYPE_BIDI_DATA_DIR=/path/to/unicode/15.1.0 crystal spec spec/truetype/bidi_conformance_spec.cr
#
# Expected files in TRUETYPE_BIDI_DATA_DIR:
# - BidiTest.txt
# - BidiCharacterTest.txt

module BidiConformanceHelpers
  def self.run_conformance? : Bool
    ENV["TRUETYPE_RUN_BIDI_CONFORMANCE"]? == "1"
  end

  def self.data_dir : String
    ENV["TRUETYPE_BIDI_DATA_DIR"]? || "spec/fixtures/unicode/15.1.0"
  end

  def self.bidi_test_path : String
    File.join(data_dir, "BidiTest.txt")
  end

  def self.bidi_character_test_path : String
    File.join(data_dir, "BidiCharacterTest.txt")
  end

  def self.removed_by_x9?(klass : TrueType::Bidi::CharClass) : Bool
    case klass
    when TrueType::Bidi::CharClass::RLE,
         TrueType::Bidi::CharClass::LRE,
         TrueType::Bidi::CharClass::RLO,
         TrueType::Bidi::CharClass::LRO,
         TrueType::Bidi::CharClass::PDF,
         TrueType::Bidi::CharClass::BN
      true
    else
      false
    end
  end

  def self.class_token_to_codepoint(token : String) : UInt32
    case token
    when "L"   then 0x0041_u32
    when "R"   then 0x05D0_u32
    when "AL"  then 0x0634_u32
    when "EN"  then 0x0031_u32
    when "ES"  then 0x002B_u32
    when "ET"  then 0x0024_u32
    when "AN"  then 0x0661_u32
    when "CS"  then 0x002C_u32
    when "NSM" then 0x0300_u32
    when "BN"  then 0x00AD_u32
    when "B"   then 0x000A_u32
    when "S"   then 0x0009_u32
    when "WS"  then 0x0020_u32
    when "ON"  then 0x0021_u32
    when "LRE" then 0x202A_u32
    when "RLE" then 0x202B_u32
    when "LRO" then 0x202D_u32
    when "RLO" then 0x202E_u32
    when "PDF" then 0x202C_u32
    when "LRI" then 0x2066_u32
    when "RLI" then 0x2067_u32
    when "FSI" then 0x2068_u32
    when "PDI" then 0x2069_u32
    else
      0x0041_u32
    end
  end

  def self.build_string(codepoints : Array(UInt32)) : String
    String.build do |io|
      codepoints.each { |cp| io << cp.unsafe_chr }
    end
  end
end

describe TrueType::Bidi, "Unicode conformance" do
  it "passes BidiCharacterTest.txt" do
    next unless BidiConformanceHelpers.run_conformance?
    next unless File.exists?(BidiConformanceHelpers.bidi_character_test_path)

    cases = 0
    level_failures = 0
    order_failures = 0

    File.each_line(BidiConformanceHelpers.bidi_character_test_path) do |line|
      data = line.split("#", 2)[0].strip
      next if data.empty?

      fields = data.split(";").map(&.strip)
      next unless fields.size >= 5

      codepoints = fields[0].split.map { |hex| hex.to_u32(16) }
      direction = case fields[1]
                  when "0"
                    TrueType::Bidi::ParagraphDirection::LeftToRight
                  when "1"
                    TrueType::Bidi::ParagraphDirection::RightToLeft
                  else
                    TrueType::Bidi::ParagraphDirection::Auto
                  end

      expected_levels = fields[3].split
      expected_order = fields[4].split.map(&.to_i)

      result = TrueType::Bidi.resolve(BidiConformanceHelpers.build_string(codepoints), direction)

      expected_levels.each_with_index do |level, index|
        next if level == "x"

        if result.levels[index]? != level.to_i
          level_failures += 1
          break
        end
      end

      filtered_order = result.visual_to_logical.reject do |logical_index|
        BidiConformanceHelpers.removed_by_x9?(result.original_classes[logical_index])
      end
      order_failures += 1 unless filtered_order == expected_order

      cases += 1
    end

    level_failures.should eq(0), "BidiCharacterTest level failures: #{level_failures} / #{cases}"
    order_failures.should eq(0), "BidiCharacterTest order failures: #{order_failures} / #{cases}"
  end

  it "passes BidiTest.txt" do
    next unless BidiConformanceHelpers.run_conformance?
    next unless File.exists?(BidiConformanceHelpers.bidi_test_path)

    cases = 0
    level_failures = 0
    order_failures = 0

    expected_levels = [] of String
    expected_reorder = [] of Int32

    File.each_line(BidiConformanceHelpers.bidi_test_path) do |raw|
      line = raw.strip
      next if line.empty? || line.starts_with?("#")

      if line.starts_with?("@Levels:")
        expected_levels = line.sub("@Levels:", "").strip.split
        next
      end

      if line.starts_with?("@Reorder:")
        data = line.sub("@Reorder:", "").strip
        expected_reorder = data.empty? ? [] of Int32 : data.split.map(&.to_i)
        next
      end

      next if line.starts_with?("@")

      fields = line.split(";")
      next unless fields.size >= 2

      tokens = fields[0].split
      bitset = fields[1].strip.to_i(16)
      text = BidiConformanceHelpers.build_string(tokens.map { |token| BidiConformanceHelpers.class_token_to_codepoint(token) })

      [
        {1, TrueType::Bidi::ParagraphDirection::Auto},
        {2, TrueType::Bidi::ParagraphDirection::LeftToRight},
        {4, TrueType::Bidi::ParagraphDirection::RightToLeft},
      ].each do |mask, direction|
        next if (bitset & mask) == 0

        result = TrueType::Bidi.resolve(text, direction)

        level_ok = true
        expected_levels.each_with_index do |level, index|
          next if level == "x"

          if result.levels[index]? != level.to_i
            level_ok = false
            break
          end
        end
        level_failures += 1 unless level_ok

        filtered_order = result.visual_to_logical.reject do |logical_index|
          BidiConformanceHelpers.removed_by_x9?(result.original_classes[logical_index])
        end
        order_failures += 1 unless filtered_order == expected_reorder

        cases += 1
      end
    end

    level_failures.should eq(0), "BidiTest level failures: #{level_failures} / #{cases}"
    order_failures.should eq(0), "BidiTest order failures: #{order_failures} / #{cases}"
  end
end
