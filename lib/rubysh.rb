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

# You can then create a new Rubysh command:
#
#  command = Rubysh('ls')
#  command.run
def Rubysh(*args, &blk)
  Rubysh::Command.new(args, &blk)
end

def AliasRubysh(name)
  metaclass = class << self; self; end
  metaclass.send(:alias_method, name, :Rubysh)
  Object.const_set(name, Rubysh)
end

module Rubysh
  # Convenience methods
  def self.run(*args, &blk)
    command = Rubysh::Command.new(args, &blk)
    command.run
  end

  def self.run_async(*args, &blk)
    command = Rubysh::Command.new(args, &blk)
    command.run_async
  end

  def self.check_call(*args, &blk)
    command = Rubysh::Command.new(args, &blk)
    command.check_call
  end

  def self.Command(*args, &blk)
    Command.new(*args, &blk)
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

  def self.>(target=(t=true; nil), opts=(o=true; nil))
    target, opts = handle_redirect_args(target, t, opts, o)
    target ||= :stdout

    Redirect.new(1, '>', target, opts)
  end

  def self.>>(target=(t=true; nil), opts=(o=true; nil))
    target, opts = handle_redirect_args(target, t, opts, o)
    target ||= :stdout

    Redirect.new(1, '>>', target, opts)
  end

  def self.<(target=(t=true; nil), opts=(o=true; nil))
    target, opts = handle_redirect_args(target, t, opts, o)
    target ||= :stdin

    Redirect.new(0, '<', target, opts)
  end

  # Hack to implement <<<
  def self.<<(fd=(f=true; nil), opts=(o=true; nil))
    fd, opts = handle_redirect_args(fd, f, opts, o)
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

  def self.handle_redirect_args(target, target_omitted, opts, opts_omitted)
    if opts_omitted && target.kind_of?(Hash)
      # Shift over if user provided target as a hash but omitted opts.
      opts = target
      opts_omitted = target_omitted

      target = nil
      target_omitted = true
    end

    # User provided a false-y value for target. This probably
    # indicates a bug in the user's code, where a variable is
    # accidentally nil.
    if !target_omitted && !target
      raise Rubysh::Error::BaseError.new("You provided #{target.inspect} as your redirect target. This probably indicates a bug in your code. Either omit the target argument or provide a non-false-y value for it.")
    end

    return target, opts
  end
end
