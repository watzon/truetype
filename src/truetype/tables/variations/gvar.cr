module TrueType
  module Tables
    module Variations
      # Represents a tuple of axis coordinates (peak values for a variation region).
      # Values are in F2DOT14 format (normalized -1.0 to 1.0 range).
      # Named AxisTuple to avoid conflict with Crystal's built-in Tuple type.
      struct AxisTuple
        getter coordinates : Array(Float64)

        def initialize(@coordinates : Array(Float64))
        end

        def size : Int32
          @coordinates.size
        end

        def [](index : Int32) : Float64
          @coordinates[index]
        end
      end

      # Represents a delta value (x, y adjustment for a point).
      struct PointDelta
        getter x : Int16
        getter y : Int16

        def initialize(@x : Int16, @y : Int16)
        end
      end

      # Flags for TupleVariationHeader.tupleIndex
      module TupleFlags
        EMBEDDED_PEAK_TUPLE   = 0x8000_u16 # Peak tuple follows inline
        INTERMEDIATE_REGION   = 0x4000_u16 # Has intermediate start/end tuples
        PRIVATE_POINT_NUMBERS = 0x2000_u16 # Has private point numbers
        TUPLE_INDEX_MASK      = 0x0FFF_u16 # Index into shared tuples
      end

      # Flags for GlyphVariationData.tupleVariationCount
      module GlyphVariationFlags
        SHARED_POINT_NUMBERS = 0x8000_u16 # Shared point numbers at start
        COUNT_MASK           = 0x0FFF_u16 # Number of tuple variation headers
      end

      # Header for a single tuple variation within a glyph's variation data.
      struct TupleVariationHeader
        # Size of the serialized data for this tuple
        getter variation_data_size : UInt16

        # Packed tuple index and flags
        getter tuple_index : UInt16

        # Peak tuple coordinates (if EMBEDDED_PEAK_TUPLE)
        getter peak_tuple : AxisTuple?

        # Intermediate region start (if INTERMEDIATE_REGION)
        getter intermediate_start_tuple : AxisTuple?

        # Intermediate region end (if INTERMEDIATE_REGION)
        getter intermediate_end_tuple : AxisTuple?

        def initialize(
          @variation_data_size : UInt16,
          @tuple_index : UInt16,
          @peak_tuple : AxisTuple?,
          @intermediate_start_tuple : AxisTuple?,
          @intermediate_end_tuple : AxisTuple?
        )
        end

        # Check if this tuple has embedded peak coordinates
        def embedded_peak? : Bool
          (@tuple_index & TupleFlags::EMBEDDED_PEAK_TUPLE) != 0
        end

        # Check if this tuple has intermediate region
        def intermediate_region? : Bool
          (@tuple_index & TupleFlags::INTERMEDIATE_REGION) != 0
        end

        # Check if this tuple has private point numbers
        def private_point_numbers? : Bool
          (@tuple_index & TupleFlags::PRIVATE_POINT_NUMBERS) != 0
        end

        # Get the shared tuple index (if not embedded)
        def shared_tuple_index : UInt16
          @tuple_index & TupleFlags::TUPLE_INDEX_MASK
        end
      end

      # Variation data for a single glyph.
      class GlyphVariationData
        include IOHelpers

        # Tuple variation headers
        getter tuple_headers : Array(TupleVariationHeader)

        # Shared point numbers (if SHARED_POINT_NUMBERS flag set)
        getter shared_point_numbers : Array(UInt16)?

        # Raw serialized data for delta unpacking
        getter serialized_data : Bytes

        # Data offset within serialized data
        getter data_offset : UInt16

        def initialize(
          @tuple_headers : Array(TupleVariationHeader),
          @shared_point_numbers : Array(UInt16)?,
          @serialized_data : Bytes,
          @data_offset : UInt16
        )
        end

        # Check if there are shared point numbers
        def has_shared_point_numbers? : Bool
          !@shared_point_numbers.nil?
        end

        extend IOHelpers
      end

      # The 'gvar' (glyph variations) table contains variation data
      # for TrueType glyph outlines.
      class Gvar
        include IOHelpers

        # Major version (should be 1)
        getter major_version : UInt16

        # Minor version (should be 0)
        getter minor_version : UInt16

        # Number of variation axes
        getter axis_count : UInt16

        # Number of shared tuples
        getter shared_tuple_count : UInt16

        # Offset to shared tuples array
        getter shared_tuples_offset : UInt32

        # Number of glyphs
        getter glyph_count : UInt16

        # Flags (bit 0: 0 = uint16 offsets, 1 = uint32 offsets)
        getter flags : UInt16

        # Offset to glyph variation data array
        getter glyph_variation_data_array_offset : UInt32

        # Shared tuples (peak coordinates for common variation regions)
        getter shared_tuples : Array(AxisTuple)

        # Raw table data for lazy glyph data parsing
        @data : Bytes

        # Glyph variation data offsets
        @glyph_offsets : Array(UInt32)

        # Long offsets flag
        LONG_OFFSETS = 0x0001_u16

        def initialize(
          @major_version : UInt16,
          @minor_version : UInt16,
          @axis_count : UInt16,
          @shared_tuple_count : UInt16,
          @shared_tuples_offset : UInt32,
          @glyph_count : UInt16,
          @flags : UInt16,
          @glyph_variation_data_array_offset : UInt32,
          @shared_tuples : Array(AxisTuple),
          @data : Bytes,
          @glyph_offsets : Array(UInt32)
        )
        end

        # Parse the gvar table from raw bytes
        def self.parse(data : Bytes) : Gvar
          io = IO::Memory.new(data)

          major_version = read_uint16(io)
          minor_version = read_uint16(io)
          axis_count = read_uint16(io)
          shared_tuple_count = read_uint16(io)
          shared_tuples_offset = read_uint32(io)
          glyph_count = read_uint16(io)
          flags = read_uint16(io)
          glyph_variation_data_array_offset = read_uint32(io)

          # Read glyph offsets
          long_offsets = (flags & LONG_OFFSETS) != 0
          glyph_offsets = Array(UInt32).new(glyph_count.to_i + 1)

          (glyph_count + 1).times do
            offset = if long_offsets
                       read_uint32(io)
                     else
                       # Short offsets are stored as offset/2
                       read_uint16(io).to_u32 * 2
                     end
            glyph_offsets << offset
          end

          # Parse shared tuples
          shared_tuples = Array(AxisTuple).new(shared_tuple_count.to_i)
          if shared_tuple_count > 0 && shared_tuples_offset > 0
            io.seek(shared_tuples_offset.to_i64)
            shared_tuple_count.times do
              coords = Array(Float64).new(axis_count.to_i)
              axis_count.times do
                # F2DOT14 format
                raw = read_int16(io)
                coords << raw.to_f64 / 16384.0
              end
              shared_tuples << AxisTuple.new(coords)
            end
          end

          new(
            major_version, minor_version,
            axis_count, shared_tuple_count,
            shared_tuples_offset, glyph_count,
            flags, glyph_variation_data_array_offset,
            shared_tuples, data, glyph_offsets
          )
        end

        # Check if a glyph has variation data
        def has_variation_data?(glyph_id : UInt16) : Bool
          return false if glyph_id >= @glyph_count
          idx = glyph_id.to_i
          @glyph_offsets[idx] != @glyph_offsets[idx + 1]
        end

        # Get the size of variation data for a glyph
        def variation_data_size(glyph_id : UInt16) : UInt32
          return 0_u32 if glyph_id >= @glyph_count
          idx = glyph_id.to_i
          @glyph_offsets[idx + 1] - @glyph_offsets[idx]
        end

        # Get the raw variation data bytes for a glyph
        def glyph_variation_bytes(glyph_id : UInt16) : Bytes?
          return nil if glyph_id >= @glyph_count
          return nil unless has_variation_data?(glyph_id)

          idx = glyph_id.to_i
          start_offset = @glyph_variation_data_array_offset + @glyph_offsets[idx]
          end_offset = @glyph_variation_data_array_offset + @glyph_offsets[idx + 1]

          return nil if end_offset > @data.size

          @data[start_offset...end_offset]
        end

        # Parse glyph variation data (lazy, on-demand)
        def parse_glyph_variation_data(glyph_id : UInt16) : GlyphVariationData?
          glyph_data = glyph_variation_bytes(glyph_id)
          return nil unless glyph_data
          return nil if glyph_data.empty?

          io = IO::Memory.new(glyph_data)

          # Read tuple variation count and flags
          tuple_variation_count_raw = read_uint16(io)
          has_shared_points = (tuple_variation_count_raw & GlyphVariationFlags::SHARED_POINT_NUMBERS) != 0
          tuple_count = (tuple_variation_count_raw & GlyphVariationFlags::COUNT_MASK).to_i

          # Read data offset
          data_offset = read_uint16(io)

          # Parse tuple headers
          tuple_headers = Array(TupleVariationHeader).new(tuple_count)
          tuple_count.times do
            variation_data_size = read_uint16(io)
            tuple_index = read_uint16(io)

            # Parse peak tuple if embedded
            peak_tuple = if (tuple_index & TupleFlags::EMBEDDED_PEAK_TUPLE) != 0
                           coords = Array(Float64).new(@axis_count.to_i)
                           @axis_count.times do
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
              start_coords = Array(Float64).new(@axis_count.to_i)
              @axis_count.times do
                raw = read_int16(io)
                start_coords << raw.to_f64 / 16384.0
              end
              intermediate_start = AxisTuple.new(start_coords)

              end_coords = Array(Float64).new(@axis_count.to_i)
              @axis_count.times do
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

          # Get serialized data section
          serialized_data = glyph_data[data_offset.to_i..]

          # Parse shared point numbers if present
          shared_point_numbers = if has_shared_points && serialized_data.size > 0
                                   parse_packed_points(IO::Memory.new(serialized_data))
                                 else
                                   nil
                                 end

          GlyphVariationData.new(
            tuple_headers, shared_point_numbers,
            serialized_data, data_offset
          )
        end

        # Get the peak tuple for a tuple header
        def peak_tuple_for(header : TupleVariationHeader) : AxisTuple?
          if header.embedded_peak?
            header.peak_tuple
          else
            idx = header.shared_tuple_index.to_i
            return nil if idx >= @shared_tuples.size
            @shared_tuples[idx]
          end
        end

        # Calculate the scalar multiplier for a tuple given instance coordinates.
        # Returns 0.0 if the region doesn't apply, otherwise a value in [0.0, 1.0].
        def calculate_scalar(
          header : TupleVariationHeader,
          normalized_coords : Array(Float64)
        ) : Float64
          peak = peak_tuple_for(header)
          return 0.0 unless peak
          return 0.0 if peak.size != normalized_coords.size

          scalar = 1.0

          peak.coordinates.each_with_index do |peak_val, i|
            # If peak is 0, this axis doesn't affect this tuple
            next if peak_val == 0.0

            coord = normalized_coords[i]

            if header.intermediate_region?
              start_tuple = header.intermediate_start_tuple
              end_tuple = header.intermediate_end_tuple
              return 0.0 unless start_tuple && end_tuple

              start_val = start_tuple[i]
              end_val = end_tuple[i]

              # Check if coordinate is outside the region
              if coord < ::Math.min(start_val, end_val) || coord > ::Math.max(start_val, end_val)
                return 0.0
              end

              # Calculate per-axis scalar
              if coord == peak_val
                # At peak, scalar is 1.0 for this axis
                next
              elsif start_val <= end_val
                if coord <= start_val
                  return 0.0
                elsif coord >= end_val
                  return 0.0
                elsif coord <= peak_val
                  axis_scalar = (coord - start_val) / (peak_val - start_val)
                  scalar *= axis_scalar
                else
                  axis_scalar = (end_val - coord) / (end_val - peak_val)
                  scalar *= axis_scalar
                end
              else
                # Inverted range
                if coord >= start_val
                  return 0.0
                elsif coord <= end_val
                  return 0.0
                elsif coord >= peak_val
                  axis_scalar = (start_val - coord) / (start_val - peak_val)
                  scalar *= axis_scalar
                else
                  axis_scalar = (coord - end_val) / (peak_val - end_val)
                  scalar *= axis_scalar
                end
              end
            else
              # Non-intermediate region: range is [0, peak] or [peak, 0]
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

        # Parse packed point numbers from IO
        private def parse_packed_points(io : IO) : Array(UInt16)
          points = [] of UInt16

          # Read count
          count_byte = read_uint8(io)
          count = if (count_byte & 0x80) != 0
                    # High bit set: 2-byte count
                    ((count_byte & 0x7F).to_u16 << 8) | read_uint8(io).to_u16
                  elsif count_byte == 0
                    # Zero means all points
                    return points
                  else
                    count_byte.to_u16
                  end

          return points if count == 0

          # Read point runs
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

        # Parse packed deltas from IO
        def parse_packed_deltas(io : IO, count : Int32) : Array(Int16)
          deltas = Array(Int16).new(count)
          read_count = 0

          while read_count < count
            control = read_uint8(io)
            run_count = (control & 0x3F) + 1

            if (control & 0x80) != 0
              # DELTAS_ARE_ZERO: all zeros in this run
              run_count.times do
                break if read_count >= count
                deltas << 0_i16
                read_count += 1
              end
            elsif (control & 0x40) != 0
              # DELTAS_ARE_WORDS: 16-bit deltas
              run_count.times do
                break if read_count >= count
                deltas << read_int16(io)
                read_count += 1
              end
            else
              # 8-bit deltas
              run_count.times do
                break if read_count >= count
                deltas << read_int8(io).to_i16
                read_count += 1
              end
            end
          end

          deltas
        end

        # Represents computed deltas for a glyph's points at specific variation coordinates.
        struct GlyphDeltas
          # X deltas for each point (in font units)
          getter x_deltas : Array(Float64)

          # Y deltas for each point (in font units)
          getter y_deltas : Array(Float64)

          def initialize(@x_deltas : Array(Float64), @y_deltas : Array(Float64))
          end

          # Number of points
          def size : Int32
            @x_deltas.size
          end

          # Check if there are any non-zero deltas
          def any_nonzero? : Bool
            @x_deltas.any? { |d| d != 0.0 } || @y_deltas.any? { |d| d != 0.0 }
          end
        end

        # Compute the interpolated deltas for a glyph at the given normalized coordinates.
        # Returns nil if the glyph has no variation data.
        # The point_count should match the number of points in the glyph (including phantom points).
        def compute_glyph_deltas(
          glyph_id : UInt16,
          normalized_coords : Array(Float64),
          point_count : Int32
        ) : GlyphDeltas?
          glyph_data = parse_glyph_variation_data(glyph_id)
          return nil unless glyph_data
          return nil if glyph_data.tuple_headers.empty?

          # Initialize accumulated deltas (includes 4 phantom points)
          total_point_count = point_count + 4
          x_deltas = Array(Float64).new(total_point_count, 0.0)
          y_deltas = Array(Float64).new(total_point_count, 0.0)

          # Create IO for serialized data
          io = IO::Memory.new(glyph_data.serialized_data)

          # Process each tuple
          glyph_data.tuple_headers.each do |header|
            # Calculate scalar for this tuple
            scalar = calculate_scalar(header, normalized_coords)
            next if scalar == 0.0

            # Determine point numbers for this tuple
            point_numbers = if header.private_point_numbers?
                              parse_packed_points(io)
                            elsif shared = glyph_data.shared_point_numbers
                              shared
                            else
                              # All points
                              (0...total_point_count).map(&.to_u16).to_a
                            end

            # Handle "all points" case (empty array means all points)
            if point_numbers.empty?
              point_numbers = (0...total_point_count).map(&.to_u16).to_a
            end

            # Parse deltas for X coordinates
            x_raw = parse_packed_deltas(io, point_numbers.size)
            # Parse deltas for Y coordinates
            y_raw = parse_packed_deltas(io, point_numbers.size)

            # Apply deltas with scalar
            point_numbers.each_with_index do |pt_idx, i|
              next if pt_idx >= total_point_count
              x_deltas[pt_idx.to_i] += scalar * x_raw[i]
              y_deltas[pt_idx.to_i] += scalar * y_raw[i]
            end
          end

          # Return only the actual glyph points (exclude phantom points)
          GlyphDeltas.new(
            x_deltas[0...point_count],
            y_deltas[0...point_count]
          )
        end

        extend IOHelpers
      end
    end
  end
end
