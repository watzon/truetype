module TrueType
  module Tables
    module Math
      # MathValueRecord contains a value and optional device table offset
      struct MathValueRecord
        include IOHelpers

        # The value in font design units
        getter value : Int16

        # Offset to device table (for size-specific adjustments)
        getter device_offset : UInt16

        def initialize(@value : Int16, @device_offset : UInt16 = 0)
        end

        def self.parse(io : IO::Memory) : MathValueRecord
          value = read_int16(io)
          device_offset = read_uint16(io)
          new(value, device_offset)
        end

        extend IOHelpers
      end

      # Enumeration of all math constants
      enum MathConstant
        # Percentage scaling for script level 1 (default: 80%)
        ScriptPercentScaleDown
        # Percentage scaling for script level 2 (default: 60%)
        ScriptScriptPercentScaleDown
        # Minimum height for delimited expressions
        DelimitedSubFormulaMinHeight
        # Minimum clearance at top/bottom of display expressions
        DisplayOperatorMinHeight
        # Height of math axis (fraction bar, etc.)
        MathLeading
        # Height of math axis above baseline
        AxisHeight
        # Height for accents (circumflex, etc.)
        AccentBaseHeight
        # Maximum height for flattened accents
        FlattenedAccentBaseHeight
        # Standard shift for subscripts
        SubscriptShiftDown
        # Minimum drop for subscripts
        SubscriptTopMax
        # Minimum gap between subscript and baseline
        SubscriptBaselineDropMin
        # Standard shift for superscripts
        SuperscriptShiftUp
        # Compressed shift for superscripts
        SuperscriptShiftUpCramped
        # Minimum drop for superscripts
        SuperscriptBottomMin
        # Minimum gap between superscript and baseline
        SuperscriptBaselineDropMax
        # Minimum gap between sub and superscript
        SubSuperscriptGapMin
        # Shift down of superscript when next to subscript
        SuperscriptBottomMaxWithSubscript
        # Extra space around raised/lowered bars
        SpaceAfterScript
        # Minimum shift up for upper limit of operator
        UpperLimitGapMin
        # Minimum distance from limit baseline to operator top
        UpperLimitBaselineRiseMin
        # Minimum shift down for lower limit of operator
        LowerLimitGapMin
        # Minimum distance from limit baseline to operator bottom
        LowerLimitBaselineDropMin
        # Minimum gap between numerator and rule
        StackTopShiftUp
        # Shift for display-style numerator
        StackTopDisplayStyleShiftUp
        # Minimum gap between denominator and rule
        StackBottomShiftDown
        # Shift for display-style denominator
        StackBottomDisplayStyleShiftDown
        # Minimum gap for stacked numerator/denominator
        StackGapMin
        # Minimum gap for display-style stacked
        StackDisplayStyleGapMin
        # Distance from baseline to top of bar
        StretchStackTopShiftUp
        # Distance from baseline to bottom of bar
        StretchStackBottomShiftDown
        # Minimum gap between bar and stacked elements
        StretchStackGapAboveMin
        # Minimum gap below bar for stacked elements
        StretchStackGapBelowMin
        # Shift for numerator in fractions
        FractionNumeratorShiftUp
        # Display-style shift for numerator
        FractionNumeratorDisplayStyleShiftUp
        # Shift for denominator in fractions
        FractionDenominatorShiftDown
        # Display-style shift for denominator
        FractionDenominatorDisplayStyleShiftDown
        # Minimum gap between numerator and bar
        FractionNumeratorGapMin
        # Display-style minimum gap
        FractionNumDisplayStyleGapMin
        # Thickness of fraction bar
        FractionRuleThickness
        # Minimum gap between bar and denominator
        FractionDenominatorGapMin
        # Display-style minimum gap
        FractionDenomDisplayStyleGapMin
        # Minimum gap for skewed fractions
        SkewedFractionHorizontalGap
        # Vertical gap for skewed fractions
        SkewedFractionVerticalGap
        # Minimum clearance between bar and overbar
        OverbarVerticalGap
        # Thickness of overbar
        OverbarRuleThickness
        # Extra white space above overbar
        OverbarExtraAscender
        # Minimum clearance between bar and underbar
        UnderbarVerticalGap
        # Thickness of underbar
        UnderbarRuleThickness
        # Extra white space below underbar
        UnderbarExtraDescender
        # Extra space above radical
        RadicalVerticalGap
        # Display-style extra space above radical
        RadicalDisplayStyleVerticalGap
        # Thickness of radical rule
        RadicalRuleThickness
        # Extra white space above radical rule
        RadicalExtraAscender
        # How far into radical the kern extends
        RadicalKernBeforeDegree
        # How far after degree the kern extends
        RadicalKernAfterDegree
        # Height of radical degree
        RadicalDegreeBottomRaisePercent
      end

      # The 51 math constants for typesetting
      class MathConstants
        include IOHelpers

        # Percentage values (stored as percentages, 0-100)
        getter script_percent_scale_down : Int16
        getter script_script_percent_scale_down : Int16

        # MathValueRecords for the remaining 49 constants
        getter delimited_sub_formula_min_height : MathValueRecord
        getter display_operator_min_height : MathValueRecord
        getter math_leading : MathValueRecord
        getter axis_height : MathValueRecord
        getter accent_base_height : MathValueRecord
        getter flattened_accent_base_height : MathValueRecord
        getter subscript_shift_down : MathValueRecord
        getter subscript_top_max : MathValueRecord
        getter subscript_baseline_drop_min : MathValueRecord
        getter superscript_shift_up : MathValueRecord
        getter superscript_shift_up_cramped : MathValueRecord
        getter superscript_bottom_min : MathValueRecord
        getter superscript_baseline_drop_max : MathValueRecord
        getter sub_superscript_gap_min : MathValueRecord
        getter superscript_bottom_max_with_subscript : MathValueRecord
        getter space_after_script : MathValueRecord
        getter upper_limit_gap_min : MathValueRecord
        getter upper_limit_baseline_rise_min : MathValueRecord
        getter lower_limit_gap_min : MathValueRecord
        getter lower_limit_baseline_drop_min : MathValueRecord
        getter stack_top_shift_up : MathValueRecord
        getter stack_top_display_style_shift_up : MathValueRecord
        getter stack_bottom_shift_down : MathValueRecord
        getter stack_bottom_display_style_shift_down : MathValueRecord
        getter stack_gap_min : MathValueRecord
        getter stack_display_style_gap_min : MathValueRecord
        getter stretch_stack_top_shift_up : MathValueRecord
        getter stretch_stack_bottom_shift_down : MathValueRecord
        getter stretch_stack_gap_above_min : MathValueRecord
        getter stretch_stack_gap_below_min : MathValueRecord
        getter fraction_numerator_shift_up : MathValueRecord
        getter fraction_numerator_display_style_shift_up : MathValueRecord
        getter fraction_denominator_shift_down : MathValueRecord
        getter fraction_denominator_display_style_shift_down : MathValueRecord
        getter fraction_numerator_gap_min : MathValueRecord
        getter fraction_num_display_style_gap_min : MathValueRecord
        getter fraction_rule_thickness : MathValueRecord
        getter fraction_denominator_gap_min : MathValueRecord
        getter fraction_denom_display_style_gap_min : MathValueRecord
        getter skewed_fraction_horizontal_gap : MathValueRecord
        getter skewed_fraction_vertical_gap : MathValueRecord
        getter overbar_vertical_gap : MathValueRecord
        getter overbar_rule_thickness : MathValueRecord
        getter overbar_extra_ascender : MathValueRecord
        getter underbar_vertical_gap : MathValueRecord
        getter underbar_rule_thickness : MathValueRecord
        getter underbar_extra_descender : MathValueRecord
        getter radical_vertical_gap : MathValueRecord
        getter radical_display_style_vertical_gap : MathValueRecord
        getter radical_rule_thickness : MathValueRecord
        getter radical_extra_ascender : MathValueRecord
        getter radical_kern_before_degree : MathValueRecord
        getter radical_kern_after_degree : MathValueRecord
        getter radical_degree_bottom_raise_percent : Int16

        def initialize(
          @script_percent_scale_down : Int16,
          @script_script_percent_scale_down : Int16,
          @delimited_sub_formula_min_height : MathValueRecord,
          @display_operator_min_height : MathValueRecord,
          @math_leading : MathValueRecord,
          @axis_height : MathValueRecord,
          @accent_base_height : MathValueRecord,
          @flattened_accent_base_height : MathValueRecord,
          @subscript_shift_down : MathValueRecord,
          @subscript_top_max : MathValueRecord,
          @subscript_baseline_drop_min : MathValueRecord,
          @superscript_shift_up : MathValueRecord,
          @superscript_shift_up_cramped : MathValueRecord,
          @superscript_bottom_min : MathValueRecord,
          @superscript_baseline_drop_max : MathValueRecord,
          @sub_superscript_gap_min : MathValueRecord,
          @superscript_bottom_max_with_subscript : MathValueRecord,
          @space_after_script : MathValueRecord,
          @upper_limit_gap_min : MathValueRecord,
          @upper_limit_baseline_rise_min : MathValueRecord,
          @lower_limit_gap_min : MathValueRecord,
          @lower_limit_baseline_drop_min : MathValueRecord,
          @stack_top_shift_up : MathValueRecord,
          @stack_top_display_style_shift_up : MathValueRecord,
          @stack_bottom_shift_down : MathValueRecord,
          @stack_bottom_display_style_shift_down : MathValueRecord,
          @stack_gap_min : MathValueRecord,
          @stack_display_style_gap_min : MathValueRecord,
          @stretch_stack_top_shift_up : MathValueRecord,
          @stretch_stack_bottom_shift_down : MathValueRecord,
          @stretch_stack_gap_above_min : MathValueRecord,
          @stretch_stack_gap_below_min : MathValueRecord,
          @fraction_numerator_shift_up : MathValueRecord,
          @fraction_numerator_display_style_shift_up : MathValueRecord,
          @fraction_denominator_shift_down : MathValueRecord,
          @fraction_denominator_display_style_shift_down : MathValueRecord,
          @fraction_numerator_gap_min : MathValueRecord,
          @fraction_num_display_style_gap_min : MathValueRecord,
          @fraction_rule_thickness : MathValueRecord,
          @fraction_denominator_gap_min : MathValueRecord,
          @fraction_denom_display_style_gap_min : MathValueRecord,
          @skewed_fraction_horizontal_gap : MathValueRecord,
          @skewed_fraction_vertical_gap : MathValueRecord,
          @overbar_vertical_gap : MathValueRecord,
          @overbar_rule_thickness : MathValueRecord,
          @overbar_extra_ascender : MathValueRecord,
          @underbar_vertical_gap : MathValueRecord,
          @underbar_rule_thickness : MathValueRecord,
          @underbar_extra_descender : MathValueRecord,
          @radical_vertical_gap : MathValueRecord,
          @radical_display_style_vertical_gap : MathValueRecord,
          @radical_rule_thickness : MathValueRecord,
          @radical_extra_ascender : MathValueRecord,
          @radical_kern_before_degree : MathValueRecord,
          @radical_kern_after_degree : MathValueRecord,
          @radical_degree_bottom_raise_percent : Int16
        )
        end

        def self.parse(io : IO::Memory) : MathConstants
          # First two are simple Int16 percentages
          script_percent_scale_down = read_int16(io)
          script_script_percent_scale_down = read_int16(io)

          # Rest are MathValueRecords (value + device offset)
          delimited_sub_formula_min_height = MathValueRecord.parse(io)
          display_operator_min_height = MathValueRecord.parse(io)
          math_leading = MathValueRecord.parse(io)
          axis_height = MathValueRecord.parse(io)
          accent_base_height = MathValueRecord.parse(io)
          flattened_accent_base_height = MathValueRecord.parse(io)
          subscript_shift_down = MathValueRecord.parse(io)
          subscript_top_max = MathValueRecord.parse(io)
          subscript_baseline_drop_min = MathValueRecord.parse(io)
          superscript_shift_up = MathValueRecord.parse(io)
          superscript_shift_up_cramped = MathValueRecord.parse(io)
          superscript_bottom_min = MathValueRecord.parse(io)
          superscript_baseline_drop_max = MathValueRecord.parse(io)
          sub_superscript_gap_min = MathValueRecord.parse(io)
          superscript_bottom_max_with_subscript = MathValueRecord.parse(io)
          space_after_script = MathValueRecord.parse(io)
          upper_limit_gap_min = MathValueRecord.parse(io)
          upper_limit_baseline_rise_min = MathValueRecord.parse(io)
          lower_limit_gap_min = MathValueRecord.parse(io)
          lower_limit_baseline_drop_min = MathValueRecord.parse(io)
          stack_top_shift_up = MathValueRecord.parse(io)
          stack_top_display_style_shift_up = MathValueRecord.parse(io)
          stack_bottom_shift_down = MathValueRecord.parse(io)
          stack_bottom_display_style_shift_down = MathValueRecord.parse(io)
          stack_gap_min = MathValueRecord.parse(io)
          stack_display_style_gap_min = MathValueRecord.parse(io)
          stretch_stack_top_shift_up = MathValueRecord.parse(io)
          stretch_stack_bottom_shift_down = MathValueRecord.parse(io)
          stretch_stack_gap_above_min = MathValueRecord.parse(io)
          stretch_stack_gap_below_min = MathValueRecord.parse(io)
          fraction_numerator_shift_up = MathValueRecord.parse(io)
          fraction_numerator_display_style_shift_up = MathValueRecord.parse(io)
          fraction_denominator_shift_down = MathValueRecord.parse(io)
          fraction_denominator_display_style_shift_down = MathValueRecord.parse(io)
          fraction_numerator_gap_min = MathValueRecord.parse(io)
          fraction_num_display_style_gap_min = MathValueRecord.parse(io)
          fraction_rule_thickness = MathValueRecord.parse(io)
          fraction_denominator_gap_min = MathValueRecord.parse(io)
          fraction_denom_display_style_gap_min = MathValueRecord.parse(io)
          skewed_fraction_horizontal_gap = MathValueRecord.parse(io)
          skewed_fraction_vertical_gap = MathValueRecord.parse(io)
          overbar_vertical_gap = MathValueRecord.parse(io)
          overbar_rule_thickness = MathValueRecord.parse(io)
          overbar_extra_ascender = MathValueRecord.parse(io)
          underbar_vertical_gap = MathValueRecord.parse(io)
          underbar_rule_thickness = MathValueRecord.parse(io)
          underbar_extra_descender = MathValueRecord.parse(io)
          radical_vertical_gap = MathValueRecord.parse(io)
          radical_display_style_vertical_gap = MathValueRecord.parse(io)
          radical_rule_thickness = MathValueRecord.parse(io)
          radical_extra_ascender = MathValueRecord.parse(io)
          radical_kern_before_degree = MathValueRecord.parse(io)
          radical_kern_after_degree = MathValueRecord.parse(io)
          # Last one is a simple Int16 percentage
          radical_degree_bottom_raise_percent = read_int16(io)

          new(
            script_percent_scale_down,
            script_script_percent_scale_down,
            delimited_sub_formula_min_height,
            display_operator_min_height,
            math_leading,
            axis_height,
            accent_base_height,
            flattened_accent_base_height,
            subscript_shift_down,
            subscript_top_max,
            subscript_baseline_drop_min,
            superscript_shift_up,
            superscript_shift_up_cramped,
            superscript_bottom_min,
            superscript_baseline_drop_max,
            sub_superscript_gap_min,
            superscript_bottom_max_with_subscript,
            space_after_script,
            upper_limit_gap_min,
            upper_limit_baseline_rise_min,
            lower_limit_gap_min,
            lower_limit_baseline_drop_min,
            stack_top_shift_up,
            stack_top_display_style_shift_up,
            stack_bottom_shift_down,
            stack_bottom_display_style_shift_down,
            stack_gap_min,
            stack_display_style_gap_min,
            stretch_stack_top_shift_up,
            stretch_stack_bottom_shift_down,
            stretch_stack_gap_above_min,
            stretch_stack_gap_below_min,
            fraction_numerator_shift_up,
            fraction_numerator_display_style_shift_up,
            fraction_denominator_shift_down,
            fraction_denominator_display_style_shift_down,
            fraction_numerator_gap_min,
            fraction_num_display_style_gap_min,
            fraction_rule_thickness,
            fraction_denominator_gap_min,
            fraction_denom_display_style_gap_min,
            skewed_fraction_horizontal_gap,
            skewed_fraction_vertical_gap,
            overbar_vertical_gap,
            overbar_rule_thickness,
            overbar_extra_ascender,
            underbar_vertical_gap,
            underbar_rule_thickness,
            underbar_extra_descender,
            radical_vertical_gap,
            radical_display_style_vertical_gap,
            radical_rule_thickness,
            radical_extra_ascender,
            radical_kern_before_degree,
            radical_kern_after_degree,
            radical_degree_bottom_raise_percent
          )
        end

        # Get a constant value by enum
        def get(constant : MathConstant) : Int16
          case constant
          when .script_percent_scale_down?
            @script_percent_scale_down
          when .script_script_percent_scale_down?
            @script_script_percent_scale_down
          when .delimited_sub_formula_min_height?
            @delimited_sub_formula_min_height.value
          when .display_operator_min_height?
            @display_operator_min_height.value
          when .math_leading?
            @math_leading.value
          when .axis_height?
            @axis_height.value
          when .accent_base_height?
            @accent_base_height.value
          when .flattened_accent_base_height?
            @flattened_accent_base_height.value
          when .subscript_shift_down?
            @subscript_shift_down.value
          when .subscript_top_max?
            @subscript_top_max.value
          when .subscript_baseline_drop_min?
            @subscript_baseline_drop_min.value
          when .superscript_shift_up?
            @superscript_shift_up.value
          when .superscript_shift_up_cramped?
            @superscript_shift_up_cramped.value
          when .superscript_bottom_min?
            @superscript_bottom_min.value
          when .superscript_baseline_drop_max?
            @superscript_baseline_drop_max.value
          when .sub_superscript_gap_min?
            @sub_superscript_gap_min.value
          when .superscript_bottom_max_with_subscript?
            @superscript_bottom_max_with_subscript.value
          when .space_after_script?
            @space_after_script.value
          when .upper_limit_gap_min?
            @upper_limit_gap_min.value
          when .upper_limit_baseline_rise_min?
            @upper_limit_baseline_rise_min.value
          when .lower_limit_gap_min?
            @lower_limit_gap_min.value
          when .lower_limit_baseline_drop_min?
            @lower_limit_baseline_drop_min.value
          when .stack_top_shift_up?
            @stack_top_shift_up.value
          when .stack_top_display_style_shift_up?
            @stack_top_display_style_shift_up.value
          when .stack_bottom_shift_down?
            @stack_bottom_shift_down.value
          when .stack_bottom_display_style_shift_down?
            @stack_bottom_display_style_shift_down.value
          when .stack_gap_min?
            @stack_gap_min.value
          when .stack_display_style_gap_min?
            @stack_display_style_gap_min.value
          when .stretch_stack_top_shift_up?
            @stretch_stack_top_shift_up.value
          when .stretch_stack_bottom_shift_down?
            @stretch_stack_bottom_shift_down.value
          when .stretch_stack_gap_above_min?
            @stretch_stack_gap_above_min.value
          when .stretch_stack_gap_below_min?
            @stretch_stack_gap_below_min.value
          when .fraction_numerator_shift_up?
            @fraction_numerator_shift_up.value
          when .fraction_numerator_display_style_shift_up?
            @fraction_numerator_display_style_shift_up.value
          when .fraction_denominator_shift_down?
            @fraction_denominator_shift_down.value
          when .fraction_denominator_display_style_shift_down?
            @fraction_denominator_display_style_shift_down.value
          when .fraction_numerator_gap_min?
            @fraction_numerator_gap_min.value
          when .fraction_num_display_style_gap_min?
            @fraction_num_display_style_gap_min.value
          when .fraction_rule_thickness?
            @fraction_rule_thickness.value
          when .fraction_denominator_gap_min?
            @fraction_denominator_gap_min.value
          when .fraction_denom_display_style_gap_min?
            @fraction_denom_display_style_gap_min.value
          when .skewed_fraction_horizontal_gap?
            @skewed_fraction_horizontal_gap.value
          when .skewed_fraction_vertical_gap?
            @skewed_fraction_vertical_gap.value
          when .overbar_vertical_gap?
            @overbar_vertical_gap.value
          when .overbar_rule_thickness?
            @overbar_rule_thickness.value
          when .overbar_extra_ascender?
            @overbar_extra_ascender.value
          when .underbar_vertical_gap?
            @underbar_vertical_gap.value
          when .underbar_rule_thickness?
            @underbar_rule_thickness.value
          when .underbar_extra_descender?
            @underbar_extra_descender.value
          when .radical_vertical_gap?
            @radical_vertical_gap.value
          when .radical_display_style_vertical_gap?
            @radical_display_style_vertical_gap.value
          when .radical_rule_thickness?
            @radical_rule_thickness.value
          when .radical_extra_ascender?
            @radical_extra_ascender.value
          when .radical_kern_before_degree?
            @radical_kern_before_degree.value
          when .radical_kern_after_degree?
            @radical_kern_after_degree.value
          when .radical_degree_bottom_raise_percent?
            @radical_degree_bottom_raise_percent
          else
            0_i16
          end
        end

        extend IOHelpers
      end
    end
  end
end
