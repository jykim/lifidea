class Searcher
  attr_reader :clf
  CON_FEATURES = [:title, :content, :tag, :time, :topic, :string, :cooc, :occur]
  DOC_FEATURES = [:title, :content, :tag, :time, :topic, :path, :type, :concept]
    
  # Initialize cache / index
  def initialize(o = {})
    @debug = o[:debug] || false
    $items = {} if !$items
    if !cache_data("exists")
      #debugger
      open_index()
      cache_data("exists", "true")
      error "[init_controller] searcher initializd..."
    else
      @clf = cache_data('clf')
      @con_weights = cache_data('con_weights')
      @doc_weights = cache_data('doc_weights')
    end
  end
  
  # Prepare index for searching
  def open_index(o={})
    @clf = cache_data('clf', Searcher.load_features())
    @con_weights = cache_data('con_weights', Searcher.load_weights(CON_FEATURES, 'con', Conf.weight_con))
    @doc_weights = cache_data('doc_weights', Searcher.load_weights(DOC_FEATURES, 'doc', Conf.weight_doc))
  end
  
  def process_request(qtype, query, o = {})
    result = case qtype
    when 'k' : search_by_keyword(query, o)
    when 'c' : search_by_item(query, 'con', o)
    when 'd' : search_by_item(query, 'doc', o)
    end
  end
  
  # (stub) Keyword Search
  def search_by_keyword(keyword, o = {})
    
  end
  
  # (stub) Similarity Search
  def search_by_item(item, o = {})
    
  end
  
  def self.load_weights(features, type, rank = 'uniform')
    result = [0] * features.size
    rank ||= ENV['rank']
    if features.include?(rank)
      features.each_with_index{|e,i|result[i] = 1 if e == rank}
      return result
    elsif rank == 'uniform'
      return [1] * features.size 
    end
    
    begin
      weight_hash = IO.read(read_recent_file_in(RAILS_ROOT+"/data/learner_output", :filter=>/#{ENV['RAILS_ENV']}.*#{type}.*#{rank}/)).
        split("\n")[0].split(" ")[1..-1].map_hash{|e|r = e.split(":") ; [r[0].to_i, r[1].to_f]}
      result = [] ; 1.upto(features.size){|i|result << ((weight_hash[i] && weight_hash[i] > 0) ? weight_hash[i] : 0)}
    rescue Exception => e
      puts "[Searcher.load_weights] error : ", e
    end
    puts "[Searcher.load_weights] #{features.inspect}(#{rank}) = #{result.inspect}"
    result
  end
  
  # Load link & occurrence table to memory
  def self.load_features()
    clf = LinkFeatures.new
    clf.load Link.all.map{|l|[l.ltype, l.out_id.to_i, l.in_id.to_i, l.weight]}
    #clf.load Occurrence.all.map{|l|['s', l.tag_id.to_i, l.item_id.to_i, 1]}, :force=>true
    info "[load_features] done!"
    clf
  end
  
  
  # Calculate Indirect Concept Similarity
  def get_concept_feature(doc1, doc2)
    result = []
    @clf.read_links('e',doc1).each do |k,v|
      @clf.read_links('e',doc2).each do |k2,v2|
        if k == k2 
          result << 3 * v * v2
        else
          result << @clf.read('k',k,k2) * v * v2
        end
      end
    end
    #p result
    result.mean
  end
  
  # Get tag or concept overlap feature
  def get_overlap_feature(ltype, item1, item2)
    @clf.read_links(ltype, item1.id).keys.overlap(@clf.read_links(ltype, item2.id).keys)
  end
  
  # 
  def log_preference(query_item, type, click_position, o={})
    $f_li = File.open(RAILS_ROOT + "/data/learner_input/learner_input_#{ENV['RAILS_ENV']}_#{type}_#{Time.now.ymd}.txt", 'a')
    
    result = search_by_item(query_item, type)
    last_query_no = SysConfig.find_by_title("LAST_QUERY_NO").content.to_i
    #debugger
    log = result[0..(click_position-1)].reverse.map_with_index{|e,i|
      [((i==0)? 2 : 1), "qid:#{last_query_no}", e, "# #{query_item} -> #{e[:id]}" ]
    }
    if !o[:export_mode]
      #$clf.increment('c', dnos[0], dnos[1])
      SysConfig.find_by_title("LAST_QUERY_NO").update_attributes(:content=>(last_query_no+1)) 
    end
    $f_li.puts log.map{|e|e.join(" ")}.join("\n") if log.size > 1
    $f_li.flush
  end
  
  def self.export_sim_feature(filename)
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
end
