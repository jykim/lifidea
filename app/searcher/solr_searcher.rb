class SolrSearcher < Searcher
  attr_accessor :items
  def initialize(o={})
    super(o)
  end
  
  def open_index(o={})
    super(o)
  end
  
  # Search given keyword query
  # - 2) document scoring
  # - merging 1) and 2) into final score
  def search_by_keyword(query, o={})
    result = Sunspot.search(Item) do
      keywords query
      without :itype_str, 'query'
      without :hidden_flag, '1'
    end
    result.hits.map{|e|[e.instance, e.score]}
  end
  
  # Search based on similarity
  # - Find target document
  # - Evaluate similarity query
  # @param item <Int> : id of item sought for
  def search_by_item(item, type ,o={})
    query_item = Item.find(item.to_i)
    return nil if !query_item
    case type
    when 'con' : features, weights, filter_qry = (o[:features] || CON_FEATURES), (o[:weights] || @con_weights), "itype_text:concept -itype_text:query"
    when 'doc' : features, weights, filter_qry = (o[:features] || DOC_FEATURES), (o[:weights] || @doc_weights), "-itype_text:concept -itype_text:query"
    end
    #debugger
    #puts "[search_by_item] features/weights = #{features.inspect}/#{weights.inspect}"
    result = if cache_data([item, type, 'result'].join("_"))
      cache_data([item, type, 'result'].join("_"))
    else
      cache_data([item, type, 'result'].join("_"), calc_sim_features(query_item, type, filter_qry, o))
    end
    #weights.map!{|e|Math.max(e,0.0)}
    #puts result.inspect
    result.sort_by{|fts| 
      fts[:score] = features.map_with_index{|e,i|(fts[e]||0.0) * weights[i]}.sum
    }.reverse
  end
  
  def calc_sim_features(query_item, type, filter_qry, o={})
    #puts "[calc_sim_features] query_item = #{query_item} "
    #debugger
    result = []
    # Initial Solr Query
    solr = RSolr.connect :url=>Conf.solr_server
    solr_result = solr.request "/mlt", :q => "id:\"Item #{query_item.id}\"",:fl => "*,score", :fq =>filter_qry , 
      "mlt.fl" => "title_text,content_text,uri_text,itype_text", "mlt.mintf" => 1, "rows" => (o[:rows] || 50)
    Item.find(solr_result['response']['docs'].map{|e|e["id"].split(" ")[1]}).
      each{|i| $items[i.id] = cache_data("item_#{i.id}", i)}

    # Feature Vector generation
    solr_result['response']['docs'].each do |e|
      #debugger
      e["id"] = e["id"].split(" ")[1]
      next if o[:items] && !o[:items].include?(e["id"])
      begin
        item = $items[e["id"].to_i]
        #leven_dist = (item.did.size + query_item.did.size).to_f / item.did.levenshtein(query_item.did)/4
        fts = {:id=>item.id, :content=>(e["score"]/2)}
        fts[:tag] = item.tags.overlap(query_item.tags)
        fts[:time] = (item.basetime - query_item.basetime ).normalize_time
        case type
        when 'con'
          fts[:string] = item.did.str_sim(query_item.did)
          fts[:topic] = @clf.read('t', item.id, query_item.id)
          fts[:cooc] = Math.overlap(@clf.read('o', item.id, query_item.id), @clf.read_sum('o', item.id), @clf.read_sum('o', query_item.id))
          fts[:occur] = @clf.read_sum('o', item.id).normalize(Item.count_docs)
        when 'doc'
          if item.remark && query_item.remark
            arr1, arr2 = item.remark.split(",").map{|e|e.to_f}, query_item.remark.split(",").map{|e|e.to_f}
            fts[:topic] = arr1.map_with_index{|e,i|e*arr2[i]}.sum
          end
          fts[:concept] =  item.link_cons.overlap(query_item.link_cons)
        end
        #puts fts.inspect        
      rescue Exception => e
        error "[search_by_item] Error in #{query_item} -> #{item}", e
        next
      end
      result << fts
    end
    result
  end
  
  def log_preference(query_item, type, click_position, o={})
    $f_li = File.open(RAILS_ROOT + "/data/learner_input/learner_input_#{ENV['RAILS_ENV']}_#{type}_#{Time.now.to_ymd}.txt", 'a')
    
    result = search_by_item(query_item, type)
    last_query_no = SysConfig.find_by_title("LAST_QUERY_NO").content.to_i
    #debugger
    log = result[0..(click_position-1)].reverse.map_with_index{|e,i|
      [((i==0)? 2 : 1), "qid:#{last_query_no}", e, "# #{query_item} -> #{e[:id]}" ]
    }
    if !o[:export_mode]
      #$clf.increment('c', dnos[0], dnos[1])
      SysConfig.find_by_title("LAST_QUERY_NO").update_attributes(:content=>(last_query_no+1)) 
    end
    $f_li.puts log.map{|e|e.join(" ")}.join("\n") if log.size > 1
    $f_li.flush
  end
end
