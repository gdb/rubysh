module Rubysh
  # Note that in bash, the semantics of redirection appear to be
  # following (tested empirically, rather than reading a spec):
  #
  # - If a, b are file descriptors, [a<&b] and [a>&b] mean the same
  #   thing: copy FD b to a (try 'echo test 3>/tmp/testing.txt 1<&3')
  # - If b is an invalid file descriptor, then [a>&b] throws an
  #   error.
  class Redirect < BaseDirective
    @references = []
    def self.hold(*references)
      # Needed for Ruby 1.8, where we can't set IO objects to not
      # close the underlying FD on destruction
      @references += references
    end

    attr_accessor :source, :direction, :target

    def initialize(source, direction, target)
      unless direction == '<' || direction == '>'
        raise Rubysh::Error::BaseError.new("Direction must be one of > or <, not #{direction.inspect}")
      end

      @source = source
      @target = target
      @direction = direction
    end

    def apply!
      Rubysh.log.info("About to apply redirect for #{self}")

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
      printable_file(source)
    end

    def printable_target
      printable_file(target)
    end

    # TODO: support files
    def stringify
      source_file = printable_source
      target_file = printable_target

      case direction
      when '<'
        source_file = nil if source_file == 0
        "#{source_file}<&#{target_file}"
      when '>'
        source_file = nil if source_file == 1
        "#{source_file}>&#{target_file}"
      end
    end

    def to_s
      "Redirect: #{stringify}"
    end

    def ==(other)
      self.class == other.class &&
        self.printable_source == other.printable_source &&
        self.printable_target == other.printable_target
    end

    private

    def file_as_io(file)
      if file.kind_of?(IO)
        file
      elsif file.kind_of?(Integer)
        io = IO.new(file)
        self.class.hold(io)
        io
      else
        raise Rubysh::Error::BaseError.new("Unrecognized file spec: #{file.inspect}")
      end
    end

    # TODO: Sort out this vs. printable_file (will differ once string
    # filenames are introduced)
    def file_as_fd(file)
      printable_file(file)
    end

    def printable_file(file)
      if file.respond_to?(:fileno)
        file.fileno
      else
        file
      end
    end
  end
end
