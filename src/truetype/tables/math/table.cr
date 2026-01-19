module TrueType
  module Tables
    module Math
      # The 'MATH' table contains mathematical typesetting data.
      # Used by math fonts like Latin Modern Math, STIX, etc.
      class MATH
        include IOHelpers

        # Table version (1.0)
        getter version : UInt32

        # Math constants (51 values for typesetting)
        getter math_constants : MathConstants?

        # Per-glyph math info (italics, accents, kerns)
        getter math_glyph_info : MathGlyphInfo?

        # Glyph variants for stretchy characters
        getter math_variants : MathVariants?

        def initialize(
          @version : UInt32,
          @math_constants : MathConstants?,
          @math_glyph_info : MathGlyphInfo?,
          @math_variants : MathVariants?
        )
        end

        # Parse MATH table from raw bytes
        def self.parse(data : Bytes) : MATH
          io = IO::Memory.new(data)

          major_version = read_uint16(io)
          minor_version = read_uint16(io)
          version = (major_version.to_u32 << 16) | minor_version.to_u32

          math_constants_offset = read_uint16(io)
          math_glyph_info_offset = read_uint16(io)
          math_variants_offset = read_uint16(io)

          # Parse MathConstants
          math_constants : MathConstants? = nil
          if math_constants_offset != 0
            constants_io = IO::Memory.new(data[math_constants_offset.to_i..])
            math_constants = MathConstants.parse(constants_io)
          end

          # Parse MathGlyphInfo
          math_glyph_info : MathGlyphInfo? = nil
          if math_glyph_info_offset != 0
            math_glyph_info = MathGlyphInfo.parse(data, math_glyph_info_offset.to_u32)
          end

          # Parse MathVariants
          math_variants : MathVariants? = nil
          if math_variants_offset != 0
            math_variants = MathVariants.parse(data, math_variants_offset.to_u32)
          end

          new(version, math_constants, math_glyph_info, math_variants)
        end

        # Get a math constant value
        def constant(c : MathConstant) : Int16
          @math_constants.try(&.get(c)) || 0_i16
        end

        # Convenience methods for common constants
        def axis_height : Int16
          constant(MathConstant::AxisHeight)
        end

        def fraction_rule_thickness : Int16
          constant(MathConstant::FractionRuleThickness)
        end

        def overbar_rule_thickness : Int16
          constant(MathConstant::OverbarRuleThickness)
        end

        def underbar_rule_thickness : Int16
          constant(MathConstant::UnderbarRuleThickness)
        end

        def radical_rule_thickness : Int16
          constant(MathConstant::RadicalRuleThickness)
        end

        def subscript_shift_down : Int16
          constant(MathConstant::SubscriptShiftDown)
        end

        def superscript_shift_up : Int16
          constant(MathConstant::SuperscriptShiftUp)
        end

        def script_percent_scale_down : Int16
          constant(MathConstant::ScriptPercentScaleDown)
        end

        def script_script_percent_scale_down : Int16
          constant(MathConstant::ScriptScriptPercentScaleDown)
        end

        # Get italics correction for a glyph
        def italics_correction(glyph_id : UInt16) : Int16?
          @math_glyph_info.try(&.italics_correction(glyph_id))
        end

        # Get top accent attachment for a glyph
        def top_accent_attachment(glyph_id : UInt16) : Int16?
          @math_glyph_info.try(&.top_accent_attachment(glyph_id))
        end

        # Check if glyph is an extended shape
        def extended_shape?(glyph_id : UInt16) : Bool
          @math_glyph_info.try(&.extended_shape?(glyph_id)) || false
        end

        # Get math kern at specified corner and height
        def kern(glyph_id : UInt16, corner : MathKernCorner, height : Int16) : Int16
          @math_glyph_info.try(&.kern(glyph_id, corner, height)) || 0_i16
        end

        # Check if glyph has vertical variants
        def has_vertical_variants?(glyph_id : UInt16) : Bool
          @math_variants.try(&.has_vertical_variants?(glyph_id)) || false
        end

        # Check if glyph has horizontal variants
        def has_horizontal_variants?(glyph_id : UInt16) : Bool
          @math_variants.try(&.has_horizontal_variants?(glyph_id)) || false
        end

        # Get vertical variants for a glyph
        def vertical_variants(glyph_id : UInt16) : Array(MathGlyphVariant)?
          @math_variants.try(&.vertical_variants(glyph_id))
        end

        # Get horizontal variants for a glyph
        def horizontal_variants(glyph_id : UInt16) : Array(MathGlyphVariant)?
          @math_variants.try(&.horizontal_variants(glyph_id))
        end

        # Get vertical assembly for a glyph
        def vertical_assembly(glyph_id : UInt16) : GlyphAssembly?
          @math_variants.try(&.vertical_assembly(glyph_id))
        end

        # Get horizontal assembly for a glyph
        def horizontal_assembly(glyph_id : UInt16) : GlyphAssembly?
          @math_variants.try(&.horizontal_assembly(glyph_id))
        end

        # Get minimum connector overlap for glyph assemblies
        def min_connector_overlap : UInt16
          @math_variants.try(&.min_connector_overlap) || 0_u16
        end

        # Check if the table has math constants
        def has_constants? : Bool
          !@math_constants.nil?
        end

        # Check if the table has glyph info
        def has_glyph_info? : Bool
          !@math_glyph_info.nil?
        end

        # Check if the table has variants
        def has_variants? : Bool
          !@math_variants.nil?
        end

        extend IOHelpers
      end
    end
  end
end
