class Searcher
  attr_accessor :cols
  include InferenceNetwork
  attr_accessor :cons, :docs
  #RULE_DEF = 'method:jm,lambda:0.1'
  RULE_DEF = 'method:dirichlet,mu:1500'
  FEATURES = ['c_title','c_content','c_uri','c_tag','time','co-oc','topic','occur']
  INDEX_FIELD_DEF = [:title, :content, :uri]
  INDEX_FIELDS = {"calendar"=>[:start_at, :location], "email"=>[:from, :to, :date], "file"=>[:filename], "news"=>[:tag_list], "webpage"=>[:tag_list]}
  
  #RULE_DEF = 'method:dirichlet,mu:100'
  
  # @param [Array<IR::Index>] cols : target collections
  def initialize(cols = nil, o = {})
    @cols = cols
    @debug = o[:debug] || false
    @lambda = nil
    $clf = LinkFeatures.new
    parse_rule(o[:rule] || RULE_DEF)
  end
  
  def self.load_weights(rank = nil)
    result = [0] * Searcher::FEATURES.size
    rank ||= ENV['rank']
    if FEATURES.include?(rank)
      FEATURES.each_with_index{|e,i|result[i] = 1 if e == rank}
      return result
    elsif rank == 'uniform'
      return [1] * Searcher::FEATURES.size 
    end
    
    begin
      weight_hash = IO.read(read_recent_file_in(RAILS_ROOT+"/data/learner_output", :filter=>/#{ENV['RAILS_ENV']}.*#{rank}/)).
        split("\n")[0].split(" ")[1..-1].map_hash{|e|r = e.split(":") ; [r[0].to_i, r[1].to_f]}
      result = [] ; 1.upto(Searcher::FEATURES.size){|i|result << ((weight_hash[i] && weight_hash[i] > 0) ? weight_hash[i] : 0)}
    rescue Exception => e
      puts "[Searcher.load_weights] error:", e
    end
    puts "[Searcher.load_weights] weights(#{rank}) = #{result.inspect}"
    result
  end
  
  def self.load_features()
    $clf.load Link.all.map{|l|[l.ltype, l.out_id.to_i, l.in_id.to_i, l.weight]}
  end
  
  def load_items()
    Searcher.load_features() if !$clf
    @items = Item.valid.indexed
    @item_groups = @items.group_by{|d|d.itype}.map{|e| 
      IR::Index.new(e[1].map{|d|d.get_index}, 
      :cid=>e[0], :fields=>[:title, :content, :tag, :uri])}
    info "[Searcher::load_items] #{@items.size} cols loaded."
  end
  
  def load_concepts()
    Searcher.load_features() if !$clf
    @cons = IR::Index.new( Item.valid.indexed.concepts.map{|d|d.get_index}.find_all{|i|!i.blank?}, 
      :cid=>'concepts', :fields=>[:title, :content, :tag, :uri] , :init_df=>true )
    #info "[Searcher::load_concepts] #{@cons.items.size} concepts loaded."
  end
  
  def load_documents()
    @cols = Item.documents.indexed.
      group_by{|d|d.itype}.find_all{|k,v|v.size>10}.map{|e| 
        IR::Index.new(e[1].map{|d|d.get_index}, 
        :cid=>e[0], :fields=>[INDEX_FIELD_DEF,INDEX_FIELDS[e[0]]].flatten)}
    info "[load_index] #{@cols.size} cols loaded."
  end
  
  # Search given keyword query
  # - 1) collection scoring
  # - 2) document scoring
  # - merging 1) and 2) into final score
  def search_by_keyword(query, o={})
    parsed_query = InferenceNetwork.parse_query(query)
    o[:indri_query] ||= "#combine(#{parsed_query.map{|w|w+'.(document)'}.join(' ')})"
    #info "[searcher_daemon] indri_query = [#{o[:indri_query]}]"
    #qws = query.scan(LanguageModel::PTN_TERM)
    InferenceNetwork.eval_indri_query(o[:indri_query])
    topk = o[:topk] || 50
    doc_scores = {}
    @cols.each do |col|
      if !o[:col]
        debug "[search] Scoring #{col.cid}"
        col_score = score_col(col, parsed_query, :cql, :cqls => parsed_query.map{|e|col.lm.prob(e)})
        col_score_log = if col_score == 0
          MIN_NUM
          #debug "[search] Skipping collection #{col.cid}"
          #next
        else
          Math.log(col_score)
        end
      end
      doc_scores[col.cid] = []
      col.docs.each do |doc|
        #debug "[search] Scoring #{doc.did}"
        next if (o[:doc] && o[:doc] != doc.did) || (o[:col] && o[:col] != col.cid)
        begin
          @debug = true if o[:id]
          @match_found = false
          if( doc_score = score_doc(doc,col))
            doc_scores[col.cid] << [doc.did, (col_score_log||0) + doc_score] if doc_score > MIN_NUM
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
  
  CS_TYPES = [:cql, :mpmax, :mpmean, :smpmean, :mphmean, :mpgmean, :clarity, :qlm, :gmap, :redde, :dict]
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
      when :gmap    : o[:rank_list].map{|e|Math.exp(e[1])}.gmean
      when :redde   : o[:rank_list].map{|e|Math.exp(e[1])}.sum
      when :dict    : (DICT_COLS[col.cid].map{|e|e.to_s.stem} & parsed_query).size
      end
    rescue Exception => e
      warn("[Searcher#score_col] result = 0 (exception)")      
    end
    (result || 0)
  end
end
