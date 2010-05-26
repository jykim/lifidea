require 'ddl_include'
require 'extractor/stat_extractor'
#include CollectorHelper

def extract_fixture_from(table_name, o = {})
  i = "000"
  sql = "SELECT * FROM %s"
  path = o[:path] || "#{RAILS_ROOT}/db/backup_#{Time.now.ymd}"
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
    annotation = ENV['annotation'] || true
    ch = Indexer.init_concept_hash() if annotation
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
  
  desc "Export Top-K Concept Features"
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
  
  desc "Export Top K relevant items"
  task :rel_items => :environment do
    result_total = []
    type = ENV['type'] || 'con'
    filename = ENV['filename'] || "data/rel_items_#{type}_#$renv.csv"
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
    $f_li = File.open(filename,'w')
    $last_query_no = 0

    type = ENV['type']
    features = get_features_by_type(type, ENV['omit'])
    $f_li.puts ['pref','basetime','src_id','target_id','src','target','sum'].concat(features).join(",") if $method=='grid'
    searcher = SolrSearcher.new
    searcher.open_index()
    
    History.between($start_at, $end_at).find_all_by_htype(type).each do |h|
      next if ENV['id'] && h.id != ENV['id'].to_i
      next if $user != 'all' && $user != 'top5' && h.user && $user != h.user.uid
      next if $user == 'top5' && !['ylim','yhkim','rshorey','gbh','uysal','lfriedl','vdang','limemoon'].include?(h.user.uid)
      puts "Exporting #{h.id} (#{h.src_item_id} by #{h.user.uid})"
      result_str = []
      params = h.m[:url].gsub("%7C","|").split("&")[1..-1].map_hash{|e|e.split("=")}
      skipped_items = params["skipped_items"].split("|").map{|e|e.to_i}
      begin
        result = searcher.search_by_item(h.src_item_id, h.htype, :working_set=>skipped_items, :no_cache=>true)
        #puts "#{skipped_items.inspect} => #{result.map{|e|e[:id]}.inspect}"
        raise DataError, "Source Item not found!"  if !result
        #result = result_raw.find_all{|r|skipped_items.include?(r[:id])}
        #puts result.size
        #raise Exception, "Top item clicked!" if skipped_items.size < 2 
        raise DataError, "Record not found!" if result.find_all{|r|r[:id]==skipped_items[0]}.size == 0 #result.size < 2 || 
        result_str = result.map{|r|
          #debugger
          preference = (r[:id]==skipped_items[0])? 2 : 1
          feature_values = features.map{|f|r[f]||0}
          if preference == 1 && searcher.clf.read('c', h.src_item_id.to_i, r[:id]) > 0
            puts "clicked item : #{h.src_item_id}-#{r[:id]} #{preference} / #{searcher.clf.read('c', h.src_item_id.to_i, r[:id])}"
            next
          end
          case $method
          when 'grid'
            [preference, h.basetime, h.src_item_id, r[:id], Item.find(h.src_item_id).title, Item.find(r[:id]).title, feature_values.sum].
              concat(feature_values).to_csv
          when 'ranksvm'
            "#{preference} qid:#$last_query_no #{feature_values.map_with_index{|f,i|"#{i+1}:#{f}"}.join(' ')} # #{h.src_item_id} -> #{r[:id]} "          
          else
            error "No argument!!!!!"
          end
        }.find_all{|e|e}.sort_by{|e|e[0..0].to_i}.reverse
        #puts result_str
        #raise Exception, "Incorrect Pair" if result_str.size < 2 || result_str[0][0..0] != '2'
      rescue Interrupt
        break
      rescue DataError => e
        error "[export:sim_features] #{h.src_item_id}(#{skipped_items.size}) : #{(skipped_items - result.map{|r|r[:id]}).inspect} not found!" if skipped_items && result
        next
      rescue Exception => e
        error "[export:sim_features] other exceptions.. #{e.inspect}"
        #debugger
        next
      end
      $f_li.puts result_str
      $last_query_no += 1
      #index.log_preference([h.src_item_id, skipped_items].flatten.join("|"), :export_mode=>true)
    end
    puts "#$last_query_no items exported..."
    $f_li.flush
  end
    
  desc "Export Stat table into CSV"
  task(:stats => :environment) do
    ["day","week","month"].each{|unit|export_stat_for(unit, $start_at, $end_at)}
  end
  
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

  desc "Export Concept Links into dot file"
  task :concept_links => :environment do
    template = ERB.new(IO.read('lib/tasks/graph_neato.erb'))
    $clf = cache_data('clf', Searcher.load_features())
    threshold = ENV['threshold'] || 1
    ltype = ENV['ltype'] || 'k'
    level = ENV['level'] || 1
    degree = ENV['degree'] || 5
    filename = ENV['filename'] || "data/concept_links_#{$renv}_#{ENV['concept']}_#{ltype}#{threshold}-#{level}-#{degree}.dot"
    conditions = if ENV['concept']
      rel_concepts = get_relevant_concepts(ENV['concept'].to_i, threshold.to_f, level.to_i, degree.to_i)
      ['ltype = ? and weight >= ? and (in_id in (?) or out_id in (?))', ltype, threshold.to_f, rel_concepts, rel_concepts]
    else
      ['ltype = ? and weight >= ?', ltype, threshold.to_f]
    end
    nodes = Link.all(:conditions=>conditions).
      find_all{|l| (l.initem && l.initem.concept? && l.outitem && l.outitem.concept?)}.
      map{|l|{:from=>l.outitem.title, :to=>l.initem.title, :weight=>l.weight}} #, :label=>l.ltype
    File.open(filename , "w"){|f| f.puts template.result(binding) }
    puts 'created dot file...'
    puts cmd = "neato -T png -o #{filename}.png #{filename}"
    `#{cmd}`
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

