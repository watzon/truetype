require "../spec_helper"

describe TrueType::OutlinePoint do
  describe ".on_curve" do
    it "creates an on-curve point" do
      point = TrueType::OutlinePoint.on_curve(100_i16, 200_i16)
      point.x.should eq(100_i16)
      point.y.should eq(200_i16)
      point.type.should eq(TrueType::PointType::OnCurve)
      point.on_curve?.should be_true
      point.control_point?.should be_false
    end
  end

  describe ".quad_control" do
    it "creates a quadratic control point" do
      point = TrueType::OutlinePoint.quad_control(50_i16, 75_i16)
      point.type.should eq(TrueType::PointType::QuadraticControl)
      point.on_curve?.should be_false
      point.control_point?.should be_true
    end
  end

  describe "#transform" do
    it "applies a transformation matrix" do
      point = TrueType::OutlinePoint.on_curve(100_i16, 0_i16)
      # Scale by 2
      transformed = point.transform(2.0, 0.0, 0.0, 2.0, 0.0, 0.0)
      transformed.x.should eq(200_i16)
      transformed.y.should eq(0_i16)
    end

    it "applies translation" do
      point = TrueType::OutlinePoint.on_curve(100_i16, 200_i16)
      # Translate by (50, 100)
      transformed = point.transform(1.0, 0.0, 0.0, 1.0, 50.0, 100.0)
      transformed.x.should eq(150_i16)
      transformed.y.should eq(300_i16)
    end
  end

  describe "#offset" do
    it "offsets the point" do
      point = TrueType::OutlinePoint.on_curve(100_i16, 200_i16)
      offset = point.offset(10_i16, -20_i16)
      offset.x.should eq(110_i16)
      offset.y.should eq(180_i16)
    end
  end
end

describe TrueType::Contour do
  describe "#add" do
    it "adds points to the contour" do
      contour = TrueType::Contour.new
      contour.add(TrueType::OutlinePoint.on_curve(0_i16, 0_i16))
      contour.add(TrueType::OutlinePoint.on_curve(100_i16, 0_i16))
      contour.size.should eq(2)
    end
  end

  describe "#bounding_box" do
    it "returns the bounding box of all points" do
      contour = TrueType::Contour.new([
        TrueType::OutlinePoint.on_curve(0_i16, 0_i16),
        TrueType::OutlinePoint.on_curve(100_i16, 50_i16),
        TrueType::OutlinePoint.on_curve(50_i16, 100_i16),
      ])
      bbox = contour.bounding_box
      bbox.should eq({0_i16, 0_i16, 100_i16, 100_i16})
    end

    it "returns zero box for empty contour" do
      contour = TrueType::Contour.new
      contour.bounding_box.should eq({0_i16, 0_i16, 0_i16, 0_i16})
    end
  end

  describe "#to_svg_path" do
    it "generates SVG path for simple contour" do
      contour = TrueType::Contour.new([
        TrueType::OutlinePoint.on_curve(0_i16, 0_i16),
        TrueType::OutlinePoint.on_curve(100_i16, 0_i16),
        TrueType::OutlinePoint.on_curve(100_i16, 100_i16),
        TrueType::OutlinePoint.on_curve(0_i16, 100_i16),
      ])
      path = contour.to_svg_path
      path.should contain("M 0 0")
      path.should contain("L 100 0")
      path.should contain("Z")
    end

    it "generates quadratic curves" do
      contour = TrueType::Contour.new([
        TrueType::OutlinePoint.on_curve(0_i16, 0_i16),
        TrueType::OutlinePoint.quad_control(50_i16, 100_i16),
        TrueType::OutlinePoint.on_curve(100_i16, 0_i16),
      ])
      path = contour.to_svg_path
      path.should contain("Q")
    end

    it "returns empty string for empty contour" do
      contour = TrueType::Contour.new
      contour.to_svg_path.should eq("")
    end
  end
end

describe TrueType::GlyphOutline do
  describe "#empty?" do
    it "returns true for empty outline" do
      outline = TrueType::GlyphOutline.new
      outline.empty?.should be_true
    end

    it "returns false when contours exist" do
      contour = TrueType::Contour.new([
        TrueType::OutlinePoint.on_curve(0_i16, 0_i16),
      ])
      outline = TrueType::GlyphOutline.new([contour])
      outline.empty?.should be_false
    end
  end

  describe "#point_count" do
    it "returns total points across all contours" do
      contour1 = TrueType::Contour.new([
        TrueType::OutlinePoint.on_curve(0_i16, 0_i16),
        TrueType::OutlinePoint.on_curve(100_i16, 0_i16),
      ])
      contour2 = TrueType::Contour.new([
        TrueType::OutlinePoint.on_curve(0_i16, 0_i16),
      ])
      outline = TrueType::GlyphOutline.new([contour1, contour2])
      outline.point_count.should eq(3)
    end
  end

  describe "#to_svg" do
    it "generates complete SVG" do
      contour = TrueType::Contour.new([
        TrueType::OutlinePoint.on_curve(0_i16, 0_i16),
        TrueType::OutlinePoint.on_curve(100_i16, 0_i16),
        TrueType::OutlinePoint.on_curve(100_i16, 100_i16),
        TrueType::OutlinePoint.on_curve(0_i16, 100_i16),
      ])
      outline = TrueType::GlyphOutline.new(
        [contour],
        0_i16, 0_i16, 100_i16, 100_i16
      )
      svg = outline.to_svg
      svg.should contain("<svg")
      svg.should contain("viewBox")
      svg.should contain("<path")
      svg.should contain("</svg>")
    end
  end

  describe "#merge!" do
    it "merges another outline" do
      contour1 = TrueType::Contour.new([
        TrueType::OutlinePoint.on_curve(0_i16, 0_i16),
      ])
      contour2 = TrueType::Contour.new([
        TrueType::OutlinePoint.on_curve(100_i16, 100_i16),
      ])
      outline1 = TrueType::GlyphOutline.new([contour1], 0_i16, 0_i16, 50_i16, 50_i16)
      outline2 = TrueType::GlyphOutline.new([contour2], 50_i16, 50_i16, 100_i16, 100_i16)

      outline1.merge!(outline2)
      outline1.contour_count.should eq(2)
      outline1.x_min.should eq(0_i16)
      outline1.y_min.should eq(0_i16)
      outline1.x_max.should eq(100_i16)
      outline1.y_max.should eq(100_i16)
    end
  end
end

describe TrueType::Parser do
  describe "#glyph_outline" do
    it "extracts outline for a glyph" do
      parser = TrueType::Parser.parse(FONT_PATH)

      # Get outline for 'A'
      glyph_id = parser.glyph_id('A')
      outline = parser.glyph_outline(glyph_id)

      outline.should be_a(TrueType::GlyphOutline)
      outline.empty?.should be_false
      outline.contour_count.should be > 0
      outline.point_count.should be > 0
    end

    it "returns empty outline for .notdef glyph 0" do
      parser = TrueType::Parser.parse(FONT_PATH)

      # Glyph 0 is .notdef - may or may not have an outline
      outline = parser.glyph_outline(0_u16)
      outline.should be_a(TrueType::GlyphOutline)
    end

    it "returns empty outline for non-existent glyph" do
      parser = TrueType::Parser.parse(FONT_PATH)

      outline = parser.glyph_outline(0xFFFF_u16)
      outline.should be_a(TrueType::GlyphOutline)
    end
  end

  describe "#char_outline" do
    it "extracts outline for a character" do
      parser = TrueType::Parser.parse(FONT_PATH)

      outline = parser.char_outline('B')
      outline.should be_a(TrueType::GlyphOutline)
      outline.empty?.should be_false
    end
  end

  describe "#glyph_svg_path" do
    it "returns SVG path data" do
      parser = TrueType::Parser.parse(FONT_PATH)

      glyph_id = parser.glyph_id('O')
      path = parser.glyph_svg_path(glyph_id)

      path.should be_a(String)
      path.should contain("M") # moveto command
      path.should contain("Z") # closepath command
    end
  end

  describe "#char_svg_path" do
    it "returns SVG path data for character" do
      parser = TrueType::Parser.parse(FONT_PATH)

      path = parser.char_svg_path('O')
      path.should contain("M")
    end
  end

  describe "#glyph_svg" do
    it "returns complete SVG" do
      parser = TrueType::Parser.parse(FONT_PATH)

      glyph_id = parser.glyph_id('A')
      svg = parser.glyph_svg(glyph_id)

      svg.should contain("<svg")
      svg.should contain("<path")
    end

    it "accepts width and height" do
      parser = TrueType::Parser.parse(FONT_PATH)

      glyph_id = parser.glyph_id('A')
      svg = parser.glyph_svg(glyph_id, 100, 100)

      svg.should contain("width=\"100\"")
      svg.should contain("height=\"100\"")
    end
  end

  describe "#char_svg" do
    it "returns complete SVG for character" do
      parser = TrueType::Parser.parse(FONT_PATH)

      svg = parser.char_svg('A', 50, 50)
      svg.should contain("<svg")
      svg.should contain("width=\"50\"")
    end
  end

  describe "#glyph_bounding_box" do
    it "returns bounding box for glyph" do
      parser = TrueType::Parser.parse(FONT_PATH)

      glyph_id = parser.glyph_id('A')
      bbox = parser.glyph_bounding_box(glyph_id)

      bbox[2].should be > bbox[0] # x_max > x_min
      bbox[3].should be > bbox[1] # y_max > y_min
    end
  end

  describe "#char_bounding_box" do
    it "returns bounding box for character" do
      parser = TrueType::Parser.parse(FONT_PATH)

      bbox = parser.char_bounding_box('X')
      bbox.should be_a(Tuple(Int16, Int16, Int16, Int16))
    end
  end
end

describe TrueType::OutlineExtractor do
  describe ".extract_simple" do
    it "extracts outline from simple glyph" do
      parser = TrueType::Parser.parse(FONT_PATH)

      # Find a simple (non-composite) glyph
      glyph_id = parser.glyph_id('I') # Usually simple
      glyph_data = parser.glyf.glyph(glyph_id, parser.loca)

      unless glyph_data.composite? || glyph_data.empty?
        outline = TrueType::OutlineExtractor.extract_simple(glyph_data)
        outline.should be_a(TrueType::GlyphOutline)
        outline.empty?.should be_false
      end
    end
  end

  describe ".parse_composite_components" do
    it "parses composite glyph components" do
      parser = TrueType::Parser.parse(FONT_PATH)

      # Try to find a composite glyph (accented characters are usually composite)
      glyph_id = parser.glyph_id('é')
      glyph_data = parser.glyf.glyph(glyph_id, parser.loca)

      if glyph_data.composite?
        components = TrueType::OutlineExtractor.parse_composite_components(glyph_data)
        components.should_not be_empty
        components.first.glyph_id.should be >= 0_u16
      end
    end
  end
end
