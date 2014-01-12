class Rubysh::Subprocess
  class ParallelIO
    module EOF; end
    class NothingAvailable < StandardError; end

    # readers/writers should be hashes mapping {fd => name}
    def initialize(readers, writers)
      @finished_readers = Set.new
      @on_read = nil
      @readers = readers

      @writers = writers
      @finished_writers = Set.new
      @on_write = nil
      @writer_buffers = {}
    end

    def register_reader(reader, name)
      @readers[reader] = name
    end

    def register_writer(writer, name)
      @writers[writer] = name
    end

    def on_read(method=nil, &blk)
      raise "Can't provide both method and block" if method && blk
      @on_read = method || blk
    end

    def on_write(method=nil, &blk)
      raise "Can't provide both method and block" if method && blk
      @on_write = method || blk
    end

    def write(writer_name, data, close_on_complete=true)
      writer = writer_by_name(writer_name)
      buffer_state = @writer_buffers[writer] ||= {
        :data => '',
        :close_on_complete => nil
      }

      if buffer_state[:close_on_complete]
        raise Rubysh::Error::AlreadyClosedError.new("You have already marked #{writer.inspect} as close_on_complete; can't write more data")
      end

      buffer_state[:close_on_complete] = close_on_complete
      # XXX: unnecessary copy here
      buffer_state[:data] += data

      # Note that this leads to a bit of weird semantics if you try
      # doing a write('') from within an on_write handler, since it'll
      # call this synchronously. May want to change at some point.
      finalize_writer_if_done(writer)
    end

    def close(writer_name)
      writer = writer_by_name(writer_name)
      writer.close
    end

    def available_readers
      potential = @readers.keys - @finished_readers.to_a
      potential.select {|reader| !reader.closed?}
    end

    # Writers with a non-zero number of bytes remaining to write
    def available_writers
      potential = @writer_buffers.keys - @finished_writers.to_a
      potential.select {|writer| !writer.closed? && get_data(writer).length > 0}
    end

    def run
      while available_writers.length > 0 || available_readers.length > 0
        run_once
      end
    end

    # This method is a stub so it can be extended in subclasses
    def run_once(timeout=nil)
      run_select_loop(timeout)
    end

    def run_select_loop(timeout)
      potential_readers = available_readers
      potential_writers = available_writers

      begin
        selected = IO.select(potential_readers, potential_writers, nil, timeout)
      rescue Errno::EINTR
        retry
      else
        raise NothingAvailable unless selected
      end

      ready_readers, ready_writers, _ = selected
      $stdout.puts "Stuff: #{ready_readers.inspect}, #{ready_writers.inspect} (total: #{@readers.inspect}"

      ready_readers.each do |reader|
        read_available(reader)
      end

      ready_writers.each do |writer|
        write_available(writer)
      end
    end

    def consume_all_available
      begin
        loop {run_select_loop(0)}
      rescue NothingAvailable
      end
    end

    def read_available(reader)
      begin
        data = reader.read_nonblock(4096)
        p data
      rescue EOFError, Errno::EPIPE
        p "done"
        finalize_reader(reader)
      rescue Errno::EAGAIN, Errno::EWOULDBLOCK, Errno::EINTR
      else
        issue_reader_callback(reader, data)
      end
    end

    private

    def finalize_reader(reader)
      @finished_readers.add(reader)
      issue_reader_callback(reader, EOF)
      reader.close
    end

    def issue_reader_callback(reader, data)
      if @on_read
        name = reader_name(reader)
        @on_read.call(name, data) if name
      end
    end

    def reader_name(reader)
      @readers.fetch(reader)
    end

    def write_available(writer)
      data = get_data(writer)
      begin
        count = writer.write_nonblock(data)
      rescue EOFError, Errno::EPIPE
        finalize_writer(writer)
      rescue Errno::EAGAIN, Errno::EWOULDBLOCK, Errno::EINTR
      else
        # XXX: This may be a lot of copying. May want to think about
        # how this scales.
        written = data[0...count]
        remaining = data[count..-1]
        set_data(writer, remaining)
        issue_writer_callback(writer, written, remaining)
      end
      finalize_writer_if_done(writer)
    end

    # Will only schedule a writer if it has a nonzero number of bytes
    # left to write, so we need to manually check if we're out after
    # every run.
    def finalize_writer_if_done(writer)
      if !writer.closed? &&
          buffer_state(writer)[:close_on_complete] &&
          get_data(writer).length == 0
        finalize_writer(writer)
      end
    end

    def finalize_writer(writer)
      # TODO: think about how we should deal with errors, maybe
      remaining = get_data(writer)
      @finished_writers.add(writer)
      issue_writer_callback(writer, EOF, remaining)
      writer.close if buffer_state(writer)[:close_on_complete]
    end

    def get_data(writer)
      buffer_state(writer)[:data]
    end

    def set_data(writer, data)
      buffer_state(writer)[:data] = data
    end

    def buffer_state(writer)
      buffer_state = @writer_buffers[writer]
      Rubysh.assert(buffer_state, "No buffer state: #{writer.inspect}", true)
      buffer_state
    end

    def issue_writer_callback(writer, data, remaining)
      if @on_write
        name = writer_name(writer)
        @on_write.call(name, data, remaining) if name
      end
    end

    def writer_name(writer)
      @writers.fetch(writer)
    end

    # Could make this fast, but don't think it matters enough.
    def writer_by_name(writer_name)
      @writers.detect {|writer, name| writer_name == name}.first
    end
  end
end
