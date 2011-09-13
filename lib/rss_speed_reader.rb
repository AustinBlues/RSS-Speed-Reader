require 'xml'
require 'rss_speed_reader/version'


module RssSpeedReader
  class NewLocation < StandardError; end
  class NotRSS < StandardError; end

  @@logger = nil


  # Set logger to be used.
  def self.set_logger(logger)
    @@logger = logger
  end


  # Log if @@logger
  def self.log(method, *args)
    @@logger.send(method, args) if @@logger
  end


  # Is source in reader in RSS format?
  def self.rss?(reader)
    parser_stack = []
    parse_header(reader, parser_stack)
  rescue NotRSS
    false
  else
    true
  end


  # Parse RSS, reading XML from +io+, returning hash with all RSS
  # feed relevant data.
  def self.parse(reader)
    status = ''
    stack = []
    begin
      title, website_url, channel_base = RssSpeedReader.parse_header(reader, stack)
      channel_base ||= website_url

      stack.pop

      libxmls = []

      RssSpeedReader.parse_body(reader, stack, channel_base) do |libxml|
	libxmls << libxml
      end
    end
    {:title => title, :website_url => website_url, :items => libxmls}
  end


  # Parse up to the first item
  def self.parse_header(reader, stack)
    title = nil
    base = ''
    website_url = nil

    begin
      status = reader.read
    rescue LibXML::XML::Error
      raise NotRSS, 'not XML'
    rescue
      log(:warn, "HEADER READ ERROR(#{$!.class}): '#{$!}'.")
      log(:warn, $!.backtrace)
      return title, website_url, base
    else
      raise NotRSS, 'empty file' unless status
    end

    while status
      case reader.node_type
      when XML::Reader::TYPE_ELEMENT
	stack << reader.name
	path = stack.join('/')
	case path
	when 'feed', 'rss', 'rss10', 'rss11', 'rdf:RDF', 'atom03', 'atom', 'atom10'
	  base = $1 if reader['xml:base'] =~ %r{(.*/).*}
	  base << '/' unless base[-1] == ?/
	when 'feed/link'
	  if reader['rel'] == 'alternate' && reader['type'] == 'text/html'
	    website_url = reader['href'].strip if !reader['href'].nil? && !reader['href'].empty?
	  elsif reader['type'] !~ /xml/ && reader['rel'] != 'replies'
	    website_url = reader['href'] if website_url.nil?
	  end
	when 'feed/entry', 'feed/atom:entry', 'feed/atom03:entry', 'feed/atom10:entry',
	    'feed/entry', 'feed/atom10:entry', 'feed/atom03:entry', 'feed/atom:entry',
	    'rss/channel/item', 'rdf:RDF/item',
	    'rss10:item', 'rss11:items/rss11:item', 'rss11:items/item', 'items/rss11:item',
	    'items/items', 'item', 'atom10:entry', 'atom03:entry', 'atom:entry', 'entry'
	  break		# end of header
	end
	stack.pop if reader.empty_element?
      when XML::Reader::TYPE_TEXT, XML::Reader::TYPE_CDATA
	path = stack.join('/')
	case path
	when 'rss', 'feed', 'rdf:RDF'
	  feed_type = reader.name
	when 'rss/channel/title', 'feed/title', 'rdf:RDF/channel/title'
	  title = reader.value.strip
	when 'rss/link', 'rss/channel/link', 'rdf:RDF/channel/link'
	  base = website_url = reader.value.strip
	when 'feed/id'
	  website_url = reader.value.strip if website_url.nil? || website_url.empty?
	when 'redirect/newLocation'
	  rss_url = reader.value.strip
	  raise RssSpeedReader::NewLocation, rss_url
	end
      when XML::Reader::TYPE_END_ELEMENT
	stack.pop
      when XML::Reader::TYPE_DOCUMENT_TYPE
	type = reader.name.strip
	raise NotRSS, type unless type =~ /\A(xml|rss|rdf:RDF)\z/i
      end
      begin
	status = reader.read
      rescue
	log(:warn, "HEADER2 READ ERROR: '#{$!}'.")
	return title, website_url, base
      end
    end

    return title, website_url, base
  end


  # Parse the items, yeilding for each one.
  def self.parse_body(reader, stack, channel_base)
    libxml = {}		# force scope
    links = []		# force scope

    begin	# post test loop
      case reader.node_type
      when XML::Reader::TYPE_ELEMENT
	stack << reader.name
	path = stack.join('/')
	case path
	when 'feed/entry/link', 'feed/entry/a', 'feed/entry/url', 'feed/entry/href',
	    'feed/atom:entry/link', 'feed/atom:entry/atom:link',
	    'feed/atom03:entry/link', 'feed/atom03:entry/atom03:link',
	    'feed/atom10:entry/link', 'feed/atom10:entry/atom10:link'
	  link = {}
	  link[:href] = reader['href'].strip if reader['href']
	  link[:type] = reader['type']
	  link[:title] = reader['title']
	  link[:rel] = reader['rel']
	  links << link if reader.empty_element?
	when 'rss/channel/item/enclosure'
	  link = {}
	  link[:href] = reader['url'].strip unless reader['url'].empty?
	  link[:type] = reader['type']
	  links << link if reader.empty_element?
	when 'rss/channel/item/description', 'feed/entry/summary'
	  libxml['description'] =
	    reader.empty_element? ? '' : reader.read_inner_xml
	when 'feed/entry', 'feed/atom10:entry', 'feed/atom03:entry', 'feed/atom:entry',
	    'rss/channel/item', 'rdf:RDF/item',
	    'rss10:item', 'rss11:items/rss11:item', 'rss11:items/item', 'items/rss11:item',
	    'items/items', 'item', 'atom10:entry', 'atom03:entry', 'atom:entry', 'entry'
	  links = []
	  #	  log(:debug, "RESET LINKS.")
	  libxml = {'description' => 'MISSING'}
	  item_base = channel_base ? channel_base.dup : ''
	  item_base << reader['xml:base'] if reader['xml:base']
	  item_base << '/' unless item_base =~ %r{/\Z}
	when 'feed'
	  channel_base = $1 if reader['xml:base'] =~ %r{(.*/).*}
	  channel_base << '/' unless channel_base =~ %r{/\Z}
	  log(:debug, "CHANNEL_BASE(<feed xml:base=>): '#{channel_base}'.")
	end
	stack.pop if reader.empty_element?
      when XML::Reader::TYPE_TEXT, XML::Reader::TYPE_CDATA
	path = stack.join('/')
	case path
	when 'feed/entry/title', 'rss/channel/item/title', 'rss/item/title',
	    'rdf:RDF/item/title'
	  libxml['title'] = reader.value
	when 'feed/entry/content'
	  libxml['description'] = reader.value if libxml['description'] == 'MISSING'
	when'rss/channel/item/description', 'rdf:RDF/item/description'
	  libxml['description'] = reader.value
	when 'feed/entry/summary'
	  libxml['description'] = reader.value
	when 'feed/entry/feedburner:origLink', 'rss/channel/item/link',
	    'rdf:RDF/item/link'
	  link = {:href => reader.value.strip} unless reader.value.empty?
	  links << link
	when 'feed/entry/id', 'rss/channel/item/guid'
	  libxml['ident'] = reader.value
	when 'feed/entry/published', 'rss/channel/item/pubDate', 'rdf:RDF/item/dc:date'
	  libxml['time'] ||= reader.value
	when 'feed/entry/updated'
	  libxml['time'] = reader.value
	when %r{guid\Z}
	  log(:info, "GUID: '#{reader.value}'.")
	end
      when XML::Reader::TYPE_END_ELEMENT
	path = stack.join('/')
	case path
	when 'feed/entry/link', 'feed/entry/a', 'feed/entry/url', 'feed/entry/href',
	    'feed/atom:entry/link', 'feed/atom:entry/atom:link',
	    'feed/atom03:entry/link', 'feed/atom03:entry/atom03:link',
	    'feed/atom10:entry/link', 'feed/atom10:entry/atom10:link',
	    'rss/channel/item/enclosure'
	  links << link
	when 'feed/entry', 'rss/channel/item', 'rdf:RDF/item'
	  libxml['url'] = RssSpeedReader.resolve_links(links, item_base)

	  # FIXME debug code
	  if libxml['url'] !~ %r{\Ahttps?://}i
	    log(:warn, "MISSING PROTOCOL: '#{libxml['url']}'.")
	    log(:warn, "  BASE: '#{item_base}'.")
	    log(:warn, "  LINKS: '#{links.inspect}'.")
	  end
	  if libxml['url'] !~ %r{/?\w+(\.\w+)+/?}
	    log(:warn, "MISSING DOMAIN: '#{libxml['url']}'.")
	    log(:warn, "  BASE: '#{item_base}'.")
	  end

	  libxml.each_value{|v| v.strip!}

#	  log(:debug, "ITEM_BASE: '#{item_base}'.")

	  yield libxml
	end
	stack.pop
      end
    end while reader.read
  end



  # Helper to select most desireable one among the links in a item, a
  # heuristic
  def self.resolve_links(links, base_url)
#    log(:debug, "LINKS: #{links.inspect}.")
    max_score = -99
    url = nil
    links.reverse.each do |link|
      score = 0
      if link[:href].nil? || link[:href] =~ %r{\A/?\Z}	# empty or single slash
	score -= 3
      end
      if link[:type] =~ /html/
	score += 2
      elsif link[:type] =~ /xml/
	score += 0
      elsif !link[:type].nil?
	score -= 1
      end
      case link[:rel]
      when 'alternate'
	score += 1
      when 'shorturl'
	score += 2
      when 'self'
	score -= 1
      when 'replies'
	score -= 3
      end
#      log(:debug, "SCORE(#{score}): #{link.inspect}.")
      if score > max_score
	url = link[:href]
	max_score = score
      end
    end
    
#    log(:debug, "URL: #{url.inspect}.")
#    log(:debug, "BASE_URL: #{base_url.inspect}.")
    result = if url =~ %r{\Ahttps?://}
      url
    else
      if url =~ %r{\A/}
	base_url = base_url.slice(%r{\w+://\w+(.\w+)+})
      end
      # compress any double slashes not in protocol
      "#{base_url}#{url}".gsub(%r{[^:]//}){$&.slice(0, 2)}
    end
#    log(:debug, "RESULT: '#{result}'.")
    result
  end
end
