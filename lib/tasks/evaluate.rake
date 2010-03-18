require 'ddl_include'
require 'yard'
#require 'collector/rss_collector_helper'
namespace :evaluate do
  task(:sim_search => :environment) do
    set_type = ENV['set_type'] || 'test'
    input = ENV['input'] || get_learner_input_file()+".#{set_type}"
    output = ENV['output'] || get_evaluation_file($type)
    searcher = SolrSearcher.new
    features = case $type
    when 'con' : Searcher::CON_FEATURES
    when 'doc' : Searcher::DOC_FEATURES
    end
    methods = [features, 'uniform','grid','svm'].flatten
    weights = methods.map{|e|Searcher::load_weights(features, $type, e)}
    weights << ENV['weights'].split(",").map{|e|e.to_f} if ENV['weights']
    result_all = []
    WeightLearner.parse_ranksvm_input(input).each do |ids|
      result = [] ; query, rel = ids[0].to_i, ids[1].to_i
      #puts "Query : #{query} -> Rel : #{rel}"
      #debugger
      weights.each_with_index do |weight,i|
        rank_list = searcher.search_by_item(query, $type, :weights=>weight).map{|fts|[fts[:id], fts[:score]]}
        recip_rank = 0 ; rank_list.each_with_index{|e,i|recip_rank = 1.0 / (i+1) if e[0] == rel}
        result << recip_rank
      end
      result_all << [query, result].flatten
    end
    result_all << ["summary(#$type/#{set_type})", (1..(weights.size)).map{|e|result_all.map{|e2|e2[e]}.mean}].flatten
    write_csv(output, result_all, :mode=>'a', :header=>["query", methods].flatten)
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
      case $type
      when 'csel': Rake::Task['export:csel_features'].execute
      when /con|doc/ : Rake::Task['export:sim_features'].execute
      end
      Rake::Task['etc:split_file'].execute
      1.upto(ENV['folds'].to_i) do |i|
        puts "====== Starting #{i}th fold ======="
        ENV['fold'] = i.to_s
        $fold = "-k#{ENV['folds']}-#{ENV['fold']}"
        ['grid','ranksvm'].each do |method|#'ranksvm','grid','liblinear'
          $method = method
          Rake::Task['run:learner'].execute
        end
        ENV['set_type'] = 'test'
        case $type
        when 'con'
          Rake::Task['evaluate:sim_search'].execute # evaluate at test set
        when 'csel'
          #ENV['set_type'] = 'train'
          #Rake::Task['evaluate:csel_combs'].execute
          Rake::Task['evaluate:csel_combs'].execute # evaluate at test set
        end
      end
    end
    
    def learn_weights(input_data, weights, o = {})
      learner = WeightLearner.new
      learner.learn_by_grid_search(input_data, weights, $type, :grid_type=>ENV['grid_type'])
      weight_values = Searcher.load_weights(RubySearcher::CS_TYPES || $cs_types, 'grid')
    end
    
    desc "Leave one feature out"
    task :leave_one_out => :environment do
      ENV['method'] = 'grid'
      input = ENV['input'] || get_feature_file()
      weight_file = ENV['weights'] || get_learner_output_file($method)
      output = ENV['output'] || get_evaluation_file('leave_one_out')
      result_csel = [WeightLearner.evaluate_csel_with(read_csv(input), learn_weights(read_csv(input), weight_file))[0].mean]
      puts "result(all) : #{result_csel}"
      RubySearcher::CS_TYPES.each_with_index do |e,i|
        $cs_types = RubySearcher::CS_TYPES.dup ; $cs_types.delete_at(i)
        weight_values = learn_weights(read_csv(input), weight_file)
        result_csel << WeightLearner.evaluate_csel_with(read_csv(input), weight_values)[0].mean
      end
      write_csv output, [result_csel], :header=>['all', RubySearcher::CS_TYPES].flatten
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
    
    desc "Learner parameter of liblinear"
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
