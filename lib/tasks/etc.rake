require 'ddl_include'
require 'yard'
#require 'collector/rss_collector_helper'
namespace :etc do
  desc "Run YARD documentation"
  task(:yard => :environment) do
    YARD::Rake::YardocTask.new do |t|
      t.files   = ['lib/**/*.rb','app/**/*.rb','rubylib/**/*.rb','test/**/*.rb' ]   # optional
      t.options = ['--any', '--extra', '--opts'] # optional
    end
  end
  
  task(:clear_db => :environment) do
    return if !ENV['force'] && ENV['RAILS_ENV'] != 'development'
    Item.destroy_all
    Tag.destroy_all
    Link.destroy_all
    Occurrence.destroy_all
    History.destroy_all
    Query.destroy_all
    History.destroy_all
    Game.destroy_all
  end
  
  def split_file(filename, data, o={})
    result_train, result_test = [], []
    data.each_with_index do |e,i|
      #puts rand(), train_ratio
      if (o[:train_ratio] && rand() < o[:train_ratio]) ||
         (o[:test_set] && !o[:test_set].include?(i))
        result_train << e
      else
        result_test << e
      end
    end
    File.open(filename+'.train','w'){|f|f.puts result_train.join}
    File.open(filename+'.test','w'){|f|f.puts result_test.join}
  end
  
  desc "Split Input file into Train & Test"
  task(:split_file => :environment) do
    filename = ENV['input'] || get_learner_input_file()
    data = IO.read(filename).split(/^(?=2)/)
    if ENV['train_ratio'] 
      train_ratio = ENV['train_ratio'].to_f
      split_file(filename, data, :train_ratio=>train_ratio)
    elsif ENV['folds']
      test_sets=(0..data.size).to_a.shuffle.in_groups_of((data.size.to_f / ENV['folds'].to_f).ceil)
      p test_sets
      1.upto(ENV['folds'].to_i) do |i|
        puts "#{test_sets[i-1].size} / #{data.size}"
        split_file(get_learner_input_file(i), data, :test_set=>test_sets[i-1])
      end
    else
      error "[split_file] No parameter specified!"
    end
  end
  
  task(:evaluate => :environment) do
    set_type = ENV['set_type'] || 'test'
    input = ENV['input'] || get_learner_input_file(ENV['fold'])+".#{set_type}"
    output = ENV['output'] || "data/evaluation_#{$renv}_#{$today}.csv"
    $searcher = Searcher.new
    $searcher.load_concepts() ; index = $searcher.cons
    methods = [Searcher::FEATURES, 'uniform','grid','svm'].flatten
    weights = methods.map{|e|Searcher::load_weights(e)}
    weights << ENV['weights'].split(",").map{|e|e.to_f} if ENV['weights']
    result_all = []
    qrels = IO.read(input).split("\n").find_all{|l|l =~ /^2/}
    qrels.map{|l|l.scan(/\# (\d+) \-\> (\d+)/)[0]}.each do |ids|
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
  
  task(:evaluate_cval) do
    1.upto(ENV['folds'].to_i) do |i|
      puts "====== Starting #{i}th fold ======="
      ENV['fold'] = i.to_s
      $remark = '_' + ENV['remark'] if ENV['remark']
      ENV['output'] = "data/evaluation_#{$renv}_#{$today}#{$remark}_k#{ENV['folds']}-#{ENV['fold']}.csv"
      Rake::Task['etc:learn_and_evaluate'].execute
    end
  end
  
  desc "Run Learner to Train Weights"
  task(:learn_and_evaluate => :environment) do
    #input = ENV['input'] || "data/learner_input_#{$renv}.txt"
    #weights = ENV['weights'] || "data/learner_output_#{$renv}_#{$today}.txt"
    Rake::Task['export:learner_input'].execute if !ENV['fold'] || ENV['fold'].to_i == 1
    ['svm','grid'].each do |method|
      next if ENV['svm_only'] && method != 'svm'
      ENV['method'] = method
      Rake::Task['run:learner'].execute
    end
    ENV['set_type'] = 'train'
    Rake::Task['etc:evaluate'].execute
    ENV['set_type'] = 'test'
    Rake::Task['etc:evaluate'].execute # evaluate at test set
  end
  
  task(:monitor => :environment) do
    require 'daemons/manager.rb'
  end
  
  desc "Profile Indexing"
  task :profiler => :environment do
    require 'ruby-prof'
    RubyProf.start
    #====
    $searcher = Searcher.new(nil, :debug=>ENV['debug'])
    $searcher.load_documents()
    #====
    result = RubyProf.stop
    printer = RubyProf::FlatPrinter.new(result)
    printer.print(STDOUT, 0)
    exit()
  end
  
  desc "Move crawled files into index folder"
  task :move_files do
    ext = ENV['ext'] || pdf
    Dir.mkdir(ext) if !File.exist?(ext)
    target = find_in_path(ENV['src'], :recursion=>true, :filter=>/\.#{ext}$/)
    puts "found #{target.size} files"
    target.each do |e|
      puts cmd = "mv #{e} data/docs/#{ext}/#{e.scan(/\w+/).join("_")}"
      system(cmd)
    end
  end
  
  desc "Expire queries"
  task :expire_queries => :environment do
    docs = Item.find_all_by_query_flag(true)
    process_count = 0
    docs.each do |d|
      query_count = Query.valid_queries(d.id).size
      if query_count > (ENV['threshold'] || 1).to_i
        process_count += 1
        d.update_attributes!(:query_flag=>false) if !ENV['trial']
      end
    end
    puts "#{process_count} docs were processed..."
  end
  
  namespace :csel do
    desc "Calculate Single-feature Result"
    task :evaluate_features => :environment do
      in_filename = ENV['filename'] || "data/csel_#$renv-#$min_prob-#$mp_smt.csv"
      out_filename = ENV['out_filename'] || "data/csel_evaluate_features_#$renv-#$min_prob-#$mp_smt.csv"
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
        :header=>["qid","query","user","date","position", "did", "itype",Searcher::CS_TYPES].flatten
    end

    desc "Get Features"
    task :evaluate_batch => :environment do
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
  
  desc "PD Index Create"
  task :create_index => :environment do
    col_root = ENV['col_root'] || "/Users/lifidea/dev/data/pagehunt/raw/c0002"
    ENV['force'] = "true"
    Rake::Task['etc:clear_db'].execute
    if Source.all().size == 0
      COL_TYPES.each do |col|
        Source.create(:title=>col, :itype=>col, :uri=>"file://#{col_root}/#{col}_doc", 
          :option=>{:trec=>true},:active_flag=>true)
      end
    end
    ENV['repeat'] = "100000"
    Rake::Task['run:collector'].execute
  end
end
