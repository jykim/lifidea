require 'ddl_include'
#require 'feedzirra'

# Collect from RSS Feed
# 
class RSSCollector < Collector
  # Read RSS feed
  # @todo refactor source-specific processing
  def read_from_source(o = {})
    feed_text = if ENV['RAILS_ENV'] == 'test'
      IO.read("#{Rails.root}/test/fixtures/sources/#{@src.itype}.xml")
    else read_uri(@src, (o[:postfix]||''))
    end
    return nil if !@src.update_sync_content(feed_text) && !o[:force]
    
    # Getting ready for source-specific processing
    feed_text.gsub!(/prism:category/,"category") if @src.uri =~ /citeulike/
    query_text, result_count = nil, 0

    feed_data = parse_by_feedzirra(feed_text, @src) #
    feed_data.reverse.map_with_index do |e,i|
      #puts e.inspect
      #debugger
      # source-specific processing
      itype = case @src.title
      when 'Web History'
        type, content = e[:metadata][:tag_list], e[:content]
        e[:metadata][:tag_list] = "" ; e.delete(:content)
        case type
        when /query/
          if content =~ /(\d+) result\(s\)/
            query_text, result_count = e[:title], ($1).to_i
            e[:did] = e[:title].to_id
          end
          "query"
        else
          if result_count > 0
            #puts "query : #{query_text}"
            e[:metadata][:query] = query_text
            result_count -= 1
          end
          "webpage"
        end
      else
        @src.itype
      end
      e[:metadata].delete(:tag_list) if ['calendar'].include?(@src.itype)
      e.merge(:itype=>itype, :basetime=>(e[:basetime] || Time.now).in_time_zone(TIMEZONE))
    end
  end
  
  def read_batch_from_source(o = {})
    result = []
    item_per_page = 50
    0.upto(o[:times].to_i) do |i|
      result_current = read_from_source(o.merge(:postfix=>"&start-index=#{i*item_per_page+1}&max-results=#{item_per_page}"))
      result.concat result_current
      break if result_current.size < item_per_page
    end
    result
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

  # Parse feed_text using Feedzirra
  # - this provides additional option to fetch more of metadata
  # @return [Array<Hash>] list of parsed feeditems
  def parse_by_feedzirra(feed_text, src)
    if @src.uri =~ /citeulike/
      Feedzirra::Feed.add_common_feed_entry_element('dc:source', :as => :source)
      #Feedzirra::Feed.add_common_feed_entry_element('dc:creator', :as => :authors)
      Feedzirra::Feed.add_common_feed_entry_element('prism:publicationYear', :as => :pub_year)
    end
    feed_data = Feedzirra::Feed.parse feed_text
    #debugger
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
