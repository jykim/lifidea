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
  
  desc "Re-build Index & Links"
  task :rebuild_all => :environment do
    $start_at = "20010101"
    Link.find_all_by_ltype(['o','e','k']).each{|e|e.destroy}
    Rake::Task['run:indexer'].execute
    Rake::Task['sunspot:solr:reindex'].execute
    #Rake::Task['export:topk_concept_features'].execute
  end
  
  desc "Re-calculate Weights using all clicks"
  task :recalc_weights => :environment do
    $start_at = "20010101"
    $method = 'ranksvm'
    Rake::Task['export:sim_features'].execute
    $method = ENV['method']
    ENV['input'] = get_feature_file($method)
    ENV['train_ratio'] = "0.9"
    Rake::Task['etc:split_file'].execute
    Rake::Task['run:learner'].execute
  end
  
  desc "Collection Statistics"
  task :col_stat => :environment do
    $searcher = Searcher.new(:debug=>ENV['debug'])
    $searcher.load_documents()
    $searcher.cols.each do |c|
      puts [c.cid, c.docs.map{|d|d.lm.size}.mean].join("\t")
    end
  end
  
  def split_file(filename, data, o={})
    result_train, result_test = [o[:header]], [o[:header]]
    data.each_with_index do |e,i|
      #puts rand(), train_ratio
      if o[:test_set]
        if !o[:test_set].include?(i)
          if o[:train_ratio] && (o[:random] ? rand() : i.to_f / data.size) > o[:train_ratio].to_f
            next
          else
            result_train << e
          end
        else
          result_test << e
        end
      elsif o[:train_ratio]
        if (o[:random] ? rand() : i.to_f / data.size) > o[:train_ratio].to_f
          result_test << e
        else
          result_train << e
        end
      else
        puts "No parameter specified!"
      end
    end
    File.open(filename+"#{o[:train_ratio]}.train",'w'){|f|f.puts result_train.find_valid.join}
    File.open(filename+"#{o[:train_ratio]}.test" ,'w'){|f|f.puts result_test.find_valid.join}
  end
  
  def conv_file(filename, method)
    col_hash = $cols.map_hash_with_index{|e,i|[e, i+1]}
    result = []
    read_csv(filename,:output=>:array).each_with_index do |l,i|
      rel_col = l[6]
      case method
      when 'liblinear'
        result << [col_hash[rel_col]].concat(l[7..-1].map_with_index{|e,j|[j+1,e].join(":")})
      when 'ranksvm'
        raise DataError, "Col size not consistent! #{l[7..-1].size}!=#{$cols.size * RubySearcher::CS_TYPES.size}" if l[7..-1].size != $cols.size * RubySearcher::CS_TYPES.size
        values_col = l[7..-1].map_with_index{|e,j|[e,j]}.group_by{|e|e[1]/RubySearcher::CS_TYPES.size}
        result.concat values_col.map{|col,features|
          [((col+1 == col_hash[rel_col])? 2 : 1), "qid:#{i+1}", features.map_with_index{|e,j|[j+1,e[0]].join(":")}].flatten
          }.sort_by{|e|e[0]}.reverse
      end
    end
    File.open(filename.gsub(/grid/,method), 'w'){|f|f.puts result.map{|e|e.join(" ")}.join("\n")}
  end
  
  desc "Split Input file into Train & Test"
  task(:split_file => :environment) do
    total_ratio = ENV['total_ratio'] || 1
    filename = ENV['input'] || get_feature_file()
    puts "Splitting #{filename}... (#{ENV['method']})"
    header = nil
    data = case ($method ||= ENV['method'])
    when 'ranksvm' : IO.read(filename).split(/^(?=2)/)
    when 'liblinear' : IO.read(filename).split(/^/)
    when 'grid'
      content = IO.read(filename).split(/^(?=2)/)
      header = content[0]
      content[1..-1]
    else
      error "[split_file] No parameter specified!"
    end
    #debugger
    error "[split_file] Data is blank!" if data.blank?
    if !ENV['folds']
      split_file(filename, data, :train_ratio=>ENV['train_ratio'])
    else
      test_sets=(0...data.size).to_a.shuffle.in_groups_of((data.size.to_f / ENV['folds'].to_f).floor)
      #debugger
      #puts ((0...data.size).to_a - test_sets[0..(ENV['folds'].to_i-1)].flatten)
      ((0...data.size).to_a - test_sets[0...(ENV['folds'].to_i)].flatten).
        each_with_index{|e,i|test_sets[i] << e if e}
      #p test_sets
      1.upto(ENV['folds'].to_i) do |i|
        puts "#{test_sets[i-1].size} / #{data.size}"
        $fold = "-k#{ENV['folds']}-#{i}"
        split_file(get_learner_input_file(), data, 
          :random=>true, :header=>header, :train_ratio=>ENV['train_ratio'], :test_set=>test_sets[i-1])
        if $type == 'csel' && $method == 'grid'
          conv_file(get_learner_input_file()+'.train', 'ranksvm')
          conv_file(get_learner_input_file()+'.test', 'ranksvm')
          conv_file(get_learner_input_file()+'.train', 'liblinear')
          conv_file(get_learner_input_file()+'.test', 'liblinear')
        end
      end
    end
  end
  
  desc "Convert grid feature file"
  task :conv_file => :environment do
    $method ||= ENV['method']
    conv_file(get_feature_file('grid'), $method)
  end
  
  task(:monitor => :environment) do
    require 'daemons/manager.rb'
  end
  
  desc "Profile Indexing"
  task :profiler => :environment do
    require 'ruby-prof'
    RubyProf.start
    #====
    $searcher = Searcher.new(:debug=>ENV['debug'])
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
