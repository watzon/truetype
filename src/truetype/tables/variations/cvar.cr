# cvar table - CVT Variations
# Contains variation data for the Control Value Table (CVT) used in TrueType hinting.
#
# Reference: https://learn.microsoft.com/en-us/typography/opentype/spec/cvar

module TrueType
  module Tables
    module Variations
      # The cvar table stores variation data for the CVT (Control Value Table).
      # CVT values are used by TrueType hinting instructions to ensure consistent
      # rendering at different sizes and on different devices.
      #
      # The cvar table uses TupleVariationStore format, similar to gvar but simpler
      # since CVT values are a simple array rather than glyph outlines.
      class Cvar
        include IOHelpers

        # Major version (should be 1)
        getter major_version : UInt16

        # Minor version (should be 0)
        getter minor_version : UInt16

        # Tuple variation count and flags
        getter tuple_variation_count : UInt16

        # Offset to serialized data
        getter data_offset : UInt16

        # Tuple variation headers
        getter tuple_headers : Array(TupleVariationHeader)

        # Shared point numbers (if present)
        getter shared_point_numbers : Array(UInt16)?

        # Raw data for delta unpacking
        @data : Bytes

        # Number of CVT values (from cvt table)
        getter cvt_count : UInt16

        # Axis count (from fvar)
        getter axis_count : UInt16

        # Flags
        SHARED_POINT_NUMBERS = 0x8000_u16
        COUNT_MASK           = 0x0FFF_u16

        def initialize(
          @major_version : UInt16,
          @minor_version : UInt16,
          @tuple_variation_count : UInt16,
          @data_offset : UInt16,
          @tuple_headers : Array(TupleVariationHeader),
          @shared_point_numbers : Array(UInt16)?,
          @data : Bytes,
          @cvt_count : UInt16,
          @axis_count : UInt16
        )
        end

        def self.parse(data : Bytes, cvt_count : UInt16, axis_count : UInt16) : Cvar
          io = IO::Memory.new(data)

          major_version = read_uint16(io)
          minor_version = read_uint16(io)
          tuple_variation_count_raw = read_uint16(io)
          data_offset = read_uint16(io)

          has_shared_points = (tuple_variation_count_raw & SHARED_POINT_NUMBERS) != 0
          tuple_count = (tuple_variation_count_raw & COUNT_MASK).to_i

          # Parse tuple headers
          tuple_headers = Array(TupleVariationHeader).new(tuple_count)
          tuple_count.times do
            variation_data_size = read_uint16(io)
            tuple_index = read_uint16(io)

            # Parse peak tuple if embedded
            peak_tuple = if (tuple_index & TupleFlags::EMBEDDED_PEAK_TUPLE) != 0
                           coords = Array(Float64).new(axis_count.to_i)
                           axis_count.times do
                             raw = read_int16(io)
                             coords << raw.to_f64 / 16384.0
                           end
                           AxisTuple.new(coords)
                         else
                           nil
                         end

            # Parse intermediate region if present
            intermediate_start = nil
            intermediate_end = nil
            if (tuple_index & TupleFlags::INTERMEDIATE_REGION) != 0
              start_coords = Array(Float64).new(axis_count.to_i)
              axis_count.times do
                raw = read_int16(io)
                start_coords << raw.to_f64 / 16384.0
              end
              intermediate_start = AxisTuple.new(start_coords)

              end_coords = Array(Float64).new(axis_count.to_i)
              axis_count.times do
                raw = read_int16(io)
                end_coords << raw.to_f64 / 16384.0
              end
              intermediate_end = AxisTuple.new(end_coords)
            end

            tuple_headers << TupleVariationHeader.new(
              variation_data_size, tuple_index,
              peak_tuple, intermediate_start, intermediate_end
            )
          end

          # Parse shared point numbers if present
          serialized_data = data[data_offset.to_i..]
          shared_io = IO::Memory.new(serialized_data)

          shared_point_numbers = if has_shared_points
                                   parse_packed_points(shared_io)
                                 else
                                   nil
                                 end

          new(
            major_version,
            minor_version,
            tuple_variation_count_raw,
            data_offset,
            tuple_headers,
            shared_point_numbers,
            data,
            cvt_count,
            axis_count
          )
        end

        # Check if there are any tuple variations
        def has_variations? : Bool
          !@tuple_headers.empty?
        end

        # Get the number of tuple variations
        def tuple_count : Int32
          (@tuple_variation_count & COUNT_MASK).to_i
        end

        # Compute the interpolated CVT deltas at given normalized coordinates.
        # Returns an array of deltas to add to base CVT values.
        def compute_cvt_deltas(normalized_coords : Array(Float64)) : Array(Float64)
          deltas = Array(Float64).new(@cvt_count.to_i, 0.0)
          return deltas if @tuple_headers.empty?

          serialized_data = @data[@data_offset.to_i..]
          io = IO::Memory.new(serialized_data)

          # Skip shared point numbers if present
          if @shared_point_numbers
            # Already parsed, but we need to skip in the IO
            # Re-parse to advance the position
            parse_packed_points(io)
          end

          @tuple_headers.each do |header|
            # Calculate scalar
            scalar = calculate_scalar(header, normalized_coords)
            next if scalar == 0.0

            # Get point numbers for this tuple
            point_numbers = if header.private_point_numbers?
                              parse_packed_points(io)
                            elsif shared = @shared_point_numbers
                              shared
                            else
                              # All CVT values
                              (0...@cvt_count).map(&.to_u16).to_a
                            end

            # Handle "all points" case
            if point_numbers.empty?
              point_numbers = (0...@cvt_count).map(&.to_u16).to_a
            end

            # Parse deltas
            raw_deltas = parse_packed_deltas(io, point_numbers.size)

            # Apply deltas
            point_numbers.each_with_index do |idx, i|
              next if idx >= @cvt_count
              deltas[idx.to_i] += scalar * raw_deltas[i]
            end
          end

          deltas
        end

        # Calculate scalar for a tuple header
        private def calculate_scalar(header : TupleVariationHeader, normalized_coords : Array(Float64)) : Float64
          peak = if header.embedded_peak?
                   header.peak_tuple
                 else
                   # cvar doesn't use shared tuples like gvar, so this shouldn't happen
                   nil
                 end

          return 0.0 unless peak
          return 0.0 if peak.size != normalized_coords.size

          scalar = 1.0

          peak.coordinates.each_with_index do |peak_val, i|
            next if peak_val == 0.0

            coord = normalized_coords[i]

            if header.intermediate_region?
              start_tuple = header.intermediate_start_tuple
              end_tuple = header.intermediate_end_tuple
              return 0.0 unless start_tuple && end_tuple

              start_val = start_tuple[i]
              end_val = end_tuple[i]

              if coord < Math.min(start_val, end_val) || coord > Math.max(start_val, end_val)
                return 0.0
              end

              if peak_val >= 0
                if coord < peak_val
                  axis_scalar = if peak_val == start_val
                                  1.0
                                else
                                  (coord - start_val) / (peak_val - start_val)
                                end
                  scalar *= axis_scalar
                else
                  axis_scalar = if peak_val == end_val
                                  1.0
                                else
                                  (end_val - coord) / (end_val - peak_val)
                                end
                  scalar *= axis_scalar
                end
              else
                if coord > peak_val
                  axis_scalar = if peak_val == start_val
                                  1.0
                                else
                                  (coord - start_val) / (peak_val - start_val)
                                end
                  scalar *= axis_scalar
                else
                  axis_scalar = if peak_val == end_val
                                  1.0
                                else
                                  (end_val - coord) / (end_val - peak_val)
                                end
                  scalar *= axis_scalar
                end
              end
            else
              # Non-intermediate
              if peak_val > 0
                return 0.0 if coord < 0.0 || coord > peak_val
                scalar *= coord / peak_val
              else
                return 0.0 if coord > 0.0 || coord < peak_val
                scalar *= coord / peak_val
              end
            end
          end

          scalar
        end

        # Parse packed point numbers
        private def self.parse_packed_points(io : IO) : Array(UInt16)
          points = [] of UInt16

          count_byte = read_uint8(io)
          count = if (count_byte & 0x80) != 0
                    ((count_byte & 0x7F).to_u16 << 8) | read_uint8(io).to_u16
                  elsif count_byte == 0
                    return points
                  else
                    count_byte.to_u16
                  end

          return points if count == 0

          point = 0_u16
          read_count = 0

          while read_count < count
            control = read_uint8(io)
            run_count = (control & 0x7F) + 1
            words = (control & 0x80) != 0

            run_count.times do
              break if read_count >= count
              delta = if words
                        read_uint16(io)
                      else
                        read_uint8(io).to_u16
                      end
              point = point &+ delta
              points << point
              read_count += 1
            end
          end

          points
        end

        private def parse_packed_points(io : IO) : Array(UInt16)
          Cvar.parse_packed_points(io)
        end

        # Parse packed deltas
        private def parse_packed_deltas(io : IO, count : Int32) : Array(Int16)
          deltas = Array(Int16).new(count)
          read_count = 0

          while read_count < count
            control = read_uint8(io)
            run_count = (control & 0x3F) + 1

            if (control & 0x80) != 0
              # Zeros
              run_count.times do
                break if read_count >= count
                deltas << 0_i16
                read_count += 1
              end
            elsif (control & 0x40) != 0
              # Words
              run_count.times do
                break if read_count >= count
                deltas << read_int16(io)
                read_count += 1
              end
            else
              # Bytes
              run_count.times do
                break if read_count >= count
                deltas << read_int8(io).to_i16
                read_count += 1
              end
            end
          end

          deltas
        end

        extend IOHelpers
      end
    end
  end
end
