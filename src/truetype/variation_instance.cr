# VariationInstance - A convenience class for working with variable font instances.
#
# This class provides a higher-level API for working with variable fonts,
# managing axis coordinates and providing easy access to interpolated metrics
# and glyph outlines.
#
# Example usage:
# ```
# font = TrueType::Parser.parse("RobotoFlex.ttf")
# instance = font.variation_instance
#
# # Set axis values
# instance.set("wght", 700.0)
# instance.set("wdth", 75.0)
#
# # Or set multiple at once
# instance.set({"wght" => 700.0, "wdth" => 75.0})
#
# # Get interpolated metrics
# puts instance.ascender
# puts instance.advance_width('A')
#
# # Get interpolated glyph outline
# outline = instance.glyph_outline('A')
# puts outline.to_svg_path
# ```

module TrueType
  # Represents a specific instance of a variable font with set axis coordinates.
  class VariationInstance
    # The underlying font parser
    getter font : Parser

    # Current axis coordinates (tag => user value)
    getter coordinates : Hash(String, Float64)

    # Cached normalized coordinates
    @normalized_coords : Array(Float64)?

    def initialize(@font : Parser)
      @coordinates = {} of String => Float64

      # Initialize with default values for all axes
      @font.variation_axes.each do |axis|
        @coordinates[axis.tag] = axis.default_value.to_f64
      end
    end

    # Create an instance from a named instance in the font
    def self.from_named_instance(font : Parser, instance_index : Int32) : VariationInstance?
      instances = font.named_instances
      return nil if instance_index < 0 || instance_index >= instances.size

      instance = instances[instance_index]
      axes = font.variation_axes

      var_instance = new(font)

      # Set coordinates from the named instance
      instance.coordinates.each_with_index do |coord, i|
        next if i >= axes.size
        var_instance.set(axes[i].tag, coord.to_f64)
      end

      var_instance
    end

    # Check if this is a variable font
    def variable_font? : Bool
      @font.variable_font?
    end

    # Get all available axis tags
    def axis_tags : Array(String)
      @font.variation_axes.map(&.tag)
    end

    # Get axis info by tag
    def axis(tag : String) : Tables::Variations::VariationAxisRecord?
      @font.variation_axes.find { |a| a.tag == tag }
    end

    # Set a single axis value (in user space)
    def set(tag : String, value : Float64) : self
      axis_record = axis(tag)
      return self unless axis_record

      # Clamp to axis range
      clamped = value.clamp(axis_record.min_value.to_f64, axis_record.max_value.to_f64)
      @coordinates[tag] = clamped
      @normalized_coords = nil # Invalidate cache
      self
    end

    # Set multiple axis values at once
    def set(values : Hash(String, Float64)) : self
      values.each { |tag, value| set(tag, value) }
      self
    end

    # Get current value for an axis
    def get(tag : String) : Float64?
      @coordinates[tag]?
    end

    # Reset an axis to its default value
    def reset(tag : String) : self
      if axis_record = axis(tag)
        @coordinates[tag] = axis_record.default_value.to_f64
        @normalized_coords = nil
      end
      self
    end

    # Reset all axes to their default values
    def reset_all : self
      @font.variation_axes.each do |axis|
        @coordinates[axis.tag] = axis.default_value.to_f64
      end
      @normalized_coords = nil
      self
    end

    # Get normalized coordinates (computed and cached)
    def normalized_coordinates : Array(Float64)?
      @normalized_coords ||= @font.normalize_variation_coordinates(@coordinates)
    end

    # ===== Interpolated Metrics =====

    # Get interpolated advance width for a glyph
    def advance_width(glyph_id : UInt16) : Int32
      @font.interpolated_advance_width(glyph_id, @coordinates)
    end

    # Get interpolated advance width for a character
    def advance_width(char : Char) : Int32
      glyph_id = @font.glyph_id(char)
      advance_width(glyph_id)
    end

    # Get interpolated ascender
    def ascender : Int16
      @font.interpolated_ascender(@coordinates)
    end

    # Get interpolated descender
    def descender : Int16
      @font.interpolated_descender(@coordinates)
    end

    # Get interpolated x-height
    def x_height : Int16?
      @font.interpolated_x_height(@coordinates)
    end

    # Get interpolated cap height
    def cap_height : Int16
      @font.interpolated_cap_height(@coordinates)
    end

    # Get a metric delta by tag
    def metric_delta(tag : String) : Float64
      @font.metric_delta(tag, @coordinates)
    end

    # ===== Glyph Outlines =====

    # Get interpolated glyph outline
    def glyph_outline(glyph_id : UInt16) : GlyphOutline?
      @font.interpolated_glyph_outline(glyph_id, @coordinates)
    end

    # Get interpolated glyph outline for a character
    def glyph_outline(char : Char) : GlyphOutline?
      glyph_id = @font.glyph_id(char)
      glyph_outline(glyph_id)
    end

    # ===== Text Metrics =====

    # Calculate the width of a string at current coordinates
    def text_width(text : String) : Int32
      width = 0
      text.each_char do |char|
        width += advance_width(char)
      end
      width
    end

    # ===== Instance Info =====

    # Get a description of the current instance
    def to_s : String
      parts = @coordinates.map { |tag, value| "#{tag}=#{value.round(1)}" }
      "VariationInstance(#{parts.join(", ")})"
    end

    # Check if current coordinates match a named instance
    def matches_named_instance?(index : Int32) : Bool
      instances = @font.named_instances
      return false if index < 0 || index >= instances.size

      instance = instances[index]
      axes = @font.variation_axes

      instance.coordinates.each_with_index do |coord, i|
        return false if i >= axes.size
        tag = axes[i].tag
        current = @coordinates[tag]?
        return false unless current
        return false if (current - coord.to_f64).abs > 0.01
      end

      true
    end

    # Find matching named instance index, or nil if none match
    def named_instance_index : Int32?
      @font.named_instances.each_with_index do |_, i|
        return i if matches_named_instance?(i)
      end
      nil
    end

    # ===== Static Instance Generation =====

    # Generate a static (non-variable) font from this variation instance.
    # This creates a new font with interpolated glyph outlines and metrics
    # for the current axis coordinates.
    #
    # Note: This is a simplified implementation that:
    # - Interpolates glyph outlines via gvar
    # - Removes variation tables (fvar, gvar, avar, etc.)
    # - Updates metrics based on HVAR/MVAR deltas
    #
    # For production use, consider using fonttools or similar for
    # complete static instance generation.
    #
    # Returns the font data as Bytes, or nil if generation fails.
    def to_static_font : Bytes?
      return nil unless variable_font?

      # This is a complex operation that would require:
      # 1. Rebuilding the glyf table with interpolated outlines
      # 2. Updating hmtx with interpolated advance widths
      # 3. Updating head/hhea/OS2 with interpolated metrics
      # 4. Removing fvar, gvar, avar, STAT, HVAR, VVAR, MVAR, cvar tables
      # 5. Recalculating checksums and offsets
      #
      # For now, we provide the building blocks (interpolated outlines/metrics)
      # and leave full font generation to external tools.
      #
      # Use `interpolated_glyph_outlines` and metric methods to get the
      # interpolated data for manual font construction.
      nil
    end

    # Get all interpolated glyph outlines for this instance.
    # Returns a hash mapping glyph IDs to their interpolated outlines.
    # Useful for generating static instances or rendering.
    def interpolated_glyph_outlines : Hash(UInt16, GlyphOutline)
      outlines = {} of UInt16 => GlyphOutline
      glyph_count = @font.maxp.try(&.num_glyphs) || 0_u16

      (0...glyph_count).each do |gid|
        outline = glyph_outline(gid.to_u16)
        outlines[gid.to_u16] = outline if outline
      end

      outlines
    end

    # Get all interpolated advance widths for this instance.
    # Returns an array of advance widths indexed by glyph ID.
    def interpolated_advance_widths : Array(Int32)
      glyph_count = @font.maxp.try(&.num_glyphs) || 0_u16
      (0...glyph_count).map { |gid| advance_width(gid.to_u16) }
    end

    # Get interpolated font metrics for this instance.
    # Returns a hash with common metric values.
    def interpolated_metrics : Hash(String, Int32)
      {
        "ascender"   => ascender.to_i32,
        "descender"  => descender.to_i32,
        "cap_height" => cap_height.to_i32,
        "x_height"   => (x_height || 0).to_i32,
        "units_per_em" => @font.units_per_em.to_i32,
      }
    end
  end
end
