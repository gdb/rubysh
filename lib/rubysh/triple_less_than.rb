require 'tempfile'

module Rubysh
  # Looks like bash always buffers <<< to disk
  class TripleLessThan < BaseDirective
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
      tempfile.delete
      tempfile.write(@literal)
      tempfile.flush
      tempfile.rewind

      Util.set_cloexec(tempfile)

      state = state(runner)
      state[:tempfile] = tempfile
      state[:redirect] = Redirect.new(@fd, '<', tempfile)
    end

    def stringify
      fd = Util.to_fileno(@fd)
      beginning = fd == 0 ? '' : fd.to_s
      "#{beginning}<<< #{@literal.inspect}"
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
