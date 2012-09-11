require File.expand_path('../../../_lib', File.dirname(__FILE__))

module RubyshTest::Unit
  class ParallelIOTest < UnitTest
    describe 'when given no readers / writers' do
      it 'returns immediately from run' do
        io = Rubysh::Subprocess::ParallelIO.new({}, {})
        io.run
      end
    end

    describe 'when given only readers' do
      it 'makes callbacks as data is read' do
        reader, writer = IO.pipe
        writer.write('hi')

        count = 0

        io = Rubysh::Subprocess::ParallelIO.new({reader => :reader}, {})
        io.on_read do |reader_name, data|
          count += 1

          case count
          when 1
            assert_equal('hi', data)
            writer.write('bye')
          when 2
            assert_equal('bye', data)
            writer.write('done')
          when 3
            assert_equal('done', data)
            writer.close
          when 4
            assert_equal(Rubysh::Subprocess::ParallelIO::EOF, data)
          else
            assert(false)
          end
        end
        io.run
        assert_equal(4, count)
      end

      it 'uses the reader name when data is read' do
        reader, writer = IO.pipe
        writer.write('hi')

        io = Rubysh::Subprocess::ParallelIO.new({reader => :reader}, {})
        io.on_read do |reader_name, data|
          assert_equal(:reader, reader_name)
          writer.close unless writer.closed?
        end
        io.run
      end
    end

    describe 'when given only writers' do
      it 'makes callbacks as data is written' do
        reader, writer = IO.pipe

        count = 0

        io = Rubysh::Subprocess::ParallelIO.new({}, {writer => :writer})
        io.on_write do |writer_name, data, remaining|
          count += 1

          case count
          when 1
            assert_equal('hi', data)
            assert_equal('', remaining)
            io.write(:writer, 'bye', false)
          when 2
            assert_equal('bye', data)
            assert_equal('', remaining)
            io.write(:writer, 'done', false)
          when 3
            assert_equal('done', data)
            assert_equal('', remaining)
            io.write(:writer, '', true)
          when 4
            assert_equal(Rubysh::Subprocess::ParallelIO::EOF, data)
            assert_equal('', remaining)
          else
            assert(false)
          end
        end
        io.write(:writer, 'hi', false)
        io.run

        assert_equal(4, count)
        received = reader.read
        assert_equal('hibyedone', received)
      end

      it 'uses the writer name when data is written' do
        reader, writer = IO.pipe

        io = Rubysh::Subprocess::ParallelIO.new({}, {writer => :writer})
        io.on_write do |writer_name, data|
          assert_equal(:writer, writer_name)
        end
        io.run
      end

      it 'splits up data if it cannot all be written at once' do
        reader, writer = IO.pipe

        io = Rubysh::Subprocess::ParallelIO.new({}, {writer => :writer})
        io.on_write do |writer_name, data, remaining|
          unless data == Rubysh::Subprocess::ParallelIO::EOF
            assert(remaining.length > 0)
            assert(data.length > 0)
            writer.close
          end
        end
        io.write(:writer, '*' * 100000, false)
        io.run
      end

      it 'actually writes the correct data if it cannot all be written at once' do
        reader, writer = IO.pipe
        input = '*' * 100000
        received = ''

        io = Rubysh::Subprocess::ParallelIO.new({}, {writer => :writer})
        io.on_write do |writer_name, data, remaining|
          unless data == Rubysh::Subprocess::ParallelIO::EOF
            received << reader.read_nonblock(100000)
          end
        end
        io.write(:writer, input, true)
        io.run

        assert_equal(input, received)
      end
    end

    describe 'when given both writers and readers' do
      it 'correctly reads and writes data' do
        reader1, writer1 = IO.pipe
        reader2, writer2 = IO.pipe

        count1 = 0
        count2 = 0

        io = Rubysh::Subprocess::ParallelIO.new(
          {reader1 => :reader1, reader2 => :reader2},
          {writer1 => :writer1, writer2 => :writer2})

        io.on_read do |reader_name, data|
          if reader_name == :reader1
            count1 += 1
            case count1
            when 2
              assert_equal('hi1', data)
              io.write(:writer1, 'test1', false)
            when 4
              assert_equal('test1', data)
              io.write(:writer1, 'final1', true)
            when 7
              assert_equal('final1', data)
            when 8
              assert_equal(Rubysh::Subprocess::ParallelIO::EOF, data)
            else
              raise "Unexpected count1: #{count1}"
            end
          elsif reader_name == :reader2
            count2 += 1
            case count2
            when 2
              assert_equal('hi2', data)
              io.write(:writer2, 'test2', false)
            when 4
              assert_equal('test2', data)
              io.write(:writer2, 'final2', true)
            when 7
              assert_equal('final2', data)
            when 8
              assert_equal(Rubysh::Subprocess::ParallelIO::EOF, data)
            else
              raise "Unexpected count2: #{count2}"
            end
          else
            raise "Unrecognized reader"
          end
        end

        io.on_write do |writer_name, data, remaining|
          if writer_name == :writer1
            count1 += 1

            case count1
            when 1
              assert_equal('hi1', data)
            when 3
              assert_equal('test1', data)
            when 5
              assert_equal('final1', data)
            when 6
              assert_equal(Rubysh::Subprocess::ParallelIO::EOF, data)
            else
              raise "Unexpected count1: #{count1}"
            end
          elsif writer_name == :writer2
            count2 += 1

            case count2
            when 1
              assert_equal('hi2', data)
            when 3
              assert_equal('test2', data)
            when 5
              assert_equal('final2', data)
            when 6
              assert_equal(Rubysh::Subprocess::ParallelIO::EOF, data)
            else
              raise "Unexpected count2: #{count2}"
            end
          else
            raise "Unrecognized writer"
          end
        end

        io.write(:writer1, 'hi1', false)
        io.write(:writer2, 'hi2', false)

        io.run

        assert_equal(8, count1)
        assert_equal(8, count2)
      end
    end
  end
end
