class Rubysh::Subprocess
  class PipeWrapper
    attr_accessor :reader, :writer

    def initialize(set_cloexec=true)
      @reader, @writer = IO.pipe
      cloexec if set_cloexec
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

    def cloexec
      [@reader, @writer].each do |fd|
        fd.fcntl(Fcntl::F_SETFD, Fcntl::FD_CLOEXEC)
      end
    end

    def nonblock
      [@reader, @writer].each do |fd|
        fl = fd.fcntl(Fcntl::F_GETFL)
        fd.fcntl(Fcntl::F_SETFL, fl | Fcntl::O_NONBLOCK)
      end
    end

    def dump_yaml_and_close(msg)
      begin
        YAML.dump(msg, @writer)
      ensure
        @writer.close
        Rubysh.assert(@reader.closed?, "Reader should already be closed")
      end
    end

    def load_yaml_and_close
      begin
        YAML.load(@reader)
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
