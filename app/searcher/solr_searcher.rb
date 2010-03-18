class SolrSearcher < Searcher
  attr_accessor :items
  def initialize(o={})
    super(o)
  end
  
  def open_index(o={})
    super(o)
  end
  
  # Search based on similarity
  # - Find target document
  # - Evaluate similarity query
  # @param item <Int> : id of item sought for
  def search_by_item(item, type ,o={})
    query_item = Item.find(item.to_i)
    result = []
    return nil if !query_item
    
    case type
    when 'con' : features, weights, filter_qry = CON_FEATURES, (o[:weights] || @con_weights), "itype_text:concept -itype_text:query"
    when 'doc' : features, weights, filter_qry = DOC_FEATURES, (o[:weights] || @doc_weights), "-itype_text:concept -itype_text:query"
    end
    #debugger
    #puts "[search_by_item] weights = #{weights.inspect}"
    # Initial Solr Query
    solr = RSolr.connect :url=>Conf.solr_server
    solr_result = solr.request "/mlt", :q => "id:\"Item #{query_item.id}\"",:fl => "*,score", :fq =>filter_qry , 
      "mlt.fl" => "title_text,content_text,uri_text,itype_text", "mlt.mintf" => 1, "rows" => (o[:rows] || 50)
    Item.find(solr_result['response']['docs'].map{|e|e["id"].split(" ")[1]}).each{|i| $items[i.id] = i}    

    # Feature Vector generation
    solr_result['response']['docs'].each do |e|
      #debugger
      e["id"] = e["id"].split(" ")[1]
      next if o[:items] && !o[:items].include?(e["id"])
      begin
        item = $items[e["id"].to_i]
        leven_dist = (item.did.size + query_item.did.size).to_f / item.did.levenshtein(query_item.did)/4
        fts = {:id=>item.id, :content=>(e["score"]/4), :title=>leven_dist}
        #fts[:tag] = (item.tags & query_item.tags).size
        fts[:time] = (item.basetime - query_item.basetime ).normalize_time
        fts[:topic] = if type == 'con' : @clf.read('t', item.id, query_item.id)
        elsif item.remark && query_item.remark
          arr1, arr2 = item.remark.split(",").map{|e|e.to_f}, query_item.remark.split(",").map{|e|e.to_f}
          arr1.map_with_index{|e,i|e*arr2[i]}.sum
        end
        fts[:cooc] = @clf.read('o', item.id, query_item.id).normalize(10)
        fts[:occur] = @clf.read_sum('o', item.id).normalize(50)
        #puts fts.inspect        
      rescue Exception => e
        error "[search_by_item] Error in #{query_item} -> #{item}", e
        next
      end
      result << fts
    end
    #debugger
    result = result.sort_by{|fts| 
      fts[:score] = features.map_with_index{|e,i|(fts[e]||0.0) * weights[i]}.sum
    }.reverse
    cache_data(type+'_result', result )
    result
  end
  
  # Search given keyword query
  # - 2) document scoring
  # - merging 1) and 2) into final score
  def search_by_keyword(query, o={})
    result = Sunspot.search(Item) do
      keywords query
    end
    result.hits.map{|e|[e.instance, e.score]}
  end
  
  def log_preference(query, type, click_position, o={})
    $f_li = File.open(RAILS_ROOT + "/data/learner_input/learner_input_#{ENV['RAILS_ENV']}_#{type}_#{Time.now.to_ymd}.txt", 'a')
    
    result = cache_data(type+'_result' )
    last_query_no = SysConfig.find_by_title("LAST_QUERY_NO").content.to_i
    #debugger
    log = result[0..(click_position-1)].reverse.map_with_index{|e,i|
      [((i==0)? 2 : 1), "qid:#{last_query_no}", e, "# #{query} -> #{e[:id]}" ]
    }
    if !o[:export_mode]
      #$clf.increment('c', dnos[0], dnos[1])
      SysConfig.find_by_title("LAST_QUERY_NO").update_attributes(:content=>(last_query_no+1)) 
    end
    $f_li.puts log.map{|e|e.join(" ")}.join("\n") if log.size > 1
    $f_li.flush
  end
end
