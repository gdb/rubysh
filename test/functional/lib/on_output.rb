require File.expand_path('../_lib', File.dirname(__FILE__))

module RubyshTest::Functional
  class ReadTest < FunctionalTest
    describe 'when using :on_read' do
      it 'calls back as output is streamed' do
        stdout = ''
        stderr = ''

        runner = Rubysh('ruby', '-e', 'puts "hi"; $stderr.puts "hullo there"; puts "hello"',
          Rubysh.>, Rubysh.stderr > :stderr,
          :on_read => Proc.new do |target_name, data|
            case target_name
            when :stdout then stdout << data unless data == Rubysh::Subprocess::ParallelIO::EOF
            when :stderr then stderr << data unless data == Rubysh::Subprocess::ParallelIO::EOF
            else
              raise "Invalid name: #{target_name.inspect}"
            end
          end
          ).run
        assert_equal("hi\nhello\n", stdout)
        assert_equal("hullo there\n", stderr)
      end

      it 'does not allow reading' do
        runner = Rubysh('echo', 'hi',
          Rubysh.>, Rubysh.stderr > :stderr,
          :on_read => Proc.new {}
          ).run
        assert_raises(Rubysh::Error::BaseError) {runner.read}
      end
    end
  end
end
