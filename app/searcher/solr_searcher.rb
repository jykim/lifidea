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
  def search_by_item(item, type ,o={})
    query_item = Item.find(item.to_i)
    return nil if !query_item
    
    case type
    when 'con' : features, weights, filter_qry = CON_FEATURES, @con_weights, "itype_text:concept"
    when 'doc' : features, weights, filter_qry = DOC_FEATURES, @doc_weights, "-itype_text:concept"
    end

    # Initial Solr Query
    solr = RSolr.connect :url=>Conf.solr_server
    solr_result = solr.request "/mlt", :q => "id:\"Item #{query_item.id}\"",:fl => "*,score", :fq =>filter_qry , 
      "mlt.fl" => "title_text,content_text,uri_text,itype_text", "mlt.mintf" => 1
    Item.find(solr_result['response']['docs'].map{|e|e["id"].split(" ")[1]}).each{|i| $items[i.id] = i}    
    # Feature Vector generation
    result = solr_result['response']['docs'].map do |e|
      item = $items[e["id"].split(" ")[1].to_i]
      fts = {:id=>item.id, :content=>e["score"]}
      #fts[:tag] = (item.tags & query_item.tags).size
      fts[:time] = (item.basetime - query_item.basetime ).normalize_time
      fts[:topic] = @clf.read('t', item.id, query_item.id)
      fts[:cooc] = @clf.read('o', item.id, query_item.id).normalize
      fts[:occur] = @clf.read_sum('o', item.id).normalize
      #puts fts.inspect
      fts
    end
    #debugger    
    result = result.sort_by{|fts| 
      fts[:score] = features.map_with_index{|e,i|(fts[e]||0.0) * weights[i]}.sum
    }.reverse
    cache(type+'_result', result )
    result.map{|fts|[fts[:id], fts[:score]]}
  end
  
  # Search given keyword query
  # - 2) document scoring
  # - merging 1) and 2) into final score
  def search_by_keyword(query, o={})
    result = Sunspot.search(Item) do
      keywords query
    end
    result.hits.map{|e|[e.instance.id, e.score]}
  end
  
  
  def log_preference(query, type, click_position, o={})
    $f_li = File.open(RAILS_ROOT + "/data/learner_input/learner_input_#{ENV['RAILS_ENV']}_#{type}_#{Time.now.to_ymd}.txt", 'a')
    
    result = cache(type+'_result' )
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
