module TrueType
  module Tables
    module Hinting
      # The 'fpgm' (Font Program) table contains TrueType bytecode
      # that is executed once when the font is first loaded.
      #
      # This program typically defines functions (using FDEF) and
      # instruction definitions (using IDEF) that can be called
      # by glyph programs and the prep program.
      #
      # Table tag: 'fpgm'
      class Fpgm
        include IOHelpers

        # Raw TrueType bytecode instructions
        getter instructions : Bytes

        def initialize(@instructions : Bytes)
        end

        # Parse the fpgm table from raw bytes
        def self.parse(data : Bytes) : Fpgm
          # The table is just raw bytecode
          new(data.dup)
        end

        # Parse the fpgm table from an IO with known size
        def self.parse(io : IO, size : Int32) : Fpgm
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
