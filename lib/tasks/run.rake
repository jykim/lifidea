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
    $clf = Searcher.load_features()
    #debugger
    $idx = Indexer.new
    puts 'Indexing Documents'
    $idx.index_item_set(item_set.find_all{|i|!i.concept?}, :download=>ENV['download']) if !ENV['concept_only']
    puts 'Indexing Concepts'
    $idx.index_item_set(item_set.find_all{|i|i.concept?}, :download=>ENV['download']) if !ENV['document_only']
  end
  
  desc "Run Learner to Train Weights"
  task(:learner => :environment) do
    #puts "run:learner!"
    input = ENV['input'] || get_learner_input_file($method)
    #puts input
    weights = ENV['weights'] || get_learner_output_file($method)
    learner = WeightLearner.new
    case ($method || ENV['method'])
    when 'ranksvm' : learner.learn_by_ranksvm(input, weights)
    when 'liblinear' : learner.learn_by_liblinear(input, weights, :ll_type=>ENV['ll_type'])
    when 'libsvm' : learner.learn_by_libsvm(input, weights, :ls_type=>ENV['ls_type'])
    when 'grid'
      input_data = case $type
      when "con" : self.parse_ranksvm_input(input+'.train')
      when "csel" : read_csv(input+'.train')
      end
      #debugger
      learner.learn_by_grid_search(input_data, weights, $type, :grid_type=>ENV['grid_type'])
    else
      puts "[run:learner] No method selected!"
    end
  end
  
  desc "Run Searcher"
  task(:searcher => :environment) do
    $profile = true if ENV['profile']
    require 'lib/daemons/searcher'
  end

  task(:searcher_client => :environment) do
    puts search_remote((ENV['qtype']||'k'), ENV['query'], :port=>(ENV['port']||Conf.searcher_port))
  end  
  
  task(:batch => :environment) do
    enque_daily_job()
    Rake::Task['jobs:work'].execute  
  end
end
