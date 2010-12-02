class Learner
  LL_TYPE_DEF = 5
  LS_TYPE_DEF = 0
  
  def initialize()
    
  end
  
  # Run learner
  def learn(type, method, input, output)
    case method
    when 'ranksvm' : learn_by_ranksvm(input, output)
    when 'liblinear' : learn_by_liblinear(input, output, :ll_type=>ENV['ll_type'])
    when 'libsvm' : learn_by_libsvm(input, output, :ls_type=>ENV['ls_type'])
    when 'grid'
      input_data = read_csv(input)#+"#{ENV['train_ratio']}.train")
      learn_by_grid_search(input_data, output, type, 
        :features=>Learner.get_features_by_type(type, ENV['omit']), :grid_type=>ENV['grid_type'])
    else
      puts "[learner] No method selected!"
    end
  end
  
  def self.get_features_by_type(type, omit = nil)
    result = case type
    when 'con' : Searcher::CON_FEATURES
    when 'doc' : Searcher::DOC_FEATURES
    when 'csel' : RubySearcher::CS_TYPES
    end
    if omit
      result_new = result.dup ; result_new.delete_at(omit.to_i-1)
    else
      result_new = result
    end
    #puts "[get_features_by_type] features = #{result_new.inspect}"
    result_new
  end
  
  # Batch export similarity features for training weights 
  # - Use Searcher to get the latest feature value 
  # @param [String] method : learning method ( grid, ranksvm, etc.)
  def self.export_sim_feature(filename, type, method)
    $f_li = File.open(filename,'w')
    last_query_no = 0

    features = get_features_by_type(type, ENV['omit'])
    $f_li.puts ['pref','basetime','src_id','tgt_id','src','target','sum'].concat(features).join(",") if method=='grid'
    searcher = SolrSearcher.new
    searcher.open_index()
    
    History.between($start_at, $end_at).find_all_by_htype(type).each do |h|
      next if ENV['id'] && h.id != ENV['id'].to_i
      next if $user != 'all' && $user != 'top5' && h.user && $user != h.user.uid
      #next if $user == 'top5' && !['ylim','yhkim','rshorey','gbh','uysal','lfriedl','vdang','limemoon'].include?(h.user.uid)
      debug "Exporting #{h.id} (#{h.src_item_id} by #{h.user.uid})"
      result_str = []
      h.metadata[:skipped_items] = h.m[:url].gsub("%7C","|").split("&")[1..-1].map_hash{|e|e.split("=")}["skipped_items"] if !h.metadata[:skipped_items]
      skipped_items = h.metadata[:skipped_items].split("|").map{|e|e.to_i}
      begin
        result = searcher.search_by_item(h.src_item_id, h.htype, :working_set=>skipped_items, :no_cache=>true)
        #puts "#{skipped_items.inspect} => #{result.map{|e|e[:id]}.inspect}"
        raise DataError, "Source Item not found!"  if !result
        raise DataError, "Record not found!" if result.find_all{|r|r[:id]==skipped_items[0]}.size == 0 #result.size < 2 || 
        result_str = result.map{|r|
          #debugger
          preference = (r[:id]==skipped_items[0])? 2 : 1
          feature_values = features.map{|f|r[f]||0}
          if preference == 1 && searcher.clf.read('c', h.src_item_id.to_i, r[:id]) > 0
            debug "clicked item : #{h.src_item_id}-#{r[:id]} #{preference} / #{searcher.clf.read('c', h.src_item_id.to_i, r[:id])}"
            next
          end
          case method
          when 'grid'
            [preference, h.basetime, h.src_item_id, r[:id], Item.find(h.src_item_id).title, Item.find(r[:id]).title, feature_values.sum].
              concat(feature_values).to_csv
          when 'ranksvm'
            "#{preference} qid:#last_query_no #{feature_values.map_with_index{|f,i|"#{i+1}:#{f}"}.join(' ')} # #{h.src_item_id} -> #{r[:id]} "          
          else
            error "No argument (method) !!!!!"
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
      last_query_no += 1
      #index.log_preference([h.src_item_id, skipped_items].flatten.join("|"), :export_mode=>true)
    end
    puts "#{last_query_no} items exported..."
    $f_li.flush
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
  
  # @deprecated
  def self.parse_ranksvm_input(filename)
    IO.read(filename).split("\n").find_all{|l|l =~ /^2/}.map{|l|a = l.scan(/\# (\d+) \-\> (\d+)/)[0]}
  end
  
  def learn_by_ranksvm(input, output)
    cmd = "python anton/SVMWrapper.py -d anton/ -t #{input}#{ENV['train_ratio']}.train -a #{input}#{ENV['train_ratio']}.test -w #{output} -e 1"
    puts "[learner] running: #{cmd}"
    system(cmd)
  end
  
  def learn_by_liblinear(input, output, o={})
    cmd = "#{ENV['PG']}/liblinear/train -s #{o[:ll_type] || LL_TYPE_DEF} #{input}.train #{output}.model"
    puts "[learner] running: #{cmd}" ; system(cmd)
    cmd = "#{ENV['PG']}/liblinear/predict -b 1 #{input}.test  #{output}.model #{output}.output 1> #{output}.result"
    system(cmd)
  end
  
  def learn_by_libsvm(input, output, o={})
    cmd = "#{ENV['PG']}/libsvm/svm-train -b 1 -s #{o[:ls_type] || LS_TYPE_DEF} #{input}.train #{output}.model"
    puts "[learner] running: #{cmd}" ; system(cmd)
    cmd = "#{ENV['PG']}/libsvm/svm-predict -b 1 #{input}.test  #{output}.model #{output}.output 1> #{output}.result"
    system(cmd)
  end
  
  # @param <Array> : input_data (same as evaluate_sim_search_with)
  # @param <String> output : output file
  # @return <Array> : 
  def learn_by_grid_search(input_data, output, type, o = {})
    no_params = o[:features].size
    xvals = (1..no_params).to_a
    yvals = [] ; yvals << [0.5] * xvals.size
    results = []
    
    search_method = GoldenSectionSearchMethod.new(xvals , yvals)
    search_method.search(3) do |xvals , yvals , train , remote|
      results << case type
      when /con|doc/ : Evaluator.evaluate_sim_search_with(input_data.find_all{|e|e[:pref] == '2'}, type, yvals, o)
      when 'csel': Evaluator.evaluate_csel_with(input_data, yvals, o)
      end
      results[-1][0]
    end
    results_str = case (o[:grid_type] || 'single')
    when 'single'
      results.sort_by{|e|e[0]}.reverse.map{|l|l.map_with_index{|e,i|[i,e].join(":")}.join(" ")}.join("\n")
    when 'avg'
      max_perf = results.sort_by{|l|l[0]}[-1][0]
      results_str = results.find_all{|l|l[0] == max_perf}.merge_array_by_avg().map_with_index{|e,i|[i,e].join(":")}.join(" ")
    end
    File.open(output, 'w'){|f|f.puts results_str}
    info "[learn_by_grid_search] max(MRR) = #{results.sort_by{|e|e[0]}[-1][0]}"
    results
  end
end
