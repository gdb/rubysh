require File.expand_path('../_lib', File.dirname(__FILE__))

module RubyshTest::Functional
  class TripleLessThanTest < FunctionalTest
    describe 'when using <<< string' do
      it 'the string is delivered on stdin' do
        cmd = Rubysh('cat', Rubysh.stdout > :stdout, Rubysh.<<< 'test')
        result = cmd.run

        assert_equal(0, result.exitstatus)
        output = result.read(:stdout)
        assert_equal('test', output)
      end

      it 'stdin is read-only' do
        cmd = Rubysh(
          'ruby', '-e', '
i = IO.new(0)
begin
  i.write("hi")
rescue IOError => e
  raise "Bad error: #{e}" unless e.message == "not opened for writing"
else
  raise "Perfectly writable FD 0"
end
', Rubysh.<<< 'test')
        result = cmd.run

        assert_equal(0, result.exitstatus)
      end
    end
  end
end
