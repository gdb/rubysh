module Rubysh
  module Error
    class BaseError < Exception; end

    class ExecError < BaseError
      # Exception klass and caller from the child process
      attr_accessor :raw_message, :klass, :caller

      def initialize(message, raw_message, klass, caller)
        super(message)
        @raw_message = raw_message
        @klass = klass
        @caller = caller
      end
    end

    class UnreachableError < BaseError; end
    class AlreadyClosedError < BaseError; end
    class AlreadyRunError < BaseError; end
    class BadExitError < BaseError; end
    class ECHILDError < BaseError; end
  end
end
