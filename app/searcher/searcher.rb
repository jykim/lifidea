class Searcher
  attr_accessor :cv
  include LearnerHandler
  DISCOUNT_FACTOR = 7
    
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
      debug "[Searcher#new] searcher initializd..."
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
      if o['feedback'] || o[:subtype] == 'feedback'
        search_by_item_with_feedback(query, qtype, o)
      elsif o['context'] || o[:subtype] == 'context'
        search_by_item_with_context(query, qtype, o)
      else
        search_by_item(query, qtype, o)
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
    when 'con' : features, weights = (o[:features] || CON_FEATURES), (o[:weights] || @con_weights)
    when 'doc' : features, weights = (o[:features] || DOC_FEATURES), (o[:weights] || @doc_weights)
    else 
      error "[search_by_item] no type parameter!" ; return nil
    end
    #debug "[search_by_item] Item : #{item} #{features.inspect} = #{weights.inspect}"
    result = calc_sim_features(query_item, type, o)
    #debugger
    final_result = result.sort_by{|fts|
      fts[:score] = features.map_with_index{|e,i|(fts[e]||0.0) * weights[i]}.sum
    }.reverse
    @cv.add(:type=>type, :query=>query_item.title, :created_at=>(o[:created_at] || Time.now), :history_id=>o[:history_id], :result=>final_result) if o[:add_context]
    #puts "[search_by_item] #{item} - #{final_result[0][:id]} : #{final_result[0][:score]}"
    final_result
  end
  
  # Search items with pseudo-relevance feedback
  # @param [Array] :feedback_weights
  def search_by_item_with_feedback(item, type, o={})
    o[:feedback_weights] ||= [0.2]*5
    initial_result = search_by_item(item, type, o)
    final_result = initial_result.map_hash{|e|[e[:id], e[:score]]}
    initial_result.each_with_index do |row,i|
      break if !o[:feedback_weights][i]
      result = search_by_item(row[:id], type, o).map_hash{|e|[e[:id], e[:score]]}
      final_result = final_result.sum_prob(result.times(o[:feedback_weights][i] / DISCOUNT_FACTOR))
    end
    final_result.map{|k,v|{:id=>k, :score=>v}}.sort_by{|e|e[:score]}.reverse
  end
  
  # Search items using the context vector
  def search_by_item_with_context(item, type, o={})
    o[:context_weights] ||= [0.2]*5
    initial_result = search_by_item(item, type, o)
    final_result = initial_result.map_hash{|e|[e[:id], e[:score]]}
    debug "[search_by_item_with_context] Target : #{item} (#{o[:history_id]})"
    #debugger
    (@cv.get(o[:history_id].to_i) || []).reverse.each_with_index do |row,i|
      break if !o[:context_weights][i]
      debug "  | context : #{row[:query]}"
      result = row[:result].map_hash{|e|[e[:id], e[:score]]}
      final_result = final_result.sum_prob(result.times(o[:context_weights][i] / DISCOUNT_FACTOR))
    end
    final_result.map{|k,v|{:id=>k, :score=>v}}.sort_by{|e|e[:score]}.reverse
  end
  
  # Load feature weights from data/learner_output
  # - feature set should match with the weight file format
  # @param <String> features : feature set used
  # @param <String> type : search type (doc / con)
  # @param <String> method : weighting scheme used
  # @param <String> subtype : variation of ranking method
  def self.load_weights(features, type, method = 'uniform', subtype = 'none')
    result = [0] * features.size
    if features.include?(method)
      features.each_with_index{|e,i|result[i] = 1 if e == method}
      return result
    elsif method == 'uniform'
      return [1] * features.size 
    end
    
    begin
      filename_filter = /#{ENV['RAILS_ENV']}.*#{type}.*#{method}.*#{subtype}/
      weight_file = read_recent_file_in(Rails.root.join("data/learner_output"), :filter=>filename_filter)
      weight_hash = IO.read(weight_file).
        split("\n")[0].split(" ")[1..-1].map_hash{|e|r = e.split(":") ; [r[0].to_i, r[1].to_f]}
      result = [] ; 1.upto(features.size){|i|result << ((weight_hash[i] && weight_hash[i] > 0) ? weight_hash[i] : 0.0)}
    rescue Exception => e
      error "[Searcher.load_weights] error in file [#{weight_file}] filter [#{filename_filter}]", e
    end
    error "[Searcher.load_weights] #{features.inspect}(#{(weight_file)? File.basename(weight_file) : weight_file}) = #{result.map{|e|e.to_f.r3}.inspect}"
    result
  end
  
  # Load link & occurrence table to memory
  def self.load_features()
    clf = LinkFeatures.new
    clf.load Link.all.map{|l|[l.ltype, l.out_id.to_i, l.in_id.to_i, l.weight]}
    #clf.load Occurrence.all.map{|l|['s', l.tag_id.to_i, l.item_id.to_i, 1]}, :force=>true
    info "[load_features] done!"
    clf
  end
end
