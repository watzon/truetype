module TrueType
  module Tables
    module CFF
      # CFF2 header structure (different from CFF1)
      struct CFF2Header
        include IOHelpers

        # Major version (must be 2)
        getter major_version : UInt8

        # Minor version
        getter minor_version : UInt8

        # Size of header (offset to start of Top DICT)
        getter header_size : UInt16

        # Size of Top DICT data
        getter top_dict_length : UInt16

        def initialize(
          @major_version : UInt8,
          @minor_version : UInt8,
          @header_size : UInt16,
          @top_dict_length : UInt16
        )
        end

        def self.parse(io : IO::Memory) : CFF2Header
          major = read_uint8(io)
          minor = read_uint8(io)
          header_size = read_uint8(io).to_u16
          top_dict_length = read_uint16(io)

          new(major, minor, header_size, top_dict_length)
        end

        # CFF2 uses a different header format (5 bytes vs 4 in CFF1)
        def cff2? : Bool
          @major_version == 2
        end

        extend IOHelpers
      end

      # CFF2 Top DICT operators (different from CFF1)
      enum CFF2DictOp
        # Standard CFF1 operators that are also in CFF2
        CHAR_STRINGS     = 17
        FONT_MATRIX      = 0x0C07
        FD_ARRAY         = 0x0C24
        FD_SELECT        = 0x0C25

        # CFF2-specific operators
        VSTORE           = 24  # VariationStore offset

        # Private DICT specific
        BLEND            = 23
        VSINDEX          = 22
        SUBRS            = 19
      end

      # CFF2 Table parser
      class CFF2Table
        include IOHelpers

        getter header : CFF2Header
        getter top_dict : Dict
        getter global_subrs : Index
        getter raw_data : Bytes

        # Offsets extracted from Top DICT
        getter charstrings_offset : Int32
        getter vstore_offset : Int32
        getter fd_array_offset : Int32
        getter fd_select_offset : Int32

        def initialize(
          @header : CFF2Header,
          @top_dict : Dict,
          @global_subrs : Index,
          @raw_data : Bytes,
          @charstrings_offset : Int32,
          @vstore_offset : Int32,
          @fd_array_offset : Int32,
          @fd_select_offset : Int32
        )
        end

        def self.parse(data : Bytes) : CFF2Table
          io = IO::Memory.new(data)

          # Parse CFF2 header
          header = CFF2Header.parse(io)

          # Top DICT starts at header_size offset
          io.seek(header.header_size.to_i64)
          top_dict_data = Bytes.new(header.top_dict_length.to_i)
          io.read(top_dict_data)
          top_dict = Dict.parse(top_dict_data)

          # Global Subr INDEX follows Top DICT
          global_subrs = Index.parse(io)

          # Extract key offsets from Top DICT
          charstrings_offset = top_dict.int(DictOp::CHAR_STRINGS, 0)
          vstore_offset = top_dict.int_by_value(CFF2DictOp::VSTORE.value, 0)
          fd_array_offset = top_dict.int(DictOp::FD_ARRAY, 0)
          fd_select_offset = top_dict.int(DictOp::FD_SELECT, 0)

          new(
            header,
            top_dict,
            global_subrs,
            data,
            charstrings_offset,
            vstore_offset,
            fd_array_offset,
            fd_select_offset
          )
        end

        # Check if this is a CFF2 table
        def cff2? : Bool
          @header.cff2?
        end

        # Check if this CFF2 has a VariationStore
        def has_variation_store? : Bool
          @vstore_offset > 0
        end

        # Parse the CharStrings INDEX
        def charstrings : Index?
          return nil if @charstrings_offset <= 0

          io = IO::Memory.new(@raw_data)
          io.seek(@charstrings_offset.to_i64)
          Index.parse(io)
        rescue
          nil
        end

        # Parse the FDArray INDEX (Font DICT array)
        def fd_array : Array(Dict)?
          return nil if @fd_array_offset <= 0

          io = IO::Memory.new(@raw_data)
          io.seek(@fd_array_offset.to_i64)
          index = Index.parse(io)

          dicts = Array(Dict).new(index.size)
          index.size.times do |i|
            dicts << Dict.parse(index[i])
          end
          dicts
        rescue
          nil
        end

        extend IOHelpers
      end

      # Helper to detect CFF version from data
      def self.cff_version(data : Bytes) : Int32
        return 0 if data.size < 1
        data[0].to_i32
      end

      # Check if data is CFF2
      def self.cff2?(data : Bytes) : Bool
        cff_version(data) == 2
      end
    end
  end
end
