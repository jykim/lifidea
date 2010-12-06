module InferenceNetwork
  include Math
  PTN_OP = /\#(wsum|combine)/
  PTN_NODE = /(#{LanguageModel::PTN_TERM})\.\((\w+)\)/
  PTN_WNODE = /([\d\.]+?) (#{LanguageModel::PTN_TERM})\.\((\w+)\)/
  
  
  def self.eval_indri_query(query)
    #debugger
    result = query.gsub(PTN_OP,',op_\1').
      gsub(PTN_WNODE , '[\1,node_ql(\'\2\',d.flm[:\3],c.flm[:\3])],').
      gsub(PTN_NODE  , 'node_ql(\'\1\',d.flm[:\2],c.flm[:\2]),').
      gsub(/\s/,"").gsub(/\,\)/,")").gsub(/\(\,/,"(").gsub(/^\,/,"")
    #puts "[eval_indri_query] result = #{result}"
    module_eval <<END
          def score_doc(d, c)
            #debugger
            #puts "[score_doc] evaluating " + d.did
            result = #{result}
            #puts "Match Found!" if @match_found
            @match_found ? result : MIN_NUM
          end
END
  end
  
  # @param [String] query
  # @return [Array] parsed querywords
  def self.parse_query(query)
    query.strip.scan(LanguageModel::PTN_TERM).map{|e|e.downcase.stem}
  end
  
  def parse_rule(rule)
    #debugger
    rule_parsed = rule.split(",").map_hash{|e|e.split(":")}
    rule_name = rule_parsed['method']
    rule_value = case rule_name
    when 'jm' : rule_parsed['lambda']
    when 'dirichlet' : rule_parsed['mu']
    end
    debug "[parse_rule] #{rule} parsed"
    @rule_name, @rule_value = rule_name, rule_value.to_f
  end
  
  def get_lambda(doc_size)
    case @rule_name
    when 'jm' : @rule_value
    when 'dirichlet' : @rule_value / (@rule_value + doc_size.to_f)
    end
  end
  
  def node_ql(qw, dlm, clm ,o={})
    @match_found = true if dlm.f[qw]
    #debugger
    return 0 if dlm.size == 0
    @lambda = get_lambda(dlm.size)
    debug "[score_ql] #{qw} #{(dlm.f[qw]||0)}* #{(1-@lambda)} / #{dlm.size} + #{(clm.f[qw]||0)} * #{@lambda} / #{clm.size}" if @debug
    cql = (clm.ql[qw] ||= ((clm.f[qw]||0) * @lambda / clm.size))
    (dlm.f[qw]||0) * (1.0-@lambda) / dlm.size + cql
  end
  
  # args = [[weight1,score1], [weight2,score2], ...]
  def op_wsum(*args)
    debug "#wsum(#{args.map{|e|e.join('*')}.join(' ')})" if @debug
    sum_weights = args.map{|e|e[0]}.sum
    args.find_all{|e|e[0]>0}.map{|e|e[0] * e[1] / sum_weights}.sum
  end
  
  # args = [score1, score2, ...]
  def op_combine(*args)
    debug "#combine(#{args.join(" ")})" if @debug
    args.find_all{|e|e>0}.map{|e|log(e)}.sum / args.size
  end
end