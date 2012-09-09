require 'logger'
require 'shellwords'

require 'rubysh/version'
require 'rubysh/base_command'
require 'rubysh/base_directive'
require 'rubysh/command'
require 'rubysh/error'
require 'rubysh/fd'
require 'rubysh/pipeline'
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
# Rubysh('ls', '/tmp', Rubysh.>('/tmp/outfile.txt'))
# => Command: ls /tmp > /tmp/outfile.txt
#
# TODO:
# => Command: (ls; ls) | grep foo
# => Command: echo <(ls /tmp)
# => Command: echo >(cat)
#
# If you want to capture output:
#
# Rubysh('cat', Rubysh.stdout > :pipe)
#
# Or for interactivity:
#
# q = Rubysh('cat', Rubysh.stdout > :pipe, Rubysh.stderr > :pipe, Rubysh.stdin < :pipe)
# q.write('my whole command')
# q.communicate # closes writeable pipes and reads from all readable pipes
# q.data_from(:stdout)
# q.data_from(1)
# q.status
#
# This API is a WIP:
#
# q.write('my first command') # write data (while also reading from readable pipes
#                             # in a select() loop)
# q.communicate(:partial => true) # read available data (don't close pipes)
# q.data_from(:stdout)
# q.write('my second command')
#
# Not sure this is needed:
# Rubysh('ls', '/tmp', Rubysh.&)
# => Command: ls /tmp &

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

  def self.Pipeline(*args)
    Pipeline.new(*args)
  end

  def self.stdin
    FD.new(0)
  end

  def self.stdout
    FD.new(1)
  end

  def self.stderr
    FD.new(2)
  end

  def self.>(target)
    Redirect.new(1, '>', target)
  end

  def self.>>(target)
    Redirect.new(1, '>>', target)
  end

  def self.<(target)
    Redirect.new(0, '<', target)
  end

  # TODO: not sure exactly how this should work.
  #
  # Hack to implement <<<
  # def self.<<
  #   TripleLessThan.new
  # end

  # Internal utility methods
  def self.log
    unless @log
      @log = Logger.new(STDERR)
      @log.level = Logger::DEBUG
    end

    @log
  end

  def self.assert(fact, msg, hard=false)
    return if fact

    msg = msg ? "Assertion Failure: #{msg}" : "Assertion Failure"
    formatted = "#{msg}\n  #{caller.join("\n  ")}"
    log.error(formatted)
    raise msg if hard
  end
end
