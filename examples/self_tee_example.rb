class SelfTeeExample
  def run
    require 'rubysh/plugin/self_tee'
    Rubysh::Plugin::SelfTee.start('/tmp/logfile.txt', [1, 2])

    puts "this is a line"
    $stderr.puts "this is another line"
    puts "so is this"
  end
end

if $0 == __FILE__
  SelfTeeExample.new.run
end
