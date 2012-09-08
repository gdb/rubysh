module Rubysh
  class FD
    attr_accessor :fileno

    def initialize(fileno)
      case fileno
      when Integer
        # pass
      when :stdin
        fileno = 0
      when :stdout
        fileno = 1
      when :stderr
        fileno = 2
      else
        raise Rubysh::Error::BaseError.new("Fileno must be an integer or one of :stdin, :stdout, :stderr, not #{fileno.inspect}")
      end

      @fileno = fileno
    end

    def >(target)
      Redirect.new(self, '>', target)
    end

    def <(target)
      Redirect.new(self, '<', target)
    end

    def to_s
      "FD: #{@fileno}"
    end

    def ==(other)
      self.class == other.class &&
        self.fileno == other.fileno
    end
  end
end
