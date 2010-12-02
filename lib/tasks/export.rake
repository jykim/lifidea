require 'ddl_include'
require 'extractor/stat_extractor'
#include CollectorHelper

def extract_fixture_from(table_name, o = {})
  i = "000"
  sql = "SELECT * FROM %s"
  path = o[:path] || "#{Rails.root}/db/backup_#{Time.now.ymd}"
  Dir.mkdir( path ) if !File.exist?( path )
  debug "[extract_fixture_from] exporting to #{path}/#{table_name}.yml"
  File.open("#{path}/#{table_name}.yml", 'w') do |file| 
    data = ActiveRecord::Base.connection.select_all(sql % table_name) 
    file.write data.inject({}) { |hash, record| 
      hash["#{table_name}_#{i.succ!}"] = record 
      hash 
      }.to_yaml 
  end
end

namespace :export do
  
  desc "Export Documents into Text File"
  task(:docs => :environment) do
    path = ENV['dirname'] || "data/docs"
    #annotation = ENV['annotation'] || true
    #ch = Indexer.init_concept_hash() if annotation
    Dir.mkdir( path ) if !File.exist?( path )
    Item.valid.documents.between($start_at, $end_at).all(:conditions=>{:itype=>Item.itype_lists}).each_with_index do |d,i|
      next if ENV['id'] && ENV['id'].to_i != d.id
      puts "#{i}th item processed..." if i % 50 == 0 && i > 0
      case ENV['format']
      when 'indri'
        template = ERB.new(IO.read("lib/tasks/doc_indri.erb"))
        str = template.result(binding)
      else
        str = "#{d.title}\n"
        str += "#{d.m.values.join("\t")}\n"if d.m
        str += clear_webpage(d.content)
        ch.replace_concepts(str) if annotation
      end
      File.open("#{path}/doc_#{d.itype}_#{d.id}_#$renv.txt",'w'){|f|f.puts str}
      puts str if ENV['id']
    end
  end
  
  desc "Export Items along with Tags into Text File"
  task(:items => :environment) do
    filename = ENV['filename'] || "data/items_#$renv.csv"
    result = []
    itype = ENV['itype'] || 'all'
    Item.valid.between($start_at, $end_at).itype(itype).each_with_index do |e,i|
      puts "#{i}th item processed..." if i % 50 == 0 && i > 0
      result << [e.id, e.basetime, e.itype, e.title, e.did, e.uri, e.hidden_flag_before_type_cast, e.query_flag_before_type_cast, e.tag_titles.sort.join(",")]
    end
    write_csv filename, result, :header=>['id', 'basetime', 'itype', 'title', 'did', 'uri', 'hidden_flag' ,'query_flag' ,'tags']
  end
  
  desc "Export Links for computing Top-K Concept Features"
  task :topk_concept_features => :environment do
    topk = (ENV['topk'] && ENV['topk'].to_i) || 3
    weights = Searcher::load_weights(Searcher::CON_FEATURES, 'con', ENV['method'] || 'grid')
    searcher = SolrSearcher.new
    searcher.open_index()
    Link.find_all_by_ltype(['k']).each{|e|e.destroy}
    Item.valid.itype('concept').each_with_index do |c,i|
      #puts "== Working on #{c.title} =="
      result = searcher.search_by_item(c.id, 'con', :weights=>weights)
      result[0..topk].each_with_index do |e,i|
        Link.find_or_create(c.id, e[:id], 'k', :add=>(topk-i)/topk.to_f/2)
      end
    end
  end
  
  desc "Export Top K ranked lists (for debugging)"
  task :topk_results => :environment do
    result_total = []
    type = ENV['type'] || 'con'
    filename = ENV['filename'] || "data/topk_results_#{type}_#$renv.csv"
    topk = (ENV['topk'] && ENV['topk'].to_i) || 10
    queries = ENV['queries'] && ENV['queries'].split(",").map{|e|e.to_i}
    case type
    when 'con'
      features = Searcher::CON_FEATURES
      queries = Item.valid.concepts.map{|c|c.id}.sample(10).uniq if !ENV['queries']
    when 'doc'
      features = Searcher::DOC_FEATURES
      queries = Item.valid.documents.map{|c|c.id}.sample(10).uniq if !ENV['queries']
    end
    #debugger
    searcher = SolrSearcher.new
    searcher.open_index()
    queries.each do |q|
      query_item = Item.find(q)
      result = searcher.search_by_item(q, type)
      result_total.concat result[0..topk].map{|e|
        [query_item, Item.find(e[:id]) , e[:score], 
        features.map{|f|e[f]},
        #query_item.tag_titles.join(','), Item.find(e[:id]).tag_titles.join(',')
        #query_item.con_titles.join(','), Item.find(e[:id]).con_titles.join(',')
        ].flatten}
    end
    write_csv filename, result_total, 
      :header=>['query','target','score'].concat(features)
  end
  
  desc "Export Learner Input from Click Histories"
  task :sim_features => :environment do
    #$method ||= ENV['method']
    filename = ENV['input'] || get_feature_file($method)
    File.unlink(filename) if File.exists?(filename)
    Learner.export_sim_feature(filename, $type, $method)
  end
    
  desc "Export Stat table into CSV"
  task(:stats => :environment) do
    ["day","week","month"].each{|unit|export_stat_for(unit, $start_at, $end_at)}
  end
  
  # Traverse link graph and return relevant concept set
  def get_relevant_concepts(concept_id, threshold, level = 1, degree = 5)
    puts "[get_relevant_concepts:#{level}] for #{concept_id}"
    result = $clf.read_links('k', concept_id).find_all{|k,v|v >= threshold}.sort_by{|e|e[1]}.reverse.map{|e|e[0]}[0..(degree-1)]
    if level > 0
      result.concat result.map{|e|get_relevant_concepts(e, threshold, level-1, degree)}.flatten
    end
    puts result.inspect
    result.uniq
  end

  desc 'Create YAML fixtures from data in an existing database. Defaults to development database. Set RAILS_ENV to override.' 
  task :tables => :environment do
    if ENV['filename']
      extract_fixture_from(ENV['filename'], ENV.to_hash.symbolize_keys)
    else
      skip_tables = ["schema_info"] 
      ActiveRecord::Base.establish_connection 
      (ActiveRecord::Base.connection.tables - skip_tables).each do |table_name| 
        extract_fixture_from(table_name, ENV.to_hash.symbolize_keys)
      end
    end
  end
end

