module TrueType
  module Tables
    # The 'vhea' table contains vertical header information.
    # This table is required for fonts with vertical writing support.
    class Vhea
      include IOHelpers

      # Major version (should be 1)
      getter major_version : UInt16

      # Minor version (should be 0 or 1)
      getter minor_version : UInt16

      # Vertical typographic ascender
      # For version 1.0: distance from center baseline to previous line's descent
      # For version 1.1: typographic ascent
      getter ascent : Int16

      # Vertical typographic descender
      # For version 1.0: distance from center baseline to next line's ascent
      # For version 1.1: typographic descent
      getter descent : Int16

      # Vertical typographic line gap
      getter line_gap : Int16

      # Maximum advance height in 'vmtx' table
      getter advance_height_max : UInt16

      # Minimum top side bearing in 'vmtx' table
      getter min_top_side_bearing : Int16

      # Minimum bottom side bearing
      getter min_bottom_side_bearing : Int16

      # Maximum y extent (yMax - tsb)
      getter y_max_extent : Int16

      # Caret slope rise (used for italic fonts)
      getter caret_slope_rise : Int16

      # Caret slope run (used for italic fonts)
      getter caret_slope_run : Int16

      # Caret offset
      getter caret_offset : Int16

      # Reserved fields (should be 0)
      @reserved1 : Int16
      @reserved2 : Int16
      @reserved3 : Int16
      @reserved4 : Int16

      # Metric data format (should be 0)
      getter metric_data_format : Int16

      # Number of full vertical metrics in 'vmtx' table
      getter number_of_v_metrics : UInt16

      def initialize(
        @major_version : UInt16,
        @minor_version : UInt16,
        @ascent : Int16,
        @descent : Int16,
        @line_gap : Int16,
        @advance_height_max : UInt16,
        @min_top_side_bearing : Int16,
        @min_bottom_side_bearing : Int16,
        @y_max_extent : Int16,
        @caret_slope_rise : Int16,
        @caret_slope_run : Int16,
        @caret_offset : Int16,
        @reserved1 : Int16,
        @reserved2 : Int16,
        @reserved3 : Int16,
        @reserved4 : Int16,
        @metric_data_format : Int16,
        @number_of_v_metrics : UInt16,
      )
      end

      # Parse the vhea table from raw bytes
      def self.parse(data : Bytes) : Vhea
        io = IO::Memory.new(data)
        parse(io)
      end

      # Parse the vhea table from an IO
      def self.parse(io : IO) : Vhea
        major_version = read_uint16(io)
        minor_version = read_uint16(io)
        ascent = read_int16(io)
        descent = read_int16(io)
        line_gap = read_int16(io)
        advance_height_max = read_uint16(io)
        min_top_side_bearing = read_int16(io)
        min_bottom_side_bearing = read_int16(io)
        y_max_extent = read_int16(io)
        caret_slope_rise = read_int16(io)
        caret_slope_run = read_int16(io)
        caret_offset = read_int16(io)
        reserved1 = read_int16(io)
        reserved2 = read_int16(io)
        reserved3 = read_int16(io)
        reserved4 = read_int16(io)
        metric_data_format = read_int16(io)
        number_of_v_metrics = read_uint16(io)

        new(
          major_version, minor_version, ascent, descent, line_gap,
          advance_height_max, min_top_side_bearing, min_bottom_side_bearing,
          y_max_extent, caret_slope_rise, caret_slope_run, caret_offset,
          reserved1, reserved2, reserved3, reserved4,
          metric_data_format, number_of_v_metrics
        )
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
        write_int16(io, @ascent)
        write_int16(io, @descent)
        write_int16(io, @line_gap)
        write_uint16(io, @advance_height_max)
        write_int16(io, @min_top_side_bearing)
        write_int16(io, @min_bottom_side_bearing)
        write_int16(io, @y_max_extent)
        write_int16(io, @caret_slope_rise)
        write_int16(io, @caret_slope_run)
        write_int16(io, @caret_offset)
        write_int16(io, @reserved1)
        write_int16(io, @reserved2)
        write_int16(io, @reserved3)
        write_int16(io, @reserved4)
        write_int16(io, @metric_data_format)
        write_uint16(io, @number_of_v_metrics)
      end

      extend IOHelpers
    end
  end
end
