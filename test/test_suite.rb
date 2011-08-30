#! /usr/bin/ruby
#
require 'test/unit'
require 'xml'
require 'rss_speed_reader'


class FakeLogger
  def self.method_missing(method, *args)
    puts args
  end
end

class TestRss < Test::Unit::TestCase
  def setup
    # Disable noisy error reporting by libxml2 library on STDOUT
    XML::Error.set_handler(&XML::Error::QUIET_HANDLER)
#    RssSpeedReader.set_logger(RAILS_DEFAULT_LOGGER)
    RssSpeedReader.set_logger(FakeLogger)
  end


  # Compare output for RSS files against expected (YAML test fixtures)
  def test_parsing
    Dir['./test/rss/*.yml'].each do |filename|
      expected = YAML::load( File.open( filename ) )
      reader = XML::Reader.io(open(filename.gsub(/\.yml\Z/, '.xml')), :options => XML::Parser::Options::RECOVER)
      rss = RssSpeedReader.parse(reader)
      if rss != expected
	puts "FILE: #{filename}."
	puts "YAML:\n#{expected.inspect}"
	puts "RSS:\n#{rss.inspect}"
      end
      assert (rss == expected)
    end
  end


  # Test exception thrown for non-RSS file (it's an HTML file, a
  # common user mistake).
  def test_not_rss
    assert_raise RssSpeedReader::NotRSS do
      reader = XML::Reader.io(open('./test/rss/html_page.html'), :options => XML::Parser::Options::RECOVER)
      RssSpeedReader.parse(reader)
    end
  end
end
