module TrueType
  module Tables
    module Hinting
      # The 'LTSH' (Linear Threshold) table contains per-glyph ppem values
      # at which the glyph's advance width scales linearly.
      #
      # This table is used to optimize rendering performance by allowing
      # the rasterizer to skip hinting for glyphs at sizes where hinting
      # doesn't significantly affect the advance width.
      #
      # Table tag: 'LTSH'
      class Ltsh
        include IOHelpers

        # Table version (should be 0)
        getter version : UInt16

        # Number of glyphs (should match maxp.numGlyphs)
        getter num_glyphs : UInt16

        # Per-glyph linear threshold values (ppem)
        # A value of 1 means always linear (no sidebearing instructions)
        # A value of 0 is invalid
        # Values >= 50 are the actual threshold
        getter y_pixels : Array(UInt8)

        def initialize(@version : UInt16, @num_glyphs : UInt16, @y_pixels : Array(UInt8))
        end

        # Parse the LTSH table from raw bytes
        def self.parse(data : Bytes) : Ltsh
          io = IO::Memory.new(data)
          parse(io)
        end

        # Parse the LTSH table from an IO
        def self.parse(io : IO) : Ltsh
          version = read_uint16(io)
          num_glyphs = read_uint16(io)

          y_pixels = Array(UInt8).new(num_glyphs.to_i) do
            read_uint8(io)
          end

          new(version, num_glyphs, y_pixels)
        end

        # Get the linear threshold for a glyph
        def threshold(glyph_id : UInt16) : UInt8?
          @y_pixels[glyph_id.to_i]?
        end

        # Check if a glyph always scales linearly (no hinting needed)
        def always_linear?(glyph_id : UInt16) : Bool
          threshold = @y_pixels[glyph_id.to_i]?
          threshold == 1_u8
        end

        # Check if a glyph scales linearly at a given ppem
        def linear_at?(glyph_id : UInt16, ppem : UInt8) : Bool
          threshold = @y_pixels[glyph_id.to_i]?
          return false unless threshold
          return true if threshold == 1_u8
          ppem >= threshold
        end

        # Number of entries
        def size : Int32
          @y_pixels.size
        end

        # Check if the table is empty
        def empty? : Bool
          @y_pixels.empty?
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
          write_uint16(io, @num_glyphs)
          @y_pixels.each do |value|
            io.write_byte(value)
          end
        end

        extend IOHelpers
      end
    end
  end
end
