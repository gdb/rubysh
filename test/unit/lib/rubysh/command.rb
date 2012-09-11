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
    end
  end
end
