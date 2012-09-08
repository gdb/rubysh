require 'shellwords'

require 'rubysh/version'
require 'rubysh/error'
require 'rubysh/subprocess'

# Command:
#
# Rubysh('ls', '/tmp')
# => ls /tmp
# Rubysh('ls', '/tmp') | Rubysh('grep', 'myfile')
# => ls /tmp | grep myfile
# Rubysh('ls', '/tmp', Rubysh.stderr > Rubysh.stdout)
# => ls /tmp 2>&1
# Rubysh('ls', '/tmp', Rubysh.> '/tmp/outfile.txt')
# => ls /tmp > /tmp/outfile.txt
# Rubysh('ls', '/tmp', Rubysh.&)
# => ls /tmp &
module Rubysh
  def self.call(*args)
    Command.new(args)
  end

  def self.assert(fact, msg, hard=false)
    raise msg unless fact
  end

  class Command
    def |(other)
      Pipe(self, other)
    end

    def to_s
      raise NotImplementedError.new("Override in subclass")
    end

    def run
      raise NotImplementedError.new("Override in subclass")
    end
  end

  class SimpleCommand < Command
    def initialize(args)
      @args = args
    end

    def to_s
      # Should be smarter about printing args
      @args.map {|arg| Shellwords.shellescape(arg)}.join(' ')
    end

    def run

    end
  end

  class Pipe < Command
    def self.call(left, right)
      self.new(left, right)
    end

    def initialize(left, right)
      @left = left
      @right = right
    end

    def to_s
      "#{left} | #{right}"
    end
  end
end
