require 'set'

module Rubysh
  module Util
    def self.to_fileno(file)
      if file.respond_to?(:fileno)
        file.fileno
      else
        file
      end
    end
  end
end
