require 'ddl_include'
require 'feedzirra'

# Collect from RSS Feed
# 
class RSSCollector < Collector
  # Read RSS feed
  # @todo refactor source-specific processing
  def read_from_source(o = {})
    feed_text = if ENV['RAILS_ENV'] == 'test'
      IO.read("#{RAILS_ROOT}/test/fixtures/sources/#{@src.itype}.xml")
    else read_uri(@src)
    end
    #puts feed_text
    feed_text.gsub!(/prism:category/,"category") if @src.uri =~ /citeulike/
    #debugger
    return nil if !@src.update_sync_content(feed_text) && !o[:force]
    feed_data = parse_by_feedzirra(feed_text, @src) #
    feed_data.reverse.map_with_index do |e,i|
      # source-specific processing
      itype = case @src.title
      when 'Web History'
        e.delete(:content)
        e[:metadata][:tag_list].gsub!(" ","_")
        case e[:metadata][:tag_list]
        when /query/ : "query"
        else
          "webpage"
        end
      else
        @src.itype
      end
      e[:metadata].delete(:tag_list) if ['calendar'].include?(@src.itype)
      e.merge(:itype=>itype, :basetime=>(e[:basetime] || Time.now).in_time_zone(TIMEZONE))
    end
  end
  
  # Parse feed_text using FeedNormalizer
  # @deprecated by parse_by_feedzirra 
  def parse_by_feednormalizer(feed_text)
    feed_data = FeedNormalizer::FeedNormalizer.parse feed_text
    feed_data.entries.map do|e|
      metadata = {:author => e.author} if e.author
      {:did=>(e.id || e.urls.join(" ")), :title=>e.title,:content=>e.content,:basetime=>e.date_published, 
      :metadata=>metadata, :uri=>e.urls.join(" "), :tag_list=>e.categories.join(",")}
    end
  end

  # Parse feed_text using FeedNormalizer
  # - this provides additional option to fetch more of metadata
  # @return [Array<Hash>] list of parsed feeditems
  def parse_by_feedzirra(feed_text, src)
    if @src.uri =~ /citeulike/
      Feedzirra::Feed.add_common_feed_entry_element('dc:source', :as => :source)
      #Feedzirra::Feed.add_common_feed_entry_element('dc:creator', :as => :authors)
      Feedzirra::Feed.add_common_feed_entry_element('prism:publicationYear', :as => :pub_year)
    end
    feed_data = Feedzirra::Feed.parse feed_text
    feed_data.entries.map do|e|
      metadata = {}
      metadata[:author] =  e.author if e.author
      #metadata[:author] =  e.authors if e.respond_to?(:authors)
      metadata[:pub_year] = e.pub_year if e.respond_to?(:pub_year)
      metadata[:source] = e.source if e.respond_to?(:source)
      metadata[:tag_list] = e.categories.join(",") unless e.categories.blank?
      #debugger
      {:did=>(e.id || e.url), :title=>e.title,:content=>(e.content || e.summary),:basetime=>e.published, 
      :metadata=>metadata, :uri=>e.url}
    end    
  end
end