class WeightLearner
  def initialize()
    
  end
  
  def evaluate_perf_at(qrels, index, weights, o={})
    result = []
    #debugger
    qrels.each do |ids|
      query, rel = ids[0].to_i, ids[1].to_i
      #puts "Query : #{query} -> Rel : #{rel}"
      #debugger
      rank_list = index.find_similar(query, :weights=>weights)
      recip_rank = 0 ; rank_list.each_with_index{|e,i|recip_rank = 1.0 / (i+1) if e[0] == rel}
      result << recip_rank
    end
    puts "[evaluate_perf_at] perf = #{result.mean} at #{weights.inspect}"
    [result.mean, weights].flatten
  end
  
  def learn_by_svm(input, output)
    cmd = "python anton/SVMWrapper.py -d anton/ -t #{input}.train -a #{input}.test -w #{output} -e 1"
    puts "[learner] running: #{cmd}"
    system(cmd)
  end
  
  def learn_by_grid_search(input, output)
      searcher = Searcher.new
      searcher.load_concepts() ; $index = searcher.cons

      $qrels = IO.read(input+'.train').split("\n").find_all{|l|l =~ /^2/}
      $qrels = $qrels.map{|l|l.scan(/\# (\d+) \-\> (\d+)/)[0]}

      xvals = (1..Searcher::FEATURES.size).to_a
      yvals = [] ; yvals << [0.5] * xvals.size
      results = []
      search_method = GoldenSectionSearchMethod.new(xvals , yvals)
      search_method.search(3) do |xvals , yvals , type , remote|
        #do_retrieval_at(xvals , yvals.map{|e|(e.to_s.scan(/e/).size>0)? 0.0 : e} , $o.merge(:remote_query=>remote))[$opt_for]
        results << evaluate_perf_at($qrels, $index, yvals)
        #puts results.inspect
        results[-1][0]
      end
      #results_str = results.sort_by{|e|e[0]}.reverse.map{|l|l.map_with_index{|e,i|[i,e].join(":")}.join(" ")}.join("\n")
      max_perf = results.sort_by{|l|l[0]}[-1][0]
      results_str = results.find_all{|l|l[0] == max_perf}.merge_array_by_avg().map_with_index{|e,i|[i,e].join(":")}.join(" ")
      File.open(output, 'w'){|f|f.puts results_str}
  end
end