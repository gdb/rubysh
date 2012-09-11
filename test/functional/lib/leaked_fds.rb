require File.expand_path('../_lib', File.dirname(__FILE__))

module RubyshTest::Functional
  class RubyshTest < FunctionalTest
    describe 'when spawning with no pipe' do
      it 'has no unexpected FDs, post-exec' do
        cmd = Rubysh(File.expand_path('fd-lister', File.dirname(__FILE__)))
        cmd.run

        # TODO: assert no unexpected FDs
      end
    end

    describe 'when spawning with a redirect' do
      it 'has no unexpected FDs, post-exec' do
        cmd = Rubysh(File.expand_path('fd-lister', File.dirname(__FILE__)), Rubysh.stderr > '/dev/null')
        cmd.run

        # TODO: assert no unexpected FDs
      end
    end

    describe 'when spawning with a pipe' do
      it 'has no unexpected FDs, post-fork' do
        cmd = Rubysh(File.expand_path('fd-lister', File.dirname(__FILE__))) | Rubysh('cat')
        cmd.run

        # TODO: assert no unexpected FDs
      end

      it 'has no unexpected FDs, post-fork, when on the right side of a pipe' do
        cmd = Rubysh('echo') | Rubysh(File.expand_path('fd-lister', File.dirname(__FILE__)))
        cmd.run

        # TODO: assert no unexpected FDs
      end

      it 'has no unexpected FDs, post-fork, when in the middle of two pipes' do
        cmd = Rubysh('echo') | Rubysh(File.expand_path('fd-lister', File.dirname(__FILE__))) | Rubysh('cat')
        cmd.run

        # TODO: assert no unexpected FDs
      end
    end
  end
end
