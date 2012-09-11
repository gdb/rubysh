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

    @references = []
    def self.hold(*references)
      # Needed for Ruby 1.8, where we can't set IO objects to not
      # close the underlying FD on destruction
      @references += references
    end

    attr_accessor :source, :direction, :target

    def initialize(source, direction, target)
      unless VALID_DIRECTIONS.include?(direction)
        raise Rubysh::Error::BaseError.new("Direction must be one of #{VALID_DIRECTIONS.join(', ')}, not #{direction.inspect}")
      end

      unless source.kind_of?(IO) || source.kind_of?(FD) || source.kind_of?(Integer)
        raise Rubysh::Error::BaseError.new("Invalid source: #{source.inspect}. Source must be an IO, a Rubysh::FD, or an Integer.")
      end

      unless target.kind_of?(IO) || target.kind_of?(FD) || target.kind_of?(Integer) || target.kind_of?(String)
        raise Rubysh::Error::BaseError.new("Invalid target: #{target.inspect}. Target an IO, a Rubysh::FD, an Integer, or a String.")
      end

      @source = source
      @target = target
      @direction = direction
    end

    def apply!
      Rubysh.log.info("About to apply #{self} for #{$$}")
      # Open the target
      target_io = file_as_io(target)

      target_fd = file_as_fd(target_io)
      source_fd = file_as_fd(source)

      # Copy target -> source
      dup2(target_fd, source_fd)
      set_cloexec(source_fd, false)
    end

    def printable_source
      to_fileno(source)
    end

    def printable_target
      to_fileno(target)
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

    def writing?
      !reading?
    end

    def truncate?
      direction == '>'
    end

    private

    # If providing your own open FD, you have to set cloexec yourself.
    def file_as_io(file, default_to_cloexec=true)
      return file if file.kind_of?(IO)
      # If it's an FD, canonicalize to the FD number
      file = to_fileno(file)

      if file.kind_of?(Integer)
        io = io_without_autoclose(file)
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
      else
        raise Rubysh::Error::BaseError.new("Unrecognized file spec: #{file.inspect}")
      end

      io.fcntl(Fcntl::F_SETFD, Fcntl::FD_CLOEXEC) if default_to_cloexec
      io
    end

    # Leaks memory (needed to avoid Ruby 1.8's IO autoclose behavior),
    # and so you should only use it right before execing.
    def io_without_autoclose(fd_num)
      io = IO.new(fd_num)
      self.class.hold(io)
      io
    end

    def file_as_fd(file)
      to_fileno(file)
    end

    def to_fileno(file)
      if file.respond_to?(:fileno)
        file.fileno
      else
        file
      end
    end

    # Should really just shell out to dup2, but looks like we'd need a
    # C extension to do so. The concurrency story here is a bit off,
    # and this probably doesn't copy over all FD state
    # properly. Should be fine for now.
    def dup2(fildes, fildes2)
      original = io_without_autoclose(fildes)

      begin
        copy = io_without_autoclose(fildes2)
      rescue Errno::EBADF
      else
        copy.close
      end

      res = original.fcntl(Fcntl::F_DUPFD, fildes2)
      Rubysh.assert(res == fildes2, "Tried to open #{fildes2} but ended up with #{res} instead", true)
    end

    def set_cloexec(file, enable=true)
      file = io_without_autoclose(file) unless file.kind_of?(IO)
      value = enable ? Fcntl::FD_CLOEXEC : 0
      file.fcntl(Fcntl::F_SETFD, value)
    end
  end
end
