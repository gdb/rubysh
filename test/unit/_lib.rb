require File.expand_path('../_lib', File.dirname(__FILE__))

module RubyshTest::Unit
  class UnitTest < RubyshTest::Test; end
end

MiniTest::Unit.runner = MiniTest::Unit.new
