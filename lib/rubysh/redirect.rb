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

      if source.kind_of?(String)
        raise Rubysh::Error::BaseError.new("Only target can be a pathname. Invalid source: #{source.inspect}")
      end

      @source = source
      @target = target
      @direction = direction
    end

    def apply!
      Rubysh.log.info("About to apply #{self} for #{$$}")

      # Really just want dup2. The concurrency story here is a bit
      # off. But should be fine for now.
      target_io = target_as_io
      begin
        source_io = source_as_io
        source_io.reopen(target_io)
      rescue Errno::EBADF
        source_fileno = source_as_fd
        resulting_fileno = target_io.fcntl(Fcntl::F_DUPFD, source_fileno)
        Rubysh.assert(resulting_fileno == source_fileno, "Tried to open #{source_fileno} but ended up with #{resulting_fileno} instead", true)
      end
    end

    def source_as_io
      file_as_io(source)
    end

    def target_as_io
      file_as_io(target)
    end

    def source_as_fd
      file_as_fd(source)
    end

    def target_as_fd
      target_as_fd(target)
    end

    def printable_source
      call_fileno(source)
    end

    def printable_target
      call_fileno(target)
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

    def file_as_io(file)
      return file if file.kind_of?(IO)
      # If it's an FD, canonicalize to the FD number
      file = call_fileno(file)

      if file.kind_of?(Integer)
        io = IO.new(file)
        self.class.hold(io)
        io
      elsif file.kind_of?(String) && reading?
        File.open(file)
      elsif file.kind_of?(String) && writing? && truncate?
        # Make the following cases explicit for future compatability
        # (also to make it clear on an exception which case is at
        # fault).
        File.open(file, 'w')
      elsif file.kind_of?(String) && writing? && !truncate?
        File.open(file, 'a')
      else
        raise Rubysh::Error::BaseError.new("Unrecognized file spec: #{file.inspect}")
      end
    end

    # TODO: Should this be different from printable_file? Seems to be
    # only a coincidence that they are the same.
    def file_as_fd(file)
      call_fileno(file)
    end

    def call_fileno(file)
      if file.respond_to?(:fileno)
        file.fileno
      else
        file
      end
    end
  end
end
