# HarfBuzz Face wrapper
#
# A face represents a single font face (a specific weight/style) from a
# font file. For font collections (TTC/OTC), use the index parameter
# to select which face to load.

module TrueType
  module HarfBuzz
    # Wraps an hb_face_t, which represents a typeface (independent of size).
    #
    # A face is created from font data and provides access to font metrics
    # and tables. To actually shape text, you need to create a Font from
    # this face.
    class Face
      @ptr : LibHarfBuzz::HbFace
      @blob : Blob?

      # Creates a face from a blob.
      #
      # For font collections (TTC/OTC), use index to select which font.
      def initialize(blob : Blob, index : UInt32 = 0)
        @blob = blob  # Keep reference
        @ptr = LibHarfBuzz.hb_face_create(blob.to_unsafe, index)
      end

      # Creates a face from raw font data.
      def initialize(data : Bytes, index : UInt32 = 0)
        @blob = Blob.new(data)
        @ptr = LibHarfBuzz.hb_face_create(@blob.not_nil!.to_unsafe, index)
      end

      # Creates a face from a file path.
      def self.from_file(path : String, index : UInt32 = 0) : Face
        face = Face.allocate
        face.initialize_from_file(path, index)
        face
      end

      protected def initialize_from_file(path : String, index : UInt32)
        @blob = nil
        @ptr = LibHarfBuzz.hb_face_create_from_file_or_fail(path.to_unsafe, index)
        if @ptr.null?
          raise IO::Error.new("Failed to load font file: #{path}")
        end
      end

      # Creates an empty face.
      def self.empty : Face
        face = Face.allocate
        face.initialize_empty
        face
      end

      protected def initialize_empty
        @blob = nil
        @ptr = LibHarfBuzz.hb_face_get_empty
      end

      def finalize
        LibHarfBuzz.hb_face_destroy(@ptr)
      end

      # Returns the raw pointer for FFI calls.
      def to_unsafe : LibHarfBuzz::HbFace
        @ptr
      end

      # Returns the underlying blob.
      def blob : Blob
        @blob || begin
          # Face was created from file, get its blob
          ptr = LibHarfBuzz.hb_face_reference_blob(@ptr)
          Blob.from_ptr(ptr)
        end
      end

      # Returns the units per em of this face.
      def units_per_em : UInt32
        LibHarfBuzz.hb_face_get_upem(@ptr)
      end

      # Returns the number of glyphs in this face.
      def glyph_count : UInt32
        LibHarfBuzz.hb_face_get_glyph_count(@ptr)
      end

      # Returns the face index within the font file.
      def index : UInt32
        LibHarfBuzz.hb_face_get_index(@ptr)
      end

      # Returns true if the face is immutable.
      def immutable? : Bool
        LibHarfBuzz.hb_face_is_immutable(@ptr) != 0
      end

      # Makes the face immutable.
      def make_immutable!
        LibHarfBuzz.hb_face_make_immutable(@ptr)
      end

      # Returns a table by its tag.
      #
      # Returns an empty blob if the table doesn't exist.
      def table(tag : String) : Blob
        tag_val = HarfBuzz.tag(tag)
        ptr = LibHarfBuzz.hb_face_reference_table(@ptr, tag_val)
        Blob.from_ptr(ptr)
      end

      # Returns a table by its numeric tag.
      def table(tag : UInt32) : Blob
        ptr = LibHarfBuzz.hb_face_reference_table(@ptr, tag)
        Blob.from_ptr(ptr)
      end

      # Checks if a table exists.
      def has_table?(tag : String) : Bool
        !table(tag).empty?
      end

      # Increments the reference count and returns self.
      def reference : Face
        LibHarfBuzz.hb_face_reference(@ptr)
        self
      end
    end
  end
end
