require "../spec_helper"

describe TrueType::Font do
  describe ".open" do
    it "opens a TTF font file" do
      font = TrueType::Font.open(FONT_PATH)
      font.should be_a(TrueType::Font)
      font.format.should eq(:ttf)
    end

    it "opens an OTF font file" do
      font = TrueType::Font.open(OTF_FONT_PATH)
      font.should be_a(TrueType::Font)
      font.cff?.should be_true
    end

    it "opens a WOFF2 font file" do
      # Check if WOFF2 test file exists
      woff2_path = "spec/fixtures/fonts/DejaVuSans.woff2"
      if File.exists?(woff2_path)
        font = TrueType::Font.open(woff2_path)
        font.should be_a(TrueType::Font)
        font.format.should eq(:woff2)
      end
    end

    it "opens from bytes with auto-detection" do
      data = File.read(FONT_PATH).to_slice
      font = TrueType::Font.open(data)
      font.should be_a(TrueType::Font)
    end

    it "raises for invalid font data" do
      expect_raises(TrueType::ParseError) do
        TrueType::Font.open("invalid data".to_slice)
      end
    end
  end

  describe ".detect_format" do
    it "detects TTF format" do
      data = File.read(FONT_PATH).to_slice
      TrueType::Font.detect_format(data).should eq(:ttf)
    end

    it "detects OTF/CFF format" do
      data = File.read(OTF_FONT_PATH).to_slice
      TrueType::Font.detect_format(data).should eq(:otf)
    end

    it "detects WOFF2 format" do
      woff2_path = "spec/fixtures/fonts/DejaVuSans.woff2"
      if File.exists?(woff2_path)
        data = File.read(woff2_path).to_slice
        TrueType::Font.detect_format(data).should eq(:woff2)
      end
    end

    it "returns unknown for invalid data" do
      TrueType::Font.detect_format("invalid".to_slice).should eq(:unknown)
    end
  end

  describe "font information" do
    it "returns family name" do
      font = TrueType::Font.open(FONT_PATH)
      font.name.should contain("DejaVu")
      font.family_name.should eq(font.name)
    end

    it "returns PostScript name" do
      font = TrueType::Font.open(FONT_PATH)
      font.postscript_name.should contain("DejaVu")
    end

    it "returns style" do
      font = TrueType::Font.open(FONT_PATH)
      font.style.should_not be_empty
    end

    it "returns full name" do
      font = TrueType::Font.open(FONT_PATH)
      font.full_name.should_not be_empty
    end
  end

  describe "font properties" do
    it "returns units per em" do
      font = TrueType::Font.open(FONT_PATH)
      font.units_per_em.should be > 0
    end

    it "returns ascender and descender" do
      font = TrueType::Font.open(FONT_PATH)
      font.ascender.should be > 0
      font.descender.should be < 0
    end

    it "returns cap height" do
      font = TrueType::Font.open(FONT_PATH)
      font.cap_height.should be > 0
    end

    it "returns glyph count" do
      font = TrueType::Font.open(FONT_PATH)
      font.glyph_count.should be > 0
    end

    it "returns bounding box" do
      font = TrueType::Font.open(FONT_PATH)
      bbox = font.bounding_box
      bbox[2].should be > bbox[0] # x_max > x_min
      bbox[3].should be > bbox[1] # y_max > y_min
    end
  end

  describe "font type checks" do
    it "detects TrueType fonts" do
      font = TrueType::Font.open(FONT_PATH)
      font.truetype?.should be_true
      font.cff?.should be_false
    end

    it "detects CFF fonts" do
      font = TrueType::Font.open(OTF_FONT_PATH)
      font.cff?.should be_true
      font.truetype?.should be_false
    end

    it "detects variable fonts" do
      font = TrueType::Font.open(VARIABLE_FONT_PATH)
      font.variable?.should be_true
    end

    it "detects color fonts" do
      font = TrueType::Font.open(COLOR_FONT_PATH)
      font.color?.should be_true
    end
  end

  describe "glyph access" do
    it "returns glyph ID for characters" do
      font = TrueType::Font.open(FONT_PATH)
      glyph_a = font.glyph_id('A')
      glyph_a.should be > 0
    end

    it "returns advance width for glyphs" do
      font = TrueType::Font.open(FONT_PATH)
      width = font.advance_width(font.glyph_id('A'))
      width.should be > 0
    end

    it "returns char width" do
      font = TrueType::Font.open(FONT_PATH)
      width_a = font.char_width('A')
      width_i = font.char_width('i')
      width_a.should be > width_i
    end

    it "returns glyph outline" do
      font = TrueType::Font.open(FONT_PATH)
      outline = font.glyph_outline(font.glyph_id('A'))
      outline.should_not be_nil
      outline.contours.should_not be_empty
    end

    it "returns kerning between glyphs" do
      font = TrueType::Font.open(FONT_PATH)
      # Kerning may or may not exist for a given pair
      kern = font.kerning('A', 'V')
      kern.should be_a(Int16)
    end
  end

  describe "#shape" do
    it "shapes text into positioned glyphs" do
      font = TrueType::Font.open(FONT_PATH)
      glyphs = font.shape("Hello")
      glyphs.size.should eq(5)

      glyphs.each do |g|
        g.id.should be > 0
        g.x_advance.should be > 0
      end
    end

    it "applies kerning to shaped glyphs" do
      font = TrueType::Font.open(FONT_PATH)
      glyphs = font.shape("AV")
      # First glyph has no kerning offset, subsequent may have
      glyphs[0].x_offset.should eq(0)
    end

    it "returns empty array for empty text" do
      font = TrueType::Font.open(FONT_PATH)
      font.shape("").should be_empty
    end

    it "respects shaping options" do
      font = TrueType::Font.open(FONT_PATH)
      options = TrueType::ShapingOptions.new(kerning: false)
      glyphs = font.shape("AV", options)
      # Without kerning, all offsets should be 0
      glyphs.all? { |g| g.x_offset == 0 }.should be_true
    end
  end

  describe "#render" do
    it "renders text with cumulative positions" do
      font = TrueType::Font.open(FONT_PATH)
      glyphs = font.render("Hi")

      glyphs.size.should eq(2)
      glyphs[0].x_offset.should eq(0)  # First glyph at origin
      glyphs[1].x_offset.should be > 0 # Second glyph after first
    end
  end

  describe "#text_width" do
    it "calculates text width" do
      font = TrueType::Font.open(FONT_PATH)
      width = font.text_width("Hello")
      width.should be > 0
    end

    it "returns 0 for empty text" do
      font = TrueType::Font.open(FONT_PATH)
      font.text_width("").should eq(0)
    end
  end

  describe "variable fonts" do
    it "returns variation axes" do
      font = TrueType::Font.open(VARIABLE_FONT_PATH)
      axes = font.variation_axes
      axes.should_not be_empty
    end

    it "returns named instances" do
      font = TrueType::Font.open(VARIABLE_FONT_PATH)
      instances = font.named_instances
      instances.should_not be_empty
    end

    it "creates instance with axis values" do
      font = TrueType::Font.open(VARIABLE_FONT_PATH)
      instance = font.instance(wght: 700)
      instance.should be_a(TrueType::VariationInstance)
    end

    it "creates instance from hash" do
      font = TrueType::Font.open(VARIABLE_FONT_PATH)
      instance = font.instance({"wght" => 700.0})
      instance.should be_a(TrueType::VariationInstance)
    end

    it "creates instance from named instance index" do
      font = TrueType::Font.open(VARIABLE_FONT_PATH)
      instance = font.instance(0)
      instance.should be_a(TrueType::VariationInstance)
    end
  end

  describe "#subset" do
    it "creates a subset from text" do
      font = TrueType::Font.open(FONT_PATH)
      subset = font.subset("Hello")
      subset.should be_a(Bytes)
      subset.size.should be > 0
      subset.size.should be < font.data.size
    end

    it "creates a subset from character set" do
      font = TrueType::Font.open(FONT_PATH)
      chars = Set{'H', 'e', 'l', 'o'}
      subset = font.subset(chars)
      subset.should be_a(Bytes)
    end

    it "subset can be parsed as a valid font" do
      font = TrueType::Font.open(FONT_PATH)
      subset = font.subset("Hello World!")

      # The subset should be parseable
      subset_font = TrueType::Font.open(subset)
      subset_font.glyph_count.should be < font.glyph_count
    end

    it "applies include_notdef option" do
      font = TrueType::Font.open(FONT_PATH)

      with_notdef = font.subset("A", TrueType::SubsetOptions.new(include_notdef: true))
      without_notdef = font.subset("A", TrueType::SubsetOptions.new(include_notdef: false))

      with_font = TrueType::Font.open(with_notdef)
      without_font = TrueType::Font.open(without_notdef)

      with_font.glyph_count.should be > without_font.glyph_count
    end

    it "applies preserve_hints option for hinting tables" do
      font = TrueType::Font.open(FONT_PATH)
      next unless font.parser.has_table?("fpgm")

      with_hints = font.subset("Hello", TrueType::SubsetOptions.new(preserve_hints: true))
      without_hints = font.subset("Hello", TrueType::SubsetOptions.new(preserve_hints: false))

      with_parser = TrueType::Parser.parse(with_hints)
      without_parser = TrueType::Parser.parse(without_hints)

      with_parser.has_table?("fpgm").should be_true
      without_parser.has_table?("fpgm").should be_false
    end

    it "applies preserve_layout and preserve_kerning options" do
      font = TrueType::Font.open(FONT_PATH)

      with_layout = font.subset("Hello", TrueType::SubsetOptions.new(preserve_layout: true, preserve_kerning: true))
      without_layout = font.subset("Hello", TrueType::SubsetOptions.new(preserve_layout: false, preserve_kerning: false))

      with_parser = TrueType::Parser.parse(with_layout)
      without_parser = TrueType::Parser.parse(without_layout)

      if font.parser.has_table?("GSUB")
        with_parser.has_table?("GSUB").should be_true
        without_parser.has_table?("GSUB").should be_false
      end

      if font.parser.has_table?("kern")
        with_parser.has_table?("kern").should be_true
        without_parser.has_table?("kern").should be_false
      end
    end

    it "applies subset_names option" do
      font = TrueType::Font.open(FONT_PATH)

      compact = font.subset("Hello", TrueType::SubsetOptions.new(subset_names: true))
      full = font.subset("Hello", TrueType::SubsetOptions.new(subset_names: false))

      compact_name_records = TrueType::Parser.parse(compact).name.records.size
      full_name_records = TrueType::Parser.parse(full).name.records.size

      compact_name_records.should be <= full_name_records
    end

    it "can emit WOFF subset output" do
      font = TrueType::Font.open(FONT_PATH)
      subset = font.subset("Hello", TrueType::SubsetOptions.new(output_format: :woff))

      TrueType::Font.detect_format(subset).should eq(:woff)
      TrueType::Font.open(subset).glyph_count.should be > 0
    end

    it "can emit WOFF2 subset output" do
      font = TrueType::Font.open(FONT_PATH)
      subset = font.subset("Hello", TrueType::SubsetOptions.new(output_format: :woff2))

      TrueType::Font.detect_format(subset).should eq(:woff2)
      TrueType::Font.open(subset).glyph_count.should be > 0
    end

    it "rejects impossible sfnt flavor conversions" do
      font = TrueType::Font.open(FONT_PATH)

      expect_raises(TrueType::SubsetError) do
        font.subset("Hello", TrueType::SubsetOptions.new(output_format: :otf))
      end
    end
  end

  describe "#validate" do
    it "validates a valid font" do
      font = TrueType::Font.open(FONT_PATH)
      result = font.validate
      result.valid?.should be_true
    end

    it "returns validation result" do
      font = TrueType::Font.open(FONT_PATH)
      result = font.validate
      result.should be_a(TrueType::ValidationResult)
      result.summary.should contain("valid")
    end

    it "recovers from malformed optional OpenType layout tables" do
      raw = File.read(FONT_PATH).to_slice
      parser = TrueType::Parser.parse(raw)
      next unless parser.has_table?("GPOS")

      broken = Bytes.new(raw.size)
      broken.copy_from(raw)

      io = IO::Memory.new(broken)
      io.skip(4) # sfnt version
      num_tables = io.read_bytes(UInt16, IO::ByteFormat::BigEndian)
      io.skip(6) # search params

      num_tables.times do
        tag = String.new(Bytes.new(4).tap { |b| io.read_fully(b) })
        io.skip(8) # checksum + offset

        if tag == "GPOS"
          # Make the optional table intentionally too short.
          io.write_bytes(2_u32, IO::ByteFormat::BigEndian)
          break
        else
          io.skip(4) # length
        end
      end

      font = TrueType::Font.open(broken)
      result = font.validate

      result.valid?.should be_true
      result.warnings.any? { |w| w.table == "GPOS" && w.severity == :error }.should be_true
      font.shape("AV").size.should be > 0
    end
  end

  describe "#valid?" do
    it "returns true for valid fonts" do
      font = TrueType::Font.open(FONT_PATH)
      font.valid?.should be_true
    end
  end
end
