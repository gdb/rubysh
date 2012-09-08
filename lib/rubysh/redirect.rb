module Rubysh
  # Note that in bash, the semantics of redirection appear to be
  # following (tested empirically, rather than reading a spec):
  #
  # - If a, b are file descriptors, [a<&b] and [a>&b] mean the same
  #   thing: copy FD b to a (try 'echo test 3>/tmp/testing.txt 1<&3')
  class Redirect
    attr_accessor :source, :target, :direction

    def initialize(source, target, direction)
      unless direction == :lt || direction == :gt
        raise Rubysh::Error::BaseError.new("Direction must be one of :lt or :gt, not #{direction.inspect}")
      end

      @source = source
      @target = target
      @direction = direction
    end

    def coerced_source
      coerce_file(source)
    end

    def coerced_target
      coerce_file(target)
    end

    # TODO: support strings
    def to_s
      source_file = coerced_source
      target_file = coerced_target

      case direction
      when :lt
        source_file = nil if source_file == 0
        "#{source_file}<&#{target_file}"
      when :gt
        source_file = nil if source_file == 1
        "#{source_file}>&#{target_file}"
      end
    end

    def ==(other)
      self.class == other.class &&
        self.coerced_source == other.coerced_source &&
        self.coerced_target == other.coerced_target
    end

    private

    def coerce_file(file)
      if file.respond_to?(:fileno)
        file.fileno
      else
        file
      end
    end
  end
end
