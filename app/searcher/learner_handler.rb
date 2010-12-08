# Handle Learning-related Functions
module LearnerHandler
  attr_reader :clf
  CON_FEATURES = [:title, :content, :time, :string, :cooc, :occur]
  DOC_FEATURES = [:title, :content, :time, :topic, :path, :type, :concept]

  # Calculate similarity feature values 
  # - Connect to Solr for initial results
  # - Calculate feature values for those results
  # - Cache the results 
  # @param [Bool] :no_cache : disble result cacheing
  # @param [Array<int>] :items : items to be included for scoring
  def calc_sim_features(query_item, type, o={})
    #debugger
    #puts "[calc_sim_features] query_item = #{query_item} #{filter_qry}"
    
    if !o[:no_cache] && Conf.cache && cache_data([query_item.id, type, 'features'].join("_"))
      return cache_data([query_item.id, type, 'features'].join("_"))
    end
    result = []
    query_count = -1
    solr_result = solr_search_by_item(query_item, type, o)
    solr_result.each do |e|
      #
      e["id"] = e["id"].split(" ")[1]
      next if o[:items] && !o[:items].include?(e["id"])
      begin
        item = $items[e["id"].to_i]
        next if item.title == TEXT_DUMMY || item.title.blank?
        #info "[calc_sim_features] == #{item.title} =="
        fts = {:id=>item.id, :content=>(e["score"]/2)}
        #fts[:tag]   = item.tag_titles.overlap(query_item.tag_titles) #get_overlap_feature('s', item, query_item)
        fts[:title] = (item.title || "").word_sim(query_item.title || "")
        fts[:time]  = (item.basetime - query_item.basetime ).normalize_time
        case type
        when 'con'
          both_count, item_count = calc_df(item.title, [query_item.title]), calc_df(item.title)
          query_count = calc_df(query_item.title) if query_count < 0
          #  @clf.read('o', item.id, query_item.id), @clf.read_sum('o', item.id), @clf.read_sum('o', query_item.id)
          fts[:string] = item.did.str_sim(query_item.did)
          #fts[:topic] = @clf.read('t', item.id, query_item.id)
          fts[:cooc]  = Math.overlap(both_count, item_count, query_count)
          fts[:occur] = item_count.to_f.normalize(Item.count_docs)
        when 'doc'
          if item.remark && query_item.remark
            arr1, arr2 = item.remark.split(",").map{|e|e.to_f}, query_item.remark.split(",").map{|e|e.to_f}
            fts[:topic] = arr1.map_with_index{|e,i|e*arr2[i]}.sum
          end
          #fts[:concept] =  get_overlap_feature('e', item, query_item)
          fts[:path] = (item.uri || "").path_sim(query_item.uri || "")
          fts[:type] = (item.itype == query_item.itype)? 0.5 : 0.0
          fts[:concept] = get_concept_feature(item.id, query_item.id) / 3
        end
        if fts.values.find{|e|e.to_f.infinite? || e.to_f.nan?}
          warn "[calc_sim_features] Invalid feature for #{item.title}-#{query_item.title}\n #{fts.inspect}"
          info "[calc_sim_features] both_count, item_count, query_count = #{both_count}, #{item_count}, #{query_count}"
        end
        result << fts
      #rescue Interrupt
      #  break
      rescue Exception => e
        error "[search_by_item] Error in #{query_item} -> #{item}", e
      end#begin
    end#each
    cache_data([query_item.id, type, 'features'].join("_"), result) if !o[:no_cache] && Conf.cache
    return result
  end
  
  # Batch export similarity features for all learning methods
  # - Use Searcher to get the latest feature value 
  # @param [String] method : learning method ( grid, ranksvm, etc.)
  def export_sim_feature(type, start_at, end_at)
    last_query_no = 0
    files = ['grid','ranksvm'].map_hash do |method|
      [method, File.open(get_feature_file(type, method),'w')]
    end
    
    features = Learner.get_features_by_type(type, ENV['omit'])
    files['grid'].puts ['pref','basetime','src_id','tgt_id','src','target','sum'].concat(features).join(",")    
    History.between(start_at, end_at).find_all_by_htype(type).each do |h|
      next if ENV['id'] && h.id != ENV['id'].to_i
      next if $user != 'all' && $user != 'top5' && h.user && $user != h.user.uid
      #next if $user == 'top5' && !['ylim','yhkim','rshorey','gbh','uysal','lfriedl','vdang','limemoon'].include?(h.user.uid)
      debug "Exporting #{h.id} (#{h.src_item_id} by #{h.user.uid})"
      h.metadata[:skipped_items] = h.m[:url].gsub("%7C","|").split("&")[1..-1].map_hash{|e|e.split("=")}["skipped_items"] if !h.metadata[:skipped_items]
      skipped_items = h.metadata[:skipped_items].split("|").map{|e|e.to_i}
      begin
        result = search_by_item(h.src_item_id, h.htype, :working_set=>skipped_items, :no_cache=>true)
        # Get result from Searcher
        raise DataError, "Source Item not found!"  if !result
        raise DataError, "Record not found!" if result.find_all{|r|r[:id]==skipped_items[0]}.size == 0 #result.size < 2 || 
        result_arr = result.map{|r|
          #debugger
          pref = (r[:id]==skipped_items[0])? 2 : 1
          if pref == 1 && clf.read('c', h.src_item_id.to_i, r[:id]) > 0
            debug "clicked item : #{h.src_item_id}-#{r[:id]} #{pref} / #{clf.read('c', h.src_item_id.to_i, r[:id])}"
            next
          end
          {:id=>r[:id], :pref=>pref, :features=>features.map{|f|r[f]||0}}
        }.find_all{|e|e}.sort_by{|e|e[:pref]}.reverse
        raise Exception, "Incorrect Pair" if result_arr.size < 2 || result_arr[0][:pref] != 2
        # Export the result 
        result_arr.each do |r|
          files['grid'].puts [r[:pref], h.basetime, h.src_item_id, r[:id], Item.find(h.src_item_id).title, Item.find(r[:id]).title, r[:features].sum].concat(r[:features]).to_csv
          files['ranksvm'].puts "#{r[:pref]} qid:#{last_query_no} #{r[:features].map_with_index{|f,i|"#{i+1}:#{f}"}.join(' ')} # #{h.src_item_id} -> #{r[:id]} "          
        end
      rescue Interrupt
        break
      rescue DataError => e
        info "[export_sim_features] #{h.src_item_id}(#{skipped_items.size}) : #{(skipped_items - result.map{|r|r[:id]}).inspect} not found!" if skipped_items && result
        next
      rescue Exception => e
        info "[export_sim_features] other exceptions.. #{e.inspect}"
        #debugger
        next
      end
      last_query_no += 1
      #index.log_preference([h.src_item_id, skipped_items].flatten.join("|"), :export_mode=>true)
    end
    info "#{last_query_no} items exported..."
    files.each{|k,v|v.flush}
  end
  
  # Build Contextual Vector
  def build_context_vector()
    @prev_game_id, @prev_item_id = -1, -1
    History.all.each do |h|
      debug "Processing #{h.id} (#{h.src_item_id} by #{h.user.uid})"
      begin
        result = process_request(h.src_item_id, h.htype, :history_id=>h.id, :created_at=>h.created_at, :add_context=>true)
        if h.game_id 
          @cv.next_session_id() if h.game_id > @prev_game_id || h.item_id != @prev_item_id
          @prev_game_id, @prev_item_id = h.game_id, h.item_id
        end
      rescue Interrupt
        break
      rescue Exception => e
        error "[build_context_vector] other exceptions.. ", e
        #debugger
        next
      end
    end
  end
  
  # @deprecated
  def log_preference(query_item, type, click_position, o={})
    $f_li = File.open(Rails.root.join("data/learner_input/learner_input_#{ENV['RAILS_ENV']}_#{type}_#{Time.now.ymd}.txt"), 'a')
    result = @cv.get()[-1][:result]
    #search_by_item(query_item, type)
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
end