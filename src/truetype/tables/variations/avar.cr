module TrueType
  module Tables
    module Variations
      # Represents a single axis value mapping in avar.
      # Maps from a normalized coordinate to a modified normalized coordinate.
      struct AxisValueMap
        # Input coordinate (from default normalization), F2DOT14 format
        getter from_coordinate : Float64

        # Output coordinate (modified normalization), F2DOT14 format
        getter to_coordinate : Float64

        def initialize(@from_coordinate : Float64, @to_coordinate : Float64)
        end
      end

      # Represents the segment map for a single axis.
      # Contains piecewise linear mappings for axis value modification.
      struct SegmentMap
        # Array of axis value mappings
        getter axis_value_maps : Array(AxisValueMap)

        def initialize(@axis_value_maps : Array(AxisValueMap))
        end

        # Check if this segment map has the required mappings (-1, 0, 1)
        def valid? : Bool
          return false if @axis_value_maps.size < 3

          has_min = @axis_value_maps.any? { |m| m.from_coordinate == -1.0 && m.to_coordinate == -1.0 }
          has_default = @axis_value_maps.any? { |m| m.from_coordinate == 0.0 && m.to_coordinate == 0.0 }
          has_max = @axis_value_maps.any? { |m| m.from_coordinate == 1.0 && m.to_coordinate == 1.0 }

          has_min && has_default && has_max
        end

        # Apply the segment map to a normalized coordinate.
        # Uses piecewise linear interpolation between segment points.
        def map(normalized_value : Float64) : Float64
          return normalized_value if @axis_value_maps.empty?

          # Clamp to valid range
          normalized_value = normalized_value.clamp(-1.0, 1.0)

          # Find the segment containing this value
          maps = @axis_value_maps
          return normalized_value if maps.size < 2

          # If before first mapping, use first value
          if normalized_value <= maps.first.from_coordinate
            return maps.first.to_coordinate
          end

          # If after last mapping, use last value
          if normalized_value >= maps.last.from_coordinate
            return maps.last.to_coordinate
          end

          # Find the segment and interpolate
          (0...maps.size - 1).each do |i|
            from_map = maps[i]
            to_map = maps[i + 1]

            if normalized_value >= from_map.from_coordinate && normalized_value <= to_map.from_coordinate
              # Linear interpolation within segment
              if from_map.from_coordinate == to_map.from_coordinate
                return from_map.to_coordinate
              end

              t = (normalized_value - from_map.from_coordinate) / (to_map.from_coordinate - from_map.from_coordinate)
              return from_map.to_coordinate + t * (to_map.to_coordinate - from_map.to_coordinate)
            end
          end

          # Fallback (shouldn't happen with valid data)
          normalized_value
        end
      end

      # The 'avar' (axis variations) table allows modification of the
      # coordinate normalization for each axis, enabling non-linear
      # variation along axes.
      class Avar
        include IOHelpers

        # Major version (should be 1)
        getter major_version : UInt16

        # Minor version (should be 0)
        getter minor_version : UInt16

        # Reserved field
        getter reserved : UInt16

        # Number of axes (should match fvar)
        getter axis_count : UInt16

        # Segment maps for each axis
        getter segment_maps : Array(SegmentMap)

        def initialize(
          @major_version : UInt16,
          @minor_version : UInt16,
          @reserved : UInt16,
          @axis_count : UInt16,
          @segment_maps : Array(SegmentMap)
        )
        end

        # Parse the avar table from raw bytes
        def self.parse(data : Bytes) : Avar
          io = IO::Memory.new(data)

          major_version = read_uint16(io)
          minor_version = read_uint16(io)
          reserved = read_uint16(io)
          axis_count = read_uint16(io)

          # Parse segment maps for each axis
          segment_maps = Array(SegmentMap).new(axis_count.to_i)

          axis_count.times do
            position_map_count = read_uint16(io)

            axis_value_maps = Array(AxisValueMap).new(position_map_count.to_i)
            position_map_count.times do
              # F2DOT14 values: 2.14 fixed-point
              from_raw = read_int16(io)
              to_raw = read_int16(io)

              from_coord = from_raw.to_f64 / 16384.0
              to_coord = to_raw.to_f64 / 16384.0

              axis_value_maps << AxisValueMap.new(from_coord, to_coord)
            end

            segment_maps << SegmentMap.new(axis_value_maps)
          end

          new(major_version, minor_version, reserved, axis_count, segment_maps)
        end

        # Get the segment map for a specific axis
        def segment_map(axis_index : Int32) : SegmentMap?
          return nil if axis_index < 0 || axis_index >= @segment_maps.size
          @segment_maps[axis_index]
        end

        # Apply avar mapping to a normalized coordinate for a specific axis
        def map_coordinate(axis_index : Int32, normalized_value : Float64) : Float64
          segment = segment_map(axis_index)
          return normalized_value unless segment
          return normalized_value unless segment.valid?
          segment.map(normalized_value)
        end

        # Apply avar mapping to an array of normalized coordinates
        def map_coordinates(normalized_values : Array(Float64)) : Array(Float64)
          normalized_values.map_with_index do |value, i|
            map_coordinate(i, value)
          end
        end

        extend IOHelpers
      end
    end
  end
end
