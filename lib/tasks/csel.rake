require 'ddl_include'
namespace :csel do
  desc "Export Training Data for Collection Selection"
  task :csel_features => :environment do
    filename = ENV['filename'] || "data/csel_#$renv-#$min_prob-#$mp_smt.csv"
    if !$searcher
      $searcher = Searcher.new(:debug=>ENV['debug'])
      $searcher.load_documents()
    end
    result_all = []
    queries_all = Query.between($start_at, $end_at).all.find_all{|q|q.item}
    queries_valid = Query.valid.between($start_at, $end_at).all
    col_qlm = queries_all.group_by{|q|q.item.itype}.map_hash{|k,v|[k , LanguageModel.new(v.map{|q|q.query_text}.join(" "))]}
    debug col_qlm.inspect.round
    queries_all.each do |q|
      result = [q.id, q.query_text, q.user.uid, q.created_at, q.position, q.item.did, q.item.itype]
      parsed_query = InferenceNetwork.parse_query(q.query_text)
      $searcher.cols.each do |col|
        #debugger
        col_score_opt = {
        :rank_list => $searcher.search_by_keyword(q.query_text, :col=>col.cid, :topk=>100).find_all{|e|col.dhid[e[0]]},
        :qqls=> parsed_query.map{|e|col_qlm[col.cid].prob(e)},
        :cps => parsed_query.map{|e|col.lm.prob(e)},
        :mps => parsed_query.map{|e|col.flm.map_hash{|k,v|[k,v.prob(e)]}},
        :smps => parsed_query.map{|e|col.flm.map_hash{|k,v|[k,(1-($mp_smt||0.1))*v.prob(e)+($mp_smt||0.1)*col.lm.prob(e)]}}} # if v.prob(e) > ($min_prob || Math::MIN_PROB)
        debug col_score_opt.map{|k,v|"[q#{q.id}] #{col.cid}:#{k} #{v.inspect[0..800]}"}.join("\n").round        
        RubySearcher::CS_TYPES.each do |cs_type|
          result << $searcher.score_col(col, parsed_query, cs_type, col_score_opt)
          debug("[q#{q.id}] #{col.cid}:#{cs_type} / #{q.query_text} / #{result[-1]}".round)
        end
      end
      result_all << result
    end
    header_features = $searcher.cols.map{|e|RubySearcher::CS_TYPES.map{|e2|[e2.to_s,e.cid].join("_")}}
    write_csv filename, result_all, :normalize=>[[nil]*7, [:minmax]*RubySearcher::CS_TYPES.size*$searcher.cols.size].flatten, 
      :header=>["qid","query","user","date","position", "did", "itype", header_features].flatten
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
      results = Evaluator.evaluate_csel_with(input_data, weights)
      #Intermediate Output
      File.open(output+".#{e}.result","w"){|f|f.puts results[2][0].keys.join("\t")+"\n"+results[2].map{|e|e.values.join("\t")}.join("\n")}
      result_csel << results[0].mean
      #result_ret  << Learner.evaluate_keyword_search_with(input_data, weights)[0]
    end
    write_csv output, [result_csel, result_ret] ,:mode=>'w', :header=>methods
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
end