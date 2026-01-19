module TrueType
  module Tables
    module Color
      # Graphic type tags for sbix
      module SbixGraphicType
        PNG  = "png "
        JPG  = "jpg "
        TIFF = "tiff"
        DUPE = "dupe" # Reference to another glyph
        PDF  = "pdf " # PDF artwork
        MASK = "mask" # Mask image
      end

      # sbix glyph data
      struct SbixGlyphData
        # X offset from glyph origin
        getter origin_offset_x : Int16

        # Y offset from glyph origin
        getter origin_offset_y : Int16

        # Graphic type (png, jpg, tiff, dupe, pdf, mask)
        getter graphic_type : String

        # Raw graphic data (PNG/JPG/etc bytes, or glyph ID for dupe)
        getter data : Bytes

        def initialize(
          @origin_offset_x : Int16,
          @origin_offset_y : Int16,
          @graphic_type : String,
          @data : Bytes
        )
        end

        # Check if this is a duplicate reference
        def dupe? : Bool
          @graphic_type == SbixGraphicType::DUPE
        end

        # Get the referenced glyph ID if this is a dupe
        def dupe_glyph_id : UInt16?
          return nil unless dupe?
          return nil if @data.size < 2

          io = IO::Memory.new(@data)
          (@data[0].to_u16 << 8) | @data[1].to_u16
        end

        # Check if this is a PNG image
        def png? : Bool
          @graphic_type == SbixGraphicType::PNG
        end

        # Check if this is a JPEG image
        def jpg? : Bool
          @graphic_type == SbixGraphicType::JPG
        end

        # Check if this is a TIFF image
        def tiff? : Bool
          @graphic_type == SbixGraphicType::TIFF
        end
      end

      # sbix strike (a set of glyph images at a specific PPEM)
      class SbixStrike
        include IOHelpers

        # Pixels per EM for this strike
        getter ppem : UInt16

        # Screen pixels per inch for this strike
        getter ppi : UInt16

        # Glyph data offsets (from start of strike)
        getter glyph_data_offsets : Array(UInt32)

        # Raw strike data
        @data : Bytes

        # Strike offset in table
        @strike_offset : UInt32

        def initialize(
          @ppem : UInt16,
          @ppi : UInt16,
          @glyph_data_offsets : Array(UInt32),
          @data : Bytes,
          @strike_offset : UInt32
        )
        end

        # Get glyph data for a glyph ID
        def glyph_data(glyph_id : UInt16) : SbixGlyphData?
          return nil if glyph_id >= @glyph_data_offsets.size - 1

          start_offset = @glyph_data_offsets[glyph_id]
          end_offset = @glyph_data_offsets[glyph_id + 1]

          # Empty glyph (no data)
          return nil if start_offset == end_offset

          abs_offset = @strike_offset.to_i + start_offset.to_i
          return nil if abs_offset + 8 > @data.size

          io = IO::Memory.new(@data[abs_offset..])

          origin_offset_x = read_int16(io)
          origin_offset_y = read_int16(io)

          # Read 4-byte graphic type tag
          tag_bytes = Bytes.new(4)
          io.read_fully(tag_bytes)
          graphic_type = String.new(tag_bytes)

          # Calculate data length
          data_length = (end_offset - start_offset - 8).to_i
          return nil if data_length < 0

          data = Bytes.new(data_length)
          io.read_fully(data) if data_length > 0

          SbixGlyphData.new(origin_offset_x, origin_offset_y, graphic_type, data)
        rescue
          nil
        end

        # Check if a glyph has data in this strike
        def has_glyph?(glyph_id : UInt16) : Bool
          return false if glyph_id >= @glyph_data_offsets.size - 1
          @glyph_data_offsets[glyph_id] != @glyph_data_offsets[glyph_id + 1]
        end

        extend IOHelpers
      end

      # The 'sbix' table contains bitmap graphics for glyphs.
      # This is Apple's format for color emoji, supporting PNG, JPEG, TIFF, and PDF.
      class Sbix
        include IOHelpers

        # Flags for sbix table
        @[Flags]
        enum Flags : UInt16
          # Bit 0 must be 1
          Required = 0x0001
          # Bit 1: Draw outlines on top of bitmaps
          DrawOutlines = 0x0002
        end

        # Table version (1)
        getter version : UInt16

        # Table flags
        getter flags : Flags

        # Number of strikes (bitmap sizes)
        getter num_strikes : UInt32

        # Strikes indexed by PPEM
        @strikes : Hash(UInt16, SbixStrike)

        # Raw table data
        @data : Bytes

        # Strike offsets
        @strike_offsets : Array(UInt32)

        def initialize(
          @version : UInt16,
          @flags : Flags,
          @num_strikes : UInt32,
          @strike_offsets : Array(UInt32),
          @strikes : Hash(UInt16, SbixStrike),
          @data : Bytes
        )
        end

        # Parse sbix table from raw bytes
        def self.parse(data : Bytes, num_glyphs : UInt16) : Sbix
          io = IO::Memory.new(data)

          version = read_uint16(io)
          flags = Flags.new(read_uint16(io))
          num_strikes = read_uint32(io)

          # Read strike offsets
          strike_offsets = Array(UInt32).new(num_strikes.to_i)
          num_strikes.times do
            strike_offsets << read_uint32(io)
          end

          # Parse strikes lazily - store offsets and data
          strikes = Hash(UInt16, SbixStrike).new

          strike_offsets.each do |offset|
            next if offset >= data.size

            strike_io = IO::Memory.new(data[offset.to_i..])
            ppem = read_uint16(strike_io)
            ppi = read_uint16(strike_io)

            # Read glyph data offsets (numGlyphs + 1)
            glyph_data_offsets = Array(UInt32).new(num_glyphs.to_i + 1)
            (num_glyphs.to_i + 1).times do
              glyph_data_offsets << read_uint32(strike_io)
            end

            strikes[ppem] = SbixStrike.new(ppem, ppi, glyph_data_offsets, data, offset)
          end

          new(version, flags, num_strikes, strike_offsets, strikes, data)
        end

        # Get all available PPEM sizes
        def available_sizes : Array(UInt16)
          @strikes.keys.sort
        end

        # Get a strike by PPEM
        def strike(ppem : UInt16) : SbixStrike?
          @strikes[ppem]?
        end

        # Find the best strike for a given PPEM
        # Returns the exact match, or the closest larger size, or the largest available
        def best_strike(target_ppem : UInt16) : SbixStrike?
          return nil if @strikes.empty?

          # Try exact match first
          if strike = @strikes[target_ppem]?
            return strike
          end

          # Find closest larger size
          sorted_sizes = available_sizes
          larger = sorted_sizes.find { |s| s > target_ppem }
          return @strikes[larger]? if larger

          # Fall back to largest available
          @strikes[sorted_sizes.last]?
        end

        # Get glyph data for a glyph at a specific PPEM
        def glyph_data(glyph_id : UInt16, ppem : UInt16) : SbixGlyphData?
          strike(ppem).try(&.glyph_data(glyph_id))
        end

        # Get glyph data using best available strike
        def glyph_data_best(glyph_id : UInt16, target_ppem : UInt16) : SbixGlyphData?
          best_strike(target_ppem).try(&.glyph_data(glyph_id))
        end

        # Check if a glyph has bitmap data
        def has_glyph?(glyph_id : UInt16, ppem : UInt16) : Bool
          strike(ppem).try(&.has_glyph?(glyph_id)) || false
        end

        # Check if outlines should be drawn on top of bitmaps
        def draw_outlines? : Bool
          @flags.draw_outlines?
        end

        extend IOHelpers
      end
    end
  end
end
