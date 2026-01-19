module TrueType
  module Tables
    # Vertical origin entry for a specific glyph
    struct VertOriginYMetric
      # Glyph ID
      getter glyph_index : UInt16

      # Y coordinate of the glyph's vertical origin
      getter vert_origin_y : Int16

      def initialize(@glyph_index : UInt16, @vert_origin_y : Int16)
      end
    end

    # The 'VORG' table (Vertical Origin) is used in CFF OpenType fonts
    # to specify the vertical origin for glyphs.
    #
    # This table is optional and typically only found in CFF-based fonts
    # that support vertical writing systems (like CJK fonts).
    class Vorg
      include IOHelpers

      # Table version (currently 1.0)
      getter major_version : UInt16
      getter minor_version : UInt16

      # Default vertical origin Y for glyphs not in the vert_origin_y_metrics array
      getter default_vert_origin_y : Int16

      # Number of entries in the vert_origin_y_metrics array
      getter num_vert_origin_y_metrics : UInt16

      # Array of vertical origin metrics for specific glyphs
      getter vert_origin_y_metrics : Array(VertOriginYMetric)

      def initialize(
        @major_version : UInt16,
        @minor_version : UInt16,
        @default_vert_origin_y : Int16,
        @num_vert_origin_y_metrics : UInt16,
        @vert_origin_y_metrics : Array(VertOriginYMetric),
      )
      end

      # Parse the VORG table from raw bytes
      def self.parse(data : Bytes) : Vorg
        io = IO::Memory.new(data)
        parse(io)
      end

      # Parse the VORG table from an IO
      def self.parse(io : IO) : Vorg
        major_version = read_uint16(io)
        minor_version = read_uint16(io)
        default_vert_origin_y = read_int16(io)
        num_vert_origin_y_metrics = read_uint16(io)

        vert_origin_y_metrics = Array(VertOriginYMetric).new(num_vert_origin_y_metrics.to_i)
        num_vert_origin_y_metrics.times do
          glyph_index = read_uint16(io)
          vert_origin_y = read_int16(io)
          vert_origin_y_metrics << VertOriginYMetric.new(glyph_index, vert_origin_y)
        end

        new(major_version, minor_version, default_vert_origin_y, num_vert_origin_y_metrics, vert_origin_y_metrics)
      end

      # Get the vertical origin Y for a glyph
      # Returns the glyph-specific origin if defined, otherwise the default
      def vert_origin_y(glyph_id : UInt16) : Int16
        # The array is sorted by glyph index, so we can use binary search
        low = 0
        high = @vert_origin_y_metrics.size - 1

        while low <= high
          mid = (low + high) // 2
          metric = @vert_origin_y_metrics[mid]

          if metric.glyph_index < glyph_id
            low = mid + 1
          elsif metric.glyph_index > glyph_id
            high = mid - 1
          else
            return metric.vert_origin_y
          end
        end

        @default_vert_origin_y
      end

      # Serialize this table to bytes
      def to_bytes : Bytes
        io = IO::Memory.new
        write(io)
        io.to_slice
      end

      # Write this table to an IO
      def write(io : IO) : Nil
        write_uint16(io, @major_version)
        write_uint16(io, @minor_version)
        write_int16(io, @default_vert_origin_y)
        write_uint16(io, @num_vert_origin_y_metrics)

        @vert_origin_y_metrics.each do |metric|
          write_uint16(io, metric.glyph_index)
          write_int16(io, metric.vert_origin_y)
        end
      end

      extend IOHelpers
    end
  end
end
