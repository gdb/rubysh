require 'rubygems'
require 'bundler/setup'

require 'minitest/autorun'
require 'minitest/spec'
require 'mocha'

$:.unshift(File.expand_path('../lib', File.dirname(__FILE__)))

require 'rubysh'

module RubyshTest
  class Test < ::MiniTest::Spec
    def setup
      # Put any stubs here that you want to apply globally
    end
  end
end
