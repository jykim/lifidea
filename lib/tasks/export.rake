require 'ddl_include'
require 'extractor/stat_extractor'
include CollectorHelper

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
      str = "#{d.title}\n"
      str += "#{d.m.values.join("\t")}\n"if d.m
      str += clear_webpage(d.content)
      ch.replace_concepts(str) if annotation
      File.open("#{path}/doc_#{d.id}_#$renv.txt",'w'){|f|f.puts str}
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
      result << [e.id, e.basetime, e.itype, e.title, e.did, e.uri, e.hidden_flag_before_type_cast, e.tag_titles.sort.join(",")]
    end
    write_csv filename, result, :header=>['id', 'basetime', 'itype', 'title', 'did', 'uri', 'hidden_flag' ,'tags']
  end
  
  desc "Export Top K relevant concepts into CSV"
  task :rel_concepts => :environment do
    result_total = []
    filename = ENV['filename'] || "data/rel_concepts_#$renv.csv"
    topk = (ENV['topk'] && ENV['topk'].to_i) || 10
    queries = (ENV['queries'] && ENV['queries'].split(",").map{|e|e.to_i}) || Item.valid.concepts.map{|c|c.id}.sample(10).uniq
    $searcher = Searcher.new
    $searcher.load_concepts() ; index = $searcher.cons
    queries.each do |q|
      result = [] ; query = index.dh[q]
      if !query
        puts "Query #{q} not found!" ; next
      end
      puts "[export:rel_concepts] Scoring #{query}"
      index.docs.sample(topk).each_with_index do |d,i|
        next if d.dno == query.dno
        result << [query, d, d.feature_vector(query).to_a].flatten
        #break if i >= topk
      end
      #p result[0..topk].map{|e|e[2..-1]}
      result_total.concat result[0..topk].sort_by{|e|e[2..-1].sum}.reverse
    end
    write_csv filename, result_total, 
      :header=>['query','target'].concat(Searcher::CON_FEATURES)
  end
  
  desc "Export Learner Input from Click Histories"
  task :learner_input => :environment do
    filename = ENV['input'] || get_learner_input_file()
    File.unlink(filename) if File.exists?(filename)
    $f_li = File.open(filename, 'a')
    $last_query_no = 0
    $searcher = Searcher.new
    $searcher.load_concepts() ; index = $searcher.cons
    History.between($start_at, $end_at).find_all_by_htype("con").each do |h|
      puts "Exporting #{h.id}"
      params = h.m[:url].gsub("%7C","|").split("&")[1..-1].map_hash{|e|e.split("=")}
      skipped_items = params["skipped_items"].split("|")
      if ENV['random_items']
        skipped_items = [skipped_items[0], index.docs.map{|e|e.dno}.sample(ENV['random_items'].to_i)]
      end
      index.log_preference([h.src_item_id, skipped_items].flatten.join("|"), :export_mode=>true)
    end
    puts "Splitting #{filename}..."
    Rake::Task['etc:split_file'].execute
  end
    
  desc "Export Stat table into CSV"
  task(:stats => :environment) do
    ["day","week","month"].each{|unit|export_stat_for(unit, $start_at, $end_at)}
  end
  
  desc "Export Concept table into CSV"
  task :concepts => :environment do
    filename = ENV['filename'] || "data/concepts_#$renv.csv"
    write_csv filename, Item.concepts.all.map{|c|[c.id, c.title, c.ctype, c.synonym_id, c.hidden_flag_before_type_cast, c.modified_flag_before_type_cast]}, 
      :header=>['id','title','ctype','synonym_id','hidden_flag','modified_flag']
  end
  
  desc "Export Training Data for Collection Selection"
  task :csel_features => :environment do
    filename = ENV['filename'] || "data/csel_#$renv-#$min_prob-#$mp_smt.csv"
    if !$searcher
      $searcher = Searcher.new(nil, :debug=>ENV['debug'])
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

  desc "Export Concept Links into dot file"
  task :concept_links => :environment do
    template = ERB.new(IO.read('lib/tasks/graph_neato.erb'))
    filename = ENV['filename'] || "data/concept_links_#{ENV['ltype']}#{ENV['threshold']}.dot"
    conditions = (ENV['ltype'])? ['ltype = ?', ENV['ltype']] : []
    #conditions = (ENV['threshold'])? ['ltype = ? and weight > ?', ENV['ltype'], ENV['threshold'].to_f] : []
    nodes = Link.all(:conditions=>conditions).find_all{|l| (l.initem && l.initem.concept? && l.outitem && l.outitem.concept?)}.
      map{|l|{:from=>l.outitem.title, :to=>l.initem.title, :weight=>l.weight, :label=>l.ltype}}
    File.open(filename , "w"){|f| f.puts template.result(binding) }
    puts 'created dot file...'
    `neato -T png -o #{filename}.png #{filename}`
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

