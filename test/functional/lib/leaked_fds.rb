require File.expand_path('../_lib', File.dirname(__FILE__))
require 'shellwords'

module RubyshTest::Functional
  class LeakedFDsTest < FunctionalTest
    # Try to remove inteference from other tests
    def close_high_fds
      begin
        (3..20).each do |fd|
          begin
            io = IO.new(fd)
          rescue Errno::EBADF
          else
            io.close
          end
        end
      end
    end

    def parse_lsof(stdout)
      pids = []
      stdout.split("\n").each do |line|
        pids << $1.to_i if line =~ /\Af(\d+)\Z/
      end
      pids
    end

    before do
      close_high_fds
    end

    describe 'when spawning with no pipe' do
      it 'has no unexpected FDs, post-exec' do
        cmd = Rubysh(File.expand_path('fd-lister', File.dirname(__FILE__)), Rubysh.stdout > :stdout)
        result = cmd.run

        stdout = result.data(:stdout)
        pids = parse_lsof(stdout)
        assert_equal([0, 1, 2, 255], pids)
      end
    end

    describe 'when spawning with a redirect' do
      it 'has no unexpected FDs, post-exec' do
        cmd = Rubysh(File.expand_path('fd-lister', File.dirname(__FILE__)), Rubysh.stderr > '/dev/null', Rubysh.stdout > :stdout)
        result = cmd.run

        stdout = result.data(:stdout)
        pids = parse_lsof(stdout)
        assert_equal([0, 1, 2, 255], pids)
      end
    end

    describe 'when spawning with a pipe' do
      it 'has no unexpected FDs, post-fork' do
        cmd = Rubysh(File.expand_path('fd-lister', File.dirname(__FILE__))) | Rubysh('cat', Rubysh.stdout > :stdout)
        result = cmd.run

        stdout = result.data(:stdout)
        pids = parse_lsof(stdout)
        assert_equal([0, 1, 2, 255], pids)
      end

      it 'has no unexpected FDs, post-fork, when on the right side of a pipe' do
        cmd = Rubysh('echo') | Rubysh(File.expand_path('fd-lister', File.dirname(__FILE__)), Rubysh.stdout > :stdout)
        result = cmd.run

        stdout = result.data(:stdout)
        pids = parse_lsof(stdout)
        assert_equal([0, 1, 2, 255], pids)
      end

      it 'has no unexpected FDs, post-fork, when in the middle of two pipes' do
        cmd = Rubysh('echo') | Rubysh(File.expand_path('fd-lister', File.dirname(__FILE__))) | Rubysh('cat', Rubysh.stdout > :stdout)
        result = cmd.run

        stdout = result.data(:stdout)
        pids = parse_lsof(stdout)
        assert_equal([0, 1, 2, 255], pids)
      end
    end
  end
end
