class Rubysh::Subprocess
  class PipeWrapper
    begin
      require 'json'
      SERIALIZER = JSON
    rescue LoadError => e
      if ENV['RUBYSH_ENABLE_YAML']
        require 'yaml'
        SERIALIZER = YAML
      else
        raise LoadError.new("Could not import JSON (#{e}). You should either run in an environment with rubygems and JSON, or you can set the RUBYSH_ENABLE_YAML environment variable to allow Rubysh to internally use YAML for communication rather than JSON. This is believed safe, but YAML-parsing of untrusted input is bad, so only do this if you really can't get JSON.")
      end
    end

    attr_accessor :reader, :writer

    def initialize(reader_cloexec=true, writer_cloexec=true)
      @reader, @writer = IO.pipe
      set_reader_cloexec if reader_cloexec
      set_writer_cloexec if writer_cloexec
    end

    def read_only
      @writer.close
    end

    def write_only
      @reader.close
    end

    def close
      @writer.close
      @reader.close
    end

    def set_reader_cloexec
      @reader.fcntl(Fcntl::F_SETFD, Fcntl::FD_CLOEXEC)
    end

    def set_writer_cloexec
      @writer.fcntl(Fcntl::F_SETFD, Fcntl::FD_CLOEXEC)
    end

    def nonblock
      [@reader, @writer].each do |fd|
        fl = fd.fcntl(Fcntl::F_GETFL)
        fd.fcntl(Fcntl::F_SETFL, fl | Fcntl::O_NONBLOCK)
      end
    end

    def dump_json_and_close(msg)
      dumped = SERIALIZER.dump(msg)
      begin
        @writer.write(dumped)
      ensure
        @writer.close
        Rubysh.assert(@reader.closed?, "Reader should already be closed")
      end
    end

    def load_json_and_close
      contents = @reader.read
      return false if contents.length == 0

      begin
        SERIALIZER.load(contents)
      rescue ArgumentError => e
        # e.g. ArgumentError: syntax error on line 0, col 2: `' (could
        # happen if the subprocess was killed while writing a message)
        raise Rubysh::Error::BaseError.new("Invalid message read from pipe: #{e}")
      ensure
        @reader.close
        Rubysh.assert(@writer.closed?, "Writer should already be closed")
      end
    end
  end
end
