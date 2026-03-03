module MalformedFontHelpers
  extend self

  OPTIONAL_TABLE_TAGS = ["GDEF", "GSUB", "GPOS", "kern"] of String
  private BIG_ENDIAN = IO::ByteFormat::BigEndian

  struct TableRecord
    getter tag : String
    getter offset_position : Int64
    getter length_position : Int64
    getter offset : UInt32
    getter length : UInt32

    def initialize(@tag : String, @offset_position : Int64, @length_position : Int64, @offset : UInt32, @length : UInt32)
    end
  end

  def table_records(data : Bytes) : Array(TableRecord)
    io = IO::Memory.new(data)
    io.skip(4)
    num_tables = io.read_bytes(UInt16, BIG_ENDIAN)
    io.skip(6)

    records = [] of TableRecord
    num_tables.times do
      tag_bytes = Bytes.new(4)
      io.read_fully(tag_bytes)
      tag = String.new(tag_bytes)

      io.skip(4) # checksum
      offset_position = io.pos
      offset = io.read_bytes(UInt32, BIG_ENDIAN)
      length_position = io.pos
      length = io.read_bytes(UInt32, BIG_ENDIAN)

      records << TableRecord.new(tag, offset_position, length_position, offset, length)
    end

    records
  end

  def table_record(data : Bytes, tag : String) : TableRecord?
    table_records(data).find { |record| record.tag == tag }
  end

  def mutate_table_length(data : Bytes, tag : String, new_length : UInt32) : Bytes?
    record = table_record(data, tag)
    return nil unless record

    mutated = data.dup
    io = IO::Memory.new(mutated)
    io.pos = record.length_position
    io.write_bytes(new_length, BIG_ENDIAN)
    mutated
  end

  def mutate_table_offset(data : Bytes, tag : String, new_offset : UInt32) : Bytes?
    record = table_record(data, tag)
    return nil unless record

    mutated = data.dup
    io = IO::Memory.new(mutated)
    io.pos = record.offset_position
    io.write_bytes(new_offset, BIG_ENDIAN)
    mutated
  end

  def zero_table_prefix(data : Bytes, tag : String, bytes_to_zero : Int32 = 16) : Bytes?
    record = table_record(data, tag)
    return nil unless record

    start = record.offset.to_i
    return nil if start < 0 || start >= data.size

    max_by_length = record.length.to_i
    max_by_data = data.size - start
    size = {bytes_to_zero, max_by_length, max_by_data}.min
    return nil if size <= 0

    mutated = data.dup
    size.times do |i|
      mutated[start + i] = 0_u8
    end
    mutated
  end

  def truncate_inside_table(data : Bytes, tag : String, bytes_to_keep : Int32 = 4) : Bytes?
    record = table_record(data, tag)
    return nil unless record

    cut = record.offset.to_i + bytes_to_keep
    return nil if cut <= 0 || cut >= data.size

    data[0, cut].dup
  end

  def corpus_mutations(data : Bytes, tags : Array(String) = OPTIONAL_TABLE_TAGS) : Array(Tuple(String, Bytes))
    mutations = [] of Tuple(String, Bytes)

    tags.each do |tag|
      next unless record = table_record(data, tag)

      if mutated = mutate_table_length(data, tag, 2_u32)
        mutations << {"#{tag}:short-length", mutated}
      end

      long_length = (data.size + 4096).to_u32
      if mutated = mutate_table_length(data, tag, long_length)
        mutations << {"#{tag}:oversized-length", mutated}
      end

      if data.size > 0
        bad_offset = (data.size - 1).to_u32
        if mutated = mutate_table_offset(data, tag, bad_offset)
          mutations << {"#{tag}:bad-offset", mutated}
        end
      end

      if mutated = zero_table_prefix(data, tag)
        mutations << {"#{tag}:zero-prefix", mutated}
      end

    end

    mutations
  end

  def fuzz_mutations(data : Bytes, count : Int32, seed : UInt64 = 0x5EED_1234_u64, tags : Array(String) = OPTIONAL_TABLE_TAGS) : Array(Tuple(String, Bytes))
    rng = Random.new(seed)
    mutations = [] of Tuple(String, Bytes)

    count.times do |i|
      if mutation = random_mutation(data, rng, tags)
        label, bytes = mutation
        mutations << {"#{label}:#{i}", bytes}
      end
    end

    mutations
  end

  private def random_mutation(data : Bytes, rng : Random, tags : Array(String)) : Tuple(String, Bytes)?
    available = tags.compact_map { |tag| table_record(data, tag) }
    return nil if available.empty?

    record = available[rng.rand(available.size)]
    table_offset = record.offset.to_i
    return nil if table_offset < 0 || table_offset >= data.size

    table_span = {record.length.to_i, data.size - table_offset}.min
    return nil if table_span <= 0

    case rng.rand(5)
    when 0
      mutated = data.dup
      byte_index = table_offset + rng.rand(table_span)
      bit = (1_u8 << rng.rand(8)).to_u8
      mutated[byte_index] = (mutated[byte_index] ^ bit).to_u8
      {"#{record.tag}:flip-bit", mutated}
    when 1
      mutated = data.dup
      run_length = 1 + rng.rand({8, table_span}.min)
      run_start = table_offset + rng.rand(table_span - run_length + 1)
      run_length.times do |i|
        mutated[run_start + i] = rng.rand(256).to_u8
      end
      {"#{record.tag}:random-run", mutated}
    when 2
      options = [0_u32, 1_u32, 2_u32, 4_u32, (data.size + rng.rand(2048)).to_u32]
      new_length = options[rng.rand(options.size)]
      mutated = mutate_table_length(data, record.tag, new_length)
      mutated ? {"#{record.tag}:rewrite-length", mutated} : nil
    when 3
      return nil if data.size <= 1
      tail_window = {32, data.size}.min
      new_offset = (data.size - 1 - rng.rand(tail_window)).to_u32
      mutated = mutate_table_offset(data, record.tag, new_offset)
      mutated ? {"#{record.tag}:rewrite-offset", mutated} : nil
    else
      bytes_to_zero = 1 + rng.rand({16, table_span}.min)
      mutated = zero_table_prefix(data, record.tag, bytes_to_zero)
      mutated ? {"#{record.tag}:zero-prefix", mutated} : nil
    end
  end
end
