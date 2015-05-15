# Rubysh: Ruby subprocesses made easy

Rubysh makes shelling out easy with a __sh__-like syntax layer for Ruby:

    irb -r rubysh
    >> command = Rubysh('echo', 'hello-from-Rubysh') | Rubysh('grep', '--color', 'Rubysh')
    >> command.run
    hello-from-Rubysh
    => Rubysh::Runner: echo hello-from-Rubysh | grep --color Rubysh (exitstatus: 0)

Rubysh's philosophy is to make simple tasks simple and complex tasks
possible.

## Motivation

Existing Ruby shell libaries make it very difficult to do tasks that
are simple in __sh__, such as:

  - piping the output from one program to another
  - redirecting a program's output to a file
  - use a pre-tokenized array of arguments

(Some existing libraries make some of these tasks easy, but not all of
them at once.) Rubysh tries to emulate __sh__'s interface and
semantics as closely as possible.

## Features

Redirecting a file descriptor to a file:

    # echo hello-from-Rubysh >/tmp/file.txt
    Rubysh('echo', 'hello-from-Rubysh', Rubysh.stdout > '/tmp/file.txt')
    Rubysh('echo', 'hello-from-Rubysh', Rubysh::FD(1) > '/tmp/file.txt')

Redirecting a file descriptor to another file descriptor:

    # echo hello-from-Rubysh 2>&1
    Rubysh('echo', 'hello-from-Rubysh', Rubysh.stderr > Rubysh.stdout)

Feeding standard input with a string literal:

    # cat <<< "hello there"
    Rubysh('cat', Rubysh.<<< 'hello there')

Rubysh has been written to work with arbitrary file descriptors, so
you can do the same advanced FD redirection magic you can in __sh__:

    # cat 3<<< "hello there" <&3
    Rubysh('cat', Rubysh::FD(3).<<< 'hello there', Rubysh.stdin < Rubysh::FD(3))

You can also capture output to a named target (here :stdout, :stderr
are arbitrary symbols):

    command = Rubysh('echo', 'hi', Rubysh.stdout > :stdout, Rubysh.stderr > :stderr)
    runner = command.run
    runner.read(:stdout) # "hi\n"
    runner.read(:stderr) # ""

You can also have your child run a Ruby block rather than execute a command:

    command = Rubysh(Rubysh.stdout > :stdout) {puts "hi from child"}
    runner = command.run
    runner.read(:stdout) # "hi from child\n"

## Controlled input

You can easily read and write data interactively:

    >> runner = Rubysh('examples/dots.sh', Rubysh.>).run_async
    => Rubysh::Runner: examples/dots.sh >:stdout (readers: :stdout, pid: 78296)
    >> runner.read(:how => :partial) # block until some output available
    => ".\n.\n.\n.\n.\n.\n.\n.\n.\n"
    >> runner.read(:how => :nonblock)
    => nil
    >> runner.read # block until all output available
    => ".\n[...]"

## Reactive output

You can also receive real-time notifications as data becomes available:

    >> runner = Rubysh(
        'examples/on_read_example.sh',
         Rubysh.stdout > :stdout, Rubysh.stderr > :stderr,
         on_read: Proc.new {|target, data| puts "[#{target}]: #{data}"}
        )
    => Command: examples/on_read_example.sh >:stdout 2>:stderr {:on_read=>#<Proc:0x007f8ad3bc5790@(irb):4>}
    >> runner.run
    [stdout]: [1] Hello from stdout
    [stderr]: [1] Hello from stderr
    [stdout]: [2] Hello from stdout
    [stderr]: [2] Hello from stderr
    [...]

## API

The Rubysh helper function produces instances of `BaseCommand`. You
can run `run` on these to spawn a subprocess and then `wait` for
it to complete. Alternatively, you can do:

    command = Rubysh('ls')
    runner = command.run_async
    runner.wait

If you don't want to type `Rubysh` all the time, you can alias it with
the `AliasRubysh` helper:

    AliasRubysh(:R)
    R('ls')

## Safety

Rubysh takes a splatted array argument as a command specification. In
particular, it doesn't convert it back and forth a command-line
string, meaning you don't have to worry about spaces in
arguments. (You should still always think twice before putting
untrusted arguments into a shell argument.)

## Installation

Rubysh is hosted on Rubygems. You can install by adding this line to
your application's Gemfile:

    gem 'rubysh'

Or by installing directly via

    $ gem install rubysh

## Contributing

Patches welcome! I'm happy to merge pull requests.

## Future features

- Better support for streaming output
- Subshell syntax (`cat <(ls)`, `echo $(ls)`)
