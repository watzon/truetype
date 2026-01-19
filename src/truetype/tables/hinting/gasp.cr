module TrueType
  module Tables
    module Hinting
      # The 'gasp' (Grid-fitting And Scan-conversion Procedure) table
      # specifies rasterization behavior at different ppem sizes.
      #
      # This table controls when gridfitting (hinting) and grayscale/
      # ClearType rendering should be used for optimal text quality.
      #
      # Table tag: 'gasp'
      class Gasp
        include IOHelpers

        # GaspRange behavior flags
        @[Flags]
        enum Behavior : UInt16
          # Use gridfitting (hinting)
          Gridfit = 0x0001

          # Use grayscale rendering
          DoGray = 0x0002

          # Use gridfitting with ClearType symmetric smoothing (v1 only)
          SymmetricGridfit = 0x0004

          # Use smoothing along multiple axes with ClearType (v1 only)
          SymmetricSmoothing = 0x0008
        end

        # A single gasp range record
        record GaspRange,
          # Upper limit of range, in ppem (last should be 0xFFFF)
          range_max_ppem : UInt16,
          # Flags describing desired rasterizer behavior
          range_gasp_behavior : Behavior do
          include IOHelpers

          def self.parse(io : IO) : GaspRange
            range_max_ppem = read_uint16(io)
            range_gasp_behavior = Behavior.new(read_uint16(io))
            new(range_max_ppem, range_gasp_behavior)
          end

          def write(io : IO) : Nil
            write_uint16(io, @range_max_ppem)
            write_uint16(io, @range_gasp_behavior.value)
          end

          # Check if gridfitting is enabled
          def gridfit? : Bool
            @range_gasp_behavior.gridfit?
          end

          # Check if grayscale is enabled
          def grayscale? : Bool
            @range_gasp_behavior.do_gray?
          end

          # Check if ClearType symmetric gridfitting is enabled
          def symmetric_gridfit? : Bool
            @range_gasp_behavior.symmetric_gridfit?
          end

          # Check if ClearType symmetric smoothing is enabled
          def symmetric_smoothing? : Bool
            @range_gasp_behavior.symmetric_smoothing?
          end

          extend IOHelpers
        end

        # Table version (0 or 1)
        getter version : UInt16

        # Array of gasp range records (sorted by ppem)
        getter ranges : Array(GaspRange)

        def initialize(@version : UInt16, @ranges : Array(GaspRange))
        end

        # Parse the gasp table from raw bytes
        def self.parse(data : Bytes) : Gasp
          io = IO::Memory.new(data)
          parse(io)
        end

        # Parse the gasp table from an IO
        def self.parse(io : IO) : Gasp
          version = read_uint16(io)
          num_ranges = read_uint16(io)

          ranges = Array(GaspRange).new(num_ranges.to_i) do
            GaspRange.parse(io)
          end

          new(version, ranges)
        end

        # Get the behavior flags for a given ppem size
        def behavior(ppem : UInt16) : Behavior
          @ranges.each do |range|
            if ppem <= range.range_max_ppem
              return range.range_gasp_behavior
            end
          end
          # Default: no special behavior
          Behavior::None
        end

        # Check if gridfitting should be used at a given ppem
        def gridfit?(ppem : UInt16) : Bool
          behavior(ppem).gridfit?
        end

        # Check if grayscale should be used at a given ppem
        def grayscale?(ppem : UInt16) : Bool
          behavior(ppem).do_gray?
        end

        # Check if ClearType symmetric gridfitting should be used
        def symmetric_gridfit?(ppem : UInt16) : Bool
          behavior(ppem).symmetric_gridfit?
        end

        # Check if ClearType symmetric smoothing should be used
        def symmetric_smoothing?(ppem : UInt16) : Bool
          behavior(ppem).symmetric_smoothing?
        end

        # Number of range records
        def size : Int32
          @ranges.size
        end

        # Check if the table is empty
        def empty? : Bool
          @ranges.empty?
        end

        # Check if this is version 1 (supports ClearType flags)
        def v1? : Bool
          @version >= 1
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
          write_uint16(io, @ranges.size.to_u16)
          @ranges.each do |range|
            range.write(io)
          end
        end

        extend IOHelpers
      end
    end
  end
end
