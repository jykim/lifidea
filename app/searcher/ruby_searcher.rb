# Ruby Implementation of Searcher 
class RubySearcher < Searcher
  include InferenceNetwork
  attr_accessor :items, :index #:cons, :docs
  RULE_DEF = 'method:jm,lambda:0.1'
  #RULE_DEF = 'method:dirichlet,mu:50'
  INDEX_FIELD_DEF = [:title, :content, :uri]
  INDEX_FIELDS = {"calendar"=>[:start_at, :location], "email"=>[:from, :to, :date], "file"=>[:filename], "news"=>[:tag_list], "webpage"=>[:tag_list]}
    
  def initialize(index = nil, o={})
    super(o)
    @lambda = nil
    @index = index
    parse_rule(o[:rule] || Conf.rule_searcher ||RULE_DEF)
  end
  
  # Initialize Index from Item table
  def open_index(o={})
    Searcher.load_features() if !$clf
    @item_indices = Item.valid.indexed.group_by{|d|d.itype}.map_hash do |k,v|
      [k, IR::Index.new(v.map{|d|d.get_index}, :cid=>k, :fields=>[:title, :content, :tag, :uri], :init_df=>true)]
    end
    info "[RubySearcher::load_items] #{@item_indices.size} cols loaded."
  end
  
  # Regular search with single index
  def search_by_keyword(query, o={})
    indri_query = o[:indri_query] || "#combine(#{InferenceNetwork.parse_query(query).map{|w|w+'.(document)'}.join(' ')})"    
    InferenceNetwork.eval_indri_query(indri_query)
    topk = o[:topk] || 50
    doc_scores = []
    
    @index.docs.each do |doc|
      #debug "[search] Scoring #{doc.did}"
      next if o[:doc] && o[:doc] != doc.did
      begin
        @debug = true if o[:doc]
        @match_found = false
        if doc_score = score_doc(doc,@index)
          next if doc_score <= MIN_NUM
          doc_scores << [doc.did, doc_score] 
        end
      rescue Exception => e
        @debug = true
        error "Error on #{doc.did} #{doc.flm.size} / #{@index.lm.size} " , e
        #debugger
        score_doc(doc,@index)
        exit
      end
    end#each
    doc_scores.sort_by{|e|e[1]}.reverse[0..topk]    
  end
  
  # Search given keyword query
  # - 1) get collection score from parameter
  # - 2) document scoring
  # - merging 1) and 2) into final score
  # @param [Hash] :col_weight : a set of collection weights
  def search_and_merge_by_keyword(query, o={})
    #debugger
    indri_query = o[:indri_query] || "#combine(#{InferenceNetwork.parse_query(query).map{|w|w+'.(document)'}.join(' ')})"
    #info "[searcher_daemon] indri_query = [#{o[:indri_query]}]"
    InferenceNetwork.eval_indri_query(indri_query)
    topk = o[:topk] || 50
    col_weight = o[:col_weight] || 0.4
    doc_scores = {}
    #debugger
    @item_indices.values.each do |col|
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