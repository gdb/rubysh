require File.expand_path('../_lib', File.dirname(__FILE__))

module RubyshTest::Functional
  class TripleLessThanTest < FunctionalTest
    describe 'when using <<< string' do
      it 'the string is delivered on stdin' do
        ENV['TEST1'] = '1'
        ENV['TEST2'] = '2'
        result = Rubysh.run('sh', '-c', 'echo $TEST1; echo $TEST2', Rubysh.stdout > :stdout, :env => {'TEST1' => '3'})

        assert_equal(0, result.exitstatus)
        output = result.read(:stdout)
        assert_equal("3\n\n", output)
      end
    end
  end
end
