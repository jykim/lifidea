class WeightLearner
  LL_TYPE_DEF = 5
  LS_TYPE_DEF = 0
  
  def initialize()
    
  end
  
  def self.evaluate_sim_search_with(input_data, type, weights, o={})
    result = {}
    #puts weights.inspect
    searcher = SolrSearcher.new
    #debugger
    input_data.each do |ids|
      query, rel = ids[0].to_i, ids[1].to_i
      #puts "Query : #{query} -> Rel : #{rel}"
      #debugger
      rank_list = searcher.search_by_item(query, type, :features=>o[:features], :rows=>200, :weights=>weights).map{|fts|[fts[:id], fts[:score]]}
      #puts rank_list.inspect
      result[query] = Searcher.recip_rank(rank_list, rel)
    end
    [result.values.mean, weights].flatten
  end
  
  def self.evaluate_keyword_search_with(input_data, weights = nil, o={})
    result = {}
    if !$searcher
      $searcher = Searcher.new(o)
      $searcher.load_documents()
    end
    $searcher.parse_rule(o[:rule]) if o[:rule]
    input_data.each do |l|
      o.merge!(:col_scores=>WeightLearner.get_col_scores(l, weights)) if weights
      rank_list = $searcher.search_by_keyword(l[:query], o)
      result[l[:qid]] = Searcher.recip_rank(rank_list, l[:did])
      debug "Q[#{l[:qid]}] #{result[l[:qid]]} (#{o[:rule]} / #{l[:query]} )"
    end
    [result.values.mean, weights].flatten
  end
  
  def self.get_col_scores(input_line, weights)
    $cols.map_hash{|col|
      [col, ($cs_types || Searcher::CS_TYPES).map_with_index{|cs_type,i|input_line[[cs_type, col].join('_').to_sym].to_f * weights[i] }.sum]}
  end
  
  # @param [Array] input_data : parsed csv of input_learner_col*
  def self.evaluate_csel_with(input_data, weights, o={})
    result = {}
    col_scores = []
    input_data.each_with_index do |l,i|
      col_scores[i] = WeightLearner.get_col_scores(l, weights)
      #p values_col.max_pair
      result[l[:qid]] = (l[:itype] == col_scores[i].max_pair[0])? 1.0 : 0.0
    end
    [result.values, weights, col_scores]#.flatten
  end
  
  def self.parse_ranksvm_input(filename)
    IO.read(filename).split("\n").find_all{|l|l =~ /^2/}.map{|l|a = l.scan(/\# (\d+) \-\> (\d+)/)[0]}
  end
  
  def learn_by_ranksvm(input, output)
    cmd = "python anton/SVMWrapper.py -d anton/ -t #{input}#{ENV['train_ratio']}.train -a #{input}#{ENV['train_ratio']}.test -w #{output} -e 1"
    puts "[learner] running: #{cmd}"
    system(cmd)
  end
  
  def learn_by_liblinear(input, output, o={})
    cmd = "#{ENV['PG']}/liblinear/train -s #{o[:ll_type] || LL_TYPE_DEF} #{input}.train #{output}.model"
    puts "[learner] running: #{cmd}" ; system(cmd)
    cmd = "#{ENV['PG']}/liblinear/predict -b 1 #{input}.test  #{output}.model #{output}.output 1> #{output}.result"
    system(cmd)
  end
  
  def learn_by_libsvm(input, output, o={})
    cmd = "#{ENV['PG']}/libsvm/svm-train -b 1 -s #{o[:ls_type] || LS_TYPE_DEF} #{input}.train #{output}.model"
    puts "[learner] running: #{cmd}" ; system(cmd)
    cmd = "#{ENV['PG']}/libsvm/svm-predict -b 1 #{input}.test  #{output}.model #{output}.output 1> #{output}.result"
    system(cmd)
  end
  
  def learn_by_grid_search(input_data, output, type, o = {})
    no_params = o[:features].size
    xvals = (1..no_params).to_a
    yvals = [] ; yvals << [0.5] * xvals.size
    results = []
    
    search_method = GoldenSectionSearchMethod.new(xvals , yvals)
    search_method.search(3) do |xvals , yvals , type , remote|
      #do_retrieval_at(xvals , yvals.map{|e|(e.to_s.scan(/e/).size>0)? 0.0 : e} , $o.merge(:remote_query=>remote))[$opt_for]
      results << case $type
      when /con|doc/ : WeightLearner.evaluate_sim_search_with(input_data, $type, yvals, o)
      when 'csel': WeightLearner.evaluate_csel_with(input_data, yvals, o)
      end
      #puts results.inspect
      #puts "[learn_by_grid_search] perf = #{results[-1][0]} at #{yvals.inspect}"
      results[-1][0]
    end
    results_str = case (o[:grid_type] || 'single')
    when 'single'
      results.sort_by{|e|e[0]}.reverse.map{|l|l.map_with_index{|e,i|[i,e].join(":")}.join(" ")}.join("\n")
    when 'avg'
      max_perf = results.sort_by{|l|l[0]}[-1][0]
      results_str = results.find_all{|l|l[0] == max_perf}.merge_array_by_avg().map_with_index{|e,i|[i,e].join(":")}.join(" ")
    end
    File.open(output, 'w'){|f|f.puts results_str}
  end
end
