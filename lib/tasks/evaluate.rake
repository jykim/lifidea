require 'ddl_include'
require 'yard'
#require 'collector/rss_collector_helper'
namespace :evaluate do
  task(:sim_search => :environment) do
    set_type = ENV['set_type'] || 'test'
    input = ENV['input'] || get_learner_input_file()+".#{set_type}"
    output = ENV['output'] || "data/evaluation_#{$renv}_#{$today}.csv"
    $searcher = Searcher.new
    $searcher.load_concepts() ; index = $searcher.cons
    methods = [Searcher::FEATURES, 'uniform','grid','svm'].flatten
    weights = methods.map{|e|Searcher::load_weights(Searcher::FEATURES, e)}
    weights << ENV['weights'].split(",").map{|e|e.to_f} if ENV['weights']
    result_all = []
    WrightLearner.parse_ranksvm_input(input).each do |ids|
      result = [] ; query, rel = ids[0].to_i, ids[1].to_i
      #puts "Query : #{query} -> Rel : #{rel}"
      #debugger
      weights.each_with_index do |weight,i|
        rank_list = index.find_similar(query, :weights=>weight)
        recip_rank = 0 ; rank_list.each_with_index{|e,i|recip_rank = 1.0 / (i+1) if e[0] == rel}
        result << recip_rank
      end
      result_all << [query, result].flatten
    end
    result_all << ["summary(#{set_type})", (1..(weights.size)).map{|e|result_all.map{|e2|e2[e]}.mean}].flatten
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
      Searcher::CS_TYPES.each do |cs_type|
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
    write_csv output, result_all, :summary=>["summary", [nil]*6, [:sum]*Searcher::CS_TYPES.size].flatten, 
      :mode=>'a', :header=>["qid","query","user","date","position", "did", "itype",Searcher::CS_TYPES].flatten
  end
  
  desc "Calculate Combination Result"
  task :csel_combs => :environment do
    input = ENV['input'] || get_learner_input_file()+'.'+ENV['set_type']
    output = ENV['output'] || get_evaluation_file('col_combs')
    methods = [Searcher::CS_TYPES, Searcher::CS_COMB_TYPES].flatten
    input_data = read_csv(input)
    result_csel, result_ret = [], []
    methods.each do |e|
      weights = Searcher.load_weights(Searcher::CS_TYPES, e)
      result_csel << WeightLearner.evaluate_csel_with(input_data, weights)[0]
      #result_ret  << WeightLearner.evaluate_keyword_search_with(input_data, weights)[0]
    end
    write_csv output, [result_csel, result_ret] ,:mode=>'a', :header=>methods
  end
  
  namespace :batch do
    task(:cval) do
      case $type
      #when 'csel': Rake::Task['export:csel_features'].execute
      when 'con' : Rake::Task['export:concept_features'].execute
      end
      Rake::Task['etc:split_file'].execute
      1.upto(ENV['folds'].to_i) do |i|
        puts "====== Starting #{i}th fold ======="
        ENV['fold'] = i.to_s
        $fold = "-k#{ENV['folds']}-#{ENV['fold']}"
        ['ranksvm','grid','liblinear'].each do |method|
          $method = method
          Rake::Task['run:learner'].execute
        end
        case $type
        when 'con'
        when 'csel'
          ENV['set_type'] = 'train'
          Rake::Task['evaluate:csel_combs'].execute
          ENV['set_type'] = 'test'
          Rake::Task['evaluate:csel_combs'].execute # evaluate at test set
        end
      end
    end
    
    def learn_with_weights(input, weights, o = {})
      input_data = read_csv(input)
      input_data = input_data.find_all{|e|e[:user] == o[:filter_user]} if o[:filter_user]
      learner = WeightLearner.new
      learner.learn_by_grid_search(input_data, weights, $type, :grid_type=>ENV['grid_type'])
      weight_values = Searcher.load_weights(Searcher::CS_TYPES || $cs_types, 'grid')
      WeightLearner.evaluate_csel_with(input_data, weight_values)
    end
    
    desc "Leave one feature out"
    task :leave_one_out => :environment do
      ENV['method'] = 'grid'
      input = ENV['input'] || get_feature_file()
      weights = ENV['weights'] || get_learner_output_file($method)
      output = ENV['output'] || get_evaluation_file('leave_one_out')
      result_csel = [learn_with_weights(input, weights)]
      Searcher::CS_TYPES.each_with_index do |e,i|
        $cs_types = Searcher::CS_TYPES.dup ; $cs_types.delete_at(i)
        result_csel << learn_with_weights(input, weights)[0]
      end
      write_csv output, [result_csel], :header=>['all', Searcher::CS_TYPES].flatten
    end

    desc "User-specific feature weights"
    task :personal_weights => :environment do
      ENV['method'] = 'grid'
      input = ENV['input'] || get_feature_file()
      weights = ENV['weights'] || get_learner_output_file($method)
      output = ENV['output'] || get_evaluation_file('personal_weights')
      result_csel = [learn_with_weights(input, weights)]
      ['uysal','sjh','youngah','jangwon','ulsanrub'].each do |uid|
        result_csel << [uid,learn_with_weights(input, weights, :filter_user=>uid)].flatten
      end
      write_csv output, result_csel, :header=>['uid', 'score', Searcher::CS_TYPES.map{|e|"#{e}_weight"}].flatten
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