class SolrSearcher < Searcher
  attr_accessor :items
  def initialize(o={})
    super(o)
    nil
  end
  
  def open_index(o={})
    super(o)
  end
  
  # Search given keyword query
  # - 2) document scoring
  # - merging 1) and 2) into final score
  def search_by_keyword(query, o={})
    #debugger
    result = Sunspot.search(Item) do
      keywords query
      if o[:doc_only]
        without :itype_str, ['query','concept','tag']
      end
      #debugger
      o.find_all{|k,v|k.to_s =~ /^facet\_/}.each do |e|
        #debugger
        with (e[0].to_s.split('_')[1..-1].join('_')).to_sym, e[1] if [e[1]].flatten.first != '-1'
      end
      #debugger
      order_by(:basetime, :desc) if o[:order] == "recency"
      paginate(:page => o[:page]) if o[:page]
      facet(o[:facet]) if o[:facet]
      without :hidden_flag, '1'
    end
    #debugger
    if o[:facet]
      result.facet(o[:facet]).rows
    else
      result
    end
  end
  
  def calc_df(query, tplus = nil, tminus = nil)
    #debugger
    #puts query
    result = Sunspot.search(Item) do
      keywords query
      without :itype_str, Item::ITYPE_CONCEPT
      tplus.each{|e| with :fulltext, "#{e}"} if tplus
      tminus.each{|e| without :fulltext, "\"#{e}\""} if tminus
    end
    result.total
  end
  
  # Search items based on similarity
  # - Find target document
  # - Evaluate similarity query
  # @param [int] item : id of item sought for
  # @param [Array<int>] :working_set : subset of items to run retrieval
  def search_by_item(item, type ,o={})
    query_item = Item.find(item.to_i)
    return nil if !query_item
    case type
    when 'con' : features, weights, filter_qry = (o[:features] || CON_FEATURES), (o[:weights] || @con_weights), "itype_text:concept -itype_text:query"
    when 'doc' : features, weights, filter_qry = (o[:features] || DOC_FEATURES), (o[:weights] || @doc_weights), "-itype_text:concept -itype_text:query"
    end
    filter_qry = o[:working_set].map{|e|"id_text:#{e}"}.join(" || ") if o[:working_set]
    #debugger
    #puts "[search_by_item] features/weights = #{features.inspect}/#{weights.inspect}"
    result = calc_sim_features(query_item, type, filter_qry, o)
    final_result = result.sort_by{|fts|
      fts[:score] = features.map_with_index{|e,i|(fts[e]||0.0) * weights[i]}.sum
      #fts[0], fts[1] = fts[:id], fts[:score]
    }.reverse
    #puts "[search_by_item] #{item} - #{final_result[0][:id]} : #{final_result[0][:score]} * #{weights.inspect}"
    final_result
  end
  
  # Calculate similarity feature values 
  # - Connect to Solr for feature value calculation
  # - Cache the results
  # @param [Bool] :no_cache : disble result cacheing
  def calc_sim_features(query_item, type, filter_qry, o={})
    #puts "[calc_sim_features] query_item = #{query_item} #{filter_qry}"
    
    if !o[:no_cache] && cache_data([query_item, type, 'result'].join("_"))
      return cache_data([query_item, type, 'result'].join("_"))
    end

    # Initial Solr Query
    result = []
    solr = RSolr.connect :url=>Conf.solr_server
    begin
      solr_result = solr.request "/mlt", :q => "id:\"Item #{query_item.id}\"",:fl => "*,score", :fq =>filter_qry , "rows" => (o[:rows] || 50), 
        "mlt.fl" => "title_text,content_text,metadata_text,uri_text,itype_text", "mlt.mintf" => 1, "mlt.mindf" => 5, "mlt.boost"=>true
      Item.find(solr_result['response']['docs'].map{|e|e["id"].split(" ")[1]}).
        each{|i| $items[i.id] = cache_data("item_#{i.id}", i)}  
    rescue Exception => e
      error "[search_by_item] Error in Calling Solr", e
      return result
    end
    
    # Feature Vector generation
    solr_result['response']['docs'].each do |e|
      #debugger
      e["id"] = e["id"].split(" ")[1]
      next if o[:items] && !o[:items].include?(e["id"])
      begin
        item = $items[e["id"].to_i]
        #leven_dist = (item.did.size + query_item.did.size).to_f / item.did.levenshtein(query_item.did)/4
        fts = {:id=>item.id, :content=>(e["score"]/2)}
        #fts[:tag]   = item.tag_titles.overlap(query_item.tag_titles) #get_overlap_feature('s', item, query_item)
        fts[:title] = (item.title || "").word_sim(query_item.title || "")
        fts[:time]  = (item.basetime - query_item.basetime ).normalize_time
        case type
        when 'con'
          fts[:string] = item.did.str_sim(query_item.did)
          fts[:topic] = @clf.read('t', item.id, query_item.id)
          fts[:cooc]  = Math.overlap(@clf.read('o', item.id, query_item.id), @clf.read_sum('o', item.id), @clf.read_sum('o', query_item.id))
          fts[:occur] = @clf.read_sum('o', item.id).normalize(Item.count_docs)
        when 'doc'
          if item.remark && query_item.remark
            arr1, arr2 = item.remark.split(",").map{|e|e.to_f}, query_item.remark.split(",").map{|e|e.to_f}
            fts[:topic] = arr1.map_with_index{|e,i|e*arr2[i]}.sum
          end
          #fts[:concept] =  get_overlap_feature('e', item, query_item)
          fts[:path] = (item.uri || "").path_sim(query_item.uri || "")
          fts[:type] = (item.itype == query_item.itype)? 0.5 : 0
          fts[:concept] = get_concept_feature(item.id, query_item.id) / 3
        end
        #puts fts.inspect
      rescue Interrupt
        break
      rescue Exception => e
        error "[search_by_item] Error in #{query_item} -> #{item}", e
        next
      end#begin
      result << fts
    end#each
    
    cache_data([query_item, type, 'result'].join("_"), result) if !o[:no_cache]
    return result
  end
end
