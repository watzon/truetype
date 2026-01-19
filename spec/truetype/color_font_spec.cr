require "../spec_helper"

describe "Color Fonts" do
  describe TrueType::Parser do
    describe "#color_font?" do
      it "returns true for NotoColorEmoji" do
        parser = TrueType::Parser.parse(COLOR_FONT_PATH)
        parser.color_font?.should be_true
      end

      it "returns false for non-color fonts" do
        parser = TrueType::Parser.parse(FONT_PATH)
        parser.color_font?.should be_false
      end
    end

    describe "#cpal" do
      it "parses CPAL table from NotoColorEmoji" do
        parser = TrueType::Parser.parse(COLOR_FONT_PATH)
        cpal = parser.cpal
        cpal.should_not be_nil

        cpal = cpal.not_nil!
        cpal.version.should eq(0)
        cpal.num_palettes.should eq(1)
        cpal.num_palette_entries.should be > 0
      end

      it "returns colors from the palette" do
        parser = TrueType::Parser.parse(COLOR_FONT_PATH)
        cpal = parser.cpal.not_nil!

        # First color should be black
        color = cpal.color(0, 0)
        color.should_not be_nil
        color = color.not_nil!
        color.red.should eq(0)
        color.green.should eq(0)
        color.blue.should eq(0)
        color.alpha.should eq(255)
      end

      it "returns nil for non-color fonts" do
        parser = TrueType::Parser.parse(FONT_PATH)
        parser.cpal.should be_nil
      end
    end

    describe "#colr" do
      it "parses COLR table from NotoColorEmoji" do
        parser = TrueType::Parser.parse(COLOR_FONT_PATH)
        colr = parser.colr
        colr.should_not be_nil

        colr = colr.not_nil!
        colr.version.should eq(1) # NotoColorEmoji uses COLR v1
        colr.v1?.should be_true
      end

      it "returns nil for non-color fonts" do
        parser = TrueType::Parser.parse(FONT_PATH)
        parser.colr.should be_nil
      end
    end

    describe "#svg" do
      it "parses SVG table from NotoColorEmoji" do
        parser = TrueType::Parser.parse(COLOR_FONT_PATH)
        svg = parser.svg
        svg.should_not be_nil

        svg = svg.not_nil!
        svg.version.should eq(0)
        svg.document_count.should be > 0
      end

      it "extracts SVG documents" do
        parser = TrueType::Parser.parse(COLOR_FONT_PATH)
        svg = parser.svg.not_nil!

        # Find a glyph with SVG data
        records = svg.document_records
        records.size.should be > 0

        first_record = records.first
        first_glyph = first_record.start_glyph_id

        # Get the SVG document
        doc = svg.svg_document(first_glyph)
        doc.should_not be_nil
        doc = doc.not_nil!

        # Should be valid SVG
        doc.should contain("<svg")
      end

      it "returns nil for non-color fonts" do
        parser = TrueType::Parser.parse(FONT_PATH)
        parser.svg.should be_nil
      end
    end

    describe "#has_color_glyph?" do
      it "returns true for emoji glyphs" do
        parser = TrueType::Parser.parse(COLOR_FONT_PATH)

        # Get the glyph ID for a common emoji (e.g., U+1F600 grinning face)
        glyph_id = parser.glyph_id(0x1F600_u32)
        glyph_id.should be > 0

        parser.has_color_glyph?(glyph_id).should be_true
      end

      it "returns false for non-color fonts" do
        parser = TrueType::Parser.parse(FONT_PATH)
        glyph_id = parser.glyph_id('A')
        parser.has_color_glyph?(glyph_id).should be_false
      end
    end

    describe "#color_glyph_type" do
      it "returns SVG for emoji with SVG data" do
        parser = TrueType::Parser.parse(COLOR_FONT_PATH)

        # NotoColorEmoji has SVG data for most emoji
        glyph_id = parser.glyph_id(0x1F600_u32)
        type = parser.color_glyph_type(glyph_id)

        # NotoColorEmoji has both COLR and SVG, SVG takes priority
        type.should eq(TrueType::Parser::ColorGlyphType::SVG)
      end

      it "returns nil for glyphs without color data" do
        parser = TrueType::Parser.parse(FONT_PATH)
        glyph_id = parser.glyph_id('A')
        parser.color_glyph_type(glyph_id).should be_nil
      end
    end

    describe "#color_glyph_svg" do
      it "returns SVG document for color glyph" do
        parser = TrueType::Parser.parse(COLOR_FONT_PATH)

        glyph_id = parser.glyph_id(0x1F600_u32)
        svg = parser.color_glyph_svg(glyph_id)

        svg.should_not be_nil
        svg = svg.not_nil!
        svg.should contain("<svg")
      end

      it "returns nil for non-SVG glyphs" do
        parser = TrueType::Parser.parse(FONT_PATH)
        glyph_id = parser.glyph_id('A')
        parser.color_glyph_svg(glyph_id).should be_nil
      end
    end

    describe "#palette_color" do
      it "returns colors from CPAL" do
        parser = TrueType::Parser.parse(COLOR_FONT_PATH)

        color = parser.palette_color(0)
        color.should_not be_nil
        color = color.not_nil!

        # Should be valid color data
        color.alpha.should be >= 0
      end

      it "returns nil for non-color fonts" do
        parser = TrueType::Parser.parse(FONT_PATH)
        parser.palette_color(0).should be_nil
      end
    end
  end

  describe TrueType::Tables::Color::CPAL do
    it "parses color records correctly" do
      parser = TrueType::Parser.parse(COLOR_FONT_PATH)
      cpal = parser.cpal.not_nil!

      # Verify we can access multiple colors
      cpal.total_colors.should be > 100

      # Get a few colors and verify they're valid
      5.times do |i|
        color = cpal.color(0, i)
        color.should_not be_nil
        color = color.not_nil!
        color.alpha.should be >= 0
        color.alpha.should be <= 255
      end
    end

    it "converts colors to hex" do
      parser = TrueType::Parser.parse(COLOR_FONT_PATH)
      cpal = parser.cpal.not_nil!

      color = cpal.color(0, 0).not_nil!
      hex = color.to_hex

      # Should be a valid hex color
      hex.should match(/^#[0-9a-f]{6,8}$/i)
    end

    it "converts colors to CSS" do
      parser = TrueType::Parser.parse(COLOR_FONT_PATH)
      cpal = parser.cpal.not_nil!

      color = cpal.color(0, 0).not_nil!
      css = color.to_css

      # Should be rgb() or rgba()
      css.should match(/^rgba?\(/)
    end
  end

  describe TrueType::Tables::Color::COLR do
    it "detects v1 table correctly" do
      parser = TrueType::Parser.parse(COLOR_FONT_PATH)
      colr = parser.colr.not_nil!

      colr.v1?.should be_true
      colr.version.should eq(1)
    end

    it "can check for color glyphs" do
      parser = TrueType::Parser.parse(COLOR_FONT_PATH)
      colr = parser.colr.not_nil!

      # Get a glyph that should have color
      glyph_id = parser.glyph_id(0x1F600_u32)
      colr.has_color_glyph?(glyph_id).should be_true
    end

    it "lists color glyph IDs" do
      parser = TrueType::Parser.parse(COLOR_FONT_PATH)
      colr = parser.colr.not_nil!

      glyph_ids = colr.color_glyph_ids
      glyph_ids.should_not be_empty
    end
  end

  describe TrueType::Tables::Color::SVG do
    it "counts documents correctly" do
      parser = TrueType::Parser.parse(COLOR_FONT_PATH)
      svg = parser.svg.not_nil!

      svg.document_count.should be > 0
      svg.glyph_count.should be > svg.document_count # Multiple glyphs per document
    end

    it "handles gzip-compressed SVG" do
      parser = TrueType::Parser.parse(COLOR_FONT_PATH)
      svg = parser.svg.not_nil!

      # Find a record and check if it's compressed
      records = svg.document_records
      records.size.should be > 0

      # Try to get uncompressed SVG
      first_record = records.first
      doc = svg.svg_document(first_record.start_glyph_id)
      doc.should_not be_nil

      # Decompressed content should be valid SVG
      doc_str = doc.not_nil!
      (doc_str.includes?("<?xml") || doc_str.includes?("<svg")).should be_true
    end

    it "checks for SVG glyphs" do
      parser = TrueType::Parser.parse(COLOR_FONT_PATH)
      svg = parser.svg.not_nil!

      records = svg.document_records
      first_glyph = records.first.start_glyph_id

      svg.has_svg?(first_glyph).should be_true
      svg.has_svg?(0xFFFF_u16).should be_false # Unlikely to exist
    end
  end
end
