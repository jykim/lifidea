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
    File.open(filename+'.train','w'){|f|f.puts o[:header] ;f.puts result_train.join}
    File.open(filename+'.test' ,'w'){|f|f.puts o[:header] ;f.puts result_test.join}
  end
  
  desc "Split Input file into Train & Test"
  task(:split_file => :environment) do
    filename = ENV['input'] || get_feature_file()
    puts "Splitting #{filename}..."
    header = nil
    data = case ENV['method']
    when 'svmrank' : IO.read(filename).split(/^(?=2)/)
    when 'grid'
      content = IO.read(filename).split(/^/)
      header = content[0]
      content[1..-1]
    else
      error "[split_file] No parameter specified!"
    end
    error "[split_file] Data is blank!" if data.blank?
    if ENV['train_ratio'] 
      train_ratio = ENV['train_ratio'].to_f
      split_file(filename, data, :train_ratio=>train_ratio)
    elsif ENV['folds']
      test_sets=(0..data.size).to_a.shuffle.in_groups_of((data.size.to_f / ENV['folds'].to_f).ceil)
      #p test_sets
      1.upto(ENV['folds'].to_i) do |i|
        puts "#{test_sets[i-1].size} / #{data.size}"
        $fold = "-k#{ENV['folds']}-#{i}"
        split_file(get_learner_input_file(), data, :header=>header, :test_set=>test_sets[i-1])
      end
    else
      error "[split_file] No parameter specified!"
    end
  end
  
  task(:evaluate_cval) do
    case $type
    when 'col' : Rake::Task['export:col_features'].execute
    #when 'con' : Rake::Task['export:concept_features'].execute
    end
    Rake::Task['etc:split_file'].execute
    1.upto(ENV['folds'].to_i) do |i|
      puts "====== Starting #{i}th fold ======="
      ENV['fold'] = i.to_s
      ENV['output'] = get_evaluation_file()
      Rake::Task['etc:learn_and_evaluate'].execute
    end
  end
  
  desc "Run Learner to Train Weights"
  task(:learn_and_evaluate => :environment) do
    $fold = "-k#{ENV['folds']}-#{ENV['fold']}"
    ['svmrank','grid'].each do |method|
      next if ENV['method'] && ENV['method'] != method
      $method = method
      Rake::Task['run:learner'].execute
    end
    case $type
    when 'con'
    when 'col'
      ENV['set_type'] = 'train'
      Rake::Task['evaluate:col_select_combs'].execute
      ENV['set_type'] = 'test'
      Rake::Task['evaluate:col_select_combs'].execute # evaluate at test set
    end
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
