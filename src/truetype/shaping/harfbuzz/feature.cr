# HarfBuzz Feature wrapper
#
# Features control OpenType feature application during shaping.
# Examples: "liga" (ligatures), "kern" (kerning), "smcp" (small caps)

module TrueType
  module HarfBuzz
    # Represents an OpenType feature setting.
    #
    # Features can be enabled (value=1), disabled (value=0), or set to
    # a specific alternate (value=2, 3, etc. for features like 'salt').
    #
    # The start and end indices specify which character range the feature
    # applies to. Use `GLOBAL_START` and `GLOBAL_END` for the entire buffer.
    struct Feature
      GLOBAL_START = 0_u32
      GLOBAL_END   = UInt32::MAX

      # The feature tag (e.g., "liga", "kern", "smcp")
      getter tag : UInt32

      # The feature value (0 = off, 1 = on, 2+ = alternate index)
      getter value : UInt32

      # Start index (character/cluster position)
      getter start : UInt32

      # End index (character/cluster position)
      getter end_pos : UInt32

      # Creates a feature from a tag string.
      #
      # Examples:
      # - `Feature.new("liga")` - enable ligatures
      # - `Feature.new("kern", 0)` - disable kerning
      # - `Feature.new("salt", 2)` - use 2nd stylistic alternate
      # - `Feature.new("liga", 1, 0, 5)` - enable ligatures for chars 0-5
      def initialize(tag : String, value : UInt32 = 1, start : UInt32 = GLOBAL_START, end_pos : UInt32 = GLOBAL_END)
        @tag = HarfBuzz.tag(tag)
        @value = value
        @start = start
        @end_pos = end_pos
      end

      # Creates a feature from a numeric tag.
      def initialize(@tag : UInt32, @value : UInt32 = 1, @start : UInt32 = GLOBAL_START, @end_pos : UInt32 = GLOBAL_END)
      end

      # Parses a feature from a CSS-like string.
      #
      # Supported formats:
      # - `"liga"` or `"+liga"` - enable
      # - `"-liga"` - disable
      # - `"liga=0"` - disable
      # - `"liga=1"` - enable
      # - `"aalt=2"` - choose 2nd alternate
      # - `"kern[5:]"` - enable from position 5
      # - `"kern[:5]"` - enable up to position 5
      # - `"kern[3:5]"` - enable for positions 3-5
      def self.parse(str : String) : Feature?
        feature = uninitialized LibHarfBuzz::HbFeature
        if LibHarfBuzz.hb_feature_from_string(str.to_unsafe, str.bytesize, pointerof(feature)) != 0
          Feature.new(feature.tag, feature.value, feature.start, feature._end)
        else
          nil
        end
      end

      # Parses a feature, raising on failure.
      def self.parse!(str : String) : Feature
        parse(str) || raise ArgumentError.new("Invalid feature string: #{str}")
      end

      # Parses multiple features from a comma-separated string.
      #
      # Example: `Feature.parse_list("liga,kern,-calt,smcp")`
      def self.parse_list(str : String) : Array(Feature)
        str.split(',').compact_map { |s| parse(s.strip) }
      end

      # Converts to HarfBuzz struct for FFI.
      def to_harfbuzz : LibHarfBuzz::HbFeature
        LibHarfBuzz::HbFeature.new(
          tag: @tag,
          value: @value,
          start: @start,
          _end: @end_pos
        )
      end

      # Converts to a string representation.
      def to_s(io : IO)
        buf = uninitialized UInt8[128]
        feature = to_harfbuzz
        LibHarfBuzz.hb_feature_to_string(pointerof(feature), buf.to_unsafe.as(LibC::Char*), 128)
        io << String.new(buf.to_unsafe)
      end

      # Returns the tag as a 4-character string.
      def tag_string : String
        HarfBuzz.tag_to_string(@tag)
      end

      # Returns true if this feature is enabled (value > 0).
      def enabled? : Bool
        @value > 0
      end

      # Returns true if this feature is disabled (value == 0).
      def disabled? : Bool
        @value == 0
      end

      # Returns true if this feature applies globally.
      def global? : Bool
        @start == GLOBAL_START && @end_pos == GLOBAL_END
      end
    end

    # Common feature presets
    module Features
      # Standard ligatures (fi, fl, etc.)
      def self.liga(enabled : Bool = true) : Feature
        Feature.new("liga", enabled ? 1_u32 : 0_u32)
      end

      # Contextual ligatures
      def self.clig(enabled : Bool = true) : Feature
        Feature.new("clig", enabled ? 1_u32 : 0_u32)
      end

      # Discretionary ligatures
      def self.dlig(enabled : Bool = true) : Feature
        Feature.new("dlig", enabled ? 1_u32 : 0_u32)
      end

      # Kerning
      def self.kern(enabled : Bool = true) : Feature
        Feature.new("kern", enabled ? 1_u32 : 0_u32)
      end

      # Contextual alternates
      def self.calt(enabled : Bool = true) : Feature
        Feature.new("calt", enabled ? 1_u32 : 0_u32)
      end

      # Small caps
      def self.smcp(enabled : Bool = true) : Feature
        Feature.new("smcp", enabled ? 1_u32 : 0_u32)
      end

      # Caps to small caps
      def self.c2sc(enabled : Bool = true) : Feature
        Feature.new("c2sc", enabled ? 1_u32 : 0_u32)
      end

      # Lining figures (tabular numbers)
      def self.lnum(enabled : Bool = true) : Feature
        Feature.new("lnum", enabled ? 1_u32 : 0_u32)
      end

      # Oldstyle figures
      def self.onum(enabled : Bool = true) : Feature
        Feature.new("onum", enabled ? 1_u32 : 0_u32)
      end

      # Proportional figures
      def self.pnum(enabled : Bool = true) : Feature
        Feature.new("pnum", enabled ? 1_u32 : 0_u32)
      end

      # Tabular figures
      def self.tnum(enabled : Bool = true) : Feature
        Feature.new("tnum", enabled ? 1_u32 : 0_u32)
      end

      # Fractions
      def self.frac(enabled : Bool = true) : Feature
        Feature.new("frac", enabled ? 1_u32 : 0_u32)
      end

      # Stylistic alternates (with index)
      def self.salt(index : UInt32 = 1) : Feature
        Feature.new("salt", index)
      end

      # Stylistic set (ss01-ss20)
      def self.stylistic_set(number : Int32) : Feature
        raise ArgumentError.new("Stylistic set must be 1-20") unless (1..20).includes?(number)
        tag = "ss#{number.to_s.rjust(2, '0')}"
        Feature.new(tag, 1_u32)
      end

      # Swash
      def self.swsh(enabled : Bool = true) : Feature
        Feature.new("swsh", enabled ? 1_u32 : 0_u32)
      end

      # Historical forms
      def self.hist(enabled : Bool = true) : Feature
        Feature.new("hist", enabled ? 1_u32 : 0_u32)
      end

      # Ordinals
      def self.ordn(enabled : Bool = true) : Feature
        Feature.new("ordn", enabled ? 1_u32 : 0_u32)
      end

      # Superscript
      def self.sups(enabled : Bool = true) : Feature
        Feature.new("sups", enabled ? 1_u32 : 0_u32)
      end

      # Subscript
      def self.subs(enabled : Bool = true) : Feature
        Feature.new("subs", enabled ? 1_u32 : 0_u32)
      end

      # Default features for text shaping
      def self.defaults : Array(Feature)
        [
          liga(true),
          clig(true),
          calt(true),
          kern(true),
        ]
      end
    end
  end
end
