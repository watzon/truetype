module TrueType
  # WOFF2 hmtx table transform decoder
  # Implements the W3C WOFF2 specification section 5.4
  # https://www.w3.org/TR/WOFF2/#hmtx_table_format
  #
  # The hmtx transform removes redundant LSB data when it can be
  # reconstructed from the glyf table's xMin values.
  class Woff2HmtxTransform
    include IOHelpers

    # Transform header flags
    # Bit 0: If set, LSBs for proportional glyphs are NOT stored (derived from xMin)
    # Bit 1: If set, LSBs for monospace glyphs are NOT stored (derived from xMin)
    FLAG_NO_LSB_PROPORTIONAL = 0x01_u8
    FLAG_NO_LSB_MONOSPACE    = 0x02_u8

    def initialize
    end

    # Reconstruct hmtx table from transformed WOFF2 data
    #
    # Parameters:
    # - data: The transformed hmtx data
    # - num_glyphs: Number of glyphs (from maxp table)
    # - num_hmetrics: Number of horizontal metrics (from hhea table)
    # - x_mins: Array of xMin values for each glyph (from reconstructed glyf)
    #
    # Returns: Reconstructed hmtx table data
    def reconstruct(
      data : Bytes,
      num_glyphs : UInt16,
      num_hmetrics : UInt16,
      x_mins : Array(Int16)
    ) : Bytes
      raise ParseError.new("hmtx transform data is empty") if data.empty?
      raise ParseError.new("num_hmetrics cannot exceed num_glyphs") if num_hmetrics > num_glyphs

      io = IO::Memory.new(data)

      # Read flags byte
      flags = read_uint8(io)

      # Determine what data is stored
      has_proportional_lsbs = (flags & FLAG_NO_LSB_PROPORTIONAL) == 0
      has_monospace_lsbs = (flags & FLAG_NO_LSB_MONOSPACE) == 0

      # Both flags set means no transform was actually applied - this is invalid
      if !has_proportional_lsbs && !has_monospace_lsbs
        raise ParseError.new("Invalid hmtx transform: both LSB streams omitted but transform applied")
      end

      # Read advance widths (always present for first num_hmetrics glyphs)
      advance_widths = Array(UInt16).new(num_hmetrics.to_i)
      num_hmetrics.times do
        advance_widths << read_uint16(io)
      end

      # Read or derive LSBs for proportional glyphs (0..num_hmetrics-1)
      lsbs_proportional = Array(Int16).new(num_hmetrics.to_i)
      if has_proportional_lsbs
        num_hmetrics.times do
          lsbs_proportional << read_int16(io)
        end
      else
        # Derive from xMin
        num_hmetrics.times do |i|
          lsbs_proportional << (x_mins[i]? || 0_i16)
        end
      end

      # Read or derive LSBs for monospace glyphs (num_hmetrics..num_glyphs-1)
      monospace_count = num_glyphs.to_i - num_hmetrics.to_i
      lsbs_monospace = Array(Int16).new(monospace_count)
      if has_monospace_lsbs
        monospace_count.times do
          lsbs_monospace << read_int16(io)
        end
      else
        # Derive from xMin
        monospace_count.times do |i|
          glyph_index = num_hmetrics.to_i + i
          lsbs_monospace << (x_mins[glyph_index]? || 0_i16)
        end
      end

      # Build output hmtx table
      # Format:
      # - longHorMetric[numHMetrics]: advanceWidth (UInt16) + lsb (Int16)
      # - leftSideBearing[numGlyphs - numHMetrics]: lsb (Int16)
      output = IO::Memory.new

      # Write longHorMetric entries
      num_hmetrics.times do |i|
        write_uint16(output, advance_widths[i])
        write_int16(output, lsbs_proportional[i])
      end

      # Write remaining LSBs for monospace glyphs
      lsbs_monospace.each do |lsb|
        write_int16(output, lsb)
      end

      output.to_slice
    end

    extend IOHelpers
  end
end
