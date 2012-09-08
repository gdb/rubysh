module Rubysh
  class BaseDirective
    def stringify
      raise NotImplementedError.new("Override in subclass")
    end
  end
end
