# HarfBuzz Blob wrapper
#
# A blob wraps a chunk of binary data and facilitates its lifecycle
# management between HarfBuzz and the client application.

module TrueType
  module HarfBuzz
    # Wraps an hb_blob_t, which holds binary font data.
    #
    # Blobs are reference-counted and will be automatically freed
    # when they go out of scope.
    class Blob
      @ptr : LibHarfBuzz::HbBlob
      @prevent_gc : Bytes?

      # Creates a blob from raw bytes.
      #
      # The data is copied to ensure it remains valid for the blob's lifetime.
      def initialize(data : Bytes)
        # Keep a reference to prevent GC
        @prevent_gc = data.dup
        @ptr = LibHarfBuzz.hb_blob_create(
          @prevent_gc.not_nil!.to_unsafe.as(LibC::Char*),
          data.size.to_u32,
          LibHarfBuzz::HbMemoryMode::Duplicate,
          nil,
          nil
        )
      end

      # Creates a blob from raw bytes without copying (zero-copy).
      #
      # WARNING: The caller must ensure the data remains valid for
      # the lifetime of this blob. Use `from_bytes_unsafe` only when
      # you control the data's lifecycle.
      def self.from_bytes_unsafe(data : Bytes) : Blob
        blob = Blob.allocate
        blob.initialize_unsafe(data)
        blob
      end

      protected def initialize_unsafe(data : Bytes)
        @prevent_gc = data  # Keep reference
        @ptr = LibHarfBuzz.hb_blob_create(
          data.to_unsafe.as(LibC::Char*),
          data.size.to_u32,
          LibHarfBuzz::HbMemoryMode::Readonly,
          nil,
          nil
        )
      end

      # Creates a blob from a file path.
      def self.from_file(path : String) : Blob
        blob = Blob.allocate
        blob.initialize_from_file(path)
        blob
      end

      protected def initialize_from_file(path : String)
        @prevent_gc = nil
        @ptr = LibHarfBuzz.hb_blob_create_from_file_or_fail(path.to_unsafe)
        if @ptr.null?
          raise IO::Error.new("Failed to load font file: #{path}")
        end
      end

      # Creates an empty blob.
      def self.empty : Blob
        blob = Blob.allocate
        blob.initialize_empty
        blob
      end

      protected def initialize_empty
        @prevent_gc = nil
        @ptr = LibHarfBuzz.hb_blob_get_empty
      end

      # Creates a sub-blob (a slice of this blob).
      def sub_blob(offset : UInt32, length : UInt32) : Blob
        sub = Blob.allocate
        sub.initialize_sub(self, offset, length)
        sub
      end

      protected def initialize_sub(parent : Blob, offset : UInt32, length : UInt32)
        @prevent_gc = nil  # Parent keeps data alive
        @ptr = LibHarfBuzz.hb_blob_create_sub_blob(parent.to_unsafe, offset, length)
      end

      # Creates a blob from a raw HarfBuzz pointer.
      # Used internally when HarfBuzz returns a blob pointer.
      # The blob takes ownership and will destroy the pointer on finalize.
      def self.from_ptr(ptr : LibHarfBuzz::HbBlob) : Blob
        blob = Blob.allocate
        blob.initialize_from_ptr(ptr)
        blob
      end

      protected def initialize_from_ptr(ptr : LibHarfBuzz::HbBlob)
        @prevent_gc = nil
        @ptr = ptr
      end

      def finalize
        LibHarfBuzz.hb_blob_destroy(@ptr)
      end

      # Returns the raw pointer for FFI calls.
      def to_unsafe : LibHarfBuzz::HbBlob
        @ptr
      end

      # Returns the length of the blob in bytes.
      def size : UInt32
        LibHarfBuzz.hb_blob_get_length(@ptr)
      end

      # Returns true if the blob is empty.
      def empty? : Bool
        size == 0
      end

      # Returns true if the blob is immutable.
      def immutable? : Bool
        LibHarfBuzz.hb_blob_is_immutable(@ptr) != 0
      end

      # Makes the blob immutable.
      def make_immutable!
        LibHarfBuzz.hb_blob_make_immutable(@ptr)
      end

      # Returns the raw data as a Bytes slice.
      #
      # WARNING: The returned slice is only valid as long as this blob exists.
      def data : Bytes
        length = uninitialized UInt32
        ptr = LibHarfBuzz.hb_blob_get_data(@ptr, pointerof(length))
        Bytes.new(ptr.as(UInt8*), length)
      end

      # Increments the reference count and returns self.
      def reference : Blob
        LibHarfBuzz.hb_blob_reference(@ptr)
        self
      end
    end
  end
end
