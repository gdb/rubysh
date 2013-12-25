require 'rubysh'

# This is currently unstable. (I'm likely going to flesh out a real
# plugin interface.)

module Rubysh::Plugin
  class SelfTee
    def self.start(logfile, fd_nums)
      fd_map = {}
      fd_nums.each do |fd_num|
        fd = IO.new(fd_num)
        fd.autoclose = false
        fd_map[fd] = IO.pipe
      end

      fork {child_actions(logfile, fd_map)}
      parent_actions(fd_map)
    end

    def self.parent_actions(fd_map)
      fd_map.each do |fd, (read, write)|
        read.close
        Rubysh::Util.dup2(write, fd)
      end
    end

    def self.child_actions(logfile, fd_map)
      runner = self.new(logfile, fd_map)
      runner.run
    end

    def initialize(filename, fd_map)
      @logfile = File.open(filename, 'a')
      fd_map.each do |fd, (read, write)|
        write.close
      end

      @readers = {}
      fd_map.map {|fd, (read, write)| @readers[read] = fd}
    end

    def format_line(fd, line)
      now = Time.now
      now_fmt = now.strftime("%Y-%m-%d %H:%M:%S")
      ms_fmt = sprintf("%06d", now.usec)

      output = "[#{now_fmt}.#{ms_fmt}] #{fd.fileno}: #{line.inspect}"
      output << "\n" unless output.end_with?("\n")
      output
    end

    def run
      parallel_io = Rubysh::Subprocess::ParallelIO.new(@readers, [])
      parallel_io.on_read do |fd, data|
        next if data == Rubysh::Subprocess::ParallelIO::EOF

        formatted = format_line(fd, data)
        @logfile.write(formatted)
        @logfile.flush

        fd.write(data)
        fd.flush
      end
      parallel_io.run
    end
  end
end
