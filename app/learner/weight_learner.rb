class WeightLearner
  def initialize()
    
  end
  
  def self.evaluate_sim_search_with(input_data, weights, o={})
    result = {}
    if !$index
      searcher = Searcher.new
      searcher.load_concepts() ; $index = searcher.cons
    end
    #debugger
    input_data.each do |ids|
      query, rel = ids[0].to_i, ids[1].to_i
      #puts "Query : #{query} -> Rel : #{rel}"
      #debugger
      rank_list = $index.find_similar(query, :weights=>weights)
      result[query] = Searcher.recip_rank(rank_list, rel)
    end
    [result.values.mean, weights].flatten
  end
  
  def self.evaluate_keyword_search_with(input_data, weights = nil, o={})
    result = {}
    if !$searcher
      $searcher = Searcher.new
      $searcher.load_documents()
    end
    input_data.each do |l|
      #puts "Query : #{l[:query]}"
      o.merge!(:col_scores=>WeightLearner.get_col_scores(l, weights)) if weights
      rank_list = $searcher.search_by_keyword(l[:query], o)
      result[l[:qid]] = Searcher.recip_rank(rank_list, l[:did])
    end
    [result.values.mean, weights].flatten
  end
  
  def self.get_col_scores(input_line, weights)
    $cols.map_hash{|col|
      [col, Searcher::CS_TYPES.map_with_index{|cs_type,i|input_line[[cs_type, col].join('_').to_sym].to_f * weights[i] }.sum]}
  end
  
  # @param [Array] input_data : parsed csv of input_learner_col*
  def self.evaluate_csel_with(input_data, weights, o={})
    result = {}
    input_data.each do |l|
      col_scores = WeightLearner.get_col_scores(l, weights)
      #p values_col.max_pair
      result[l[:qid]] = (l[:itype] == col_scores.max_pair[0])? 1.0 : 0.0
    end
    [result.values.mean, weights].flatten
  end
  
  def self.parse_svmrank_input(filename)
    IO.read(input+'.train').split("\n").find_all{|l|l =~ /^2/}.map{|l|a = l.scan(/\# (\d+) \-\> (\d+)/)[0]}
  end
  
  def learn_by_svmrank(input, output)
    cmd = "python anton/SVMWrapper.py -d anton/ -t #{input}.train -a #{input}.test -w #{output} -e 1"
    puts "[learner] running: #{cmd}"
    system(cmd)
  end
  
  def learn_by_grid_search(input, output, type, o = {})
    no_params = case $type
    when 'con' : Searcher::FEATURES.size
    when 'col' : Searcher::CS_TYPES.size
    else
      error("[learn_by_grid_search] no type parameter!")
      return nil
    end
    xvals = (1..no_params).to_a
    yvals = [] ; yvals << [0.5] * xvals.size
    results = []
    input_data = case $type
    when 'con' : self.parse_svmrank_input(input+'.train')
    when 'col' : read_csv(input+'.train')
    end
    
    search_method = GoldenSectionSearchMethod.new(xvals , yvals)
    search_method.search(3) do |xvals , yvals , type , remote|
      #do_retrieval_at(xvals , yvals.map{|e|(e.to_s.scan(/e/).size>0)? 0.0 : e} , $o.merge(:remote_query=>remote))[$opt_for]
      results << case $type
      when 'con' : WeightLearner.evaluate_sim_search_with(input_data, yvals)
      when 'col' : WeightLearner.evaluate_csel_with(input_data, yvals)
      end
      #puts results.inspect
      puts "[learn_by_grid_search] perf = #{results[-1][0]} at #{yvals.inspect}"
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
