module TrueType
  module Tables
    module Bitmap
      # The 'EBSC' table (Embedded Bitmap Scaling) provides information about
      # how to scale bitmaps for sizes where explicit strikes are not available.
      #
      # Each record specifies a target PPEM size and which existing strike
      # should be scaled to approximate it.
      class EBSC
        include IOHelpers

        # Major version (2 for EBSC)
        getter major_version : UInt16

        # Minor version (0)
        getter minor_version : UInt16

        # Number of BitmapScaleTable records
        getter num_sizes : UInt32

        # Bitmap scale records
        getter sizes : Array(BitmapScale)

        def initialize(
          @major_version : UInt16,
          @minor_version : UInt16,
          @num_sizes : UInt32,
          @sizes : Array(BitmapScale)
        )
        end

        # Parse EBSC table from raw bytes
        def self.parse(data : Bytes) : EBSC
          io = IO::Memory.new(data)

          major_version = read_uint16(io)
          minor_version = read_uint16(io)
          num_sizes = read_uint32(io)

          sizes = Array(BitmapScale).new(num_sizes.to_i)
          num_sizes.times do
            sizes << BitmapScale.parse(io)
          end

          new(major_version, minor_version, num_sizes, sizes)
        end

        # Find the substitute strike for a given target PPEM
        def substitute_for(ppem_x : UInt8, ppem_y : UInt8) : BitmapScale?
          @sizes.find { |s| s.ppem_x == ppem_x && s.ppem_y == ppem_y }
        end

        # Find the substitute strike for a given target PPEM (square pixels)
        def substitute_for(ppem : UInt8) : BitmapScale?
          substitute_for(ppem, ppem)
        end

        # Get the source strike PPEM to use for a target PPEM
        def source_ppem_for(target_ppem : UInt8) : UInt8?
          scale = substitute_for(target_ppem)
          scale.try(&.substitute_ppem_x)
        end

        # Get all target PPEM sizes defined in this table
        def target_sizes : Array(UInt8)
          @sizes.map(&.ppem_x).uniq.sort
        end

        extend IOHelpers
      end

      # Bitmap scale record for EBSC table
      struct BitmapScale
        include IOHelpers
        extend IOHelpers

        # Horizontal line metrics
        getter hori : SbitLineMetrics

        # Vertical line metrics
        getter vert : SbitLineMetrics

        # Target horizontal PPEM size
        getter ppem_x : UInt8

        # Target vertical PPEM size
        getter ppem_y : UInt8

        # Substitute horizontal PPEM size (source strike to scale from)
        getter substitute_ppem_x : UInt8

        # Substitute vertical PPEM size (source strike to scale from)
        getter substitute_ppem_y : UInt8

        def initialize(
          @hori : SbitLineMetrics,
          @vert : SbitLineMetrics,
          @ppem_x : UInt8,
          @ppem_y : UInt8,
          @substitute_ppem_x : UInt8,
          @substitute_ppem_y : UInt8
        )
        end

        def self.parse(io : IO) : BitmapScale
          hori = SbitLineMetrics.parse(io)
          vert = SbitLineMetrics.parse(io)
          ppem_x = io.read_byte.not_nil!
          ppem_y = io.read_byte.not_nil!
          substitute_ppem_x = io.read_byte.not_nil!
          substitute_ppem_y = io.read_byte.not_nil!

          new(hori, vert, ppem_x, ppem_y, substitute_ppem_x, substitute_ppem_y)
        end

        # Calculate the scaling factor from substitute to target
        def scale_factor_x : Float64
          @ppem_x.to_f64 / @substitute_ppem_x.to_f64
        end

        # Calculate the scaling factor from substitute to target
        def scale_factor_y : Float64
          @ppem_y.to_f64 / @substitute_ppem_y.to_f64
        end
      end
    end
  end
end
