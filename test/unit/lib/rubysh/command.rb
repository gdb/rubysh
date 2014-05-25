require File.expand_path('../../_lib', File.dirname(__FILE__))

module RubyshTest::Unit
  class CommandTest < UnitTest
    describe 'when instantiating a command' do
      it 'parses out args and directives properly' do
        directive = Rubysh.stderr > Rubysh.stdout
        command = Rubysh::Command.new(['ls', '/tmp', directive, '/foo'])
        assert_equal(['ls', '/tmp', '/foo'], command.args)
        assert_equal([directive], command.directives)
      end

      it 'prints correctly' do
        directive = Rubysh.stderr > Rubysh.stdout
        command = Rubysh::Command.new(['ls', '/tmp', directive, '/foo'])
        assert_equal('Command: ls /tmp 2>&1 /foo', command.to_s)
      end

      it 'raises an error when given an unsplatted array' do
        assert_raises(Rubysh::Error::BaseError) {Rubysh::Command.new([['ls', 'stuff']])}
      end
    end

    describe 'when calling #run_async' do
      it 'raises the expected error when duplicating a named target' do
        cmd = Rubysh::Command.new(['ls', '/tmp', Rubysh.>, Rubysh.>])
        error = assert_raises(Rubysh::Error::BaseError) do
          cmd.run_async
        end
        assert_match(/already has a named target/, error.message)
      end
    end
  end
end
