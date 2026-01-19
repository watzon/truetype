module TrueType
  module Tables
    module Hinting
      # The 'VDMX' (Vertical Device Metrics) table stores pre-computed
      # yMax and yMin values for specific ppem sizes.
      #
      # This prevents clipping when glyphs are rendered at sizes where
      # the scaled and hinted values differ from simple linear scaling.
      #
      # Table tag: 'VDMX'
      class Vdmx
        include IOHelpers

        # A single height record in a VDMX group
        record VTable,
          # Height value for this record (ppem)
          y_pel_height : UInt16,
          # Maximum value in pixels
          y_max : Int16,
          # Minimum value in pixels
          y_min : Int16 do
          include IOHelpers

          def self.parse(io : IO) : VTable
            y_pel_height = read_uint16(io)
            y_max = read_int16(io)
            y_min = read_int16(io)
            new(y_pel_height, y_max, y_min)
          end

          def write(io : IO) : Nil
            write_uint16(io, @y_pel_height)
            write_int16(io, @y_max)
            write_int16(io, @y_min)
          end

          extend IOHelpers
        end

        # A VDMX group containing height records
        class VdmxGroup
          include IOHelpers

          # Number of height records
          getter recs : UInt16

          # Starting yPelHeight
          getter startsz : UInt8

          # Ending yPelHeight
          getter endsz : UInt8

          # Array of height records (sorted by yPelHeight)
          getter entries : Array(VTable)

          def initialize(@recs : UInt16, @startsz : UInt8, @endsz : UInt8, @entries : Array(VTable))
          end

          def self.parse(io : IO) : VdmxGroup
            recs = read_uint16(io)
            startsz = read_uint8(io)
            endsz = read_uint8(io)

            entries = Array(VTable).new(recs.to_i) do
              VTable.parse(io)
            end

            new(recs, startsz, endsz, entries)
          end

          # Get the height record for a specific ppem
          def entry(y_pel_height : UInt16) : VTable?
            @entries.find { |e| e.y_pel_height == y_pel_height }
          end

          # Get yMax/yMin for a specific ppem (using binary search would be better)
          def bounds(y_pel_height : UInt16) : Tuple(Int16, Int16)?
            entry = @entries.find { |e| e.y_pel_height == y_pel_height }
            return nil unless entry
            {entry.y_max, entry.y_min}
          end

          def write(io : IO) : Nil
            write_uint16(io, @recs)
            io.write_byte(@startsz)
            io.write_byte(@endsz)
            @entries.each(&.write(io))
          end

          extend IOHelpers
        end

        # A ratio range record for matching aspect ratios
        record RatioRange,
          # Character set (0 or 1 in version 1)
          b_char_set : UInt8,
          # X aspect ratio numerator
          x_ratio : UInt8,
          # Y aspect ratio start
          y_start_ratio : UInt8,
          # Y aspect ratio end
          y_end_ratio : UInt8 do
          include IOHelpers

          def self.parse(io : IO) : RatioRange
            b_char_set = read_uint8(io)
            x_ratio = read_uint8(io)
            y_start_ratio = read_uint8(io)
            y_end_ratio = read_uint8(io)
            new(b_char_set, x_ratio, y_start_ratio, y_end_ratio)
          end

          def write(io : IO) : Nil
            io.write_byte(@b_char_set)
            io.write_byte(@x_ratio)
            io.write_byte(@y_start_ratio)
            io.write_byte(@y_end_ratio)
          end

          # Check if this is the default/catch-all ratio (0,0,0)
          def default? : Bool
            @x_ratio == 0 && @y_start_ratio == 0 && @y_end_ratio == 0
          end

          # Check if a device aspect ratio matches this range
          def matches?(device_x_ratio : UInt8, device_y_ratio : UInt8) : Bool
            return true if default?
            device_x_ratio == @x_ratio &&
              device_y_ratio >= @y_start_ratio &&
              device_y_ratio <= @y_end_ratio
          end

          extend IOHelpers
        end

        # Table version (0 or 1)
        getter version : UInt16

        # Number of VDMX groups
        getter num_recs : UInt16

        # Number of aspect ratio groupings
        getter num_ratios : UInt16

        # Ratio range records
        getter ratio_ranges : Array(RatioRange)

        # Offsets to VDMX groups (from start of table)
        getter group_offsets : Array(UInt16)

        # VDMX groups (parsed on demand or eagerly)
        getter groups : Array(VdmxGroup)

        def initialize(
          @version : UInt16,
          @num_recs : UInt16,
          @num_ratios : UInt16,
          @ratio_ranges : Array(RatioRange),
          @group_offsets : Array(UInt16),
          @groups : Array(VdmxGroup)
        )
        end

        # Parse the VDMX table from raw bytes
        def self.parse(data : Bytes) : Vdmx
          io = IO::Memory.new(data)
          version = read_uint16(io)
          num_recs = read_uint16(io)
          num_ratios = read_uint16(io)

          ratio_ranges = Array(RatioRange).new(num_ratios.to_i) do
            RatioRange.parse(io)
          end

          group_offsets = Array(UInt16).new(num_ratios.to_i) do
            read_uint16(io)
          end

          # Parse all VDMX groups
          # Groups can be shared, so we parse unique offsets only
          unique_offsets = group_offsets.uniq.sort
          offset_to_group = Hash(UInt16, VdmxGroup).new

          unique_offsets.each do |offset|
            io.pos = offset.to_i
            offset_to_group[offset] = VdmxGroup.parse(io)
          end

          # Build groups array matching offset order
          groups = group_offsets.map { |offset| offset_to_group[offset] }

          new(version, num_recs, num_ratios, ratio_ranges, group_offsets, groups)
        end

        # Find the VDMX group for a given device aspect ratio
        def group_for_ratio(device_x_ratio : UInt8, device_y_ratio : UInt8) : VdmxGroup?
          @ratio_ranges.each_with_index do |ratio, index|
            if ratio.matches?(device_x_ratio, device_y_ratio)
              return @groups[index]?
            end
          end
          nil
        end

        # Get yMax/yMin bounds for a given ppem and aspect ratio
        def bounds(y_pel_height : UInt16, device_x_ratio : UInt8 = 1_u8, device_y_ratio : UInt8 = 1_u8) : Tuple(Int16, Int16)?
          group = group_for_ratio(device_x_ratio, device_y_ratio)
          return nil unless group
          group.bounds(y_pel_height)
        end

        # Get yMax for a given ppem (assumes 1:1 aspect ratio)
        def y_max(y_pel_height : UInt16) : Int16?
          bounds(y_pel_height).try(&.[0])
        end

        # Get yMin for a given ppem (assumes 1:1 aspect ratio)
        def y_min(y_pel_height : UInt16) : Int16?
          bounds(y_pel_height).try(&.[1])
        end

        # Check if this is version 1
        def v1? : Bool
          @version >= 1
        end

        # Number of groups
        def size : Int32
          @groups.size
        end

        # Check if the table is empty
        def empty? : Bool
          @groups.empty?
        end

        # Serialize this table to bytes
        def to_bytes : Bytes
          io = IO::Memory.new
          write(io)
          io.to_slice
        end

        # Write this table to an IO
        def write(io : IO) : Nil
          write_uint16(io, @version)
          write_uint16(io, @num_recs)
          write_uint16(io, @num_ratios)

          @ratio_ranges.each(&.write(io))
          @group_offsets.each { |offset| write_uint16(io, offset) }

          # Write unique groups at their offsets
          written_offsets = Set(UInt16).new
          @group_offsets.each_with_index do |offset, index|
            next if written_offsets.includes?(offset)
            written_offsets << offset

            # Seek to offset and write
            io.pos = offset.to_i
            @groups[index].write(io)
          end
        end

        extend IOHelpers
      end
    end
  end
end
