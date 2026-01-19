module TrueType
  module Tables
    module Variations
      # Represents an axis record in the STAT table.
      # Provides display information for variation axes.
      struct StatAxisRecord
        # 4-byte axis tag (e.g., 'wght', 'wdth')
        getter tag : String

        # Name ID for the axis name (in the 'name' table)
        getter axis_name_id : UInt16

        # Ordering value for UI sorting
        getter axis_ordering : UInt16

        def initialize(@tag : String, @axis_name_id : UInt16, @axis_ordering : UInt16)
        end
      end

      # Base class for axis value records
      abstract class AxisValue
        # Name ID for the value name (in the 'name' table)
        abstract def value_name_id : UInt16

        # Axis value flags
        abstract def flags : UInt16

        # Flag constants
        OLDER_SIBLING_FONT_ATTRIBUTE = 0x0001_u16
        ELIDABLE_AXIS_VALUE_NAME     = 0x0002_u16

        # Check if this value provides info for earlier fonts in the family
        def older_sibling? : Bool
          (flags & OLDER_SIBLING_FONT_ATTRIBUTE) != 0
        end

        # Check if this value name can be omitted (e.g., "Regular")
        def elidable? : Bool
          (flags & ELIDABLE_AXIS_VALUE_NAME) != 0
        end
      end

      # Format 1: Single value for one axis
      class AxisValueFormat1 < AxisValue
        include IOHelpers

        getter axis_index : UInt16
        getter flags : UInt16
        getter value_name_id : UInt16
        getter value : Float64

        def initialize(@axis_index : UInt16, @flags : UInt16, @value_name_id : UInt16, @value : Float64)
        end

        def self.parse(io : IO) : AxisValueFormat1
          axis_index = read_uint16(io)
          flags = read_uint16(io)
          value_name_id = read_uint16(io)
          value = read_fixed(io)
          new(axis_index, flags, value_name_id, value)
        end

        extend IOHelpers
      end

      # Format 2: Value with range for one axis
      class AxisValueFormat2 < AxisValue
        include IOHelpers

        getter axis_index : UInt16
        getter flags : UInt16
        getter value_name_id : UInt16
        getter nominal_value : Float64
        getter range_min_value : Float64
        getter range_max_value : Float64

        def initialize(
          @axis_index : UInt16,
          @flags : UInt16,
          @value_name_id : UInt16,
          @nominal_value : Float64,
          @range_min_value : Float64,
          @range_max_value : Float64
        )
        end

        def self.parse(io : IO) : AxisValueFormat2
          axis_index = read_uint16(io)
          flags = read_uint16(io)
          value_name_id = read_uint16(io)
          nominal_value = read_fixed(io)
          range_min_value = read_fixed(io)
          range_max_value = read_fixed(io)
          new(axis_index, flags, value_name_id, nominal_value, range_min_value, range_max_value)
        end

        extend IOHelpers
      end

      # Format 3: Value with linked value for one axis (e.g., Regular -> Bold)
      class AxisValueFormat3 < AxisValue
        include IOHelpers

        getter axis_index : UInt16
        getter flags : UInt16
        getter value_name_id : UInt16
        getter value : Float64
        getter linked_value : Float64

        def initialize(
          @axis_index : UInt16,
          @flags : UInt16,
          @value_name_id : UInt16,
          @value : Float64,
          @linked_value : Float64
        )
        end

        def self.parse(io : IO) : AxisValueFormat3
          axis_index = read_uint16(io)
          flags = read_uint16(io)
          value_name_id = read_uint16(io)
          value = read_fixed(io)
          linked_value = read_fixed(io)
          new(axis_index, flags, value_name_id, value, linked_value)
        end

        extend IOHelpers
      end

      # Format 4: Multi-axis value combination
      class AxisValueFormat4 < AxisValue
        include IOHelpers

        # Axis-value pair for Format 4
        struct AxisValuePair
          getter axis_index : UInt16
          getter value : Float64

          def initialize(@axis_index : UInt16, @value : Float64)
          end
        end

        getter axis_count : UInt16
        getter flags : UInt16
        getter value_name_id : UInt16
        getter axis_values : Array(AxisValuePair)

        def initialize(
          @axis_count : UInt16,
          @flags : UInt16,
          @value_name_id : UInt16,
          @axis_values : Array(AxisValuePair)
        )
        end

        def self.parse(io : IO) : AxisValueFormat4
          axis_count = read_uint16(io)
          flags = read_uint16(io)
          value_name_id = read_uint16(io)

          axis_values = Array(AxisValuePair).new(axis_count.to_i)
          axis_count.times do
            axis_index = read_uint16(io)
            value = read_fixed(io)
            axis_values << AxisValuePair.new(axis_index, value)
          end

          new(axis_count, flags, value_name_id, axis_values)
        end

        extend IOHelpers
      end

      # The 'STAT' (style attributes) table provides additional
      # metadata about variation axes and axis values.
      class Stat
        include IOHelpers

        # Major version (should be 1)
        getter major_version : UInt16

        # Minor version (0, 1, or 2)
        getter minor_version : UInt16

        # Size of each axis record (should be 8)
        getter design_axis_size : UInt16

        # Number of axis records
        getter design_axis_count : UInt16

        # Offset to axis records from start of table
        getter design_axes_offset : UInt32

        # Number of axis value tables
        getter axis_value_count : UInt16

        # Offset to axis value offsets array
        getter offset_to_axis_value_offsets : UInt32

        # Elided fallback name ID (version 1.1+)
        getter elided_fallback_name_id : UInt16?

        # Parsed axis records
        getter design_axes : Array(StatAxisRecord)

        # Parsed axis values
        getter axis_values : Array(AxisValue)

        def initialize(
          @major_version : UInt16,
          @minor_version : UInt16,
          @design_axis_size : UInt16,
          @design_axis_count : UInt16,
          @design_axes_offset : UInt32,
          @axis_value_count : UInt16,
          @offset_to_axis_value_offsets : UInt32,
          @elided_fallback_name_id : UInt16?,
          @design_axes : Array(StatAxisRecord),
          @axis_values : Array(AxisValue)
        )
        end

        # Parse the STAT table from raw bytes
        def self.parse(data : Bytes) : Stat
          io = IO::Memory.new(data)

          major_version = read_uint16(io)
          minor_version = read_uint16(io)
          design_axis_size = read_uint16(io)
          design_axis_count = read_uint16(io)
          design_axes_offset = read_uint32(io)
          axis_value_count = read_uint16(io)
          offset_to_axis_value_offsets = read_uint32(io)

          # Version 1.1+ has elidedFallbackNameID
          elided_fallback_name_id = if minor_version >= 1
                                       read_uint16(io)
                                     else
                                       nil
                                     end

          # Parse design axes
          design_axes = Array(StatAxisRecord).new(design_axis_count.to_i)
          if design_axes_offset > 0 && design_axis_count > 0
            io.seek(design_axes_offset.to_i64)
            design_axis_count.times do
              tag = read_tag(io)
              axis_name_id = read_uint16(io)
              axis_ordering = read_uint16(io)
              design_axes << StatAxisRecord.new(tag, axis_name_id, axis_ordering)
            end
          end

          # Parse axis values
          axis_values = Array(AxisValue).new(axis_value_count.to_i)
          if offset_to_axis_value_offsets > 0 && axis_value_count > 0
            io.seek(offset_to_axis_value_offsets.to_i64)

            # Read offsets to individual axis value tables
            offsets = Array(UInt16).new(axis_value_count.to_i)
            axis_value_count.times do
              offsets << read_uint16(io)
            end

            # Parse each axis value
            offsets.each do |offset|
              abs_offset = offset_to_axis_value_offsets + offset
              io.seek(abs_offset.to_i64)

              format = read_uint16(io)
              axis_value = case format
                           when 1 then AxisValueFormat1.parse(io)
                           when 2 then AxisValueFormat2.parse(io)
                           when 3 then AxisValueFormat3.parse(io)
                           when 4 then AxisValueFormat4.parse(io)
                           else
                             raise ParseError.new("Unknown STAT axis value format: #{format}")
                           end
              axis_values << axis_value
            end
          end

          new(
            major_version, minor_version,
            design_axis_size, design_axis_count,
            design_axes_offset, axis_value_count,
            offset_to_axis_value_offsets,
            elided_fallback_name_id,
            design_axes, axis_values
          )
        end

        # Find axis record by tag
        def axis(tag : String) : StatAxisRecord?
          @design_axes.find { |a| a.tag == tag }
        end

        # Get axis index by tag
        def axis_index(tag : String) : Int32?
          @design_axes.index { |a| a.tag == tag }
        end

        # Get all axis values for a specific axis index
        def values_for_axis(axis_index : Int32) : Array(AxisValue)
          @axis_values.select do |av|
            case av
            when AxisValueFormat1
              av.axis_index == axis_index
            when AxisValueFormat2
              av.axis_index == axis_index
            when AxisValueFormat3
              av.axis_index == axis_index
            when AxisValueFormat4
              av.axis_values.any? { |pair| pair.axis_index == axis_index }
            else
              false
            end
          end
        end

        # Find elidable values (like "Regular" that can be omitted from names)
        def elidable_values : Array(AxisValue)
          @axis_values.select(&.elidable?)
        end

        extend IOHelpers
      end
    end
  end
end
