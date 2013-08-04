require File.expand_path('../_lib', File.dirname(__FILE__))
require 'shellwords'

module RubyshTest::Functional
  class LeakedFDsTest < FunctionalTest
    def parse_lsof(stdout)
      pids = []
      stdout.split("\n").each do |line|
        pids << $1.to_i if line =~ /\Af(\d+)\Z/
      end
      pids
    end

    def original_fds
      output = `lsof -p "#{$$}" -F f`
      parse_lsof(output)
    end

    def expected_fd_count(original, pids)
      # MRI 1.9 reserves FDs 3, 4 for itself.
      #
      # TODO: I don't fully understand what FDs MRI decides it needs,
      # but some typical output here is that pids is [0, 1, 2, 5, 6,
      # 8, 255] while original is [0, 1, 2, 3, 4, 5, 6, 7, 8].
      #
      # That may actually indicate a bug in Rubysh somewhere, but I
      # think it means MRI likes opening FDs.
      if RUBY_VERSION =~ /\A1.9\./
        assert_equal(pids.length, original.length - 2, "Pids is #{pids.inspect} while original is #{original.inspect}")
      else
        assert_equal(pids.length, original.length, "Pids is #{pids.inspect} while original is #{original.inspect}")
      end
    end


    describe 'when spawning with no pipe' do
      it 'has no unexpected FDs, post-exec' do
        original = original_fds
        cmd = Rubysh(File.expand_path('../fd-lister', __FILE__), Rubysh.stdout > :stdout, Rubysh.stderr > '/dev/null')
        result = cmd.run

        stdout = result.read(:stdout)
        pids = parse_lsof(stdout)
        expected_fd_count(original, pids)
      end
    end

    describe 'when spawning with a redirect' do
      it 'has no unexpected FDs, post-exec' do
        original = original_fds
        cmd = Rubysh(File.expand_path('../fd-lister', __FILE__), Rubysh.stderr > '/dev/null', Rubysh.stdout > :stdout)
        result = cmd.run

        stdout = result.read(:stdout)
        pids = parse_lsof(stdout)
        expected_fd_count(original, pids)
      end
    end

    describe 'when spawning with a pipe' do
      it 'has no unexpected FDs, post-fork' do
        original = original_fds
        cmd = Rubysh(File.expand_path('../fd-lister', __FILE__)) | Rubysh('cat', Rubysh.stdout > :stdout)
        result = cmd.run

        stdout = result.read(:stdout)
        pids = parse_lsof(stdout)
        expected_fd_count(original, pids)
      end

      it 'has no unexpected FDs, post-fork, when on the right side of a pipe' do
        original = original_fds
        cmd = Rubysh('echo') | Rubysh(File.expand_path('../fd-lister', __FILE__), Rubysh.stdout > :stdout)
        result = cmd.run

        stdout = result.read(:stdout)
        pids = parse_lsof(stdout)
        expected_fd_count(original, pids)
      end

      it 'has no unexpected FDs, post-fork, when in the middle of two pipes' do
        original = original_fds
        cmd = Rubysh('echo') | Rubysh(File.expand_path('../fd-lister', __FILE__)) | Rubysh('cat', Rubysh.stdout > :stdout)
        result = cmd.run

        stdout = result.read(:stdout)
        pids = parse_lsof(stdout)
        expected_fd_count(original, pids)
      end
    end
  end
end
