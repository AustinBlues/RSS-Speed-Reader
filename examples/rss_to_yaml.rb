require 'rubygems'
require '../lib/rss_speed_reader'
require 'yaml'


reader = XML::Reader.io(STDIN)
begin
  puts RssSpeedReader.parse(reader).to_yaml
rescue RssSpeedReader::NotRSS
  STDERR.puts "Not RSS"
  exit 1
end
  
