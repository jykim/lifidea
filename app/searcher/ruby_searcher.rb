class RubySearcher < Searcher
  include InferenceNetwork
  attr_accessor :items#:cons, :docs
  RULE_DEF = 'method:jm,lambda:0.1'
  #RULE_DEF = 'method:dirichlet,mu:50'
  INDEX_FIELD_DEF = [:title, :content, :uri]
  INDEX_FIELDS = {"calendar"=>[:start_at, :location], "email"=>[:from, :to, :date], "file"=>[:filename], "news"=>[:tag_list], "webpage"=>[:tag_list]}
  
  #RULE_DEF = 'method:dirichlet,mu:100'
  
  def initialize(o={})
    super(o)
    @lambda = nil
    parse_rule(o[:rule] || Conf.rule_searcher ||RULE_DEF)
  end
  
  def open_index(o={})
    Searcher.load_features() if !$clf
    @items = Item.valid.indexed.group_by{|d|d.itype}.map_hash do |k,v|
      [k, IR::Index.new(v.map{|d|d.get_index}, :cid=>k, :fields=>[:title, :content, :tag, :uri], :init_df=>true)]
    end
    info "[RubySearcher::load_items] #{@items.size} cols loaded."
  end
  
  # Search based on similarity
  # - Find target document
  # - Evaluate similarity query
  def search_by_item(item, o={})
    query_item = Item.find(item.to_i)
    return nil if !query_item
    query = query_item.get_index
    query.col = @items[query_item.itype]
    
    weights = Vector.elements(o[:weights] || [1]*Searcher::CON_FEATURES.size)
    result = []
    @items.each do |itype,indices|
      indices.docs.each do |d|
        #debugger
        next if d.dno == query.dno
        puts "[search_by_item] Scoring #{d.did}"
        #puts "#{d.feature_vector(query).inspect}*#{weights.inspect}"
        begin
          score = d.feature_vector(query).inner_product(weights)#w[:content] * d.cosim(query) + w[:time] * d.tsim(query)          
        rescue Exception => e
          puts "Error in #{d.feature_vector(query).inspect}*#{weights.inspect}"
        end
        result << [d.dno, score]
      end
    end
    #debugger
    if ENV['rank'] == 'random'
      result.sample(50)
    else
      result.sort_by{|e|e[1]}.reverse[0..50]
    end
  end
  
  # Search given keyword query
  # - 2) document scoring
  # - merging 1) and 2) into final score
  def search_by_keyword(query, o={})
    #debugger
    indri_query = o[:indri_query] || "#combine(#{InferenceNetwork.parse_query(query).map{|w|w+'.(document)'}.join(' ')})"
    #info "[searcher_daemon] indri_query = [#{o[:indri_query]}]"
    InferenceNetwork.eval_indri_query(indri_query)
    topk = o[:topk] || 50
    col_weight = o[:col_weight] || 0.4
    doc_scores = {}
    #debugger
    @items.values.each do |col|
      col_score = (o[:col_scores])? o[:col_scores][col.cid] : MIN_PROB
      #debug "col_scores : #{o[:col_scores]}"
      doc_scores[col.cid] = []
      col.docs.each do |doc|
        #debug "[search] Scoring #{doc.did}"
        next if (o[:doc] && o[:doc] != doc.did) || (o[:col] && o[:col] != col.cid)
        begin
          @debug = true if o[:id]
          @match_found = false
          if( doc_score = score_doc(doc,col))
            next if doc_score <= MIN_NUM
            final_score = if o[:col_scores]
              col_score * Math.exp(doc_score) * col_weight + Math.exp(doc_score)
            else
              doc_score
            end
            doc_scores[col.cid] << [doc.did, final_score] 
          end
        rescue Exception => e
          @debug = true
          error "Error on #{col.cid}::#{doc.did} #{doc.flm.size} / #{col.lm.size} " , e
          #debugger
          score_doc(doc,col)
          exit
        end
      end
    end
    doc_scores.values.collapse.sort_by{|e|e[1]}.reverse[0..topk]
  end
  
  # Log pairwise preference training data into file
  # @param[String] query : query_id|clicked_item_id|skipped_item_id|...
  def log_preference(dnos, o={})
    dnos = dnos.split("|").map{|e|e.to_i}
    #puts "[log_preference] dnos=#{dnos.inspect}"
    query = @dhno[dnos[0]]
    return nil unless query

    result = []
    $last_query_no += 1
    dnos[1..-1].each_with_index do |dno,i|
      pref = (i == 0)? 2 : 1
      begin
        raise ArgumentError, "already clicked concept!" if pref == 1 && $clf.read('c', dno, query.dno) > 0
        features = @dhno[dno].feature_vector(query).to_a.map_with_index{|e,j|[j+1,fp(e)].join(":")}
      rescue Exception => e
        error "[log_preference] error in #{$last_query_no}th query : #{dno}"
        if pref == 2 #clicked concept missing!
          return
        else
          next
        end
      end
      result << [pref,"qid:#{$last_query_no}"].concat(features).concat(["# #{query.dno} -> #{dno} (#{query.did} / #{dh[dno].did})"])
    end
    if !o[:export_mode]
      $clf.increment('c', dnos[0], dnos[1])
      SysConfig.find_by_title("LAST_QUERY_NO").update_attributes(:content=>$last_query_no) 
    end
    $f_li.puts result.map{|e|e.join(" ")}.join("\n") if result.size > 1
    $f_li.flush
  end
  
  CS_TYPES = [:cql, :mpmean, :dict, :qlm, :clarity, :gavg, :redde]# :mpmax, :smpmean, :mphmean, :mpgmean
  CS_COMB_TYPES = ['uniform', 'grid', 'ranksvm']
  DICT_COLS = {
    "calendar"=>[:calendar, :schedule, :start_at, :location], "email"=>[:email, :from, :to, :date], 
    "file"=>[:file, :filename, :pdf, :html, :dvi, :ppt, :doc], "news"=>[:news, :tag_list, :blog, :tag], 
    "webpage"=>[:webpage, :http, :html, :htm , :tag_list]}
  
  # Get collection score
  # @param [String] query
  def score_col(col, parsed_query, type, o = {})
    #debug "[col_score] parsed_query = #{parsed_query}"
    #debugger
    begin
      result = case type
      when :cql     : o[:cps].multiply_log
      when :mpmax   : o[:mps].map{|e|(e.values).max}.multiply_log
      when :mpmean  : o[:mps].map{|e|(e.values).mean}.multiply_log
      when :smpmean : o[:smps].map{|e|(e.values).mean}.multiply_log
      when :mphmean : o[:mps].map{|e|(e.values).hmean}.multiply_log
      when :mpgmean : o[:mps].map{|e|(e.values).gmean}.multiply_log
      when :clarity : col.dhid[o[:rank_list][0][0]].lm.kld(col.lm)
      when :qlm     : o[:qqls].multiply_log
      when :gavg    : o[:rank_list].map{|e|Math.exp(e[1])}.pad(o[:gavg_m], o[:gavg_minql]).gmean
      when :redde   : o[:rank_list].map{|e|Math.exp(e[1])}.sum
      when :dict    : (DICT_COLS[col.cid].map{|e|e.to_s.stem} & parsed_query).size
      end
    rescue Exception => e
      warn("[Searcher#score_col] result = 0 (exception)")      
    end
    (result || 0)
  end
end