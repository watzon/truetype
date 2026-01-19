module TrueType
  module Tables
    module Metadata
      # The 'meta' table contains metadata about the font.
      # Common uses include design and supported language lists.
      class Meta
        include IOHelpers

        # Table version (should be 1)
        getter version : UInt32

        # Flags (reserved, should be 0)
        getter flags : UInt32

        # Data maps (tag -> text content)
        getter data_maps : Array(DataMap)

        def initialize(
          @version : UInt32,
          @flags : UInt32,
          @data_maps : Array(DataMap)
        )
        end

        def self.parse(data : Bytes) : Meta
          io = IO::Memory.new(data)

          version = read_uint32(io)
          flags = read_uint32(io)
          _reserved = read_uint32(io)  # data_offset (always 0)
          data_map_count = read_uint32(io)

          # Read data map records
          records = Array(Tuple(String, UInt32, UInt32)).new(data_map_count.to_i)
          data_map_count.times do
            tag = read_tag(io)
            offset = read_uint32(io)
            length = read_uint32(io)
            records << {tag, offset, length}
          end

          # Parse data maps
          data_maps = records.map do |tag, offset, length|
            text = String.new(data[offset.to_i, length.to_i])
            DataMap.new(tag, text)
          end

          new(version, flags, data_maps)
        end

        # Get metadata by tag
        def get(tag : String) : String?
          @data_maps.find { |m| m.tag == tag }.try(&.data)
        end

        # Get design languages (dlng tag)
        # Returns comma-separated list of BCP 47 language tags
        def design_languages : Array(String)?
          get("dlng").try(&.split(",").map(&.strip))
        end

        # Get supported languages (slng tag)
        # Returns comma-separated list of BCP 47 language tags
        def supported_languages : Array(String)?
          get("slng").try(&.split(",").map(&.strip))
        end

        extend IOHelpers
      end

      # A single metadata data map
      struct DataMap
        # Tag identifying the data type (e.g., "dlng", "slng")
        getter tag : String

        # Text content (UTF-8 encoded)
        getter data : String

        def initialize(@tag : String, @data : String)
        end
      end
    end
  end
end
