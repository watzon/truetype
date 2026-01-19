module TrueType
  module Tables
    module Color
      # Paint format types for COLR v1
      enum PaintFormat : UInt8
        ColrLayers             = 1
        Solid                  = 2
        SolidVar               = 3
        LinearGradient         = 4
        LinearGradientVar      = 5
        RadialGradient         = 6
        RadialGradientVar      = 7
        SweepGradient          = 8
        SweepGradientVar       = 9
        Glyph                  = 10
        ColrGlyph              = 11
        Transform              = 12
        TransformVar           = 13
        Translate              = 14
        TranslateVar           = 15
        Scale                  = 16
        ScaleVar               = 17
        ScaleAroundCenter      = 18
        ScaleAroundCenterVar   = 19
        ScaleUniform           = 20
        ScaleUniformVar        = 21
        ScaleUniformAroundCenter    = 22
        ScaleUniformAroundCenterVar = 23
        Rotate                 = 24
        RotateVar              = 25
        RotateAroundCenter     = 26
        RotateAroundCenterVar  = 27
        Skew                   = 28
        SkewVar                = 29
        SkewAroundCenter       = 30
        SkewAroundCenterVar    = 31
        Composite              = 32
      end

      # Extend mode for gradients
      enum ExtendMode : UInt8
        Pad     = 0 # Use the color at the closest stop
        Repeat  = 1 # Repeat the gradient
        Reflect = 2 # Alternate repeating forwards and backwards
      end

      # Composite mode for PaintComposite
      enum CompositeMode : UInt8
        Clear      = 0
        Src        = 1
        Dest       = 2
        SrcOver    = 3
        DestOver   = 4
        SrcIn      = 5
        DestIn     = 6
        SrcOut     = 7
        DestOut    = 8
        SrcAtop    = 9
        DestAtop   = 10
        Xor        = 11
        Plus       = 12
        Screen     = 13
        Overlay    = 14
        Darken     = 15
        Lighten    = 16
        ColorDodge = 17
        ColorBurn  = 18
        HardLight  = 19
        SoftLight  = 20
        Difference = 21
        Exclusion  = 22
        Multiply   = 23
        HSLHue     = 24
        HSLSaturation = 25
        HSLColor   = 26
        HSLLuminosity = 27
      end

      # Color stop for gradients
      struct ColorStop
        # Position of this stop (0.0 to 1.0)
        getter stop_offset : Float64

        # Palette entry index
        getter palette_index : UInt16

        # Alpha multiplier (0.0 to 1.0)
        getter alpha : Float64

        def initialize(@stop_offset : Float64, @palette_index : UInt16, @alpha : Float64)
        end
      end

      # Color line (used by gradient paints)
      struct ColorLine
        # How to handle colors outside the gradient range
        getter extend_mode : ExtendMode

        # Color stops in order
        getter color_stops : Array(ColorStop)

        def initialize(@extend_mode : ExtendMode, @color_stops : Array(ColorStop))
        end
      end

      # Affine 2x3 transformation matrix
      struct Affine2x3
        # Scale X
        getter xx : Float64
        # Shear Y
        getter yx : Float64
        # Shear X
        getter xy : Float64
        # Scale Y
        getter yy : Float64
        # Translate X
        getter dx : Float64
        # Translate Y
        getter dy : Float64

        def initialize(
          @xx : Float64, @yx : Float64,
          @xy : Float64, @yy : Float64,
          @dx : Float64, @dy : Float64
        )
        end

        # Identity transformation
        def self.identity : Affine2x3
          new(1.0, 0.0, 0.0, 1.0, 0.0, 0.0)
        end
      end

      # Abstract base for all paint types
      abstract class Paint
        include IOHelpers
        extend IOHelpers

        abstract def format : PaintFormat

        # Parse a paint from the given data at the given offset
        def self.parse(data : Bytes, offset : UInt32) : Paint?
          return nil if offset == 0 || offset >= data.size

          io = IO::Memory.new(data[offset.to_i..])
          format_byte = read_uint8(io)
          format = PaintFormat.new(format_byte)

          case format
          when .colr_layers?
            PaintColrLayers.parse(io, data)
          when .solid?, .solid_var?
            PaintSolid.parse(io, format)
          when .linear_gradient?, .linear_gradient_var?
            PaintLinearGradient.parse(io, data, offset, format)
          when .radial_gradient?, .radial_gradient_var?
            PaintRadialGradient.parse(io, data, offset, format)
          when .sweep_gradient?, .sweep_gradient_var?
            PaintSweepGradient.parse(io, data, offset, format)
          when .glyph?
            PaintGlyph.parse(io, data, offset)
          when .colr_glyph?
            PaintColrGlyph.parse(io)
          when .transform?, .transform_var?
            PaintTransform.parse(io, data, offset, format)
          when .translate?, .translate_var?
            PaintTranslate.parse(io, data, offset, format)
          when .scale?, .scale_var?, .scale_around_center?, .scale_around_center_var?,
               .scale_uniform?, .scale_uniform_var?, .scale_uniform_around_center?, .scale_uniform_around_center_var?
            PaintScale.parse(io, data, offset, format)
          when .rotate?, .rotate_var?, .rotate_around_center?, .rotate_around_center_var?
            PaintRotate.parse(io, data, offset, format)
          when .skew?, .skew_var?, .skew_around_center?, .skew_around_center_var?
            PaintSkew.parse(io, data, offset, format)
          when .composite?
            PaintComposite.parse(io, data, offset)
          else
            nil
          end
        rescue
          nil
        end

        # Read a 24-bit offset (Offset24)
        protected def self.read_offset24(io : IO) : UInt32
          b1 = read_uint8(io).to_u32
          b2 = read_uint8(io).to_u32
          b3 = read_uint8(io).to_u32
          (b1 << 16) | (b2 << 8) | b3
        end

        # Read F2Dot14 fixed-point value
        protected def self.read_f2dot14(io : IO) : Float64
          value = read_int16(io)
          value.to_f64 / 16384.0
        end

        # Read FWORD (signed 16-bit in design units)
        protected def self.read_fword(io : IO) : Int16
          read_int16(io)
        end

        # Read UFWORD (unsigned 16-bit in design units)
        protected def self.read_ufword(io : IO) : UInt16
          read_uint16(io)
        end

        # Parse a ColorLine from data at the given offset
        protected def self.parse_color_line(data : Bytes, offset : UInt32) : ColorLine?
          return nil if offset >= data.size

          io = IO::Memory.new(data[offset.to_i..])
          extend_mode = ExtendMode.new(read_uint8(io))
          num_stops = read_uint16(io)

          stops = Array(ColorStop).new(num_stops.to_i)
          num_stops.times do
            stop_offset = read_f2dot14(io)
            palette_index = read_uint16(io)
            alpha = read_f2dot14(io)
            stops << ColorStop.new(stop_offset, palette_index, alpha)
          end

          ColorLine.new(extend_mode, stops)
        rescue
          nil
        end
      end

      # PaintColrLayers: Reference layers from the LayerList
      class PaintColrLayers < Paint
        getter num_layers : UInt8
        getter first_layer_index : UInt32

        def initialize(@num_layers : UInt8, @first_layer_index : UInt32)
        end

        def format : PaintFormat
          PaintFormat::ColrLayers
        end

        def self.parse(io : IO, data : Bytes) : PaintColrLayers
          num_layers = read_uint8(io)
          first_layer_index = read_uint32(io)
          new(num_layers, first_layer_index)
        end
      end

      # PaintSolid: Solid color fill
      class PaintSolid < Paint
        getter palette_index : UInt16
        getter alpha : Float64
        @format : PaintFormat

        def initialize(@palette_index : UInt16, @alpha : Float64, @format : PaintFormat)
        end

        def format : PaintFormat
          @format
        end

        def self.parse(io : IO, format : PaintFormat) : PaintSolid
          palette_index = read_uint16(io)
          alpha = read_f2dot14(io)
          new(palette_index, alpha, format)
        end
      end

      # PaintLinearGradient: Linear gradient
      class PaintLinearGradient < Paint
        getter color_line : ColorLine?
        getter x0 : Int16
        getter y0 : Int16
        getter x1 : Int16
        getter y1 : Int16
        getter x2 : Int16
        getter y2 : Int16
        @format : PaintFormat

        def initialize(
          @color_line : ColorLine?,
          @x0 : Int16, @y0 : Int16,
          @x1 : Int16, @y1 : Int16,
          @x2 : Int16, @y2 : Int16,
          @format : PaintFormat
        )
        end

        def format : PaintFormat
          @format
        end

        def self.parse(io : IO, data : Bytes, paint_offset : UInt32, format : PaintFormat) : PaintLinearGradient
          color_line_offset = read_offset24(io)
          x0 = read_fword(io)
          y0 = read_fword(io)
          x1 = read_fword(io)
          y1 = read_fword(io)
          x2 = read_fword(io)
          y2 = read_fword(io)

          color_line = parse_color_line(data, paint_offset + color_line_offset)
          new(color_line, x0, y0, x1, y1, x2, y2, format)
        end
      end

      # PaintRadialGradient: Radial gradient between two circles
      class PaintRadialGradient < Paint
        getter color_line : ColorLine?
        getter x0 : Int16
        getter y0 : Int16
        getter radius0 : UInt16
        getter x1 : Int16
        getter y1 : Int16
        getter radius1 : UInt16
        @format : PaintFormat

        def initialize(
          @color_line : ColorLine?,
          @x0 : Int16, @y0 : Int16, @radius0 : UInt16,
          @x1 : Int16, @y1 : Int16, @radius1 : UInt16,
          @format : PaintFormat
        )
        end

        def format : PaintFormat
          @format
        end

        def self.parse(io : IO, data : Bytes, paint_offset : UInt32, format : PaintFormat) : PaintRadialGradient
          color_line_offset = read_offset24(io)
          x0 = read_fword(io)
          y0 = read_fword(io)
          radius0 = read_ufword(io)
          x1 = read_fword(io)
          y1 = read_fword(io)
          radius1 = read_ufword(io)

          color_line = parse_color_line(data, paint_offset + color_line_offset)
          new(color_line, x0, y0, radius0, x1, y1, radius1, format)
        end
      end

      # PaintSweepGradient: Sweep/conical gradient
      class PaintSweepGradient < Paint
        getter color_line : ColorLine?
        getter center_x : Int16
        getter center_y : Int16
        getter start_angle : Float64
        getter end_angle : Float64
        @format : PaintFormat

        def initialize(
          @color_line : ColorLine?,
          @center_x : Int16, @center_y : Int16,
          @start_angle : Float64, @end_angle : Float64,
          @format : PaintFormat
        )
        end

        def format : PaintFormat
          @format
        end

        def self.parse(io : IO, data : Bytes, paint_offset : UInt32, format : PaintFormat) : PaintSweepGradient
          color_line_offset = read_offset24(io)
          center_x = read_fword(io)
          center_y = read_fword(io)
          start_angle = read_f2dot14(io)
          end_angle = read_f2dot14(io)

          color_line = parse_color_line(data, paint_offset + color_line_offset)
          new(color_line, center_x, center_y, start_angle, end_angle, format)
        end
      end

      # PaintGlyph: Paint the outline of a glyph
      class PaintGlyph < Paint
        getter child_paint_offset : UInt32
        getter glyph_id : UInt16
        @data : Bytes
        @paint_offset : UInt32

        def initialize(@child_paint_offset : UInt32, @glyph_id : UInt16, @data : Bytes, @paint_offset : UInt32)
        end

        def format : PaintFormat
          PaintFormat::Glyph
        end

        # Get the child paint that defines how to fill this glyph
        def child_paint : Paint?
          Paint.parse(@data, @paint_offset + @child_paint_offset)
        end

        def self.parse(io : IO, data : Bytes, paint_offset : UInt32) : PaintGlyph
          child_paint_offset = read_offset24(io)
          glyph_id = read_uint16(io)
          new(child_paint_offset, glyph_id, data, paint_offset)
        end
      end

      # PaintColrGlyph: Reuse another COLR glyph
      class PaintColrGlyph < Paint
        getter glyph_id : UInt16

        def initialize(@glyph_id : UInt16)
        end

        def format : PaintFormat
          PaintFormat::ColrGlyph
        end

        def self.parse(io : IO) : PaintColrGlyph
          glyph_id = read_uint16(io)
          new(glyph_id)
        end
      end

      # PaintTransform: Apply an affine transformation
      class PaintTransform < Paint
        getter child_paint_offset : UInt32
        getter transform : Affine2x3
        @format : PaintFormat
        @data : Bytes
        @paint_offset : UInt32

        def initialize(
          @child_paint_offset : UInt32,
          @transform : Affine2x3,
          @format : PaintFormat,
          @data : Bytes,
          @paint_offset : UInt32
        )
        end

        def format : PaintFormat
          @format
        end

        def child_paint : Paint?
          Paint.parse(@data, @paint_offset + @child_paint_offset)
        end

        def self.parse(io : IO, data : Bytes, paint_offset : UInt32, format : PaintFormat) : PaintTransform
          child_paint_offset = read_offset24(io)
          transform_offset = read_offset24(io)

          # Parse affine matrix at transform offset
          transform_io = IO::Memory.new(data[(paint_offset + transform_offset).to_i..])
          xx = read_fixed(transform_io)
          yx = read_fixed(transform_io)
          xy = read_fixed(transform_io)
          yy = read_fixed(transform_io)
          dx = read_fixed(transform_io)
          dy = read_fixed(transform_io)

          transform = Affine2x3.new(xx, yx, xy, yy, dx, dy)
          new(child_paint_offset, transform, format, data, paint_offset)
        end

        private def self.read_fixed(io : IO) : Float64
          value = read_int32(io)
          value.to_f64 / 65536.0
        end
      end

      # PaintTranslate: Apply a translation
      class PaintTranslate < Paint
        getter child_paint_offset : UInt32
        getter dx : Int16
        getter dy : Int16
        @format : PaintFormat
        @data : Bytes
        @paint_offset : UInt32

        def initialize(
          @child_paint_offset : UInt32,
          @dx : Int16, @dy : Int16,
          @format : PaintFormat,
          @data : Bytes,
          @paint_offset : UInt32
        )
        end

        def format : PaintFormat
          @format
        end

        def child_paint : Paint?
          Paint.parse(@data, @paint_offset + @child_paint_offset)
        end

        def self.parse(io : IO, data : Bytes, paint_offset : UInt32, format : PaintFormat) : PaintTranslate
          child_paint_offset = read_offset24(io)
          dx = read_fword(io)
          dy = read_fword(io)
          new(child_paint_offset, dx, dy, format, data, paint_offset)
        end
      end

      # PaintScale: Apply scaling (various forms)
      class PaintScale < Paint
        getter child_paint_offset : UInt32
        getter scale_x : Float64
        getter scale_y : Float64
        getter center_x : Int16?
        getter center_y : Int16?
        @format : PaintFormat
        @data : Bytes
        @paint_offset : UInt32

        def initialize(
          @child_paint_offset : UInt32,
          @scale_x : Float64, @scale_y : Float64,
          @center_x : Int16?, @center_y : Int16?,
          @format : PaintFormat,
          @data : Bytes,
          @paint_offset : UInt32
        )
        end

        def format : PaintFormat
          @format
        end

        def child_paint : Paint?
          Paint.parse(@data, @paint_offset + @child_paint_offset)
        end

        def self.parse(io : IO, data : Bytes, paint_offset : UInt32, format : PaintFormat) : PaintScale
          child_paint_offset = read_offset24(io)

          scale_x, scale_y, center_x, center_y = case format
                                                 when .scale?, .scale_var?
                                                   sx = read_f2dot14(io)
                                                   sy = read_f2dot14(io)
                                                   {sx, sy, nil, nil}
                                                 when .scale_around_center?, .scale_around_center_var?
                                                   sx = read_f2dot14(io)
                                                   sy = read_f2dot14(io)
                                                   cx = read_fword(io)
                                                   cy = read_fword(io)
                                                   {sx, sy, cx, cy}
                                                 when .scale_uniform?, .scale_uniform_var?
                                                   s = read_f2dot14(io)
                                                   {s, s, nil, nil}
                                                 when .scale_uniform_around_center?, .scale_uniform_around_center_var?
                                                   s = read_f2dot14(io)
                                                   cx = read_fword(io)
                                                   cy = read_fword(io)
                                                   {s, s, cx, cy}
                                                 else
                                                   {1.0, 1.0, nil, nil}
                                                 end

          new(child_paint_offset, scale_x, scale_y, center_x, center_y, format, data, paint_offset)
        end
      end

      # PaintRotate: Apply rotation
      class PaintRotate < Paint
        getter child_paint_offset : UInt32
        getter angle : Float64
        getter center_x : Int16?
        getter center_y : Int16?
        @format : PaintFormat
        @data : Bytes
        @paint_offset : UInt32

        def initialize(
          @child_paint_offset : UInt32,
          @angle : Float64,
          @center_x : Int16?, @center_y : Int16?,
          @format : PaintFormat,
          @data : Bytes,
          @paint_offset : UInt32
        )
        end

        def format : PaintFormat
          @format
        end

        def child_paint : Paint?
          Paint.parse(@data, @paint_offset + @child_paint_offset)
        end

        def self.parse(io : IO, data : Bytes, paint_offset : UInt32, format : PaintFormat) : PaintRotate
          child_paint_offset = read_offset24(io)
          angle = read_f2dot14(io)

          center_x, center_y = if format.rotate_around_center? || format.rotate_around_center_var?
                                 {read_fword(io), read_fword(io)}
                               else
                                 {nil, nil}
                               end

          new(child_paint_offset, angle, center_x, center_y, format, data, paint_offset)
        end
      end

      # PaintSkew: Apply skew transformation
      class PaintSkew < Paint
        getter child_paint_offset : UInt32
        getter skew_x : Float64
        getter skew_y : Float64
        getter center_x : Int16?
        getter center_y : Int16?
        @format : PaintFormat
        @data : Bytes
        @paint_offset : UInt32

        def initialize(
          @child_paint_offset : UInt32,
          @skew_x : Float64, @skew_y : Float64,
          @center_x : Int16?, @center_y : Int16?,
          @format : PaintFormat,
          @data : Bytes,
          @paint_offset : UInt32
        )
        end

        def format : PaintFormat
          @format
        end

        def child_paint : Paint?
          Paint.parse(@data, @paint_offset + @child_paint_offset)
        end

        def self.parse(io : IO, data : Bytes, paint_offset : UInt32, format : PaintFormat) : PaintSkew
          child_paint_offset = read_offset24(io)
          skew_x = read_f2dot14(io)
          skew_y = read_f2dot14(io)

          center_x, center_y = if format.skew_around_center? || format.skew_around_center_var?
                                 {read_fword(io), read_fword(io)}
                               else
                                 {nil, nil}
                               end

          new(child_paint_offset, skew_x, skew_y, center_x, center_y, format, data, paint_offset)
        end
      end

      # PaintComposite: Composite two paints together
      class PaintComposite < Paint
        getter source_paint_offset : UInt32
        getter mode : CompositeMode
        getter backdrop_paint_offset : UInt32
        @data : Bytes
        @paint_offset : UInt32

        def initialize(
          @source_paint_offset : UInt32,
          @mode : CompositeMode,
          @backdrop_paint_offset : UInt32,
          @data : Bytes,
          @paint_offset : UInt32
        )
        end

        def format : PaintFormat
          PaintFormat::Composite
        end

        def source_paint : Paint?
          Paint.parse(@data, @paint_offset + @source_paint_offset)
        end

        def backdrop_paint : Paint?
          Paint.parse(@data, @paint_offset + @backdrop_paint_offset)
        end

        def self.parse(io : IO, data : Bytes, paint_offset : UInt32) : PaintComposite
          source_paint_offset = read_offset24(io)
          mode = CompositeMode.new(read_uint8(io))
          backdrop_paint_offset = read_offset24(io)
          new(source_paint_offset, mode, backdrop_paint_offset, data, paint_offset)
        end
      end
    end
  end
end
