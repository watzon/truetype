module TrueType
  # Point types in a glyph outline
  enum PointType
    # On-curve point (anchor point)
    OnCurve

    # Off-curve quadratic control point
    QuadraticControl

    # Off-curve cubic control point (for CFF fonts)
    CubicControl
  end

  # A point in a glyph outline
  struct OutlinePoint
    # X coordinate in font units
    getter x : Int16

    # Y coordinate in font units
    getter y : Int16

    # Type of point (on-curve or control point)
    getter type : PointType

    def initialize(@x : Int16, @y : Int16, @type : PointType = PointType::OnCurve)
    end

    # Create an on-curve point
    def self.on_curve(x : Int16, y : Int16) : OutlinePoint
      new(x, y, PointType::OnCurve)
    end

    # Create a quadratic control point
    def self.quad_control(x : Int16, y : Int16) : OutlinePoint
      new(x, y, PointType::QuadraticControl)
    end

    # Create a cubic control point
    def self.cubic_control(x : Int16, y : Int16) : OutlinePoint
      new(x, y, PointType::CubicControl)
    end

    # Check if this is an on-curve point
    def on_curve? : Bool
      @type == PointType::OnCurve
    end

    # Check if this is a control point
    def control_point? : Bool
      @type != PointType::OnCurve
    end

    # Apply a 2D transformation matrix to this point
    def transform(a : Float64, b : Float64, c : Float64, d : Float64, e : Float64, f : Float64) : OutlinePoint
      new_x = (a * @x + c * @y + e).round.to_i16
      new_y = (b * @x + d * @y + f).round.to_i16
      OutlinePoint.new(new_x, new_y, @type)
    end

    # Offset this point by the given amount
    def offset(dx : Int16, dy : Int16) : OutlinePoint
      OutlinePoint.new(@x + dx, @y + dy, @type)
    end
  end

  # A single contour (closed path) in a glyph
  class Contour
    # Points in this contour
    getter points : Array(OutlinePoint)

    def initialize(@points : Array(OutlinePoint) = [] of OutlinePoint)
    end

    # Add a point to this contour
    def add(point : OutlinePoint) : Nil
      @points << point
    end

    # Check if this contour is empty
    def empty? : Bool
      @points.empty?
    end

    # Get the number of points
    def size : Int32
      @points.size
    end

    # Apply a transformation to all points
    def transform(a : Float64, b : Float64, c : Float64, d : Float64, e : Float64, f : Float64) : Contour
      Contour.new(@points.map(&.transform(a, b, c, d, e, f)))
    end

    # Offset all points by the given amount
    def offset(dx : Int16, dy : Int16) : Contour
      Contour.new(@points.map(&.offset(dx, dy)))
    end

    # Get the bounding box of this contour
    def bounding_box : Tuple(Int16, Int16, Int16, Int16)
      return {0_i16, 0_i16, 0_i16, 0_i16} if @points.empty?

      x_min = @points.min_of(&.x)
      y_min = @points.min_of(&.y)
      x_max = @points.max_of(&.x)
      y_max = @points.max_of(&.y)

      {x_min, y_min, x_max, y_max}
    end

    # Convert this contour to SVG path data
    # Returns a string with moveto, lineto, and quadratic Bezier commands
    def to_svg_path : String
      return "" if @points.empty?

      path = String::Builder.new

      # Find the first on-curve point to start
      first_on_curve_idx = @points.index(&.on_curve?)
      return "" unless first_on_curve_idx

      # Rotate points so we start with on-curve
      rotated = @points.rotate(first_on_curve_idx)

      path << "M #{rotated[0].x} #{-rotated[0].y}"

      i = 1
      while i < rotated.size
        point = rotated[i]

        if point.on_curve?
          # Line to on-curve point
          path << " L #{point.x} #{-point.y}"
          i += 1
        elsif point.type == PointType::QuadraticControl
          # Quadratic Bezier curve
          # Look ahead for the end point
          next_point = rotated[(i + 1) % rotated.size]

          if next_point.on_curve?
            # Standard quadratic curve
            path << " Q #{point.x} #{-point.y} #{next_point.x} #{-next_point.y}"
            i += 2
          else
            # Implied on-curve point between two control points
            mid_x = (point.x + next_point.x) // 2
            mid_y = (point.y + next_point.y) // 2
            path << " Q #{point.x} #{-point.y} #{mid_x} #{-mid_y}"
            i += 1
          end
        elsif point.type == PointType::CubicControl
          # Cubic Bezier curve (needs 2 control points)
          ctrl1 = point
          ctrl2 = rotated[(i + 1) % rotated.size]
          end_point = rotated[(i + 2) % rotated.size]

          path << " C #{ctrl1.x} #{-ctrl1.y} #{ctrl2.x} #{-ctrl2.y} #{end_point.x} #{-end_point.y}"
          i += 3
        else
          i += 1
        end
      end

      path << " Z"
      path.to_s
    end
  end

  # Complete glyph outline with all contours
  class GlyphOutline
    # Contours in this outline
    getter contours : Array(Contour)

    # Glyph bounding box
    getter x_min : Int16
    getter y_min : Int16
    getter x_max : Int16
    getter y_max : Int16

    # Whether this outline was derived from a composite glyph
    getter? composite : Bool

    def initialize(
      @contours : Array(Contour) = [] of Contour,
      @x_min : Int16 = 0_i16,
      @y_min : Int16 = 0_i16,
      @x_max : Int16 = 0_i16,
      @y_max : Int16 = 0_i16,
      @composite : Bool = false,
    )
    end

    # Add a contour to this outline
    def add(contour : Contour) : Nil
      @contours << contour
    end

    # Check if this outline is empty
    def empty? : Bool
      @contours.empty? || @contours.all?(&.empty?)
    end

    # Get the total number of points across all contours
    def point_count : Int32
      @contours.sum(&.size)
    end

    # Get the number of contours
    def contour_count : Int32
      @contours.size
    end

    # Get the bounding box as a tuple
    def bounding_box : Tuple(Int16, Int16, Int16, Int16)
      {@x_min, @y_min, @x_max, @y_max}
    end

    # Convert the entire outline to SVG path data
    def to_svg_path : String
      @contours.map(&.to_svg_path).join(" ")
    end

    # Create an SVG string for this glyph
    def to_svg(width : Int32? = nil, height : Int32? = nil) : String
      path_data = to_svg_path
      return "" if path_data.empty?

      # Calculate viewBox from bounding box
      box_width = (@x_max - @x_min).to_i32
      box_height = (@y_max - @y_min).to_i32

      view_min_x = @x_min.to_i32
      view_min_y = -@y_max.to_i32 # SVG Y is inverted

      # Default dimensions based on bounding box
      svg_width = width || box_width
      svg_height = height || box_height

      <<-SVG
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="#{view_min_x} #{view_min_y} #{box_width} #{box_height}" width="#{svg_width}" height="#{svg_height}">
        <path d="#{path_data}" fill="currentColor"/>
      </svg>
      SVG
    end

    # Apply a 2D transformation to all contours
    def transform(a : Float64, b : Float64, c : Float64, d : Float64, e : Float64, f : Float64) : GlyphOutline
      transformed_contours = @contours.map(&.transform(a, b, c, d, e, f))

      # Recalculate bounding box
      all_points = transformed_contours.flat_map(&.points)
      if all_points.empty?
        GlyphOutline.new(transformed_contours, 0_i16, 0_i16, 0_i16, 0_i16, @composite)
      else
        new_x_min = all_points.min_of(&.x)
        new_y_min = all_points.min_of(&.y)
        new_x_max = all_points.max_of(&.x)
        new_y_max = all_points.max_of(&.y)

        GlyphOutline.new(transformed_contours, new_x_min, new_y_min, new_x_max, new_y_max, @composite)
      end
    end

    # Merge another outline into this one (for composites)
    def merge!(other : GlyphOutline) : Nil
      @contours.concat(other.contours)

      # Update bounding box
      @x_min = Math.min(@x_min, other.x_min)
      @y_min = Math.min(@y_min, other.y_min)
      @x_max = Math.max(@x_max, other.x_max)
      @y_max = Math.max(@y_max, other.y_max)
    end
  end
end
