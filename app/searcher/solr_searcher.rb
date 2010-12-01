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
    #debug "[search_by_keyword] query = #{query}"
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
      order_by(:basetime, :desc) if o[:order] == "recency" || query == TEXT_DUMMY
      paginate(:page => o[:page]) if o[:page]
      facet(o[:facet]) if o[:facet]
      without :hidden_flag, '1'
    end
    #debugger
    if o[:facet]
      result.facet(o[:facet]).rows
    else
      @cv.add(:type=>'kwd', :query=>query ,:result=>result.hits.map{|e|{:id=>e.instance.id, :score=>e.score}}) if o[:add_context]
      result
    end
  end
  
  # 
  def calc_df(query, tplus = [], tminus = [])
    #debugger
    splus = tplus.map{|e|"+\"#{e}\""}.join(" ")
    sminus = tminus.map{|e|"-\"#{e}\""}.join(" ")#
    query = "\"#{query} #{splus} #{sminus}\""
    result = Sunspot.search(Item) do
      keywords query
      without :itype_str, Item::ITYPE_CONCEPT
      #tplus.each{|e| with :fulltext, "\"#{e}\""} if tplus
      #tminus.each{|e| without :fulltext, "\"#{e}\""} if tminus
    end
    #debug "[calc_df] #{query} : #{result.total}"
    result.total
  end
  
  # Search items based on similarity
  # - Find target document
  # - Evaluate similarity query
  # @param [int] item : id of item sought for
  # @param [string] type : con(cept) or doc(ument)
  # @param [Array<int>] :working_set : subset of items to run retrieval
  def search_by_item(item, type ,o={})
    query_item = Item.find(item.to_i)
    return nil if !query_item
    case type
    when 'con' : features, weights, filter_qry = (o[:features] || CON_FEATURES), (o[:weights] || @con_weights), solr_filter_concepts()
    when 'doc' : features, weights, filter_qry = (o[:features] || DOC_FEATURES), (o[:weights] || @doc_weights), solr_filter_concepts('-', '&&')
    end
    result = calc_sim_features(query_item, type, o)
    #debugger
    final_result = result.sort_by{|fts|
      fts[:score] = features.map_with_index{|e,i|(fts[e]||0.0) * weights[i]}.sum
    }.reverse
    @cv.add(:type=>type, :query=>query_item.title, :result=>final_result) if o[:add_context]
    #puts "[search_by_item] #{item} - #{final_result[0][:id]} : #{final_result[0][:score]}"
    final_result
  end
  
  # 
  def search_by_item_with_feedback(item, type, o={})
    o[:feedback_weights] ||= [0.2]*5
    initial_result = search_by_item(item, type, o)
    final_result = initial_result.map_hash{|e|[e[:id], e[:score]]}
    initial_result.each_with_index do |row,i|
      break if !o[:feedback_weights][i]
      result = search_by_item(row[:id], type, o).map_hash{|e|[e[:id], e[:score]]}
      final_result = final_result.sum_prob(result.times(o[:feedback_weights][i]))
    end
    final_result.map{|k,v|{:id=>k, :score=>v}}.sort_by{|e|e[:score]}.reverse
  end
  
  # 
  def search_by_item_with_context(item, type, o={})
    o[:context_weights] ||= [0.2]*5
    initial_result = search_by_item(item, type, o)
    final_result = initial_result.map_hash{|e|[e[:id], e[:score]]}
    @cv.get().reverse.each_with_index do |row,i|
      break if !o[:context_weights][i]
      result = row[:result].map_hash{|e|[e[:id], e[:score]]}
      final_result = final_result.sum_prob(result.times(o[:context_weights][i]))
    end
    final_result.map{|k,v|{:id=>k, :score=>v}}.sort_by{|e|e[:score]}.reverse
  end
  
  # Calculate similarity feature values 
  # - Connect to Solr for initial results
  # - Calculate feature values for those results
  # - Cache the results 
  # @param [Bool] :no_cache : disble result cacheing
  # @param [Array<int>] :items : items to be included for scoring
  def calc_sim_features(query_item, type, o={})
    #debugger
    #puts "[calc_sim_features] query_item = #{query_item} #{filter_qry}"
    
    if !o[:no_cache] && Conf.cache && cache_data([query_item.id, type, 'features'].join("_"))
      return cache_data([query_item.id, type, 'features'].join("_"))
    end
    result = []
    query_count = -1
    solr_result = solr_search_by_item(query_item, type, o)
    solr_result.each do |e|
      #
      e["id"] = e["id"].split(" ")[1]
      next if o[:items] && !o[:items].include?(e["id"])
      begin
        item = $items[e["id"].to_i]
        next if item.title == TEXT_DUMMY || item.title.blank?
        #info "[calc_sim_features] == #{item.title} =="
        fts = {:id=>item.id, :content=>(e["score"]/2)}
        #fts[:tag]   = item.tag_titles.overlap(query_item.tag_titles) #get_overlap_feature('s', item, query_item)
        fts[:title] = (item.title || "").word_sim(query_item.title || "")
        fts[:time]  = (item.basetime - query_item.basetime ).normalize_time
        case type
        when 'con'
          both_count, item_count = calc_df(item.title, [query_item.title]), calc_df(item.title)
          query_count = calc_df(query_item.title) if query_count < 0
          #  @clf.read('o', item.id, query_item.id), @clf.read_sum('o', item.id), @clf.read_sum('o', query_item.id)
          fts[:string] = item.did.str_sim(query_item.did)
          #fts[:topic] = @clf.read('t', item.id, query_item.id)
          fts[:cooc]  = Math.overlap(both_count, item_count, query_count)
          fts[:occur] = item_count.to_f.normalize(Item.count_docs)
        when 'doc'
          if item.remark && query_item.remark
            arr1, arr2 = item.remark.split(",").map{|e|e.to_f}, query_item.remark.split(",").map{|e|e.to_f}
            fts[:topic] = arr1.map_with_index{|e,i|e*arr2[i]}.sum
          end
          #fts[:concept] =  get_overlap_feature('e', item, query_item)
          fts[:path] = (item.uri || "").path_sim(query_item.uri || "")
          fts[:type] = (item.itype == query_item.itype)? 0.5 : 0.0
          fts[:concept] = get_concept_feature(item.id, query_item.id) / 3
        end
        if fts.values.find{|e|e.to_f.infinite? || e.to_f.nan?}
          warn "[calc_sim_features] Invalid feature for #{item.title}-#{query_item.title}\n #{fts.inspect}"
          info "[calc_sim_features] both_count, item_count, query_count = #{both_count}, #{item_count}, #{query_count}"
        end
        result << fts
      #rescue Interrupt
      #  break
      rescue Exception => e
        error "[search_by_item] Error in #{query_item} -> #{item}", e
      end#begin
    end#each
    cache_data([query_item.id, type, 'features'].join("_"), result) if !o[:no_cache] && Conf.cache
    return result
  end
  
  # Filter itype from solr search results
  def solr_filter_concepts(prefix = '+', join = ' || ')
    ['query'].map{|e|"#{prefix}itype_text:#{e}"}.join("#{join}")
  end
  
  # Get similarity search result from Solr
  # - cache item fetched from database
  def solr_search_by_item(query_item, type, o={})
    # Filter query results
    if o[:working_set]
      filter_qry = o[:working_set].map{|e|"id_text:#{e}"}.join(" || ") 
    else
      case type
      when 'con' : filter_qry = solr_filter_concepts()
      when 'doc' : filter_qry = solr_filter_concepts('-', '&&')
      end
    end
    
    #debugger
    # Initial Solr Query
    solr = RSolr.connect :url=>Conf.solr_server
    begin
      solr_result = solr.request "/mlt", :q => "id:\"Item #{query_item.id}\"",:fl => "*,score", :fq =>filter_qry , "rows" => (o[:rows] || 50), 
        "mlt.fl" => "title_text,content_text,metadata_text,uri_text,itype_text", "mlt.mintf" => 1, "mlt.mindf" => 5, "mlt.boost"=>true
        
      # Cache results returned
      Item.find(solr_result['response']['docs'].map{|e|e["id"].split(" ")[1]}).
        each{|i| $items[i.id] = cache_data("item_#{i.id}", i)}  
    rescue Exception => e
      error "[search_by_item] Error in Calling Solr", e
      return []
    end
    error "[search_by_item] Nothing returned from Solr!!!" if solr_result['response']['docs'].size == 0
    # Feature Vector generation
    solr_result['response']['docs']
  end
end
