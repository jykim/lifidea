require 'task_include'
require 'collector/collector_runner'
require 'batch_job_handler'

namespace :run do
  desc "Run collector"
  task(:collector => :environment) do
    repeat = ENV['repeat'] || 1
    puts "Repeat #{repeat} times..."
    1.upto(repeat.to_i) do |i|
      begin
        count = run_collector(ENV.to_hash.symbolize_keys)
        #puts count
      rescue Exception => e
        error "[run:collector] error",e
      end
      break if count == 0
    end
  end
  
  namespace :metadata do
    desc "Run metadata updator"
    task(:updater => :environment) do
      info "From #{$start_at} ~ #{$end_at}"
      Item.documents.between($start_at, $end_at).each do |doc|
        next if ENV['itype'] && ENV['itype'] != doc.itype
        next if ENV['did'] && ENV['did'] != doc.did
        info "Processing #{doc}"
        doc.process_all()
        doc.save!
      end    
    end

    desc "Run metadata validator"
    task(:validator => :environment) do
      Item.documents.between($start_at, $end_at).each do |doc|
        #info "Processing #{doc}"
        begin
          doc.validate_metadata
        rescue Exception => e
          error "[run:metadata:validator] error in #{doc.did}", e
        end          
      end
    end#task
  end#namespace
  
  task(:indexer => :environment) do
    item_set = if ENV['id']
      doc = Item.find(ENV['id'])  
      return "No item! (#{ENV['id']})" if !doc
      [doc]
    elsif ENV['skip_to']
      Item.valid.between($start_at, $end_at).skip_to(ENV['skip_to'].to_i).all
    else
      Item.valid.between($start_at, $end_at).all
    end
    #debugger
    $idx = Indexer.new
    puts 'Indexing Documents'
    $idx.index_item_set(item_set.find_all{|i|!i.concept?}, :download=>ENV['download']) if !ENV['concept_only']
    puts 'Indexing Concepts'
    $idx.index_item_set(item_set.find_all{|i|i.concept?}, :download=>ENV['download']) if !ENV['document_only']
  end
  
  desc "Run Learner to Train Weights"
  task(:learner => :environment) do
    input = ENV['input'] || get_learner_input_file(ENV['fold'])
    #puts input
    weights = ENV['weights'] || get_learner_output_file(ENV['method'], ENV['fold'])
    learner = WeightLearner.new
    case ENV['method']
    when 'svm' : learner.learn_by_svm(input, weights)
    when 'grid' : learner.learn_by_grid_search(input, weights)
    end
  end
  
  desc "PageHunt Indexer"
  task :ph_indexer do
    while(true) do
      $idx ||= Indexer.new
      all_docs = $idx.find_target_documents
      if all_docs.size == 0
        debug "[indexer.rb] No target document!"
        exit
      end
      warn "[indexer.rb] Started indexing #{all_docs.size} docs"
      # @TODO substitute with batch finder
      all_docs.in_groups_of(FileCollector::FILES_IN_BATCH) do |batch|
        docs = batch.find_all{|d|d}
        #debugger
        #read contents
        $idx.read_files(docs.find_all{|d|d.itype =~ /file/})
        docs.each{|d| $idx.read_webpage(d) if d.itype =~ /webpage|calendar/}

        #run indexing
        docs.each{|d|$idx.index_document(d)}

        #notify Searcher on the change
      end
      sleep 0.1
    end
  end
  
  #desc "Run Searcher"
  #task(:searcher => :environment) do
  #  col = file_load("col_test.dmp")
  #  #col = IR::Index.create_from_yaml(IO.read("col_test.yaml"))
  #
  #  searcher = Searcher.new(col, Searcher::RULE_DEF)
  #  queries = IO.read(PATH_COL+"c0002_lists_manual_PRM-S.qry").find_tag("query").map{|e|e.gsub("combine ","combine").gsub(/\s\s+/,"").gsub("\n"," ")}
  #  results = []
  #  queries.each_with_index do |query,i|
  #    next if ENV['query'] && ENV['query'] != i.to_s
  #    puts "Query[#{i}] : [#{query}]"
  #    results[i] = searcher.search(query, :doc=>ENV['doc'])
  #    puts results[i].map{|e|e.join("\t")}.join("\n")
  #  end
  #end
  
  desc "Run Searcher"
  task(:searcher => :environment) do
    $profile = true if ENV['profile']
    require 'lib/daemons/searcher'
  end
  
  #desc "Run Searcher"
  #task(:searcher => :environment) do
  #  col = file_load("col_test.dmp")
  #  #col = IR::Index.create_from_yaml(IO.read("col_test.yaml"))
  #
  #  searcher = Searcher.new(col, Searcher::RULE_DEF)
  #  queries = IO.read(PATH_COL+"c0002_lists_manual_PRM-S.qry").find_tag("query").map{|e|e.gsub("combine ","combine").gsub(/\s\s+/,"").gsub("\n"," ")}
  #  results = []
  #  queries.each_with_index do |query,i|
  #    next if ENV['query'] && ENV['query'] != i.to_s
  #    puts "Query[#{i}] : [#{query}]"
  #    results[i] = searcher.search(query, :doc=>ENV['doc'])
  #    puts results[i].map{|e|e.join("\t")}.join("\n")
  #  end
  #end

  task(:searcher_client => :environment) do
    puts search_remote((ENV['qtype']||'k'), ENV['query'], :port=>(ENV['port']||get_searcher_port()))
  end  
  
  task(:batch => :environment) do
    enque_daily_job()
    Rake::Task['jobs:work'].execute  
  end
end
