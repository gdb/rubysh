module Rubysh
  class BaseDirective
    def stringify
      raise NotImplementedError.new("Override in subclass")
    end

    def prepare!(runner)
      raise NotImplementedError.new("Override in subclass")
    end

    def apply_parent!(runner)
      raise NotImplementedError.new("Override in subclass")
    end

    def apply!(runner)
      raise NotImplementedError.new("Override in subclass")
    end

    # TODO: DRY up?
    def state(runner)
      runner.state(self)
    end
  end
end
