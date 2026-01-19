module TrueType
  module Tables
    module Hinting
      # The 'prep' (Control Value Program) table contains TrueType bytecode
      # that is executed whenever the font size or transformation changes.
      #
      # This program typically modifies the control values (CVT) based on
      # the current size, resolution, or transformation. It runs after the
      # font program (fpgm) and before any glyph programs.
      #
      # Table tag: 'prep'
      class Prep
        include IOHelpers

        # Raw TrueType bytecode instructions
        getter instructions : Bytes

        def initialize(@instructions : Bytes)
        end

        # Parse the prep table from raw bytes
        def self.parse(data : Bytes) : Prep
          # The table is just raw bytecode
          new(data.dup)
        end

        # Parse the prep table from an IO with known size
        def self.parse(io : IO, size : Int32) : Prep
          instructions = Bytes.new(size)
          io.read_fully(instructions)
          new(instructions)
        end

        # Number of instruction bytes
        def size : Int32
          @instructions.size
        end

        # Check if the table is empty
        def empty? : Bool
          @instructions.empty?
        end

        # Get an instruction byte by index
        def [](index : Int32) : UInt8
          @instructions[index]
        end

        # Serialize this table to bytes
        def to_bytes : Bytes
          @instructions.dup
        end

        # Write this table to an IO
        def write(io : IO) : Nil
          io.write(@instructions)
        end

        extend IOHelpers
      end
    end
  end
end
