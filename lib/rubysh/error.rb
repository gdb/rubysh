module Rubysh
  module Error
    class BaseError < Exception; end

    class ExecError < BaseError
      # Exception klass and caller from the child process
      attr_accessor :klass, :caller

      def initialize(message, klass, caller)
        super(message)
        @klass = klass
        @caller = caller
      end
    end
  end
end
