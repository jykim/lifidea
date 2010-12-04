class Learner
  LL_TYPE_DEF = 5
  LS_TYPE_DEF = 0
  
  def initialize()
    
  end
  
  # Run learner
  def learn(type, method, input, output)
    case method
    when 'ranksvm' : learn_by_ranksvm(input, output)
    when 'liblinear' : learn_by_liblinear(input, output, :ll_type=>ENV['ll_type'])
    when 'libsvm' : learn_by_libsvm(input, output, :ls_type=>ENV['ls_type'])
    when 'grid'
      input_data = read_csv(input)#+"#{ENV['train_ratio']}.train")
      learn_by_grid_search(input_data, output, type, 
        :features=>Learner.get_features_by_type(type, ENV['omit']), :grid_type=>ENV['grid_type'])
    else
      puts "[learner] No method selected!"
    end
  end
  
  def self.get_features_by_type(type, omit = nil)
    result = case type
    when 'con' : Searcher::CON_FEATURES
    when 'doc' : Searcher::DOC_FEATURES
    when 'csel' : RubySearcher::CS_TYPES
    end
    if omit
      result_new = result.dup ; result_new.delete_at(omit.to_i-1)
    else
      result_new = result
    end
    #puts "[get_features_by_type] features = #{result_new.inspect}"
    result_new
  end
  
  # @deprecated
  def self.parse_ranksvm_input(filename)
    IO.read(filename).split("\n").find_all{|l|l =~ /^2/}.map{|l|a = l.scan(/\# (\d+) \-\> (\d+)/)[0]}
  end
  
  def learn_by_ranksvm(input, output)
    cmd = "python #{Conf.path_ranksvm}/SVMWrapper.py -d #{Conf.path_ranksvm} -t #{input} -a #{input} -w #{output} -e 1"
    debug "[learner] running: #{cmd}"
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
  
  # @param <Array> : input_data (same as evaluate_sim_search_with)
  # @param <String> output : output file
  # @return <Array> : 
  def learn_by_grid_search(input_data, output, type, o = {})
    no_params = o[:features].size
    xvals = (1..no_params).to_a
    yvals = [] ; yvals << [0.5] * xvals.size
    results = []
    
    search_method = GoldenSectionSearchMethod.new(xvals , yvals)
    search_method.search(3) do |xvals , yvals , train , remote|
      results << case type
      when /con|doc/ : Evaluator.evaluate_sim_search_with(input_data.find_all{|e|e[:pref] == '2'}, type, yvals, o)
      when 'csel': Evaluator.evaluate_csel_with(input_data, yvals, o)
      end
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
    info "[learn_by_grid_search] max(MRR) = #{results.sort_by{|e|e[0]}[-1][0]}"
    results
  end
end
