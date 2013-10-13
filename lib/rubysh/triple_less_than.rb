require 'tempfile'

module Rubysh
  # Looks like bash always buffers <<< to disk
  class TripleLessThan < BaseDirective
    attr_reader :fd, :literal

    class Shell < BaseDirective
      def initialize(fd, opts)
        @fd = fd
        @opts = opts
      end

      def <(literal=:stdin)
        TripleLessThan.new(@fd, literal)
      end

      def prepare!
        raise Rubysh::Error::BaseError.new("You have an incorrect usage of <<<, leading to a #{self.class} instance hanging around. Use it as either: Rubysh.<<< 'my string' or Rubysh::FD(3).<<< 'my string'.")
      end

      def stringify
        " << #{fd.stringify} (INVALID SYNTAX)"
      end
    end

    # TODO: support in-place strings
    def initialize(fd, literal)
      @fd = fd
      @literal = literal
    end

    def prepare!(runner)
      tempfile = Tempfile.new('buffer')
      tempfile_read_only = File.open(tempfile.path, 'r')

      tempfile.delete
      tempfile.write(@literal)
      tempfile.flush
      tempfile.rewind
      tempfile.close

      Util.set_cloexec(tempfile_read_only)

      state = state(runner)
      state[:tempfile] = tempfile_read_only
      state[:redirect] = Redirect.new(@fd, '<', tempfile_read_only)
    end

    def stringify
      fd = Util.to_fileno(@fd)
      beginning = fd == 0 ? '' : fd.to_s
      "#{beginning}<<< (#{@literal.bytesize} bytes)"
    end

    def to_s
      "TripleLessThan: #{stringify}"
    end

    def apply_parent!(runner)
      state = state(runner)
      state[:tempfile].close
      state[:redirect].apply_parent!(runner)
    end

    def apply!(runner)
      state = state(runner)
      state[:redirect].apply!(runner)
    end
  end
end
