class Searcher
  attr_reader :clf
  CON_FEATURES = [:title, :content, :time, :string, :cooc, :occur]
  DOC_FEATURES = [:title, :content, :time, :topic, :path, :type, :concept]
    
  # Initialize cache / index
  # - cache link feature values 
  # - cache feature weights
  def initialize(o = {})
    @debug = o[:debug] || false
    $items = {} if !$items
    @cv = ContextVector.new
    if !cache_data("exists")
      #debugger
      open_index()
      cache_data("exists", "true")
      error "[init_controller] searcher initializd..."
    else
      @clf = cache_data('clf')
      @con_weights = cache_data('con_weights')
      @doc_weights = cache_data('doc_weights')
    end
  end
  
  # Prepare index for searching
  def open_index(o={})
    @clf = cache_data('clf', Searcher.load_features())
    @con_weights = cache_data('con_weights', Searcher.load_weights(CON_FEATURES, 'con', Conf.weight_con))
    @doc_weights = cache_data('doc_weights', Searcher.load_weights(DOC_FEATURES, 'doc', Conf.weight_doc))
  end
  
  def process_request(query, qtype, o = {})
    result = case qtype
    when 'kwd' : search_by_keyword(query, o)
    when /con|doc/
      if o['feedback']
        search_by_item_with_feedback(query, qtype, o)
      elsif o['context']
        search_by_item_with_context(query, qtype, o)
      else
        search_by_item(query, qtype, o.merge(:add_context=>true))
      end
    end
  end
  
  # (stub) Keyword Search
  def search_by_keyword(keyword, o = {})
    
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
    debug "#{features.inspect} = #{weights.inspect}"
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

  
  # Load feature weights from data/learner_output
  # - feature set should match with the weight file format
  # @param <String> features : feature set used
  # @param <String> type : search type (doc / con)
  # @param <String> rank : weighting scheme used (default : uniform)
  def self.load_weights(features, type, rank = 'uniform')
    result = [0] * features.size
    rank ||= ENV['rank']
    if features.include?(rank)
      features.each_with_index{|e,i|result[i] = 1 if e == rank}
      return result
    elsif rank == 'uniform'
      return [1] * features.size 
    end
    
    begin
      weight_file = self.read_recent_file_in(Rails.root.join("data/learner_output"), :filter=>/#{ENV['RAILS_ENV']}.*#{type}.*#{rank}/)
      weight_hash = IO.read(weight_file).
        split("\n")[0].split(" ")[1..-1].map_hash{|e|r = e.split(":") ; [r[0].to_i, r[1].to_f]}
      result = [] ; 1.upto(features.size){|i|result << ((weight_hash[i] && weight_hash[i] > 0) ? weight_hash[i] : 0)}
    rescue Exception => e
      error "[Searcher.load_weights] error in file [#{weight_file}] ", e
    end
    debug "[Searcher.load_weights] #{features.inspect}(#{rank}) = #{result.inspect}"
    result
  end
  
  def self.read_recent_file_in(path, o = {})
    file = find_in_path(path, o).map{|e|[e,File.new(e).mtime]}.sort_by{|e|e[1]}[-1]
    puts "[read_recent_file_in] #{o[:filter]} #{file.inspect}"
    file[0]
  end
  
  # Load link & occurrence table to memory
  def self.load_features()
    clf = LinkFeatures.new
    clf.load Link.all.map{|l|[l.ltype, l.out_id.to_i, l.in_id.to_i, l.weight]}
    #clf.load Occurrence.all.map{|l|['s', l.tag_id.to_i, l.item_id.to_i, 1]}, :force=>true
    info "[load_features] done!"
    clf
  end
  
  # Calculate Indirect Concept Similarity
  def get_concept_feature(doc1, doc2)
    result = []
    @clf.read_links('e',doc1).each do |k,v|
      @clf.read_links('e',doc2).each do |k2,v2|
        if k == k2 
          result << 3 * v * v2
        else
          result << @clf.read('k',k,k2) * v * v2
        end
      end
    end
    #p result
    result.mean
  end
  
  # Get tag or concept overlap feature
  def get_overlap_feature(ltype, item1, item2)
    @clf.read_links(ltype, item1.id).keys.overlap(@clf.read_links(ltype, item2.id).keys)
  end
end
