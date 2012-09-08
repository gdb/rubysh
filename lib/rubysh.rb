require 'logger'
require 'shellwords'

require 'rubysh/version'
require 'rubysh/base_command'
require 'rubysh/command'
require 'rubysh/error'
require 'rubysh/fd'
require 'rubysh/pipe'
require 'rubysh/redirect'
require 'rubysh/subprocess'

# Command:
#
# Rubysh('ls', '/tmp')
# => Command: ls /tmp
# Rubysh('ls', '/tmp') | Rubysh('grep', 'myfile')
# => Command: ls /tmp | grep myfile
# Rubysh('ls', '/tmp', Rubysh.stderr > Rubysh.stdout)
# => Command: ls /tmp 2>&1
# Rubysh('ls', '/tmp', Rubysh.> '/tmp/outfile.txt')
# => Command: ls /tmp > /tmp/outfile.txt
# Rubysh('ls', '/tmp', Rubysh.&)
# => Command: ls /tmp &
#
# TODO:
# => Command: echo <(ls /tmp)
#
# Need to figure out how to capture FDs in the local process.

# Either create a new Rubysh command:
#
#  command = Rubysh('ls')
#  command.run
#
# Or use the block syntax to create and run one:
#
#  Rubysh {'ls'}
def Rubysh(*args, &blk)
  if blk
    raise Rubysh::Error::BaseError.new("Can't provide arguments and a block") if args.length > 0
    command = blk.call
    command = Rubysh::Command.new(command) unless command.kind_of?(Rubysh::Command)
    command.run
    command
  else
    Rubysh::Command.new(args)
  end
end

module Rubysh
  # Convenience methods
  def self.run(cmd)
    cmd.run
  end

  def self.Command(*args)
    Command.new(*args)
  end

  def self.Pipe(*args)
    Pipe.new(*args)
  end

  # External API methods
  def self.stdin
    FD.new(0)
  end

  def self.stdout
    FD.new(1)
  end

  def self.stderr
    FD.new(2)
  end

  # Internal utility methods
  def self.log
    @log ||= Logger.new(STDERR)
  end

  def self.assert(fact, msg, hard=false)
    return if fact

    msg = msg ? "Assertion Failure: #{msg}" : "Assertion Failure"
    formatted = "#{msg}\n  #{caller.join("\n  ")}"
    log.error(formatted)
    raise msg if hard
  end
end
