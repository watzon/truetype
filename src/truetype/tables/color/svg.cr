require "compress/gzip"

module TrueType
  module Tables
    module Color
      # SVG document record pointing to SVG data for a glyph range
      struct SVGDocumentRecord
        # First glyph ID in the range
        getter start_glyph_id : UInt16

        # Last glyph ID in the range
        getter end_glyph_id : UInt16

        # Offset to SVG document data (from SVGDocumentList start)
        getter svg_doc_offset : UInt32

        # Length of SVG document data
        getter svg_doc_length : UInt32

        def initialize(
          @start_glyph_id : UInt16,
          @end_glyph_id : UInt16,
          @svg_doc_offset : UInt32,
          @svg_doc_length : UInt32
        )
        end

        # Check if a glyph ID is in this record's range
        def covers?(glyph_id : UInt16) : Bool
          glyph_id >= @start_glyph_id && glyph_id <= @end_glyph_id
        end

        # Number of glyphs covered by this record
        def glyph_count : Int32
          @end_glyph_id.to_i - @start_glyph_id.to_i + 1
        end
      end

      # The 'SVG ' table contains SVG artwork for color glyphs.
      # SVG documents may be gzip-compressed (detected by magic bytes 0x1F 0x8B 0x08).
      class SVG
        include IOHelpers

        # Table version (must be 0)
        getter version : UInt16

        # SVG document records
        getter document_records : Array(SVGDocumentRecord)

        # Raw table data for extracting SVG documents
        @data : Bytes

        # Offset to SVG document list (for calculating document offsets)
        @doc_list_offset : UInt32

        # Gzip magic bytes
        GZIP_MAGIC = Bytes[0x1F, 0x8B, 0x08]

        def initialize(
          @version : UInt16,
          @document_records : Array(SVGDocumentRecord),
          @data : Bytes,
          @doc_list_offset : UInt32
        )
        end

        # Parse SVG table from raw bytes
        def self.parse(data : Bytes) : SVG
          io = IO::Memory.new(data)

          version = read_uint16(io)
          svg_doc_list_offset = read_uint32(io)
          _reserved = read_uint32(io) # Must be 0

          # Parse SVG document list
          io.seek(svg_doc_list_offset.to_i)
          num_entries = read_uint16(io)

          document_records = Array(SVGDocumentRecord).new(num_entries.to_i)
          num_entries.times do
            start_glyph = read_uint16(io)
            end_glyph = read_uint16(io)
            doc_offset = read_uint32(io)
            doc_length = read_uint32(io)
            document_records << SVGDocumentRecord.new(start_glyph, end_glyph, doc_offset, doc_length)
          end

          new(version, document_records, data, svg_doc_list_offset)
        end

        # Check if a glyph has SVG data
        def has_svg?(glyph_id : UInt16) : Bool
          find_record(glyph_id) != nil
        end

        # Get the SVG document for a glyph (decompressed if needed)
        # Returns nil if the glyph has no SVG data
        def svg_document(glyph_id : UInt16) : String?
          record = find_record(glyph_id)
          return nil unless record

          extract_svg(record)
        end

        # Get the raw SVG data for a glyph (may be compressed)
        # Returns nil if the glyph has no SVG data
        def svg_data(glyph_id : UInt16) : Bytes?
          record = find_record(glyph_id)
          return nil unless record

          extract_raw_data(record)
        end

        # Check if the SVG data for a record is gzip-compressed
        def compressed?(record : SVGDocumentRecord) : Bool
          raw = extract_raw_data(record)
          return false unless raw
          return false if raw.size < 3

          raw[0] == GZIP_MAGIC[0] &&
            raw[1] == GZIP_MAGIC[1] &&
            raw[2] == GZIP_MAGIC[2]
        end

        # Get all glyph IDs that have SVG data
        def svg_glyph_ids : Array(UInt16)
          result = [] of UInt16
          @document_records.each do |record|
            (record.start_glyph_id..record.end_glyph_id).each do |glyph_id|
              result << glyph_id.to_u16
            end
          end
          result
        end

        # Number of SVG document entries
        def document_count : Int32
          @document_records.size
        end

        # Total number of glyphs with SVG data
        def glyph_count : Int32
          @document_records.sum(&.glyph_count)
        end

        # Iterate over all SVG documents
        def each_document(&)
          @document_records.each do |record|
            if svg = extract_svg(record)
              yield record, svg
            end
          end
        end

        # Find the document record for a glyph
        # Uses binary search since records are sorted by start_glyph_id
        private def find_record(glyph_id : UInt16) : SVGDocumentRecord?
          low = 0
          high = @document_records.size - 1

          while low <= high
            mid = (low + high) // 2
            record = @document_records[mid]

            if record.end_glyph_id < glyph_id
              low = mid + 1
            elsif record.start_glyph_id > glyph_id
              high = mid - 1
            else
              return record
            end
          end

          nil
        end

        # Extract raw data for a document record
        private def extract_raw_data(record : SVGDocumentRecord) : Bytes?
          # Offset is relative to the start of the SVG document list
          abs_offset = @doc_list_offset.to_i + record.svg_doc_offset.to_i
          return nil if abs_offset + record.svg_doc_length.to_i > @data.size

          @data[abs_offset, record.svg_doc_length.to_i]
        end

        # Extract and decompress SVG document
        private def extract_svg(record : SVGDocumentRecord) : String?
          raw = extract_raw_data(record)
          return nil unless raw
          return nil if raw.empty?

          # Check for gzip compression
          if raw.size >= 3 &&
             raw[0] == GZIP_MAGIC[0] &&
             raw[1] == GZIP_MAGIC[1] &&
             raw[2] == GZIP_MAGIC[2]
            # Decompress gzip data
            decompress_gzip(raw)
          else
            # Plain UTF-8 SVG
            String.new(raw)
          end
        rescue
          nil
        end

        # Decompress gzip data
        private def decompress_gzip(data : Bytes) : String?
          io = IO::Memory.new(data)
          gzip_reader = Compress::Gzip::Reader.new(io)
          result = gzip_reader.gets_to_end
          gzip_reader.close
          result
        rescue
          nil
        end

        extend IOHelpers
      end
    end
  end
end
