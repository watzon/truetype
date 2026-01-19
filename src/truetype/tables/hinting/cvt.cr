module TrueType
  module Tables
    module Hinting
      # The 'cvt ' (Control Value Table) contains a list of values
      # that can be referenced by TrueType instructions.
      #
      # These values are typically used to control characteristics
      # for different glyphs, such as stem widths, x-heights, etc.
      # The values are in FUnits (font design units).
      #
      # Table tag: 'cvt ' (note trailing space)
      class Cvt
        include IOHelpers

        # Array of control values (FWORDs = Int16)
        getter values : Array(Int16)

        def initialize(@values : Array(Int16))
        end

        # Parse the cvt table from raw bytes
        def self.parse(data : Bytes) : Cvt
          io = IO::Memory.new(data)
          parse(io, data.size)
        end

        # Parse the cvt table from an IO with known size
        def self.parse(io : IO, size : Int32) : Cvt
          # Each entry is a FWORD (2 bytes)
          count = size // 2
          values = Array(Int16).new(count) do
            read_int16(io)
          end
          new(values)
        end

        # Get a control value by index
        def [](index : Int32) : Int16
          @values[index]
        end

        # Get a control value by index (safe)
        def []?(index : Int32) : Int16?
          @values[index]?
        end

        # Number of control values
        def size : Int32
          @values.size
        end

        # Check if the table is empty
        def empty? : Bool
          @values.empty?
        end

        # Serialize this table to bytes
        def to_bytes : Bytes
          io = IO::Memory.new
          write(io)
          io.to_slice
        end

        # Write this table to an IO
        def write(io : IO) : Nil
          @values.each do |value|
            write_int16(io, value)
          end
        end

        extend IOHelpers
      end
    end
  end
end
