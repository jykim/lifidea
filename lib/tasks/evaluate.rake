require 'ddl_include'
#require 'yard'
#require 'collector/rss_collector_helper'
namespace :evaluate do
  task(:sim_search => :environment) do
    set_type = ENV['set_type'] || 'test'
    input = ENV['input'] || get_learner_input_file()+"#{ENV['train_ratio']}.#{set_type}"
    output = ENV['output'] || get_evaluation_file(ENV['eval_type'] || $type)
    searcher = SolrSearcher.new
    features = get_features_by_type(ENV['type'], ENV['omit'])
    methods = if ENV['omit']
       ['uniform','grid','svm']
    else
      [features, 'uniform','grid','svm'].flatten
    end
    weights = methods.map{|e|Searcher::load_weights(features, $type, e)}
    weights << ENV['weights'].split(",").map{|e|e.to_f} if ENV['weights']
    result_all = []
    WeightLearner.parse_ranksvm_input(input).each do |ids|
      result = [] ; query, rel = ids[0].to_i, ids[1].to_i
      #puts "Query : #{query} -> Rel : #{rel}"
      #debugger
      weights.each_with_index do |weight,i|
        rank_list = searcher.search_by_item(query, $type, :features=>features, :weights=>weight).map{|fts|[fts[:id], fts[:score]]}
        #puts rank_list.size if i == 0
        recip_rank = 0 ; rank_list.each_with_index{|e,i|recip_rank = 1.0 / (i+1) if e[0] == rel}
        result << recip_rank
      end
      result_all << [query, result].flatten if result[0] > 0 # use only entries where relevant items were found
    end
    average = (1..(weights.size)).map{|e|result_all.map{|e2|e2[e]}.mean}
    result_all << ["summary(#$type/#{set_type})", average].flatten #if average[0] > 0
    write_csv(output, result_all,  :header=>["query", methods].flatten) #:mode=>'a',
  end
  
  desc "Calculate Single-feature Result"
  task :csel_features => :environment do
    input = ENV['filename'] || get_feature_file()
    output = ENV['output'] || get_evaluation_file('col_features')
    result_all = []
    read_csv(input).each do |l|
      result = [l[:qid], l[:query], l[:user], l[:date], l[:position], l[:did], l[:itype]]
      values_cs_type = l.find_all{|k,v|k.to_s=~/_/}.group_by{|e|e[0].to_s.split("_")[0]}
      #debugger
      RubySearcher::CS_TYPES.each do |cs_type|
        #p values_cs_type[cs_type.to_s]
        col_scores = values_cs_type[cs_type.to_s].sort_by{|e|e[1].to_f}
        if col_scores[-1][1] == col_scores[-2][1]
          #warn "[]"
          result << "x"
        else
          itype = col_scores[-1][0].to_s.split("_")[1] 
          result << ((itype == l[:itype])? 1 : itype)
        end
      end
      result_all << result
    end
    #puts result_all.map{|e|e.join(" ")}.join("\n")
    write_csv output, result_all, :summary=>["summary", [nil]*6, [:sum]*RubySearcher::CS_TYPES.size].flatten, 
      :mode=>'a', :header=>["qid","query","user","date","position", "did", "itype",RubySearcher::CS_TYPES].flatten
  end
  
  desc "Calculate Combination Result"
  task :csel_combs => :environment do
    input = ENV['input'] || get_learner_input_file()+'.'+ENV['set_type']
    output = ENV['output'] || get_evaluation_file('col_combs')
    methods = [RubySearcher::CS_TYPES, RubySearcher::CS_COMB_TYPES].flatten
    input_data = read_csv(input)
    result_csel, result_ret = [], []
    methods.each do |e|
      weights = Searcher.load_weights(RubySearcher::CS_TYPES, e)
      results = WeightLearner.evaluate_csel_with(input_data, weights)
      #Intermediate Output
      File.open(output+".#{e}.result","w"){|f|f.puts results[2][0].keys.join("\t")+"\n"+results[2].map{|e|e.values.join("\t")}.join("\n")}
      result_csel << results[0].mean
      #result_ret  << WeightLearner.evaluate_keyword_search_with(input_data, weights)[0]
    end
    write_csv output, [result_csel, result_ret] ,:mode=>'w', :header=>methods
  end
  
  namespace :batch do
    task(:cval) do
      unless ENV['skip_export']
        case $type
        when 'csel': Rake::Task['export:csel_features'].execute
        when /con|doc/ : Rake::Task['export:sim_features'].execute
        end
      end
      ENV['eval_type'] = 'cval'
      Rake::Task['etc:split_file'].execute
      1.upto(ENV['folds'].to_i) do |i|
        puts "====== Starting #{i}th fold ======="
        ENV['fold'] = i.to_s
        $fold = "-k#{ENV['folds']}-#{ENV['fold']}"
        ['grid','ranksvm'].each do |method|#'ranksvm','grid','liblinear'
          #next if ENV['method'] && ENV['method'] != method
          $method = method
          Rake::Task['run:learner'].execute
        end
        case $type
        when /con|doc/
          #ENV['set_type'] = 'train'
          #Rake::Task['evaluate:sim_search'].execute # evaluate at test set
          ENV['set_type'] = 'test'
          Rake::Task['evaluate:sim_search'].execute # evaluate at test set
        when 'csel'
          #ENV['set_type'] = 'train'
          #Rake::Task['evaluate:csel_combs'].execute
          Rake::Task['evaluate:csel_combs'].execute # evaluate at test set
        end
      end
    end
    
    def get_input_data(input_file)
      case $type
      when :csel : read_csv(input_file)
      when /con|doc/ : IO.read(input_file).map{|e|e.split(",")}.
        find_all{|l|l[0] == "2"}.map{|e|e[2..3]}#WeightLearner.parse_ranksvm_input(input_file)
      end
    end
    
    # Learn weights using given features 
    def learn_weights(input_data, features, o = {})
      learner = WeightLearner.new
      learner.learn_by_grid_search(input_data, get_learner_output_file($method), $type, :features=>features, :grid_type=>ENV['grid_type'])
      Searcher.load_weights(features, $type, 'grid')
    end
    
    def evaluate_features(input_data, features)
      case $type
      when :csel : [WeightLearner.evaluate_csel_with(input_data[1], learn_weights(input_data[0], features), :features=>features)[0]]
      when /con|doc/ : [WeightLearner.evaluate_sim_search_with(input_data[1], $type, learn_weights(input_data[0], features), :features=>features)[0]]
      end
    end
    
    desc "Leave one feature out"
    task :leave_one_out => :environment do
      #ENV['method'] = 'grid'
      Rake::Task['export:sim_features'].execute if !ENV['skip_export']
      input = ENV['input'] ||= get_feature_file($method)
      output = ENV['output'] || get_evaluation_file('leave_one_out')
      train_ratio = ENV['train_ratio'] || '0.5'
      features = get_features_by_type($type)
      Rake::Task['etc:split_file'].execute
      input_data = [get_input_data(input+"#{train_ratio}.train"), get_input_data(input+"#{train_ratio}.test")]
      puts input_data.inspect
      result_csel = [evaluate_features(input_data, features)]
      puts "result(all) : #{result_csel}"
      features.each_with_index do |e,i|
        cur_features = features.dup ; cur_features.delete_at(i)
        puts "=== #{cur_features.inspect} ==="
        result_csel << evaluate_features(input_data, cur_features)
      end
      write_csv output, [result_csel], :header=>['all', features].flatten
    end
    
    desc "Varying the amount training data"
    task :vary_amt_clicks => :environment do
      Rake::Task['export:sim_features'].execute if !ENV['skip_export']
      ENV['feature_file'] ||= get_feature_file($method)
      split_count = (ENV['split_count'] || 10).to_i
      (0..split_count).to_a.map{|e|e / split_count.to_f}.each do |train_ratio|
        next if train_ratio == 0
        puts "======= TrainRatio : #{train_ratio} ======="
        ENV['train_ratio'] = train_ratio.to_s
        ENV['input'] = ENV['feature_file']
        #debugger
        Rake::Task['etc:split_file'].execute
        ENV['input'] = ENV['feature_file'] #+ ENV['train_ratio']
        ['ranksvm','grid'].each do |method|
          $method = method
          Rake::Task['run:learner'].execute
        end
        $method = 'ranksvm'
        #$remark = train_ratio
        ENV['input'] = ENV['test_file'] || ENV['feature_file']# + 0.8.to_s
        ENV['eval_type'] = 'vary_amt_clicks'
        #ENV['input'] = ENV['feature_file'] + ENV['train_ratio']
        Rake::Task['evaluate:sim_search'].execute
      end
    end

    desc "User-specific feature weights"
    task :personalize => :environment do
      ENV['method'] = 'grid'
      input = ENV['input'] || get_feature_file()
      weight_file = ENV['weights'] || get_learner_output_file($method)
      output = ENV['output'] || get_evaluation_file('personal_weights')
      global_weights = learn_weights(read_csv(input), weight_file)
      result_csel = [['all',WeightLearner.evaluate_csel_with(read_csv(input), global_weights)[0].mean].flatten]
      ['uysal','sjh','youngah','jangwon','ulsanrub'].each do |uid|
        input_data = read_csv(input)
        personal_input_data= input_data.find_all{|e|e[:user] == uid}
        other_input_data = input_data.find_all{|e|e[:user] != uid}[0..personal_input_data.size]
        personal_weights = learn_weights(personal_input_data, weight_file)
        result_csel << [uid, WeightLearner.evaluate_csel_with(personal_input_data, global_weights)[0].mean, 
          WeightLearner.evaluate_csel_with(personal_input_data, personal_weights)[0].mean].flatten
      end
      write_csv output, result_csel, :header=>['uid', 'score', RubySearcher::CS_TYPES.map{|e|"#{e}_weight"}].flatten
    end
    
    desc "Csel Features"
    task :csel_features => :environment do
      [10,25,50,100].each do |topk|
        $topk = topk ; $remark = "topk_#{topk}"
        Rake::Task['export:csel_features'].execute
        Rake::Task['evaluate:csel_features'].execute
      end
      [3,5,10,15].each do |gavg_m|
        $gavg_m = gavg_m ; $remark = "gavg_m_#{gavg_m}"
        Rake::Task['export:csel_features'].execute
        Rake::Task['evaluate:csel_features'].execute
      end
    end
    
    desc "Learner the parameter of liblinear"
    task :learner_params => :environment do
      [0,1,2,3,4,5,6].each do |ll_type|
        puts "=============== TYPE #{ll_type} ==============="
        ENV['ll_type'] = ll_type.to_s
        $method = 'liblinear'
        1.upto(ENV['folds'].to_i) do |i|
          puts "====== Starting #{i}th fold ======="
          ENV['fold'] = i.to_s
          $fold = "-k#{ENV['folds']}-#{ENV['fold']}"
          ENV['input'] = get_learner_input_file($method)
          $remark = "lltype#{ll_type}"
          Rake::Task['run:learner'].execute
          $remark = ""
        end
      end
    end
    
    desc "Keyword Search"
    task :keyword_search do
      input_data = read_csv(ENV['input'] || get_feature_file())
      output = ENV['output'] || get_evaluation_file('keyword_search')
      result = []
      params_jm, params_dir = [0.1,0.3,0.5,0.7,0.9], [50,100,500,1500,3000]
      params_jm.each do |lambda|
        result << WeightLearner.evaluate_keyword_search_with(input_data, nil, :rule=>"method:jm,lambda:#{lambda}")[0]
      end
      params_dir.each do |mu|
        result << WeightLearner.evaluate_keyword_search_with(input_data, nil, :rule=>"method:dirichlet,mu:#{mu}")[0]
      end
      write_csv output, [result], :header=>[params_jm, params_dir].flatten
    end
  end
end
