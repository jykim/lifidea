require 'ddl_include'
namespace :evaluate do
  task(:sim_search => :environment) do
    $set_type = ENV['set_type'] || 'test'
    input = ENV['input'] || get_learner_input_file() + get_file_postfix()
    output = ENV['output'] || get_evaluation_file($set_type, $type)
    methods = ['uniform','grid','grid.feedback','svm']
    debug "[evaluate:sim_search] output = #{output}"
    Evaluator.export_sim_evaluation_result($type, methods, input, output, :subtype=>$subtype)
  end
  
  namespace :batch do
    task(:cval) do
      if ENV['context']
        @ss = SolrSearcher.new
        @ss.build_context_vector()
      end
      
      if ENV['export']
        case $type
        when 'csel': Rake::Task['export:csel_features'].execute
        when /con|doc/ : Rake::Task['export:sim_features'].execute
        end
      end
      ['grid','ranksvm'].each do |method|#'ranksvm','grid','liblinear'
        $method = method
        Rake::Task['etc:split_file'].execute
      end
      ENV['eval_type'] = 'cval'
      1.upto(ENV['folds'].to_i) do |x|
        puts "====== Starting #{x}th fold ======="
        $fold = "-k#{ENV['folds']}-#{x}"
        ['grid','feedback','ranksvm'].each{|method|#'ranksvm','grid','liblinear'
          ENV['set_type'] = 'train'
          #next if ENV['method'] && ENV['method'] != method
          if method == 'feedback'
            $method = 'grid'
            $subtype = method
          else
            $method = method
            $subtype = 'none'
          end
          Rake::Task['run:learner'].execute
        } if !ENV['skip_learner']
        $method = 'grid'
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
        find_all{|l|l[0] == "2"}.map{|e|e[2..3]}#Learner.parse_ranksvm_input(input_file)
      end
    end
    
    # Learn weights using given features 
    def learn_weights(input_data, features, o = {})
      learner = Learner.new
      learner.learn_by_grid_search(input_data, get_learner_output_file($method), $type, :features=>features, :grid_type=>ENV['grid_type'])
      Searcher.load_weights(features, $type, 'grid')
    end
    
    def evaluate_features(input_data, features)
      case $type
      when :csel : [Evaluator.evaluate_csel_with(input_data[1], learn_weights(input_data[0], features), :features=>features)[0]]
      when /con|doc/ : [Evaluator.evaluate_sim_search_with(input_data[1], $type, learn_weights(input_data[0], features), :features=>features)[0]]
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
      result_csel = [['all',Evaluator.evaluate_csel_with(read_csv(input), global_weights)[0].mean].flatten]
      ['uysal','sjh','youngah','jangwon','ulsanrub'].each do |uid|
        input_data = read_csv(input)
        personal_input_data= input_data.find_all{|e|e[:user] == uid}
        other_input_data = input_data.find_all{|e|e[:user] != uid}[0..personal_input_data.size]
        personal_weights = learn_weights(personal_input_data, weight_file)
        result_csel << [uid, Evaluator.evaluate_csel_with(personal_input_data, global_weights)[0].mean, 
          Evaluator.evaluate_csel_with(personal_input_data, personal_weights)[0].mean].flatten
      end
      write_csv output, result_csel, :header=>['uid', 'score', RubySearcher::CS_TYPES.map{|e|"#{e}_weight"}].flatten
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
    
  end#batch
end#evaluate
