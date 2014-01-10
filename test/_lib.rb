require 'rubygems'
require 'bundler/setup'

require 'minitest/autorun'
require 'minitest/spec'
require 'mocha/setup'

$:.unshift(File.expand_path('../lib', File.dirname(__FILE__)))

require 'rubysh'

module RubyshTest
  class Test < ::MiniTest::Spec
    def setup
      # Put any stubs here that you want to apply globally
    end

    def stub_pipe
      read_fd = stub(:fcntl => nil, :read => nil, :close => nil, :closed? => true)
      write_fd = stub(:fcntl => nil, :write => nil, :close => nil, :closed? => true)
      IO.stubs(:pipe => [read_fd, write_fd])
      [read_fd, write_fd]
    end
  end
end
