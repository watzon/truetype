module TrueType
  module Tables
    module Color
      # Image format for embedded bitmap data
      enum ImageFormat : UInt16
        # Format 1: Small metrics, byte-aligned data
        SmallMetricsByteAligned = 1
        # Format 2: Small metrics, bit-aligned data
        SmallMetricsBitAligned = 2
        # Format 5: Metrics in CBLC, bit-aligned data
        MetricsInCBLCBitAligned = 5
        # Format 6: Big metrics, byte-aligned data
        BigMetricsByteAligned = 6
        # Format 7: Big metrics, bit-aligned data
        BigMetricsBitAligned = 7
        # Format 8: Small metrics with component data
        SmallMetricsComponent = 8
        # Format 9: Big metrics with component data
        BigMetricsComponent = 9
        # Format 17: Small metrics + PNG data
        SmallMetricsPNG = 17
        # Format 18: Big metrics + PNG data
        BigMetricsPNG = 18
        # Format 19: Metrics in CBLC + PNG data
        MetricsInCBLCPNG = 19
      end

      # Color bitmap data extracted from CBDT
      struct ColorBitmap
        # Image width in pixels
        getter width : UInt8

        # Image height in pixels
        getter height : UInt8

        # Horizontal bearing X
        getter bearing_x : Int8

        # Horizontal bearing Y
        getter bearing_y : Int8

        # Horizontal advance
        getter advance : UInt8

        # Image format
        getter image_format : ImageFormat

        # Raw image data (PNG, or raw bitmap)
        getter data : Bytes

        def initialize(
          @width : UInt8,
          @height : UInt8,
          @bearing_x : Int8,
          @bearing_y : Int8,
          @advance : UInt8,
          @image_format : ImageFormat,
          @data : Bytes
        )
        end

        # Check if this is a PNG image
        def png? : Bool
          @image_format.small_metrics_png? ||
            @image_format.big_metrics_png? ||
            @image_format.metrics_in_cblc_png?
        end
      end

      # The 'CBDT' table (Color Bitmap Data) contains the actual bitmap data
      # for color glyphs. Used in conjunction with CBLC for location info.
      class CBDT
        include IOHelpers

        # Major version (3)
        getter major_version : UInt16

        # Minor version (0)
        getter minor_version : UInt16

        # Raw table data
        @data : Bytes

        def initialize(
          @major_version : UInt16,
          @minor_version : UInt16,
          @data : Bytes
        )
        end

        # Parse CBDT table from raw bytes
        def self.parse(data : Bytes) : CBDT
          io = IO::Memory.new(data)

          major_version = read_uint16(io)
          minor_version = read_uint16(io)

          new(major_version, minor_version, data)
        end

        # Get bitmap data for a glyph given its location info from CBLC
        def glyph_bitmap(location : GlyphBitmapLocation) : ColorBitmap?
          return nil if location.image_data_offset >= @data.size

          io = IO::Memory.new(@data[location.image_data_offset.to_i..])

          case ImageFormat.new(location.image_format)
          when .small_metrics_png?
            # Format 17: SmallGlyphMetrics + dataLen + PNG data
            metrics = SmallGlyphMetrics.parse(io)
            data_len = read_uint32(io)
            data = Bytes.new(data_len.to_i)
            io.read_fully(data)

            ColorBitmap.new(
              metrics.width,
              metrics.height,
              metrics.bearing_x,
              metrics.bearing_y,
              metrics.advance,
              ImageFormat::SmallMetricsPNG,
              data
            )
          when .big_metrics_png?
            # Format 18: BigGlyphMetrics + dataLen + PNG data
            metrics = BigGlyphMetrics.parse(io)
            data_len = read_uint32(io)
            data = Bytes.new(data_len.to_i)
            io.read_fully(data)

            ColorBitmap.new(
              metrics.width,
              metrics.height,
              metrics.hori_bearing_x,
              metrics.hori_bearing_y,
              metrics.hori_advance,
              ImageFormat::BigMetricsPNG,
              data
            )
          when .metrics_in_cblc_png?
            # Format 19: dataLen + PNG data (metrics from CBLC)
            data_len = read_uint32(io)
            data = Bytes.new(data_len.to_i)
            io.read_fully(data)

            metrics = location.metrics
            if metrics
              ColorBitmap.new(
                metrics.width,
                metrics.height,
                metrics.hori_bearing_x,
                metrics.hori_bearing_y,
                metrics.hori_advance,
                ImageFormat::MetricsInCBLCPNG,
                data
              )
            else
              ColorBitmap.new(
                0_u8, 0_u8, 0_i8, 0_i8, 0_u8,
                ImageFormat::MetricsInCBLCPNG,
                data
              )
            end
          when .small_metrics_byte_aligned?, .small_metrics_bit_aligned?
            # Format 1/2: SmallGlyphMetrics + bitmap data
            metrics = SmallGlyphMetrics.parse(io)
            remaining = location.image_data_length.to_i - 5 # 5 bytes for small metrics
            data = Bytes.new(remaining.clamp(0, @data.size))
            io.read_fully(data)

            ColorBitmap.new(
              metrics.width,
              metrics.height,
              metrics.bearing_x,
              metrics.bearing_y,
              metrics.advance,
              ImageFormat.new(location.image_format),
              data
            )
          when .big_metrics_byte_aligned?, .big_metrics_bit_aligned?
            # Format 6/7: BigGlyphMetrics + bitmap data
            metrics = BigGlyphMetrics.parse(io)
            remaining = location.image_data_length.to_i - 8 # 8 bytes for big metrics
            data = Bytes.new(remaining.clamp(0, @data.size))
            io.read_fully(data)

            ColorBitmap.new(
              metrics.width,
              metrics.height,
              metrics.hori_bearing_x,
              metrics.hori_bearing_y,
              metrics.hori_advance,
              ImageFormat.new(location.image_format),
              data
            )
          when .metrics_in_cblc_bit_aligned?
            # Format 5: Bitmap data only (metrics from CBLC)
            data = Bytes.new(location.image_data_length.to_i)
            io.read_fully(data)

            metrics = location.metrics
            if metrics
              ColorBitmap.new(
                metrics.width,
                metrics.height,
                metrics.hori_bearing_x,
                metrics.hori_bearing_y,
                metrics.hori_advance,
                ImageFormat::MetricsInCBLCBitAligned,
                data
              )
            else
              ColorBitmap.new(
                0_u8, 0_u8, 0_i8, 0_i8, 0_u8,
                ImageFormat::MetricsInCBLCBitAligned,
                data
              )
            end
          else
            nil
          end
        rescue
          nil
        end

        extend IOHelpers
      end
    end
  end
end
