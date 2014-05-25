require File.expand_path('../_lib', File.dirname(__FILE__))

module RubyshTest::Functional
  class EnvTest < FunctionalTest
    describe 'when executing a block' do
      it 'runs the expected code' do
        result = Rubysh.run(Rubysh.stdout > :stdout) {puts "hi"}

        assert_equal(0, result.exitstatus)
        output = result.read(:stdout)
        assert_equal("hi\n", output)
      end

      it 'hard exits from the subprocess' do
        Rubysh::Subprocess.any_instance.stubs(:render_exception)

        begin
          result = Rubysh.run {raise "this should in fact get printed"}
        rescue Exception
        end

        assert_equal(1, result.exitstatus)
      end
    end
  end
end
