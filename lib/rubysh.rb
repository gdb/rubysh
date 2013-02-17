require 'logger'

require 'rubysh/version'
require 'rubysh/base_command'
require 'rubysh/base_directive'
require 'rubysh/command'
require 'rubysh/error'
require 'rubysh/fd'
require 'rubysh/pipeline'
require 'rubysh/redirect'
require 'rubysh/runner'
require 'rubysh/subprocess'
require 'rubysh/triple_less_than'
require 'rubysh/util'

# Basic usage:
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
# If you want to capture output:
#
# Rubysh('cat', Rubysh.stdout > :pipe)
#
# You can name pipes with whatever symbol name you want:
#
# Rubysh('cat', 2 > :stdout, 3 > :fd3)
#
# TODOs:
#
# => Command: (ls; ls) | grep foo
# => Command: echo <(ls /tmp)
# => Command: echo >(cat)
#
# Something like the following to tee output:
#
# Rubysh('cat', Rubysh.stdout >> :pipe)
#
# The following rough API needs to be fleshed out. Maybe something
# close to the following for interactivity:
#
# cmd = Rubysh('cat', Rubysh.stdout > :stdout, Rubysh.stderr > :stderr, Rubysh.stdin < :stdin)
# q = cmd.run_async
# q.write(:stdin, 'my whole command')
# q.communicate # closes writeable pipes and reads from all readable pipes
# q.data(:stdout)
# q.exitstatus
#
# q.write(:stdin, 'my first command') # write data (while also reading from readable pipes
#                                     # in a select() loop)
# q.communicate(:partial => true) # read available data (don't close pipes)
# q.data(:stdout)
# q.write(:stdin, 'my second command')
#
# It'd be possible to support &, but I don't think it's needed:
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
  else
    Rubysh::Command.new(args)
  end
end

def AliasRubysh(name)
  metaclass = class << self; self; end
  metaclass.send(:alias_method, name, :Rubysh)
  Object.const_set(name, Rubysh)
end

module Rubysh
  # Convenience methods
  def self.run(*args, &blk)
    command = Rubysh::Command.new(args)
    command.run(&blk)
  end

  def self.check_call(*args, &blk)
    command = Rubysh::Command.new(*args)
    command.check_call(&blk)
  end

  def self.Command(*args)
    Command.new(*args)
  end

  def self.Pipeline(*args)
    Pipeline.new(*args)
  end

  def self.FD(*args)
    FD.new(*args)
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

  def self.>(target=nil, opts=nil)
    # Might want to DRY this logic up at some point. Right now seems
    # like it'd just sacrifice clarity though.
    if !opts && target.kind_of?(Hash)
      opts = target
      target = nil
    end
    target = :stdout

    Redirect.new(1, '>', target, opts)
  end

  def self.>>(target=nil, opts=nil)
    if !opts && target.kind_of?(Hash)
      opts = target
      target = nil
    end
    target = :stdout

    Redirect.new(1, '>>', target, opts)
  end

  def self.<(target=nil, opts=nil)
    if !opts && target.kind_of?(Hash)
      opts = target
      target = nil
    end
    target = :stdin

    Redirect.new(0, '<', target, opts)
  end

  # Hack to implement <<<
  def self.<<(fd=nil, opts=nil)
    if !opts && fd.kind_of?(Hash)
      opts = fd
      fd = nil
    end

    fd ||= FD.new(0)
    TripleLessThan::Shell.new(fd, opts)
  end

  # Internal utility methods
  def self.log
    unless @log
      @log = Logger.new(STDERR)
      @log.level = Logger::WARN
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
