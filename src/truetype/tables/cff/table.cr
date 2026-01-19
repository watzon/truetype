module TrueType
  module Tables
    module CFF
      # Minimal CFF table parser (header, name index, top dict index, string index, global subrs)
      class Table
        include IOHelpers

        getter major : UInt8
        getter minor : UInt8
        getter header_size : UInt8
        getter off_size : UInt8

        getter names : Index
        getter top_dicts : Index
        getter strings : Index
        getter global_subrs : Index

        def initialize(
          @major : UInt8,
          @minor : UInt8,
          @header_size : UInt8,
          @off_size : UInt8,
          @names : Index,
          @top_dicts : Index,
          @strings : Index,
          @global_subrs : Index
        )
        end

        def self.parse(data : Bytes) : Table
          io = IO::Memory.new(data)
          major = read_uint8(io)
          minor = read_uint8(io)
          header_size = read_uint8(io)
          off_size = read_uint8(io)

          # Skip to header size if needed
          io.skip(header_size.to_i - 4) if header_size > 4

          names = Index.parse(io)
          top_dicts = Index.parse(io)
          strings = Index.parse(io)
          global_subrs = Index.parse(io)

          new(major, minor, header_size, off_size, names, top_dicts, strings, global_subrs)
        end

        extend IOHelpers
      end
    end
  end
end
