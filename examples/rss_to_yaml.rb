require 'rubygems'
require '../lib/rss_speed_reader'
require 'yaml'

class FakeLogger
  def self.method_missing(method, *args)
    puts args
  end
end


RssSpeedReader.set_logger(FakeLogger)

reader = XML::Reader.io(STDIN)
begin
  puts RssSpeedReader.parse(reader).to_yaml
rescue RssSpeedReader::NotRSS
  STDERR.puts "Not RSS"
  exit 1
end
  
