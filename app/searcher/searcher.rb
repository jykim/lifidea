class Searcher
  attr_reader :clf
  CON_FEATURES = [:title, :content, :tag, :time, :topic, :string, :cooc, :occur]
  DOC_FEATURES = [:title, :content, :tag, :time, :topic, :path, :concept]
    
  # @param [Array<IR::Index>] cols : target collections
  def initialize(o = {})
    @debug = o[:debug] || false
    $items = {} if !$items
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
  
  # Implement this
  def open_index(o={})
    @clf = cache_data('clf', Searcher.load_features())
    @con_weights = cache_data('con_weights', Searcher.load_weights(CON_FEATURES, 'con', Conf.weight_con))
    @doc_weights = cache_data('doc_weights', Searcher.load_weights(DOC_FEATURES, 'doc', Conf.weight_doc))
  end
  
  def process_request(qtype, query)
    result = case qtype
    when 'k' : search_by_keyword(query)
    when 'c' : search_by_item(query, 'con')
    when 'd' : search_by_item(query, 'doc')
    end
    #puts result.inspect
    #debugger
  end
  
  # Imprement this
  def search_by_keyword(keyword, o = {})
    
  end
  
  # Implement this
  def search_by_item(item, o = {})
    
  end
  
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
      weight_hash = IO.read(read_recent_file_in(RAILS_ROOT+"/data/learner_output", :filter=>/#{ENV['RAILS_ENV']}.*#{type}.*#{rank}/)).
        split("\n")[0].split(" ")[1..-1].map_hash{|e|r = e.split(":") ; [r[0].to_i, r[1].to_f]}
      result = [] ; 1.upto(features.size){|i|result << ((weight_hash[i] && weight_hash[i] > 0) ? weight_hash[i] : 0)}
    rescue Exception => e
      puts "[Searcher.load_weights] error : ", e
    end
    puts "[Searcher.load_weights] #{features.inspect}(#{rank}) = #{result.inspect}"
    result
  end
  
  def self.load_features()
    clf = LinkFeatures.new
    clf.load Link.all.map{|l|[l.ltype, l.out_id.to_i, l.in_id.to_i, l.weight]}
    info "[load_features] done!"
    clf
  end
  
  def self.recip_rank(rank_list, rel)
    #p rank_list,rel
    result = 0.0
    rank_list.each_with_index{|e,i| result = 1.0 / (i+1) if e[0] == rel}
    result
  end
end
