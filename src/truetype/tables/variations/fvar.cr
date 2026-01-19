module TrueType
  module Tables
    module Variations
      # Represents a single variation axis in a variable font.
      # Each axis defines a dimension along which the font can vary.
      struct VariationAxisRecord
        # 4-byte axis tag (e.g., 'wght', 'wdth', 'slnt', 'opsz')
        getter tag : String

        # Minimum value for this axis (16.16 fixed-point)
        getter min_value : Float64

        # Default value for this axis (16.16 fixed-point)
        getter default_value : Float64

        # Maximum value for this axis (16.16 fixed-point)
        getter max_value : Float64

        # Axis qualifiers (bit 0 = hidden axis)
        getter flags : UInt16

        # Name ID for the axis name (in the 'name' table)
        getter axis_name_id : UInt16

        # Flag constants
        HIDDEN_AXIS = 0x0001_u16

        def initialize(
          @tag : String,
          @min_value : Float64,
          @default_value : Float64,
          @max_value : Float64,
          @flags : UInt16,
          @axis_name_id : UInt16
        )
        end

        # Check if this axis should be hidden from user interfaces
        def hidden? : Bool
          (@flags & HIDDEN_AXIS) != 0
        end

        # Common axis tag constants
        WEIGHT_TAG     = "wght"
        WIDTH_TAG      = "wdth"
        SLANT_TAG      = "slnt"
        OPTICAL_SIZE   = "opsz"
        ITALIC_TAG     = "ital"
        GRADE_TAG      = "GRAD"

        # Check if this is a weight axis
        def weight? : Bool
          @tag == WEIGHT_TAG
        end

        # Check if this is a width axis
        def width? : Bool
          @tag == WIDTH_TAG
        end

        # Check if this is a slant axis
        def slant? : Bool
          @tag == SLANT_TAG
        end

        # Check if this is an optical size axis
        def optical_size? : Bool
          @tag == OPTICAL_SIZE
        end
      end

      # Represents a named instance in a variable font.
      # Named instances are predefined combinations of axis values.
      struct InstanceRecord
        # Name ID for the subfamily name (in the 'name' table)
        getter subfamily_name_id : UInt16

        # Instance flags (reserved, must be 0)
        getter flags : UInt16

        # Axis coordinate values for this instance (one per axis, 16.16 fixed-point)
        getter coordinates : Array(Float64)

        # Optional PostScript name ID (0xFFFF if not present)
        getter postscript_name_id : UInt16?

        def initialize(
          @subfamily_name_id : UInt16,
          @flags : UInt16,
          @coordinates : Array(Float64),
          @postscript_name_id : UInt16? = nil
        )
        end
      end

      # The 'fvar' (font variations) table defines the axes of variation
      # in a variable font and any named instances.
      class Fvar
        include IOHelpers

        # Major version (should be 1)
        getter major_version : UInt16

        # Minor version (should be 0)
        getter minor_version : UInt16

        # Offset to axis array from start of table
        getter axes_array_offset : UInt16

        # Reserved field (should be 2)
        getter reserved : UInt16

        # Number of variation axes
        getter axis_count : UInt16

        # Size of each axis record (should be 20)
        getter axis_size : UInt16

        # Number of named instances
        getter instance_count : UInt16

        # Size of each instance record
        getter instance_size : UInt16

        # Array of variation axis records
        getter axes : Array(VariationAxisRecord)

        # Array of named instance records
        getter instances : Array(InstanceRecord)

        def initialize(
          @major_version : UInt16,
          @minor_version : UInt16,
          @axes_array_offset : UInt16,
          @reserved : UInt16,
          @axis_count : UInt16,
          @axis_size : UInt16,
          @instance_count : UInt16,
          @instance_size : UInt16,
          @axes : Array(VariationAxisRecord),
          @instances : Array(InstanceRecord)
        )
        end

        # Parse the fvar table from raw bytes
        def self.parse(data : Bytes) : Fvar
          io = IO::Memory.new(data)

          major_version = read_uint16(io)
          minor_version = read_uint16(io)
          axes_array_offset = read_uint16(io)
          reserved = read_uint16(io)
          axis_count = read_uint16(io)
          axis_size = read_uint16(io)
          instance_count = read_uint16(io)
          instance_size = read_uint16(io)

          # Validate version
          unless major_version == 1 && minor_version == 0
            raise ParseError.new("Unsupported fvar version: #{major_version}.#{minor_version}")
          end

          # Parse axes
          io.seek(axes_array_offset.to_i64)
          axes = Array(VariationAxisRecord).new(axis_count.to_i)

          axis_count.times do
            tag = read_tag(io)
            min_value = read_fixed(io)
            default_value = read_fixed(io)
            max_value = read_fixed(io)
            flags = read_uint16(io)
            axis_name_id = read_uint16(io)

            axes << VariationAxisRecord.new(
              tag, min_value, default_value, max_value, flags, axis_name_id
            )
          end

          # Parse instances
          # Instance records start immediately after axis records
          instances = Array(InstanceRecord).new(instance_count.to_i)

          # Determine if instances have PostScript name ID
          # instanceSize = 4 + (axisCount * 4) without postScriptNameID
          # instanceSize = 6 + (axisCount * 4) with postScriptNameID
          base_instance_size = 4 + (axis_count.to_i * 4)
          has_postscript_name = instance_size > base_instance_size

          instance_count.times do
            subfamily_name_id = read_uint16(io)
            flags = read_uint16(io)

            coordinates = Array(Float64).new(axis_count.to_i)
            axis_count.times do
              coordinates << read_fixed(io)
            end

            postscript_name_id = if has_postscript_name
                                   id = read_uint16(io)
                                   id == 0xFFFF ? nil : id
                                 else
                                   nil
                                 end

            instances << InstanceRecord.new(
              subfamily_name_id, flags, coordinates, postscript_name_id
            )
          end

          new(
            major_version, minor_version,
            axes_array_offset, reserved,
            axis_count, axis_size,
            instance_count, instance_size,
            axes, instances
          )
        end

        # Find an axis by its tag
        def axis(tag : String) : VariationAxisRecord?
          @axes.find { |a| a.tag == tag }
        end

        # Get the index of an axis by its tag
        def axis_index(tag : String) : Int32?
          @axes.index { |a| a.tag == tag }
        end

        # Get all axis tags
        def axis_tags : Array(String)
          @axes.map(&.tag)
        end

        # Check if a specific axis exists
        def has_axis?(tag : String) : Bool
          @axes.any? { |a| a.tag == tag }
        end

        # Get the default coordinates (all axes at their default values)
        def default_coordinates : Array(Float64)
          @axes.map(&.default_value)
        end

        # Normalize a user-space coordinate to the normalized space [-1, 1]
        # This is the default normalization without avar adjustments
        def normalize_coordinate(axis_index : Int32, user_value : Float64) : Float64
          return 0.0 if axis_index < 0 || axis_index >= @axes.size

          axis = @axes[axis_index]
          default_val = axis.default_value
          min_val = axis.min_value
          max_val = axis.max_value

          if user_value < default_val
            if default_val == min_val
              0.0
            else
              -(default_val - user_value) / (default_val - min_val)
            end
          elsif user_value > default_val
            if max_val == default_val
              0.0
            else
              (user_value - default_val) / (max_val - default_val)
            end
          else
            0.0
          end
        end

        # Normalize coordinates for all axes
        def normalize_coordinates(user_values : Hash(String, Float64)) : Array(Float64)
          @axes.map_with_index do |axis, i|
            user_value = user_values[axis.tag]? || axis.default_value
            normalize_coordinate(i, user_value)
          end
        end

        # Clamp a value to the valid range for an axis
        def clamp_to_axis_range(axis_index : Int32, value : Float64) : Float64
          return value if axis_index < 0 || axis_index >= @axes.size

          axis = @axes[axis_index]
          value.clamp(axis.min_value, axis.max_value)
        end

        extend IOHelpers
      end
    end
  end
end
