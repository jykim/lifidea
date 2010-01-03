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
    WrightLearner.parse_svmrank_input(input).each do |ids|
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
  task :col_select_features => :environment do
    in_filename = ENV['filename'] || get_feature_file()
    out_filename = ENV['out_filename'] || get_evaluation_file()
    result_all = []
    read_csv(in_filename).each do |l|
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
    write_csv out_filename, result_all, :summary=>["summary", [nil]*6, [:sum]*Searcher::CS_TYPES.size].flatten, 
      :mode=>'a', :header=>["qid","query","user","date","position", "did", "itype",Searcher::CS_TYPES].flatten
  end
  
  desc "Calculate Combination Result"
  task :col_select_combs => :environment do
    in_filename = ENV['filename'] || get_learner_input_file()+'.'+ENV['set_type']
    out_filename = ENV['out_filename'] || get_evaluation_file()
    methods = [Searcher::CS_TYPES, Searcher::CS_COMB_TYPES].flatten
    input_data = read_csv(in_filename)
    result = methods.map{|e|WeightLearner.evaluate_col_select_with(input_data, Searcher.load_weights(Searcher::CS_TYPES, e))[0]}
    write_csv out_filename, [result], :mode=>'a', :header=>methods
  end

  desc "Get Features"
  task :csel_features_batch => :environment do
    [0.00000001, 0.000000001].each do |min_prob|
      $min_prob = min_prob
      Rake::Task['export:csel_features'].execute
      Rake::Task['etc:csel:evaluate_features'].execute
    end      
    [0.1,0.3,0.5,0.7,0.9].each do |mp_smt|
      $mp_smt = mp_smt
      Rake::Task['export:csel_features'].execute
      Rake::Task['etc:csel:evaluate_features'].execute
    end
  end
end