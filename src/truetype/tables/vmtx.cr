module TrueType
  module Tables
    # Vertical metric record for a glyph
    struct VMetric
      # Advance height in font units
      getter advance_height : UInt16

      # Top side bearing in font units
      getter top_side_bearing : Int16

      def initialize(@advance_height : UInt16, @top_side_bearing : Int16)
      end
    end

    # The 'vmtx' table contains vertical metrics for each glyph.
    # This table is required for fonts with vertical writing support.
    class Vmtx
      include IOHelpers

      # Vertical metrics for each glyph with full metrics
      getter v_metrics : Array(VMetric)

      # Top side bearings for glyphs beyond number_of_v_metrics
      getter top_side_bearings : Array(Int16)

      def initialize(@v_metrics : Array(VMetric), @top_side_bearings : Array(Int16))
      end

      # Parse the vmtx table from raw bytes
      # Requires number_of_v_metrics from vhea and num_glyphs from maxp
      def self.parse(data : Bytes, number_of_v_metrics : UInt16, num_glyphs : UInt16) : Vmtx
        io = IO::Memory.new(data)
        parse(io, number_of_v_metrics, num_glyphs)
      end

      # Parse the vmtx table from an IO
      def self.parse(io : IO, number_of_v_metrics : UInt16, num_glyphs : UInt16) : Vmtx
        v_metrics = Array(VMetric).new(number_of_v_metrics.to_i)

        number_of_v_metrics.times do
          advance_height = read_uint16(io)
          top_side_bearing = read_int16(io)
          v_metrics << VMetric.new(advance_height, top_side_bearing)
        end

        # Remaining glyphs only have top side bearing
        remaining = num_glyphs.to_i - number_of_v_metrics.to_i
        top_side_bearings = Array(Int16).new(remaining)

        remaining.times do
          top_side_bearings << read_int16(io)
        end

        new(v_metrics, top_side_bearings)
      end

      # Get the advance height for a glyph
      def advance_height(glyph_id : UInt16) : UInt16
        if glyph_id < @v_metrics.size
          @v_metrics[glyph_id].advance_height
        else
          # Glyphs beyond number_of_v_metrics use the last advance height
          @v_metrics.last?.try(&.advance_height) || 0_u16
        end
      end

      # Get the top side bearing for a glyph
      def top_side_bearing(glyph_id : UInt16) : Int16
        if glyph_id < @v_metrics.size
          @v_metrics[glyph_id].top_side_bearing
        else
          idx = glyph_id.to_i - @v_metrics.size
          if idx >= 0 && idx < @top_side_bearings.size
            @top_side_bearings[idx]
          else
            0_i16
          end
        end
      end

      # Serialize this table to bytes
      def to_bytes : Bytes
        io = IO::Memory.new
        write(io)
        io.to_slice
      end

      # Write this table to an IO
      def write(io : IO) : Nil
        @v_metrics.each do |metric|
          write_uint16(io, metric.advance_height)
          write_int16(io, metric.top_side_bearing)
        end
        @top_side_bearings.each do |tsb|
          write_int16(io, tsb)
        end
      end

      # Create a new vmtx table with only the specified glyph IDs
      # glyph_id_map maps old glyph IDs to new glyph IDs
      def subset(glyph_id_map : Hash(UInt16, UInt16)) : Vmtx
        # Collect metrics for subset glyphs in order of new glyph IDs
        sorted_entries = glyph_id_map.to_a.sort_by { |_, new_id| new_id }

        new_metrics = sorted_entries.map do |old_id, _|
          VMetric.new(advance_height(old_id), top_side_bearing(old_id))
        end

        # For simplicity, all glyphs in the subset have full metrics
        Vmtx.new(new_metrics, [] of Int16)
      end

      extend IOHelpers
    end
  end
end
