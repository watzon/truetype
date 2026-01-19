module TrueType
  module Tables
    module CFF
      # CFF INDEX structure - used for Name INDEX, String INDEX, etc.
      class Index
        include IOHelpers

        getter count : UInt16
        getter offsets : Array(UInt32)
        getter data : Bytes

        def initialize(@count : UInt16, @offsets : Array(UInt32), @data : Bytes)
        end

        def self.parse(io : IO) : Index
          count = read_uint16(io)
          return new(0_u16, [] of UInt32, Bytes.empty) if count == 0

          off_size = read_uint8(io)
          offsets = Array(UInt32).new(count.to_i + 1)

          (count + 1).times do
            offset = case off_size
                     when 1 then read_uint8(io).to_u32
                     when 2 then read_uint16(io).to_u32
                     when 3 then read_uint24(io)
                     when 4 then read_uint32(io)
                     else        0_u32
                     end
            offsets << offset
          end

          # Calculate data size
          data_size = offsets.last.to_i - 1
          data = Bytes.new(data_size > 0 ? data_size : 0)
          io.read_fully(data) if data_size > 0

          new(count, offsets, data)
        end

        # Read 24-bit unsigned integer
        private def self.read_uint24(io : IO) : UInt32
          bytes = Bytes.new(3)
          io.read_fully(bytes)
          (bytes[0].to_u32 << 16) | (bytes[1].to_u32 << 8) | bytes[2].to_u32
        end

        # Get element at index
        def [](index : Int32) : Bytes
          return Bytes.empty if index < 0 || index >= @count

          start_offset = @offsets[index].to_i - 1
          end_offset = @offsets[index + 1].to_i - 1

          return Bytes.empty if start_offset < 0 || end_offset > @data.size

          @data[start_offset...end_offset]
        end

        # Get element as string
        def string_at(index : Int32) : String
          String.new(self[index])
        end

        # Number of elements
        def size : Int32
          @count.to_i
        end

        def empty? : Bool
          @count == 0
        end

        # Iterate over elements
        def each(&)
          @count.times do |i|
            yield self[i.to_i32]
          end
        end

        # Iterate with index
        def each_with_index(&)
          @count.times do |i|
            yield self[i.to_i32], i.to_i32
          end
        end

        extend IOHelpers
      end
    end
  end
end
