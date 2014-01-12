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

    describe 'when registering a reader post-hoc' do
      it 'successfully uses both the existing and new reader' do
        buffers = {}
        runner = Rubysh('sh', '-c', '
echo stdout1
read _
echo stdout2
',
          Rubysh.>, Rubysh.<,
          :on_read => Proc.new do |name, bytes|
            (buffers[name] ||= '') << bytes
          end
          ).run_async
        reader, writer = IO.pipe
        runner.parallel_io.register_reader(reader, :pipe)

        # run_once may be triggered by sigchld
        runner.parallel_io.run_once until buffers.length > 0
        assert_equal(nil, buffers[:pipe])
        assert_equal("stdout1\n", buffers[:stdout])
        buffers.clear

        runner.write("stdin\n")
        writer.write('pipe')

        runner.parallel_io.run_once until buffers[:stdout]
        assert_equal('pipe', buffers[:pipe])
        assert_equal("stdout2\n", buffers[:stdout])
      end
    end
  end
end
