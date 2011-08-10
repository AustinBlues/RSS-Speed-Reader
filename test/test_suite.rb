#! /usr/bin/ruby
#
require 'test/unit'
require 'xml'
require 'rss_speed_reader'


class TestRss < Test::Unit::TestCase
  def setup
    # Disable noisy error reporting by libxml2 library on STDOUT
    XML::Error.set_handler(&XML::Error::QUIET_HANDLER)
#    RssSpeedReader.set_logger(RAILS_DEFAULT_LOGGER)
  end


  # Compare output for RSS files against expected (YAML test fixtures)
  def test_parsing
    Dir['./test/rss/*.yml'].each do |filename|
      expected = YAML::load( File.open( filename ) )
      rss = parse(open(filename.gsub(/\.yml\Z/, '.xml')))
#      if rss != expected
#	puts "FILE: #{filename}."
#	puts "YAML:\n#{expected.to_yaml}"
#	puts "RSS:\n#{rss.to_yaml}"
#      end
      assert (rss == expected)
    end
  end


  # Test exception thrown for non-RSS file (it's an HTML file, a
  # common user mistake.
  def test_not_rss
    io = open('./test/rss/html_page.html')
    assert_raise RssSpeedReader::NotRSS do
      parse(io)
    end
  end


  def parse(io)
    reader = XML::Reader.io(io, :options => XML::Parser::Options::RECOVER)
    status = ''
    stack = []
    begin
      title, website_url, channel_base = RssSpeedReader.parse_header(reader, stack)
      channel_base ||= website_url
    
      stack.pop
    
      libxmls = []

      RssSpeedReader.parse_body(reader, stack, channel_base) do |libxml|
#      libxml['title'] = if !libxml['title'].empty?
#			  dehtml(libxml['title'])
#			elsif libxml['description'].empty?
#			  libxml['url']
#			else
#			  truncate_between_words(dehtml(libxml['description']))
#			end
	raise "MISSING POST TITLE!" unless libxml['title']
	raise "MISSING POST URL!" unless libxml['url']
	libxmls << libxml
      end
#    rescue Errno::ENOENT
#      channel.status = $!.to_s
#    rescue OpenURI::HTTPError
#      channel.status = "HTTP error (#{$!})"
#    rescue Timeout::Error, Errno::ETIMEDOUT	# 1st value has wrong namespace
#      channel.status = 'Not responding (timeout)'
#    rescue SocketError
#      channel.status = "Socket error (#{$!})"
#    rescue LibXML::XML::Error
#      puts "LibXML::XML::Error: #{$!}."
#      raise RssSpeedReader::NotRSS
#    rescue LibXML::XML::Error
#      channel.status = case $!.to_s
#		       when /UTF-8/
#			 'Invalid UTF-8 encoding'
#		       when /\AFatal error: xmlParseEntityRef: no name at :/
#			 'Invalid RSS/XML encoding'
#		       when /\AFatal error: /
#			 log_msg = "Invalid RSS/XML encoding (#{$'})"
#			 "Invalid RSS/XML encoding"
#		       else
#			 log_msg = "Invalid RSS/XML (#{$!.to_s})"
#			 "Invalid RSS/XML"
#		       end
    end
    {:title => title, :website_url => website_url, :items => libxmls}
  end
end
