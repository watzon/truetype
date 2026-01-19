module TrueType
  module Tables
    module Variations
      # Represents a region axis coordinates record.
      # Defines the start, peak, and end of a region for one axis.
      struct RegionAxisCoordinates
        # Start of region (F2DOT14)
        getter start_coord : Float64

        # Peak of region (F2DOT14)
        getter peak_coord : Float64

        # End of region (F2DOT14)
        getter end_coord : Float64

        def initialize(@start_coord : Float64, @peak_coord : Float64, @end_coord : Float64)
        end

        # Calculate the scalar for this axis given a normalized coordinate
        def scalar(normalized_coord : Float64) : Float64
          # If peak is 0, this axis doesn't contribute
          return 1.0 if @peak_coord == 0.0

          # Outside the region
          if normalized_coord < @start_coord || normalized_coord > @end_coord
            return 0.0
          end

          # At peak
          return 1.0 if normalized_coord == @peak_coord

          # Interpolate
          if normalized_coord < @peak_coord
            if @peak_coord == @start_coord
              1.0
            else
              (normalized_coord - @start_coord) / (@peak_coord - @start_coord)
            end
          else
            if @end_coord == @peak_coord
              1.0
            else
              (@end_coord - normalized_coord) / (@end_coord - @peak_coord)
            end
          end
        end
      end

      # Represents a variation region.
      # A region defines a multi-dimensional subset of the variation space.
      struct VariationRegion
        # Axis coordinates for this region (one per axis)
        getter axis_coordinates : Array(RegionAxisCoordinates)

        def initialize(@axis_coordinates : Array(RegionAxisCoordinates))
        end

        # Calculate the scalar for this region given normalized coordinates
        def scalar(normalized_coords : Array(Float64)) : Float64
          return 0.0 if normalized_coords.size != @axis_coordinates.size

          result = 1.0
          @axis_coordinates.each_with_index do |axis_coord, i|
            axis_scalar = axis_coord.scalar(normalized_coords[i])
            return 0.0 if axis_scalar == 0.0
            result *= axis_scalar
          end
          result
        end
      end

      # Represents the variation region list.
      class VariationRegionList
        include IOHelpers

        # Number of variation axes
        getter axis_count : UInt16

        # Number of variation regions
        getter region_count : UInt16

        # Array of variation regions
        getter regions : Array(VariationRegion)

        def initialize(@axis_count : UInt16, @region_count : UInt16, @regions : Array(VariationRegion))
        end

        def self.parse(io : IO, offset : UInt32) : VariationRegionList
          io.seek(offset.to_i64)

          axis_count = read_uint16(io)
          region_count = read_uint16(io)

          regions = Array(VariationRegion).new(region_count.to_i)
          region_count.times do
            axis_coords = Array(RegionAxisCoordinates).new(axis_count.to_i)
            axis_count.times do
              # F2DOT14 values
              start_raw = read_int16(io)
              peak_raw = read_int16(io)
              end_raw = read_int16(io)

              start_coord = start_raw.to_f64 / 16384.0
              peak_coord = peak_raw.to_f64 / 16384.0
              end_coord = end_raw.to_f64 / 16384.0

              axis_coords << RegionAxisCoordinates.new(start_coord, peak_coord, end_coord)
            end
            regions << VariationRegion.new(axis_coords)
          end

          new(axis_count, region_count, regions)
        end

        extend IOHelpers
      end

      # Represents item variation data for a subtable.
      class ItemVariationData
        include IOHelpers

        # Number of items in this subtable
        getter item_count : UInt16

        # Number of 16-bit deltas (word count)
        getter word_delta_count : UInt16

        # Number of regions referenced
        getter region_index_count : UInt16

        # Indices into the region list
        getter region_indices : Array(UInt16)

        # Delta values: [item_count][region_index_count]
        # Each item has one delta per referenced region
        getter delta_sets : Array(Array(Int32))

        def initialize(
          @item_count : UInt16,
          @word_delta_count : UInt16,
          @region_index_count : UInt16,
          @region_indices : Array(UInt16),
          @delta_sets : Array(Array(Int32))
        )
        end

        def self.parse(io : IO, offset : UInt32) : ItemVariationData
          io.seek(offset.to_i64)

          item_count = read_uint16(io)
          word_delta_count = read_uint16(io)
          region_index_count = read_uint16(io)

          region_indices = Array(UInt16).new(region_index_count.to_i)
          region_index_count.times do
            region_indices << read_uint16(io)
          end

          # Parse delta sets
          # word_delta_count indicates how many deltas are 16-bit (rest are 8-bit)
          delta_sets = Array(Array(Int32)).new(item_count.to_i)
          item_count.times do
            deltas = Array(Int32).new(region_index_count.to_i)

            region_index_count.times do |i|
              delta = if i < word_delta_count
                        read_int16(io).to_i32
                      else
                        read_int8(io).to_i32
                      end
              deltas << delta
            end

            delta_sets << deltas
          end

          new(item_count, word_delta_count, region_index_count, region_indices, delta_sets)
        end

        # Get delta for an item given normalized coordinates
        def get_delta(item_index : UInt16, normalized_coords : Array(Float64), region_list : VariationRegionList) : Float64
          return 0.0 if item_index >= @item_count
          return 0.0 if item_index >= @delta_sets.size

          deltas = @delta_sets[item_index.to_i]
          total = 0.0

          deltas.each_with_index do |delta, i|
            next if i >= @region_indices.size
            region_idx = @region_indices[i].to_i
            next if region_idx >= region_list.regions.size

            region = region_list.regions[region_idx]
            scalar = region.scalar(normalized_coords)
            total += scalar * delta
          end

          total
        end

        extend IOHelpers
      end

      # The ItemVariationStore contains variation data used by
      # HVAR, VVAR, MVAR, and other tables.
      class ItemVariationStore
        include IOHelpers

        # Format (should be 1)
        getter format : UInt16

        # Offset to variation region list
        getter variation_region_list_offset : UInt32

        # Number of item variation data subtables
        getter item_variation_data_count : UInt16

        # Variation region list
        getter region_list : VariationRegionList

        # Item variation data subtables
        getter item_variation_data : Array(ItemVariationData)

        def initialize(
          @format : UInt16,
          @variation_region_list_offset : UInt32,
          @item_variation_data_count : UInt16,
          @region_list : VariationRegionList,
          @item_variation_data : Array(ItemVariationData)
        )
        end

        def self.parse(data : Bytes, offset : UInt32) : ItemVariationStore
          io = IO::Memory.new(data)
          io.seek(offset.to_i64)
          base_offset = offset

          format = read_uint16(io)
          variation_region_list_offset = read_uint32(io)
          item_variation_data_count = read_uint16(io)

          # Read offsets to item variation data subtables
          item_variation_data_offsets = Array(UInt32).new(item_variation_data_count.to_i)
          item_variation_data_count.times do
            item_variation_data_offsets << read_uint32(io)
          end

          # Parse region list
          region_list = VariationRegionList.parse(io, base_offset + variation_region_list_offset)

          # Parse item variation data subtables
          item_variation_data = item_variation_data_offsets.map do |ivd_offset|
            ItemVariationData.parse(io, base_offset + ivd_offset)
          end

          new(format, variation_region_list_offset, item_variation_data_count, region_list, item_variation_data)
        end

        # Get delta for an outer/inner index pair
        def get_delta(outer_index : UInt16, inner_index : UInt16, normalized_coords : Array(Float64)) : Float64
          return 0.0 if outer_index >= @item_variation_data.size
          @item_variation_data[outer_index.to_i].get_delta(inner_index, normalized_coords, @region_list)
        end

        # Compute region scalars for a given vsindex (used by CFF2 blend)
        # Returns an array of scalars, one per region referenced by the subtable
        def compute_scalars(vsindex : UInt16, normalized_coords : Array(Float64)) : Array(Float64)
          return [] of Float64 if vsindex >= @item_variation_data.size

          subtable = @item_variation_data[vsindex.to_i]
          scalars = Array(Float64).new(subtable.region_indices.size)

          subtable.region_indices.each do |region_idx|
            if region_idx < @region_list.regions.size
              region = @region_list.regions[region_idx.to_i]
              scalars << region.scalar(normalized_coords)
            else
              scalars << 0.0
            end
          end

          scalars
        end

        # Get the number of regions for a given subtable index
        def region_count(vsindex : UInt16) : Int32
          return 0 if vsindex >= @item_variation_data.size
          @item_variation_data[vsindex.to_i].region_indices.size
        end

        extend IOHelpers
      end

      # Delta set index map - maps item indices to variation store indices
      class DeltaSetIndexMap
        include IOHelpers

        # Entry format
        getter format : UInt8

        # Entry size in bytes
        getter entry_size : UInt8

        # Number of entries
        getter map_count : UInt32

        # Map data (outer << inner_bits | inner)
        getter map_data : Array(UInt32)

        # Number of bits for inner index
        getter inner_index_bits : UInt8

        def initialize(
          @format : UInt8,
          @entry_size : UInt8,
          @map_count : UInt32,
          @map_data : Array(UInt32),
          @inner_index_bits : UInt8
        )
        end

        def self.parse(io : IO, offset : UInt32) : DeltaSetIndexMap
          io.seek(offset.to_i64)

          format = read_uint8(io)
          entry_size = read_uint8(io)
          map_count = if format == 0
                        read_uint16(io).to_u32
                      else
                        read_uint32(io)
                      end

          # Entry size determines inner index bits
          # Entry format: (outerIndex << innerBits) | innerIndex
          inner_index_bits = case entry_size
                             when 1 then 0_u8
                             when 2 then 8_u8
                             when 3 then 8_u8
                             when 4 then 16_u8
                             else        8_u8
                             end

          map_data = Array(UInt32).new(map_count.to_i)
          map_count.times do
            value = case entry_size
                    when 1 then read_uint8(io).to_u32
                    when 2 then read_uint16(io).to_u32
                    when 3
                      b0 = read_uint8(io).to_u32
                      b1 = read_uint8(io).to_u32
                      b2 = read_uint8(io).to_u32
                      (b0 << 16) | (b1 << 8) | b2
                    when 4 then read_uint32(io)
                    else        read_uint16(io).to_u32
                    end
            map_data << value
          end

          new(format, entry_size, map_count, map_data, inner_index_bits)
        end

        # Get outer and inner indices for a given item index
        def get_indices(item_index : UInt32) : Tuple(UInt16, UInt16)
          return {0_u16, 0_u16} if item_index >= @map_count

          value = @map_data[item_index.to_i]
          inner_mask = (1_u32 << @inner_index_bits) - 1
          inner = (value & inner_mask).to_u16
          outer = (value >> @inner_index_bits).to_u16
          {outer, inner}
        end

        extend IOHelpers
      end
    end
  end
end
