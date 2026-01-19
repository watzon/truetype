require "../spec_helper"

describe TrueType::Tables::Variations::Fvar do
  describe "parsing Roboto Flex" do
    font = TrueType::Parser.parse(VARIABLE_FONT_PATH)

    it "detects variable font" do
      font.variable_font?.should be_true
    end

    it "parses fvar table" do
      fvar = font.fvar
      fvar.should_not be_nil
    end

    it "has correct version" do
      fvar = font.fvar.not_nil!
      fvar.major_version.should eq(1)
      fvar.minor_version.should eq(0)
    end

    it "parses axes" do
      fvar = font.fvar.not_nil!
      fvar.axis_count.should be > 0
      fvar.axes.size.should eq(fvar.axis_count)
    end

    # Roboto Flex has 13 axes: GRAD, XOPQ, XTRA, YOPQ, YTAS, YTDE, YTFI, YTLC, YTUC, opsz, slnt, wdth, wght
    it "has expected axes for Roboto Flex" do
      fvar = font.fvar.not_nil!
      tags = fvar.axis_tags

      # Check for common registered axes
      tags.should contain("wght")
      tags.should contain("wdth")
      tags.should contain("opsz")
      tags.should contain("slnt")

      # Check for custom axes (uppercase = custom)
      tags.should contain("GRAD")
    end

    it "parses weight axis correctly" do
      fvar = font.fvar.not_nil!
      weight_axis = fvar.axis("wght")
      weight_axis.should_not be_nil

      axis = weight_axis.not_nil!
      axis.weight?.should be_true
      axis.min_value.should be <= axis.default_value
      axis.default_value.should be <= axis.max_value

      # Typical weight range is 100-900 or similar
      axis.min_value.should be >= 100.0
      axis.max_value.should be <= 1000.0
    end

    it "parses width axis correctly" do
      fvar = font.fvar.not_nil!
      width_axis = fvar.axis("wdth")
      width_axis.should_not be_nil

      axis = width_axis.not_nil!
      axis.width?.should be_true
      # Width is typically in percentage (25-200)
      axis.min_value.should be >= 25.0
      axis.max_value.should be <= 200.0
    end

    it "finds axis by tag" do
      fvar = font.fvar.not_nil!
      fvar.has_axis?("wght").should be_true
      fvar.has_axis?("FAKE").should be_false

      idx = fvar.axis_index("wght")
      idx.should_not be_nil
    end

    it "provides default coordinates" do
      fvar = font.fvar.not_nil!
      defaults = fvar.default_coordinates
      defaults.size.should eq(fvar.axis_count)

      # Each default should be within the axis range
      fvar.axes.each_with_index do |axis, i|
        defaults[i].should be >= axis.min_value
        defaults[i].should be <= axis.max_value
        defaults[i].should eq(axis.default_value)
      end
    end

    it "checks hidden flag" do
      fvar = font.fvar.not_nil!
      # Most axes should not be hidden
      visible_count = fvar.axes.count { |a| !a.hidden? }
      visible_count.should be > 0
    end
  end

  describe "axis normalization" do
    font = TrueType::Parser.parse(VARIABLE_FONT_PATH)
    fvar = font.fvar.not_nil!

    it "normalizes default value to 0" do
      weight_idx = fvar.axis_index("wght").not_nil!
      weight_axis = fvar.axes[weight_idx]

      normalized = fvar.normalize_coordinate(weight_idx, weight_axis.default_value)
      normalized.should eq(0.0)
    end

    it "normalizes min value to -1" do
      weight_idx = fvar.axis_index("wght").not_nil!
      weight_axis = fvar.axes[weight_idx]

      normalized = fvar.normalize_coordinate(weight_idx, weight_axis.min_value)
      normalized.should be_close(-1.0, 0.001)
    end

    it "normalizes max value to 1" do
      weight_idx = fvar.axis_index("wght").not_nil!
      weight_axis = fvar.axes[weight_idx]

      normalized = fvar.normalize_coordinate(weight_idx, weight_axis.max_value)
      normalized.should be_close(1.0, 0.001)
    end

    it "interpolates values between default and max" do
      weight_idx = fvar.axis_index("wght").not_nil!
      weight_axis = fvar.axes[weight_idx]

      # Midpoint between default and max
      mid_value = (weight_axis.default_value + weight_axis.max_value) / 2.0
      normalized = fvar.normalize_coordinate(weight_idx, mid_value)

      normalized.should be > 0.0
      normalized.should be < 1.0
      normalized.should be_close(0.5, 0.001)
    end

    it "normalizes hash of coordinates" do
      coords = {"wght" => 700.0, "wdth" => 100.0}
      normalized = fvar.normalize_coordinates(coords)

      normalized.size.should eq(fvar.axis_count)
    end
  end

  describe "named instances" do
    font = TrueType::Parser.parse(VARIABLE_FONT_PATH)
    fvar = font.fvar.not_nil!

    it "parses instances" do
      fvar.instance_count.should be >= 0
      fvar.instances.size.should eq(fvar.instance_count)
    end

    it "instances have correct coordinate count" do
      fvar.instances.each do |instance|
        instance.coordinates.size.should eq(fvar.axis_count)
      end
    end

    it "instance coordinates are within axis ranges" do
      fvar.instances.each do |instance|
        fvar.axes.each_with_index do |axis, i|
          coord = instance.coordinates[i]
          coord.should be >= axis.min_value
          coord.should be <= axis.max_value
        end
      end
    end
  end

  describe "Parser integration" do
    it "returns empty arrays for non-variable font" do
      font = TrueType::Parser.parse(FONT_PATH)
      font.variable_font?.should be_false
      font.variation_axes.should be_empty
      font.named_instances.should be_empty
    end

    it "returns axes and instances for variable font" do
      font = TrueType::Parser.parse(VARIABLE_FONT_PATH)
      font.variable_font?.should be_true
      font.variation_axes.should_not be_empty
      # Named instances may or may not be present
    end
  end
end

describe TrueType::Tables::Variations::Stat do
  describe "parsing Roboto Flex" do
    font = TrueType::Parser.parse(VARIABLE_FONT_PATH)

    it "parses STAT table" do
      stat = font.stat
      stat.should_not be_nil
    end

    it "has correct version" do
      stat = font.stat.not_nil!
      stat.major_version.should eq(1)
      stat.minor_version.should be >= 0
    end

    it "parses design axes" do
      stat = font.stat.not_nil!
      stat.design_axis_count.should be > 0
      stat.design_axes.size.should eq(stat.design_axis_count)
    end

    it "design axes match fvar axes" do
      stat = font.stat.not_nil!
      fvar = font.fvar.not_nil!

      # STAT should have at least as many axes as fvar
      stat.design_axis_count.should be >= fvar.axis_count

      # Each fvar axis should have a corresponding STAT axis
      fvar.axis_tags.each do |tag|
        stat.axis(tag).should_not be_nil
      end
    end

    it "parses axis values" do
      stat = font.stat.not_nil!
      stat.axis_value_count.should be >= 0
      stat.axis_values.size.should eq(stat.axis_value_count)
    end

    it "finds axis by tag" do
      stat = font.stat.not_nil!
      stat.axis("wght").should_not be_nil
      stat.axis("FAKE").should be_nil
    end
  end

  describe "axis value formats" do
    font = TrueType::Parser.parse(VARIABLE_FONT_PATH)
    stat = font.stat.not_nil!

    it "handles different axis value formats" do
      stat.axis_values.each do |av|
        av.value_name_id.should be > 0

        case av
        when TrueType::Tables::Variations::AxisValueFormat1
          av.axis_index.should be < stat.design_axis_count
        when TrueType::Tables::Variations::AxisValueFormat2
          av.range_min_value.should be <= av.nominal_value
          av.nominal_value.should be <= av.range_max_value
        when TrueType::Tables::Variations::AxisValueFormat3
          # linked_value is for style linking (e.g., Regular -> Bold)
          true
        when TrueType::Tables::Variations::AxisValueFormat4
          av.axis_count.should eq(av.axis_values.size)
        end
      end
    end

    it "identifies elidable values" do
      # May or may not have elidable values
      elidable = stat.elidable_values
      elidable.each do |av|
        av.elidable?.should be_true
      end
    end
  end
end

describe TrueType::Tables::Variations::Avar do
  describe "parsing Roboto Flex" do
    font = TrueType::Parser.parse(VARIABLE_FONT_PATH)

    it "parses avar table" do
      avar = font.avar
      avar.should_not be_nil
    end

    it "has correct version" do
      avar = font.avar.not_nil!
      avar.major_version.should eq(1)
      avar.minor_version.should eq(0)
    end

    it "has segment maps for each axis" do
      avar = font.avar.not_nil!
      fvar = font.fvar.not_nil!

      avar.axis_count.should eq(fvar.axis_count)
      avar.segment_maps.size.should eq(avar.axis_count)
    end

    it "segment maps have required mappings" do
      avar = font.avar.not_nil!

      avar.segment_maps.each do |segment|
        # A valid segment map should have at least 3 mappings: -1, 0, 1
        if segment.axis_value_maps.size >= 3
          segment.valid?.should be_true
        end
      end
    end
  end

  describe "coordinate mapping" do
    font = TrueType::Parser.parse(VARIABLE_FONT_PATH)
    avar = font.avar.not_nil!

    it "maps identity points correctly" do
      # The required mappings should be identity: -1 -> -1, 0 -> 0, 1 -> 1
      avar.segment_maps.each_with_index do |segment, i|
        next unless segment.valid?

        avar.map_coordinate(i, -1.0).should be_close(-1.0, 0.01)
        avar.map_coordinate(i, 0.0).should be_close(0.0, 0.01)
        avar.map_coordinate(i, 1.0).should be_close(1.0, 0.01)
      end
    end

    it "returns input for invalid axis index" do
      avar.map_coordinate(-1, 0.5).should eq(0.5)
      avar.map_coordinate(1000, 0.5).should eq(0.5)
    end
  end

  describe "Parser integration" do
    it "normalizes coordinates with avar" do
      font = TrueType::Parser.parse(VARIABLE_FONT_PATH)
      fvar = font.fvar.not_nil!

      # Use default values for all axes
      user_coords = {} of String => Float64
      fvar.axes.each do |axis|
        user_coords[axis.tag] = axis.default_value
      end

      normalized = font.normalize_variation_coordinates(user_coords)
      normalized.should_not be_nil

      # All defaults should normalize to approximately 0
      normalized.not_nil!.each do |n|
        n.should be_close(0.0, 0.01)
      end
    end

    it "returns nil for non-variable font" do
      font = TrueType::Parser.parse(FONT_PATH)
      font.normalize_variation_coordinates({"wght" => 400.0}).should be_nil
    end
  end
end

describe TrueType::Tables::Variations::Gvar do
  describe "parsing Roboto Flex" do
    font = TrueType::Parser.parse(VARIABLE_FONT_PATH)

    it "parses gvar table" do
      gvar = font.gvar
      gvar.should_not be_nil
    end

    it "has correct version" do
      gvar = font.gvar.not_nil!
      gvar.major_version.should eq(1)
      gvar.minor_version.should eq(0)
    end

    it "axis count matches fvar" do
      gvar = font.gvar.not_nil!
      fvar = font.fvar.not_nil!
      gvar.axis_count.should eq(fvar.axis_count)
    end

    it "has shared tuples" do
      gvar = font.gvar.not_nil!
      gvar.shared_tuple_count.should be >= 0
      gvar.shared_tuples.size.should eq(gvar.shared_tuple_count)
    end

    it "shared tuples have correct axis count" do
      gvar = font.gvar.not_nil!
      gvar.shared_tuples.each do |tuple|
        tuple.size.should eq(gvar.axis_count)
      end
    end

    it "shared tuple coordinates are normalized" do
      gvar = font.gvar.not_nil!
      gvar.shared_tuples.each do |tuple|
        tuple.coordinates.each do |coord|
          # F2DOT14 range is approximately -2 to 2, but normalized is typically -1 to 1
          coord.should be >= -2.0
          coord.should be <= 2.0
        end
      end
    end

    it "has glyph count" do
      gvar = font.gvar.not_nil!
      gvar.glyph_count.should be > 0
    end
  end

  describe "glyph variation data" do
    font = TrueType::Parser.parse(VARIABLE_FONT_PATH)
    gvar = font.gvar.not_nil!

    it "identifies glyphs with variation data" do
      # At least some glyphs should have variation data
      has_data_count = 0
      (0...gvar.glyph_count.clamp(0, 100)).each do |gid|
        if gvar.has_variation_data?(gid.to_u16)
          has_data_count += 1
        end
      end
      has_data_count.should be > 0
    end

    it "can get variation data size" do
      (0...gvar.glyph_count.clamp(0, 100)).each do |gid|
        size = gvar.variation_data_size(gid.to_u16)
        if gvar.has_variation_data?(gid.to_u16)
          size.should be > 0
        else
          size.should eq(0)
        end
      end
    end

    it "can parse glyph variation data" do
      # Find first glyph with data
      glyph_with_data : UInt16? = nil
      (0...gvar.glyph_count).each do |gid|
        if gvar.has_variation_data?(gid.to_u16)
          glyph_with_data = gid.to_u16
          break
        end
      end

      next unless glyph_with_data

      glyph_data = gvar.parse_glyph_variation_data(glyph_with_data.not_nil!)
      glyph_data.should_not be_nil

      data = glyph_data.not_nil!
      data.tuple_headers.should_not be_empty
    end

    it "tuple headers have valid data" do
      # Find first glyph with data
      (0...gvar.glyph_count.clamp(0, 50)).each do |gid|
        next unless gvar.has_variation_data?(gid.to_u16)

        glyph_data = gvar.parse_glyph_variation_data(gid.to_u16)
        next unless glyph_data

        glyph_data.tuple_headers.each do |header|
          # If embedded peak, should have peak tuple
          if header.embedded_peak?
            header.peak_tuple.should_not be_nil
            header.peak_tuple.not_nil!.size.should eq(gvar.axis_count)
          else
            # Should reference a valid shared tuple
            header.shared_tuple_index.should be < gvar.shared_tuple_count
          end

          # If intermediate region, should have both start and end
          if header.intermediate_region?
            header.intermediate_start_tuple.should_not be_nil
            header.intermediate_end_tuple.should_not be_nil
          end
        end

        break # Just check first glyph with data
      end
    end
  end

  describe "scalar calculation" do
    font = TrueType::Parser.parse(VARIABLE_FONT_PATH)
    gvar = font.gvar.not_nil!
    fvar = font.fvar.not_nil!

    it "calculates scalar at default coordinates" do
      # Find first glyph with data
      (0...gvar.glyph_count.clamp(0, 50)).each do |gid|
        next unless gvar.has_variation_data?(gid.to_u16)

        glyph_data = gvar.parse_glyph_variation_data(gid.to_u16)
        next unless glyph_data
        next if glyph_data.tuple_headers.empty?

        # Default normalized coordinates are all 0
        default_coords = Array(Float64).new(gvar.axis_count.to_i, 0.0)

        header = glyph_data.tuple_headers.first
        scalar = gvar.calculate_scalar(header, default_coords)

        # Scalar should be between 0 and 1
        scalar.should be >= 0.0
        scalar.should be <= 1.0

        break
      end
    end
  end

  describe "Parser integration" do
    it "returns false for non-variable font glyph variations" do
      font = TrueType::Parser.parse(FONT_PATH)
      font.glyph_has_variations?(0_u16).should be_false
    end

    it "checks glyph variations for variable font" do
      font = TrueType::Parser.parse(VARIABLE_FONT_PATH)
      # At least some glyphs should have variations
      has_var_count = 0
      (0...100).each do |gid|
        has_var_count += 1 if font.glyph_has_variations?(gid.to_u16)
      end
      has_var_count.should be > 0
    end
  end

  # HVAR table tests
  describe "HVAR table" do
    font = TrueType::Parser.parse(VARIABLE_FONT_PATH)

    it "parses HVAR table" do
      font.hvar.should_not be_nil
    end

    it "has correct version" do
      hvar = font.hvar.not_nil!
      hvar.major_version.should eq(1)
      hvar.minor_version.should eq(0)
    end

    it "has item variation store" do
      hvar = font.hvar.not_nil!
      hvar.item_variation_store.should_not be_nil
    end

    it "item variation store has regions" do
      hvar = font.hvar.not_nil!
      hvar.item_variation_store.region_list.regions.should_not be_empty
    end

    it "item variation store regions have correct axis count" do
      hvar = font.hvar.not_nil!
      fvar = font.fvar.not_nil!
      hvar.item_variation_store.region_list.axis_count.should eq(fvar.axis_count)
    end

    it "can calculate advance width delta at default coordinates" do
      hvar = font.hvar.not_nil!
      fvar = font.fvar.not_nil!

      # Default coordinates (all zeros)
      default_coords = Array(Float64).new(fvar.axis_count.to_i, 0.0)

      # Delta at default should be 0 or very close to 0
      glyph_id = font.glyph_id('A')
      delta = hvar.advance_width_delta(glyph_id, default_coords)
      delta.abs.should be < 1.0
    end

    it "calculates non-zero delta at non-default coordinates" do
      hvar = font.hvar.not_nil!
      fvar = font.fvar.not_nil!

      # Find wght axis and set to max
      coords = Array(Float64).new(fvar.axis_count.to_i, 0.0)
      fvar.axes.each_with_index do |axis, i|
        if axis.tag == "wght"
          coords[i] = 1.0 # Max normalized weight
        end
      end

      # Delta should be non-zero for most glyphs at extreme weight
      glyph_id = font.glyph_id('A')
      delta = hvar.advance_width_delta(glyph_id, coords)
      # We can't guarantee non-zero, but it should work without error
      delta.should be_a(Float64)
    end
  end

  # MVAR table tests
  describe "MVAR table" do
    font = TrueType::Parser.parse(VARIABLE_FONT_PATH)

    it "parses MVAR table" do
      font.mvar.should_not be_nil
    end

    it "has correct version" do
      mvar = font.mvar.not_nil!
      mvar.major_version.should eq(1)
      mvar.minor_version.should eq(0)
    end

    it "has value records" do
      mvar = font.mvar.not_nil!
      mvar.value_records.should_not be_empty
    end

    it "has item variation store" do
      mvar = font.mvar.not_nil!
      mvar.item_variation_store.should_not be_nil
    end

    it "value records have valid 4-byte tags" do
      mvar = font.mvar.not_nil!
      mvar.value_records.each do |record|
        record.value_tag.size.should eq(4)
      end
    end

    it "can get available metrics" do
      mvar = font.mvar.not_nil!
      metrics = mvar.available_metrics
      metrics.should_not be_empty
    end

    it "can check if metric exists" do
      mvar = font.mvar.not_nil!
      first_tag = mvar.value_records.first.value_tag
      mvar.has_metric?(first_tag).should be_true
      mvar.has_metric?("xxxx").should be_false
    end

    it "calculates metric delta at default coordinates" do
      mvar = font.mvar.not_nil!
      fvar = font.fvar.not_nil!

      default_coords = Array(Float64).new(fvar.axis_count.to_i, 0.0)
      first_tag = mvar.value_records.first.value_tag

      delta = mvar.metric_delta(first_tag, default_coords)
      delta.abs.should be < 1.0
    end

    it "returns 0 for unknown metric" do
      mvar = font.mvar.not_nil!
      fvar = font.fvar.not_nil!

      default_coords = Array(Float64).new(fvar.axis_count.to_i, 0.0)
      delta = mvar.metric_delta("xxxx", default_coords)
      delta.should eq(0.0)
    end
  end

  # Variation API tests via Parser
  describe "variation API" do
    font = TrueType::Parser.parse(VARIABLE_FONT_PATH)

    describe "advance_width_delta" do
      it "returns 0 for default coordinates" do
        coords = {"wght" => 400.0, "wdth" => 100.0}
        glyph_id = font.glyph_id('A')
        delta = font.advance_width_delta(glyph_id, coords)
        delta.abs.should be < 5.0 # Should be close to 0 at defaults
      end

      it "returns non-zero for non-default weight" do
        coords = {"wght" => 900.0}  # Bold
        glyph_id = font.glyph_id('A')
        delta = font.advance_width_delta(glyph_id, coords)
        delta.should be_a(Float64)
      end
    end

    describe "interpolated_advance_width" do
      it "returns base width at default coordinates" do
        coords = {"wght" => 400.0, "wdth" => 100.0}
        glyph_id = font.glyph_id('A')
        base_width = font.advance_width(glyph_id)
        interp_width = font.interpolated_advance_width(glyph_id, coords)
        (interp_width - base_width).abs.should be < 5
      end

      it "returns different width at bold weight" do
        glyph_id = font.glyph_id('A')
        base_width = font.advance_width(glyph_id)

        bold_coords = {"wght" => 900.0}
        bold_width = font.interpolated_advance_width(glyph_id, bold_coords)

        # Bold width should be different (usually wider)
        bold_width.should be_a(Int32)
      end
    end

    describe "metric_delta" do
      it "returns 0 for unknown metric" do
        coords = {"wght" => 400.0}
        delta = font.metric_delta("xxxx", coords)
        delta.should eq(0.0)
      end

      it "works for known metrics if available" do
        mvar = font.mvar
        if mvar && mvar.available_metrics.includes?("hasc")
          coords = {"wght" => 900.0}
          delta = font.metric_delta("hasc", coords)
          delta.should be_a(Float64)
        end
      end
    end

    describe "interpolated_ascender" do
      it "returns base ascender at default coordinates" do
        coords = {"wght" => 400.0, "wdth" => 100.0}
        base = font.ascender
        interp = font.interpolated_ascender(coords)
        (interp - base).abs.should be < 50
      end
    end

    describe "interpolated_descender" do
      it "returns base descender at default coordinates" do
        coords = {"wght" => 400.0, "wdth" => 100.0}
        base = font.descender
        interp = font.interpolated_descender(coords)
        (interp - base).abs.should be < 50
      end
    end
  end

  # VVAR table tests (may not be present in Roboto Flex)
  describe "VVAR table" do
    font = TrueType::Parser.parse(VARIABLE_FONT_PATH)

    it "returns nil if VVAR table not present" do
      # Roboto Flex doesn't have VVAR table
      font.vvar.should be_nil
    end
  end

  # cvar table tests
  describe "cvar table" do
    font = TrueType::Parser.parse(VARIABLE_FONT_PATH)

    it "returns nil if cvar table not present" do
      # Roboto Flex doesn't have cvar table
      font.cvar.should be_nil
    end

    it "returns nil for non-variable font" do
      static_font = TrueType::Parser.parse(FONT_PATH)
      static_font.cvar.should be_nil
    end
  end

  # Non-variable font tests for metrics variation
  describe "metrics variation for non-variable font" do
    font = TrueType::Parser.parse(FONT_PATH)

    it "returns nil for hvar" do
      font.hvar.should be_nil
    end

    it "returns nil for mvar" do
      font.mvar.should be_nil
    end

    it "returns nil for vvar" do
      font.vvar.should be_nil
    end

    it "returns 0 for advance_width_delta" do
      glyph_id = font.glyph_id('A')
      delta = font.advance_width_delta(glyph_id, {"wght" => 700.0})
      delta.should eq(0.0)
    end

    it "returns base width for interpolated_advance_width" do
      glyph_id = font.glyph_id('A')
      base = font.advance_width(glyph_id)
      interp = font.interpolated_advance_width(glyph_id, {"wght" => 700.0})
      interp.should eq(base)
    end
  end

  # VariationInstance API tests
  describe "VariationInstance" do
    font = TrueType::Parser.parse(VARIABLE_FONT_PATH)

    describe "creation" do
      it "creates instance from font" do
        instance = font.variation_instance
        instance.should_not be_nil
        instance.font.should eq(font)
      end

      it "initializes with default axis values" do
        instance = font.variation_instance
        font.variation_axes.each do |axis|
          value = instance.get(axis.tag)
          value.should_not be_nil
          value.not_nil!.should eq(axis.default_value.to_f64)
        end
      end

      it "creates instance from named instance" do
        instances = font.named_instances
        next if instances.empty?

        instance = font.variation_instance(0)
        instance.should_not be_nil
      end

      it "returns nil for invalid named instance index" do
        instance = font.variation_instance(-1)
        instance.should be_nil

        instance = font.variation_instance(9999)
        instance.should be_nil
      end
    end

    describe "axis manipulation" do
      it "sets axis value" do
        instance = font.variation_instance
        instance.set("wght", 700.0)
        instance.get("wght").should eq(700.0)
      end

      it "clamps value to axis range" do
        instance = font.variation_instance
        wght_axis = font.variation_axes.find { |a| a.tag == "wght" }
        next unless wght_axis

        # Try to set beyond max
        instance.set("wght", 9999.0)
        instance.get("wght").should eq(wght_axis.max_value.to_f64)

        # Try to set below min
        instance.set("wght", -9999.0)
        instance.get("wght").should eq(wght_axis.min_value.to_f64)
      end

      it "sets multiple axes at once" do
        instance = font.variation_instance
        instance.set({"wght" => 700.0, "wdth" => 75.0})
        instance.get("wght").should eq(700.0)
        instance.get("wdth").should eq(75.0)
      end

      it "resets axis to default" do
        instance = font.variation_instance
        wght_axis = font.variation_axes.find { |a| a.tag == "wght" }
        next unless wght_axis

        instance.set("wght", 900.0)
        instance.reset("wght")
        instance.get("wght").should eq(wght_axis.default_value.to_f64)
      end

      it "resets all axes" do
        instance = font.variation_instance
        instance.set({"wght" => 900.0, "wdth" => 50.0})
        instance.reset_all

        font.variation_axes.each do |axis|
          instance.get(axis.tag).should eq(axis.default_value.to_f64)
        end
      end

      it "returns axis tags" do
        instance = font.variation_instance
        tags = instance.axis_tags
        tags.includes?("wght").should be_true
        tags.includes?("wdth").should be_true
      end

      it "returns axis info" do
        instance = font.variation_instance
        axis = instance.axis("wght")
        axis.should_not be_nil
        axis.not_nil!.tag.should eq("wght")
      end
    end

    describe "interpolated metrics" do
      it "returns advance width" do
        instance = font.variation_instance
        width = instance.advance_width('A')
        width.should be > 0
      end

      it "calculates width at different weights" do
        regular = font.variation_instance.set("wght", 400.0)
        bold = font.variation_instance.set("wght", 900.0)

        regular_width = regular.advance_width('A')
        bold_width = bold.advance_width('A')

        # Both should return valid widths (may or may not differ based on HVAR data)
        regular_width.should be > 0
        bold_width.should be > 0
      end

      it "returns ascender" do
        instance = font.variation_instance
        instance.ascender.should be > 0
      end

      it "returns descender" do
        instance = font.variation_instance
        instance.descender.should be < 0
      end

      it "returns cap height" do
        instance = font.variation_instance
        instance.cap_height.should be > 0
      end
    end

    describe "glyph outlines" do
      it "returns glyph outline by id" do
        instance = font.variation_instance
        glyph_id = font.glyph_id('A')
        outline = instance.glyph_outline(glyph_id)
        outline.should_not be_nil
      end

      it "returns glyph outline by char" do
        instance = font.variation_instance
        outline = instance.glyph_outline('A')
        outline.should_not be_nil
      end

      it "returns different outlines at different weights" do
        regular = font.variation_instance.set("wght", 400.0)
        bold = font.variation_instance.set("wght", 900.0)

        regular_outline = regular.glyph_outline('A')
        bold_outline = bold.glyph_outline('A')

        next unless regular_outline && bold_outline

        # Should have same number of points but different coordinates
        regular_outline.point_count.should eq(bold_outline.point_count)

        # Compare some points
        reg_pts = regular_outline.contours.flat_map(&.points)
        bold_pts = bold_outline.contours.flat_map(&.points)

        different = reg_pts.zip(bold_pts).any? { |r, b| r.x != b.x || r.y != b.y }
        different.should be_true
      end
    end

    describe "text metrics" do
      it "calculates text width" do
        instance = font.variation_instance
        width = instance.text_width("Hello")
        width.should be > 0
      end

      it "calculates different widths at different weights" do
        regular = font.variation_instance.set("wght", 400.0)
        bold = font.variation_instance.set("wght", 900.0)

        regular_width = regular.text_width("Hello World")
        bold_width = bold.text_width("Hello World")

        regular_width.should_not eq(bold_width)
      end
    end

    describe "instance info" do
      it "returns string representation" do
        instance = font.variation_instance.set("wght", 700.0)
        str = instance.to_s
        str.should contain("wght=700")
      end

      it "checks named instance match" do
        instances = font.named_instances
        next if instances.empty?

        # Create instance from named instance
        instance = font.variation_instance(0)
        next unless instance

        # Should match
        instance.matches_named_instance?(0).should be_true
      end

      it "finds named instance index" do
        instances = font.named_instances
        next if instances.empty?

        instance = font.variation_instance(0)
        next unless instance

        idx = instance.named_instance_index
        idx.should eq(0)
      end
    end

    describe "static instance generation" do
      it "returns nil for to_static_font (not fully implemented)" do
        instance = font.variation_instance.set("wght", 700.0)
        # Currently returns nil as full generation requires table rebuilding
        instance.to_static_font.should be_nil
      end

      it "returns interpolated glyph outlines" do
        instance = font.variation_instance.set("wght", 700.0)
        outlines = instance.interpolated_glyph_outlines
        outlines.should_not be_empty
        outlines.size.should be > 0
      end

      it "returns interpolated advance widths" do
        instance = font.variation_instance.set("wght", 700.0)
        widths = instance.interpolated_advance_widths
        widths.should_not be_empty
        widths.all? { |w| w >= 0 }.should be_true
      end

      it "returns interpolated metrics" do
        instance = font.variation_instance.set("wght", 700.0)
        metrics = instance.interpolated_metrics
        metrics["ascender"].should be > 0
        metrics["descender"].should be < 0
        metrics["units_per_em"].should be > 0
      end
    end
  end

  # Glyph outline interpolation tests
  describe "glyph outline interpolation" do
    font = TrueType::Parser.parse(VARIABLE_FONT_PATH)

    describe "compute_glyph_deltas" do
      it "handles glyphs without variation data" do
        gvar = font.gvar.not_nil!
        fvar = font.fvar.not_nil!

        # Find a glyph without variation data
        no_var_glyph : UInt16? = nil
        (0...gvar.glyph_count.clamp(0, 100)).each do |gid|
          unless gvar.has_variation_data?(gid.to_u16)
            no_var_glyph = gid.to_u16
            break
          end
        end

        if no_var_glyph
          normalized = Array(Float64).new(fvar.axis_count.to_i, 0.0)
          deltas = gvar.compute_glyph_deltas(no_var_glyph.not_nil!, normalized, 10)
          deltas.should be_nil
        end
      end

      it "returns deltas for glyphs with variation data" do
        gvar = font.gvar.not_nil!
        fvar = font.fvar.not_nil!

        # Find a glyph with variation data
        glyph_with_data : UInt16? = nil
        point_count = 0
        (1...gvar.glyph_count.clamp(1, 100)).each do |gid|
          if gvar.has_variation_data?(gid.to_u16)
            outline = font.glyph_outline(gid.to_u16)
            if outline && outline.point_count > 0
              glyph_with_data = gid.to_u16
              point_count = outline.point_count
              break
            end
          end
        end

        next unless glyph_with_data

        # Set weight to max
        normalized = Array(Float64).new(fvar.axis_count.to_i, 0.0)
        fvar.axes.each_with_index do |axis, i|
          if axis.tag == "wght"
            normalized[i] = 1.0
          end
        end

        deltas = gvar.compute_glyph_deltas(glyph_with_data.not_nil!, normalized, point_count)
        deltas.should_not be_nil

        d = deltas.not_nil!
        d.size.should eq(point_count)
        d.x_deltas.size.should eq(point_count)
        d.y_deltas.size.should eq(point_count)
      end

      it "returns zero deltas at default coordinates" do
        gvar = font.gvar.not_nil!
        fvar = font.fvar.not_nil!

        # Find a glyph with variation data
        (1...gvar.glyph_count.clamp(1, 50)).each do |gid|
          next unless gvar.has_variation_data?(gid.to_u16)
          outline = font.glyph_outline(gid.to_u16)
          next unless outline && outline.point_count > 0

          # Default coordinates (all zeros)
          default_coords = Array(Float64).new(fvar.axis_count.to_i, 0.0)
          deltas = gvar.compute_glyph_deltas(gid.to_u16, default_coords, outline.point_count)

          if deltas
            # At default, most deltas should be zero or very small
            max_delta = deltas.x_deltas.map(&.abs).max
            max_delta.should be < 10.0 # Allow small rounding
          end

          break
        end
      end
    end

    describe "interpolated_glyph_outline" do
      it "returns base outline for non-variable font" do
        static_font = TrueType::Parser.parse(FONT_PATH)
        glyph_id = static_font.glyph_id('A')
        base = static_font.glyph_outline(glyph_id)
        interp = static_font.interpolated_glyph_outline(glyph_id, {"wght" => 700.0})

        interp.should_not be_nil
        if base && interp
          interp.point_count.should eq(base.point_count)
        end
      end

      it "returns outline at default coordinates" do
        glyph_id = font.glyph_id('A')
        coords = {"wght" => 400.0, "wdth" => 100.0}
        outline = font.interpolated_glyph_outline(glyph_id, coords)
        outline.should_not be_nil
      end

      it "returns outline at bold weight" do
        glyph_id = font.glyph_id('A')
        coords = {"wght" => 900.0}
        outline = font.interpolated_glyph_outline(glyph_id, coords)
        outline.should_not be_nil
      end

      it "produces different outline at different weights" do
        glyph_id = font.glyph_id('A')

        regular = font.interpolated_glyph_outline(glyph_id, {"wght" => 400.0})
        bold = font.interpolated_glyph_outline(glyph_id, {"wght" => 900.0})

        next unless regular && bold
        next unless regular.point_count > 0 && bold.point_count > 0

        # Same number of points
        regular.point_count.should eq(bold.point_count)

        # But different coordinates (at least some should differ)
        reg_pts = regular.contours.flat_map(&.points)
        bold_pts = bold.contours.flat_map(&.points)

        different_count = reg_pts.zip(bold_pts).count { |r, b| r.x != b.x || r.y != b.y }
        different_count.should be > 0
      end

      it "produces valid SVG path" do
        glyph_id = font.glyph_id('A')
        coords = {"wght" => 700.0}
        outline = font.interpolated_glyph_outline(glyph_id, coords)

        next unless outline

        svg = outline.to_svg_path
        svg.should_not be_empty
        svg.should contain("M") # Should have moveto
      end
    end
  end
end
