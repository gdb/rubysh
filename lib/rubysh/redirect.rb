require 'stringio'

module Rubysh
  # Note that in bash, the semantics of redirection appear to be
  # following (tested empirically, rather than reading a spec):
  #
  # - [a<&b] and [a>&b] mean the same thing: copy FD b to a
  #   (try 'echo test 3>/tmp/testing.txt 1<&3')
  # - [a<&a] appears to be a no-op: ls /dev/fd 9<&9
  # - If b != a is an invalid file descriptor, then [a>&b] throws an
  #   error.
  # - Pathnames can only be on the right-hand side of a redirect.
  class Redirect < BaseDirective
    VALID_DIRECTIONS = ['<', '>', '>>']

    attr_accessor :source, :direction, :target

    def initialize(source, direction, target, opts=nil)
      unless VALID_DIRECTIONS.include?(direction)
        raise Rubysh::Error::BaseError.new("Direction must be one of #{VALID_DIRECTIONS.join(', ')}, not #{direction.inspect}")
      end

      unless source.kind_of?(IO) || source.kind_of?(FD) || source.kind_of?(Integer)
        raise Rubysh::Error::BaseError.new("Invalid source: #{source.inspect}. Source must be an IO, a Rubysh::FD, or an Integer.")
      end

      unless target.respond_to?(:fileno) || target.kind_of?(Integer) || target.kind_of?(String) || target.kind_of?(Symbol)
        raise Rubysh::Error::BaseError.new("Invalid target: #{target.inspect}. Target must respond to :fileno or be an Integer, a String, or a Symbol.")
      end

      @source = source
      @target = target
      @direction = direction
      @opts = opts || {}
    end

    def printable_source
      Util.to_fileno(source)
    end

    def printable_target
      case target
      when Symbol
        target.inspect
      else
        Util.to_fileno(target)
      end
    end

    # TODO: support files
    def stringify
      source_file = printable_source
      target_file = printable_target

      case direction
      when '<', '>>'
        source_file = nil if source_file == 0
      when '>'
        source_file = nil if source_file == 1
      else
        raise Rubysh::Error::BaseError.new("Unrecognized direction: #{direction.inspect}")
      end

      ampersand = target_file.kind_of?(Integer) ? '&' : nil

      "#{source_file}#{direction}#{ampersand}#{target_file}"
    end

    def to_s
      "Redirect: #{stringify}"
    end

    def ==(other)
      self.class == other.class &&
        self.printable_source == other.printable_source &&
        self.printable_target == other.printable_target
    end

    def reading?
      direction == '<'
    end

    def target_reading?
      !reading?
    end

    def writing?
      !reading?
    end

    def target_writing?
      !writing?
    end

    def truncate?
      direction == '>'
    end

    def named_target?
      target.kind_of?(Symbol)
    end

    def target_name
      raise Rubysh::Error::BaseError.new("Not a named target") unless named_target?
      target
    end

    def prepare!(runner)
      prepare_target(runner)
    end

    def prepare_target(runner)
      return unless named_target?
      targets = runner.targets
      if targets.include?(target_name)
        raise Rubysh::Error::BaseError.new("#{runner} already has a named target: #{target_name.inspect}")
      end

      pipe = Subprocess::PipeWrapper.new

      targets[target_name] = {
        :target_reading? => target_reading?,
        :target => target_reading? ? pipe.reader : pipe.writer,
        :complement => target_reading? ? pipe.writer : pipe.reader,
        :buffer => StringIO.new,
        :target_name => target_name,
        :read_pos => 0,
        :subprocess_fd_number => Util.to_fileno(source),
        :tee => @opts[:tee],
        :on_read => @opts[:on_read],
        :on_write => @opts[:on_write],
      }
    end

    # E.g. Rubysh.stdin < :stdin
    def apply_parent!(runner)
      return unless named_target?
      target_state = runner.target_state(target_name)
      target_state[:complement].close
    end

    def apply!(runner)
      Rubysh.log.info("About to apply #{self} for #{$$}")

      # Open the target
      target_io = file_as_io(runner, target)

      target_fd = Util.to_fileno(target_io)
      source_fd = Util.to_fileno(source)

      # Copy target -> source
      Util.dup2(target_fd, source_fd)
      Util.set_cloexec(source_fd, false)
    end

    private

    # If providing your own open FD, you have to set cloexec yourself.
    def file_as_io(runner, file, default_to_cloexec=true)
      return file if file.kind_of?(IO)
      # If it's an FD, canonicalize to the FD number
      file = Util.to_fileno(file)

      if file.kind_of?(Integer)
        io = Util.io_without_autoclose(file)
        # Someone else opened
        default_to_cloexec = false
      elsif file.kind_of?(String) && reading?
        io = File.open(file)
      elsif file.kind_of?(String) && writing? && truncate?
        # Make the following cases explicit for future compatability
        # (also to make it clear on an exception which case is at
        # fault).
        io = File.open(file, 'w')
      elsif file.kind_of?(String) && writing? && !truncate?
        io = File.open(file, 'a')
      elsif file.kind_of?(Symbol)
        target_state = runner.target_state(file)
        io = target_state[:complement]
        # Someone else opened
        default_to_cloexec = false
      else
        raise Rubysh::Error::BaseError.new("Unrecognized file spec: #{file.inspect}")
      end

      io.fcntl(Fcntl::F_SETFD, Fcntl::FD_CLOEXEC) if default_to_cloexec
      io
    end
  end
end
