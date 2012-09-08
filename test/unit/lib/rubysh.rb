require File.expand_path('../_lib', File.dirname(__FILE__))

module RubyshTest::Unit
  class RubyshTest < UnitTest
    describe 'when running a command' do
      # Rubysh('ls', '/tmp')
      describe 'that is straightline' do
        it 'prints nicely' do
          command = Rubysh('ls', '/tmp')
          expected = 'Command: ls /tmp'
          assert_equal(expected, command.to_s)
        end

        it 'creates a command with the expected arguments' do
          command = Rubysh('ls', '/tmp')
          command.instantiate_subprocess
          subprocess = command.subprocess
          assert_equal('ls', subprocess.command)
          assert_equal(['/tmp'], subprocess.args)
          assert_equal([], subprocess.opts)
        end
      end

      # Rubysh('ls', '/tmp') | Rubysh('grep', 'myfile')
      describe 'with a pipe' do
        it 'prints nicely' do
          command = Rubysh('ls', '/tmp') | Rubysh('grep', 'myfile')
          expected = 'Command: ls /tmp | grep myfile'
          assert_equal(expected, command.to_s)
        end

        it 'creates a command with the expected arguments' do
          read_fd, write_fd = stub_pipe
          command = Rubysh('ls', '/tmp') | Rubysh('grep', 'myfile')

          # TODO: have some abstraction for this?
          command.left.instantiate_subprocess
          command.right.instantiate_subprocess

          left_subprocess = command.left.subprocess
          right_subprocess = command.right.subprocess

          assert_equal([Rubysh::Redirect.new(Rubysh::FD.new(1), write_fd, :gt)], left_subprocess.opts)
          assert_equal([Rubysh::Redirect.new(Rubysh::FD.new(0), read_fd, :lt)], right_subprocess.opts)
        end
      end

      # Rubysh('ls', '/tmp', Rubysh.stderr > Rubysh.stdout)
      describe 'with a redirection to another file descriptor' do
        it 'prints nicely' do
          command = Rubysh('ls', '/tmp', Rubysh.stderr > Rubysh.stdout)
          expected = 'Command: ls /tmp 2>&1'
          assert_equal(expected, command.to_s)
        end

        it 'creates a command with the expected arguments' do
          command = Rubysh('ls', '/tmp', Rubysh.stderr > Rubysh.stdout)
          command.instantiate_subprocess
          subprocess = command.subprocess
          assert_equal('ls', subprocess.command)
          assert_equal(['/tmp'], subprocess.args)
          assert_equal([Rubysh::Redirect.new(Rubysh::FD.new(2), Rubysh::FD.new(1), :gt)], subprocess.opts)
        end
      end
    end
  end
end
