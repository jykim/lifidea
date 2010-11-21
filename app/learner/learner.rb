class Learner
  LL_TYPE_DEF = 5
  LS_TYPE_DEF = 0
  
  def initialize()
    
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
      when /con|doc/ : Evaluator.evaluate_sim_search_with(input_data, $type, yvals, o)
      when 'csel': Evaluator.evaluate_csel_with(input_data, yvals, o)
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
