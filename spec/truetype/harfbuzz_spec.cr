require "../spec_helper"

# HarfBuzz specs - comprehensive tests when compiled with -Dharfbuzz
{% if flag?(:harfbuzz) %}

describe TrueType::HarfBuzz do
  describe "availability" do
    it "reports HarfBuzz as available" do
      TrueType.harfbuzz_available?.should be_true
    end

    it "returns version string" do
      version = TrueType::HarfBuzz.version_string
      version.should_not be_empty
      version.should match(/^\d+\.\d+\.\d+/)
    end

    it "returns version tuple" do
      major, minor, micro = TrueType::HarfBuzz.version
      major.should be >= 0
    end

    it "checks version requirements" do
      TrueType::HarfBuzz.version_atleast?(2, 0, 0).should be_true
    end
  end

  describe "tag utilities" do
    it "creates tag from string" do
      tag = TrueType::HarfBuzz.tag("liga")
      tag.should be > 0
    end

    it "converts tag to string" do
      tag = TrueType::HarfBuzz.tag("kern")
      str = TrueType::HarfBuzz.tag_to_string(tag)
      str.should eq("kern")
    end

    it "round-trips tag conversion" do
      %w[liga kern smcp onum tnum frac salt calt].each do |tag_str|
        tag = TrueType::HarfBuzz.tag(tag_str)
        TrueType::HarfBuzz.tag_to_string(tag).should eq(tag_str)
      end
    end
  end

  describe TrueType::HarfBuzz::Feature do
    describe "initialization" do
      it "creates feature from tag string" do
        feature = TrueType::HarfBuzz::Feature.new("liga")
        feature.tag_string.should eq("liga")
        feature.value.should eq(1)
        feature.enabled?.should be_true
        feature.global?.should be_true
      end

      it "creates disabled feature" do
        feature = TrueType::HarfBuzz::Feature.new("kern", 0_u32)
        feature.tag_string.should eq("kern")
        feature.disabled?.should be_true
      end

      it "creates feature with specific value" do
        feature = TrueType::HarfBuzz::Feature.new("aalt", 3_u32)
        feature.value.should eq(3)
      end

      it "creates feature with range" do
        feature = TrueType::HarfBuzz::Feature.new("liga", 1_u32, 5_u32, 10_u32)
        feature.start.should eq(5)
        feature.end_pos.should eq(10)
        feature.global?.should be_false
      end
    end

    describe "parsing" do
      it "parses simple enable feature" do
        feature = TrueType::HarfBuzz::Feature.parse!("liga")
        feature.tag_string.should eq("liga")
        feature.enabled?.should be_true
      end

      it "parses explicit enable with +" do
        feature = TrueType::HarfBuzz::Feature.parse!("+kern")
        feature.tag_string.should eq("kern")
        feature.enabled?.should be_true
      end

      it "parses disable with -" do
        feature = TrueType::HarfBuzz::Feature.parse!("-calt")
        feature.tag_string.should eq("calt")
        feature.disabled?.should be_true
      end

      it "parses value assignment" do
        feature = TrueType::HarfBuzz::Feature.parse!("aalt=2")
        feature.tag_string.should eq("aalt")
        feature.value.should eq(2)
      end

      it "parses explicit disable with =0" do
        feature = TrueType::HarfBuzz::Feature.parse!("liga=0")
        feature.disabled?.should be_true
      end

      it "parses range syntax" do
        feature = TrueType::HarfBuzz::Feature.parse!("kern[3:5]")
        feature.tag_string.should eq("kern")
        feature.start.should eq(3)
        feature.end_pos.should eq(5)
      end

      it "returns nil for invalid feature" do
        TrueType::HarfBuzz::Feature.parse("").should be_nil
        # Note: HarfBuzz pads short strings with spaces, so "x" becomes "x   " which is valid
        # We only test empty string here
      end

      it "raises for invalid feature with parse!" do
        expect_raises(ArgumentError) do
          TrueType::HarfBuzz::Feature.parse!("")
        end
      end

      it "parses feature list" do
        features = TrueType::HarfBuzz::Feature.parse_list("liga,kern,-calt,smcp")
        features.size.should eq(4)
        features[0].tag_string.should eq("liga")
        features[1].tag_string.should eq("kern")
        features[2].disabled?.should be_true
        features[3].tag_string.should eq("smcp")
      end

      it "handles whitespace in feature list" do
        features = TrueType::HarfBuzz::Feature.parse_list("liga, kern, -calt")
        features.size.should eq(3)
      end
    end

    describe "to_s" do
      it "converts feature to string" do
        feature = TrueType::HarfBuzz::Feature.new("liga")
        feature.to_s.should contain("liga")
      end
    end
  end

  describe TrueType::HarfBuzz::Features do
    it "provides liga preset" do
      f = TrueType::HarfBuzz::Features.liga
      f.tag_string.should eq("liga")
      f.enabled?.should be_true
    end

    it "provides kern preset" do
      f = TrueType::HarfBuzz::Features.kern
      f.tag_string.should eq("kern")
    end

    it "provides smcp preset" do
      f = TrueType::HarfBuzz::Features.smcp
      f.tag_string.should eq("smcp")
    end

    it "provides numeric feature presets" do
      TrueType::HarfBuzz::Features.lnum.tag_string.should eq("lnum")
      TrueType::HarfBuzz::Features.onum.tag_string.should eq("onum")
      TrueType::HarfBuzz::Features.pnum.tag_string.should eq("pnum")
      TrueType::HarfBuzz::Features.tnum.tag_string.should eq("tnum")
    end

    it "provides frac preset" do
      TrueType::HarfBuzz::Features.frac.tag_string.should eq("frac")
    end

    it "provides stylistic alternates" do
      salt = TrueType::HarfBuzz::Features.salt(2)
      salt.tag_string.should eq("salt")
      salt.value.should eq(2)
    end

    it "provides stylistic sets" do
      (1..20).each do |n|
        ss = TrueType::HarfBuzz::Features.stylistic_set(n)
        ss.tag_string.should eq("ss#{n.to_s.rjust(2, '0')}")
      end
    end

    it "rejects invalid stylistic set numbers" do
      expect_raises(ArgumentError) do
        TrueType::HarfBuzz::Features.stylistic_set(0)
      end
      expect_raises(ArgumentError) do
        TrueType::HarfBuzz::Features.stylistic_set(21)
      end
    end

    it "provides default feature set" do
      defaults = TrueType::HarfBuzz::Features.defaults
      defaults.should_not be_empty
      tags = defaults.map(&.tag_string)
      tags.should contain("liga")
      tags.should contain("kern")
      tags.should contain("calt")
    end

    it "allows disabling presets" do
      TrueType::HarfBuzz::Features.liga(false).disabled?.should be_true
      TrueType::HarfBuzz::Features.kern(false).disabled?.should be_true
    end
  end

  describe TrueType::HarfBuzz::Direction do
    it "creates direction from string" do
      TrueType::HarfBuzz::Direction.from_string("ltr").should eq(TrueType::HarfBuzz::Direction::LTR)
      TrueType::HarfBuzz::Direction.from_string("rtl").should eq(TrueType::HarfBuzz::Direction::RTL)
      TrueType::HarfBuzz::Direction.from_string("ttb").should eq(TrueType::HarfBuzz::Direction::TTB)
      TrueType::HarfBuzz::Direction.from_string("btt").should eq(TrueType::HarfBuzz::Direction::BTT)
    end

    it "checks horizontal directions" do
      TrueType::HarfBuzz::Direction::LTR.horizontal?.should be_true
      TrueType::HarfBuzz::Direction::RTL.horizontal?.should be_true
      TrueType::HarfBuzz::Direction::TTB.horizontal?.should be_false
    end

    it "checks vertical directions" do
      TrueType::HarfBuzz::Direction::TTB.vertical?.should be_true
      TrueType::HarfBuzz::Direction::BTT.vertical?.should be_true
      TrueType::HarfBuzz::Direction::LTR.vertical?.should be_false
    end

    it "checks backward directions" do
      TrueType::HarfBuzz::Direction::RTL.backward?.should be_true
      TrueType::HarfBuzz::Direction::BTT.backward?.should be_true
      TrueType::HarfBuzz::Direction::LTR.backward?.should be_false
    end

    it "checks forward directions" do
      TrueType::HarfBuzz::Direction::LTR.forward?.should be_true
      TrueType::HarfBuzz::Direction::TTB.forward?.should be_true
      TrueType::HarfBuzz::Direction::RTL.forward?.should be_false
    end
  end

  describe TrueType::HarfBuzz::Blob do
    it "creates blob from bytes" do
      data = Bytes.new(100) { |i| i.to_u8 }
      blob = TrueType::HarfBuzz::Blob.new(data)
      blob.size.should eq(100)
      blob.empty?.should be_false
    end

    it "creates empty blob" do
      blob = TrueType::HarfBuzz::Blob.empty
      blob.empty?.should be_true
      blob.size.should eq(0)
    end

    it "creates blob from file" do
      blob = TrueType::HarfBuzz::Blob.from_file("spec/fixtures/fonts/DejaVuSans.ttf")
      blob.size.should be > 0
      blob.empty?.should be_false
    end

    it "raises for non-existent file" do
      expect_raises(IO::Error) do
        TrueType::HarfBuzz::Blob.from_file("/nonexistent/path/font.ttf")
      end
    end

    it "provides access to data" do
      original = Bytes.new(50) { |i| i.to_u8 }
      blob = TrueType::HarfBuzz::Blob.new(original)
      data = blob.data
      data.size.should eq(50)
    end

    it "can be made immutable" do
      blob = TrueType::HarfBuzz::Blob.new(Bytes.new(10))
      blob.immutable?.should be_false
      blob.make_immutable!
      blob.immutable?.should be_true
    end

    it "creates sub-blob" do
      data = Bytes.new(100) { |i| i.to_u8 }
      blob = TrueType::HarfBuzz::Blob.new(data)
      sub = blob.sub_blob(10_u32, 20_u32)
      sub.size.should eq(20)
    end
  end

  describe TrueType::HarfBuzz::Face do
    it "creates face from file" do
      face = TrueType::HarfBuzz::Face.from_file("spec/fixtures/fonts/DejaVuSans.ttf")
      face.units_per_em.should eq(2048)
      face.glyph_count.should be > 0
      face.index.should eq(0)
    end

    it "creates face from bytes" do
      data = File.read("spec/fixtures/fonts/DejaVuSans.ttf").to_slice
      face = TrueType::HarfBuzz::Face.new(data)
      face.units_per_em.should eq(2048)
    end

    it "creates face from blob" do
      blob = TrueType::HarfBuzz::Blob.from_file("spec/fixtures/fonts/DejaVuSans.ttf")
      face = TrueType::HarfBuzz::Face.new(blob)
      face.units_per_em.should eq(2048)
    end

    it "checks for tables" do
      face = TrueType::HarfBuzz::Face.from_file("spec/fixtures/fonts/DejaVuSans.ttf")
      face.has_table?("cmap").should be_true
      face.has_table?("head").should be_true
      face.has_table?("hhea").should be_true
      face.has_table?("XXXX").should be_false
    end

    it "retrieves table data" do
      face = TrueType::HarfBuzz::Face.from_file("spec/fixtures/fonts/DejaVuSans.ttf")
      cmap = face.table("cmap")
      cmap.empty?.should be_false
      cmap.size.should be > 0
    end

    it "returns empty blob for missing table" do
      face = TrueType::HarfBuzz::Face.from_file("spec/fixtures/fonts/DejaVuSans.ttf")
      missing = face.table("ZZZZ")
      missing.empty?.should be_true
    end

    it "can be made immutable" do
      face = TrueType::HarfBuzz::Face.from_file("spec/fixtures/fonts/DejaVuSans.ttf")
      face.immutable?.should be_false
      face.make_immutable!
      face.immutable?.should be_true
    end
  end

  describe TrueType::HarfBuzz::Font do
    it "creates font from face" do
      face = TrueType::HarfBuzz::Face.from_file("spec/fixtures/fonts/DejaVuSans.ttf")
      font = TrueType::HarfBuzz::Font.new(face)
      font.should_not be_nil
    end

    it "creates font from bytes" do
      data = File.read("spec/fixtures/fonts/DejaVuSans.ttf").to_slice
      font = TrueType::HarfBuzz::Font.new(data)
      font.should_not be_nil
    end

    it "creates font from file" do
      font = TrueType::HarfBuzz::Font.from_file("spec/fixtures/fonts/DejaVuSans.ttf")
      font.should_not be_nil
    end

    describe "glyph operations" do
      it "gets glyph for codepoint" do
        font = TrueType::HarfBuzz::Font.from_file("spec/fixtures/fonts/DejaVuSans.ttf")
        glyph = font.glyph('A'.ord.to_u32)
        glyph.should_not be_nil
        glyph.not_nil!.should be > 0
      end

      it "gets nominal glyph" do
        font = TrueType::HarfBuzz::Font.from_file("spec/fixtures/fonts/DejaVuSans.ttf")
        glyph = font.nominal_glyph('B'.ord.to_u32)
        glyph.should_not be_nil
      end

      it "gets horizontal advance" do
        font = TrueType::HarfBuzz::Font.from_file("spec/fixtures/fonts/DejaVuSans.ttf")
        glyph = font.glyph('M'.ord.to_u32).not_nil!
        advance = font.h_advance(glyph)
        advance.should be > 0
      end

      it "gets kerning between glyphs" do
        font = TrueType::HarfBuzz::Font.from_file("spec/fixtures/fonts/DejaVuSans.ttf")
        a_glyph = font.glyph('A'.ord.to_u32).not_nil!
        v_glyph = font.glyph('V'.ord.to_u32).not_nil!
        kern = font.h_kerning(a_glyph, v_glyph)
        kern.should be_a(Int32)
      end
    end

    describe "scale configuration" do
      it "sets and gets scale" do
        font = TrueType::HarfBuzz::Font.from_file("spec/fixtures/fonts/DejaVuSans.ttf")
        font.set_scale(1000, 2000)
        x, y = font.scale
        x.should eq(1000)
        y.should eq(2000)
      end

      it "sets uniform scale" do
        font = TrueType::HarfBuzz::Font.from_file("spec/fixtures/fonts/DejaVuSans.ttf")
        font.scale = 500
        x, y = font.scale
        x.should eq(500)
        y.should eq(500)
      end
    end

    describe "ppem configuration" do
      it "sets and gets ppem" do
        font = TrueType::HarfBuzz::Font.from_file("spec/fixtures/fonts/DejaVuSans.ttf")
        font.set_ppem(16, 16)
        x, y = font.ppem
        x.should eq(16)
        y.should eq(16)
      end
    end

    describe "ptem configuration" do
      it "sets and gets ptem" do
        font = TrueType::HarfBuzz::Font.from_file("spec/fixtures/fonts/DejaVuSans.ttf")
        font.ptem = 12.5_f32
        font.ptem.should be_close(12.5, 0.01)
      end
    end
  end

  describe TrueType::HarfBuzz::Buffer do
    it "creates empty buffer" do
      buffer = TrueType::HarfBuzz::Buffer.new
      buffer.empty?.should be_true
      buffer.length.should eq(0)
    end

    describe "adding text" do
      it "adds UTF-8 text" do
        buffer = TrueType::HarfBuzz::Buffer.new
        buffer.add_utf8("Hello")
        buffer.length.should eq(5)
        buffer.empty?.should be_false
      end

      it "adds UTF-8 text with Unicode" do
        buffer = TrueType::HarfBuzz::Buffer.new
        buffer.add_utf8("Héllo")
        buffer.length.should eq(5)
      end

      it "adds codepoints" do
        buffer = TrueType::HarfBuzz::Buffer.new
        codepoints = ['H'.ord.to_u32, 'i'.ord.to_u32]
        buffer.add_codepoints(codepoints)
        buffer.length.should eq(2)
      end

      it "adds single codepoint with cluster" do
        buffer = TrueType::HarfBuzz::Buffer.new
        buffer.add('A'.ord.to_u32, 0_u32)
        buffer.add('B'.ord.to_u32, 1_u32)
        buffer.length.should eq(2)
      end
    end

    describe "buffer properties" do
      it "sets and gets direction" do
        buffer = TrueType::HarfBuzz::Buffer.new
        buffer.direction = TrueType::HarfBuzz::Direction::RTL
        buffer.direction.should eq(TrueType::HarfBuzz::Direction::RTL)
      end

      it "sets and gets script" do
        buffer = TrueType::HarfBuzz::Buffer.new
        buffer.script = "Arab"
        buffer.script.should_not eq(0)
      end

      it "sets and gets language" do
        buffer = TrueType::HarfBuzz::Buffer.new
        buffer.language = "en"
        buffer.language.should_not be_nil
      end

      it "guesses segment properties for Latin text" do
        buffer = TrueType::HarfBuzz::Buffer.new
        buffer.add_utf8("Hello World")
        buffer.guess_segment_properties
        buffer.direction.should eq(TrueType::HarfBuzz::Direction::LTR)
      end
    end

    describe "buffer manipulation" do
      it "clears contents" do
        buffer = TrueType::HarfBuzz::Buffer.new
        buffer.add_utf8("Hello")
        buffer.clear!
        buffer.empty?.should be_true
      end

      it "resets buffer" do
        buffer = TrueType::HarfBuzz::Buffer.new
        buffer.add_utf8("Hello")
        buffer.direction = TrueType::HarfBuzz::Direction::RTL
        buffer.reset!
        buffer.empty?.should be_true
      end

      it "pre-allocates space" do
        buffer = TrueType::HarfBuzz::Buffer.new
        buffer.pre_allocate(1000_u32).should be_true
        buffer.allocation_successful?.should be_true
      end
    end

    describe "shaping" do
      it "shapes simple text" do
        buffer = TrueType::HarfBuzz::Buffer.new
        buffer.add_utf8("Hello")
        buffer.guess_segment_properties

        font = TrueType::HarfBuzz::Font.from_file("spec/fixtures/fonts/DejaVuSans.ttf")
        buffer.shape(font)

        buffer.length.should eq(5)
        glyphs = buffer.glyphs
        glyphs.size.should eq(5)
        glyphs.all? { |g| g.id > 0 }.should be_true
      end

      it "shapes with features" do
        buffer = TrueType::HarfBuzz::Buffer.new
        buffer.add_utf8("fi")
        buffer.guess_segment_properties

        font = TrueType::HarfBuzz::Font.from_file("spec/fixtures/fonts/DejaVuSans.ttf")
        features = [TrueType::HarfBuzz::Features.liga]
        buffer.shape(font, features)

        buffer.length.should be >= 1
      end

      it "returns glyph info" do
        buffer = TrueType::HarfBuzz::Buffer.new
        buffer.add_utf8("AB")
        buffer.guess_segment_properties

        font = TrueType::HarfBuzz::Font.from_file("spec/fixtures/fonts/DejaVuSans.ttf")
        buffer.shape(font)

        infos = buffer.glyph_infos
        infos.size.should eq(2)
        infos[0].cluster.should eq(0)
        infos[1].cluster.should eq(1)
      end

      it "returns glyph positions" do
        buffer = TrueType::HarfBuzz::Buffer.new
        buffer.add_utf8("AB")
        buffer.guess_segment_properties

        font = TrueType::HarfBuzz::Font.from_file("spec/fixtures/fonts/DejaVuSans.ttf")
        buffer.shape(font)

        positions = buffer.glyph_positions
        positions.size.should eq(2)
        positions.all? { |p| p.x_advance > 0 }.should be_true
      end

      it "returns combined glyphs" do
        buffer = TrueType::HarfBuzz::Buffer.new
        buffer.add_utf8("Test")
        buffer.guess_segment_properties

        font = TrueType::HarfBuzz::Font.from_file("spec/fixtures/fonts/DejaVuSans.ttf")
        buffer.shape(font)

        glyphs = buffer.glyphs
        glyphs.size.should eq(4)

        glyphs.each_with_index do |g, i|
          g.id.should be > 0
          g.cluster.should eq(i)
          g.x_advance.should be > 0
        end
      end
    end
  end

  describe TrueType::HarfBuzz::ShapingOptions do
    it "creates default options" do
      options = TrueType::HarfBuzz::ShapingOptions.new
      options.features.should_not be_empty
    end

    it "creates kerning-only options" do
      options = TrueType::HarfBuzz::ShapingOptions.kerning_only
      options.features.size.should eq(1)
      options.features.first.tag_string.should eq("kern")
    end

    it "creates Latin preset" do
      options = TrueType::HarfBuzz::ShapingOptions.latin
      options.direction.should eq(TrueType::HarfBuzz::Direction::LTR)
      options.script.should eq("Latn")
    end

    it "creates Arabic preset" do
      options = TrueType::HarfBuzz::ShapingOptions.arabic
      options.direction.should eq(TrueType::HarfBuzz::Direction::RTL)
      options.script.should eq("Arab")
    end

    it "creates Hebrew preset" do
      options = TrueType::HarfBuzz::ShapingOptions.hebrew
      options.direction.should eq(TrueType::HarfBuzz::Direction::RTL)
      options.script.should eq("Hebr")
    end

    it "creates CJK preset" do
      options = TrueType::HarfBuzz::ShapingOptions.cjk
      options.direction.should eq(TrueType::HarfBuzz::Direction::LTR)
      options.script.should eq("Hani")
    end

    it "creates vertical CJK preset" do
      options = TrueType::HarfBuzz::ShapingOptions.cjk_vertical
      options.direction.should eq(TrueType::HarfBuzz::Direction::TTB)
    end
  end

  describe TrueType::HarfBuzz::Shaper do
    it "shapes text with TrueType::Font" do
      font = TrueType::Font.open("spec/fixtures/fonts/DejaVuSans.ttf")
      result = TrueType::HarfBuzz::Shaper.shape(font, "Hello")

      result.glyphs.size.should eq(5)
      result.width.should be > 0
      result.direction.should eq(TrueType::HarfBuzz::Direction::LTR)
    end

    it "shapes with options" do
      font = TrueType::Font.open("spec/fixtures/fonts/DejaVuSans.ttf")
      options = TrueType::HarfBuzz::ShapingOptions.latin
      result = TrueType::HarfBuzz::Shaper.shape(font, "Hello", options)

      result.glyphs.size.should eq(5)
      result.direction.should eq(TrueType::HarfBuzz::Direction::LTR)
    end

    it "calculates total width correctly" do
      font = TrueType::Font.open("spec/fixtures/fonts/DejaVuSans.ttf")
      result = TrueType::HarfBuzz::Shaper.shape(font, "MMMM")

      total = result.glyphs.sum(&.x_advance)
      result.width.should eq(total)
    end

    it "returns positioned glyphs" do
      font = TrueType::Font.open("spec/fixtures/fonts/DejaVuSans.ttf")
      result = TrueType::HarfBuzz::Shaper.shape(font, "Test")

      positioned = result.positioned_glyphs
      positioned.size.should eq(4)

      positioned[0].x.should eq(0)
      positioned[0].y.should eq(0)
    end

    it "shapes with pre-created HarfBuzz font" do
      font = TrueType::Font.open("spec/fixtures/fonts/DejaVuSans.ttf")
      hb_font = TrueType::HarfBuzz::Font.new(font.data)

      result1 = TrueType::HarfBuzz::Shaper.shape_with_font(hb_font, "First")
      result2 = TrueType::HarfBuzz::Shaper.shape_with_font(hb_font, "Second")

      result1.glyphs.size.should eq(5)
      result2.glyphs.size.should eq(6)
    end
  end

  describe "TrueType::Font HarfBuzz integration" do
    describe "#shape_advanced" do
      it "shapes text using HarfBuzz" do
        font = TrueType::Font.open("spec/fixtures/fonts/DejaVuSans.ttf")
        glyphs = font.shape_advanced("Hello")

        glyphs.size.should eq(5)
        glyphs.all? { |g| g.id > 0 }.should be_true
      end

      it "shapes with custom options" do
        font = TrueType::Font.open("spec/fixtures/fonts/DejaVuSans.ttf")
        options = TrueType::HarfBuzz::ShapingOptions.new(
          features: [TrueType::HarfBuzz::Features.kern]
        )
        glyphs = font.shape_advanced("AV", options)

        glyphs.size.should eq(2)
      end

      it "returns PositionedGlyph structs" do
        font = TrueType::Font.open("spec/fixtures/fonts/DejaVuSans.ttf")
        glyphs = font.shape_advanced("Hi")

        glyphs.each do |g|
          g.should be_a(TrueType::PositionedGlyph)
          g.id.should be_a(UInt16)
          g.cluster.should be_a(Int32)
          g.x_advance.should be_a(Int32)
        end
      end
    end

    describe "#render_advanced" do
      it "returns positioned glyphs with absolute coordinates" do
        font = TrueType::Font.open("spec/fixtures/fonts/DejaVuSans.ttf")
        glyphs = font.render_advanced("Hello")

        glyphs.size.should eq(5)
        glyphs[0].x_offset.should eq(0)

        prev_x = -1
        glyphs.each do |g|
          g.x_offset.should be > prev_x
          prev_x = g.x_offset
        end
      end

      it "accumulates advances correctly" do
        font = TrueType::Font.open("spec/fixtures/fonts/DejaVuSans.ttf")
        glyphs = font.render_advanced("MM")

        glyphs[1].x_offset.should eq(glyphs[0].x_advance)
      end
    end

    describe "#shape_harfbuzz" do
      it "returns full ShapingResult" do
        font = TrueType::Font.open("spec/fixtures/fonts/DejaVuSans.ttf")
        result = font.shape_harfbuzz("Test")

        result.should be_a(TrueType::HarfBuzz::ShapingResult)
        result.glyphs.size.should eq(4)
        result.width.should be > 0
      end
    end

    describe "#harfbuzz_font" do
      it "creates reusable HarfBuzz font" do
        font = TrueType::Font.open("spec/fixtures/fonts/DejaVuSans.ttf")
        hb_font = font.harfbuzz_font

        hb_font.should be_a(TrueType::HarfBuzz::Font)

        result1 = TrueType::HarfBuzz::Shaper.shape_with_font(hb_font, "First")
        result2 = TrueType::HarfBuzz::Shaper.shape_with_font(hb_font, "Second")

        result1.glyphs.should_not be_empty
        result2.glyphs.should_not be_empty
      end
    end

    describe "#shape_best_effort" do
      it "uses HarfBuzz when available" do
        font = TrueType::Font.open("spec/fixtures/fonts/DejaVuSans.ttf")
        glyphs = font.shape_best_effort("Hello")

        glyphs.size.should eq(5)
        glyphs.all? { |g| g.id > 0 }.should be_true
      end

      it "converts ShapingOptions to HarfBuzz options" do
        font = TrueType::Font.open("spec/fixtures/fonts/DejaVuSans.ttf")
        options = TrueType::ShapingOptions.new(
          ligatures: true,
          kerning: true,
          contextual_alternates: false
        )
        glyphs = font.shape_best_effort("fi", options)

        glyphs.should_not be_empty
      end

      it "handles RTL direction" do
        font = TrueType::Font.open("spec/fixtures/fonts/DejaVuSans.ttf")
        options = TrueType::ShapingOptions.new(direction: :rtl)
        glyphs = font.shape_best_effort("Hello", options)

        glyphs.should_not be_empty
      end
    end
  end

  describe "edge cases" do
    it "handles empty string" do
      font = TrueType::Font.open("spec/fixtures/fonts/DejaVuSans.ttf")
      glyphs = font.shape_advanced("")
      glyphs.should be_empty
    end

    it "handles single character" do
      font = TrueType::Font.open("spec/fixtures/fonts/DejaVuSans.ttf")
      glyphs = font.shape_advanced("X")
      glyphs.size.should eq(1)
    end

    it "handles long text" do
      font = TrueType::Font.open("spec/fixtures/fonts/DejaVuSans.ttf")
      text = "A" * 1000
      glyphs = font.shape_advanced(text)
      glyphs.size.should eq(1000)
    end

    it "handles whitespace" do
      font = TrueType::Font.open("spec/fixtures/fonts/DejaVuSans.ttf")
      glyphs = font.shape_advanced("A B C")
      glyphs.size.should eq(5)
    end

    it "handles newlines" do
      font = TrueType::Font.open("spec/fixtures/fonts/DejaVuSans.ttf")
      glyphs = font.shape_advanced("A\nB")
      glyphs.size.should eq(3)
    end

    it "handles mixed scripts" do
      font = TrueType::Font.open("spec/fixtures/fonts/DejaVuSans.ttf")
      glyphs = font.shape_advanced("ABC123")
      glyphs.size.should eq(6)
    end
  end
end

{% else %}

# When HarfBuzz is not available, these minimal tests run
describe TrueType do
  describe "HarfBuzz availability" do
    it "reports HarfBuzz as not available" do
      TrueType.harfbuzz_available?.should be_false
    end
  end

  describe "Font#shape_best_effort" do
    it "falls back to basic shaping" do
      font = TrueType::Font.open("spec/fixtures/fonts/DejaVuSans.ttf")
      glyphs = font.shape_best_effort("Hello")

      glyphs.size.should eq(5)
      glyphs.all? { |g| g.id > 0 }.should be_true
    end

    it "respects shaping options" do
      font = TrueType::Font.open("spec/fixtures/fonts/DejaVuSans.ttf")
      options = TrueType::ShapingOptions.new(kerning: true)
      glyphs = font.shape_best_effort("AV", options)

      glyphs.size.should eq(2)
    end
  end
end

{% end %}
