module TrueType
  module Tables
    module Metadata
      # The 'DSIG' table contains digital signature information.
      # Most font validators and applications ignore the signature contents
      # but check for its presence as a quality indicator.
      class DSIG
        include IOHelpers

        # Table version (should be 1)
        getter version : UInt32

        # Number of signatures
        getter num_signatures : UInt16

        # Flags (permission flags)
        getter flags : UInt16

        # Signature records
        getter signatures : Array(SignatureRecord)

        def initialize(
          @version : UInt32,
          @num_signatures : UInt16,
          @flags : UInt16,
          @signatures : Array(SignatureRecord)
        )
        end

        def self.parse(data : Bytes) : DSIG
          io = IO::Memory.new(data)

          version = read_uint32(io)
          num_signatures = read_uint16(io)
          flags = read_uint16(io)

          # Read signature records
          records = Array(Tuple(UInt32, UInt32, UInt32)).new(num_signatures.to_i)
          num_signatures.times do
            format = read_uint32(io)
            length = read_uint32(io)
            offset = read_uint32(io)
            records << {format, length, offset}
          end

          # Parse signatures
          signatures = records.map do |format, length, offset|
            sig_data = data[offset.to_i, length.to_i]
            SignatureRecord.new(format, length, offset, sig_data)
          end

          new(version, num_signatures, flags, signatures)
        end

        # Check if the font is signed
        def signed? : Bool
          @num_signatures > 0
        end

        # Check if this font cannot be subset
        def cannot_subset? : Bool
          (@flags & 0x0001) != 0
        end

        # Check if this font can only be installed in read-only mode
        def cannot_install_without_embedding_bits? : Bool
          (@flags & 0x0002) != 0
        end

        extend IOHelpers
      end

      # A single digital signature record
      struct SignatureRecord
        # Signature format (usually 1)
        getter format : UInt32

        # Length of signature data
        getter length : UInt32

        # Offset to signature data (for reference)
        getter offset : UInt32

        # Raw signature data
        getter data : Bytes

        def initialize(@format : UInt32, @length : UInt32, @offset : UInt32, @data : Bytes)
        end

        # Check if this is a PKCS#7 signature (format 1)
        def pkcs7? : Bool
          @format == 1
        end
      end
    end
  end
end
