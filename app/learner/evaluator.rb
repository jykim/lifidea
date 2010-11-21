# Evaluation of Algorithms
class Evaluator
  def initialize(args)
    
  end
  
  # Calculate Reciprocal Rank
  def self.recip_rank(rank_list, rel)
    #p rank_list,rel
    result = 0.0
    rank_list.each_with_index{|e,i| result = 1.0 / (i+1) if e[0] == rel}
    result
  end
  
  def self.evaluate_sim_query_set(input, features, weights)
    result_all = []
    searcher = SolrSearcher.new
    qrels = Learner.parse_ranksvm_input(input)
    qrels.each do |ids|
      result = [] ; query, rel = ids[0].to_i, ids[1].to_i
      weights.each_with_index do |weight,i|
        rank_list = searcher.search_by_item(query, $type, :features=>features, :weights=>weight).map{|fts|[fts[:id], fts[:score]]}
        result << self.recip_rank(rank_list, rel)
      end
      result_all << [query, result].flatten #if result[0] > 0 # use only entries where relevant items were found
    end
    average = (1..(weights.size)).map{|e|result_all.map{|e2|e2[e]}.mean}
    result_all << ["summary(#$type/#$set_type)", average].flatten
  end
  
  def self.evaluate_sim_search_with(input_data, type, weights, o={})
    result = {}
    #puts weights.inspect
    searcher = SolrSearcher.new
    #debugger
    input_data.each do |ids|
      query, rel = ids[0].to_i, ids[1].to_i
      #puts "Query : #{query} -> Rel : #{rel}"
      #debugger
      rank_list = searcher.search_by_item(query, type, :features=>o[:features], :weights=>weights).map{|fts|[fts[:id], fts[:score]]}
      #puts rank_list.inspect
      result[query] = self.recip_rank(rank_list, rel)
    end
    [result.values.mean, weights].flatten
  end
  
  def self.evaluate_keyword_search_with(input_data, weights = nil, o={})
    result = {}
    if !$searcher
      $searcher = Searcher.new(o)
      $searcher.load_documents()
    end
    $searcher.parse_rule(o[:rule]) if o[:rule]
    input_data.each do |l|
      o.merge!(:col_scores=>Learner.get_col_scores(l, weights)) if weights
      rank_list = $searcher.search_by_keyword(l[:query], o)
      result[l[:qid]] = self.recip_rank(rank_list, l[:did])
      debug "Q[#{l[:qid]}] #{result[l[:qid]]} (#{o[:rule]} / #{l[:query]} )"
    end
    [result.values.mean, weights].flatten
  end
  
  # Get collection-level score 
  # @param [Array<String>] input_line : each line of input_data
  def self.get_col_scores(input_line, weights)
    $cols.map_hash{|col|
      [col, ($cs_types || Searcher::CS_TYPES).map_with_index{|cs_type,i|input_line[[cs_type, col].join('_').to_sym].to_f * weights[i] }.sum]}
  end
  
  # @param [Array] input_data : parsed csv of input_learner_col*
  def self.evaluate_csel_with(input_data, weights, o={})
    result = {}
    col_scores = []
    input_data.each_with_index do |l,i|
      col_scores[i] = Learner.get_col_scores(l, weights)
      #p values_col.max_pair
      result[l[:qid]] = (l[:itype] == col_scores[i].max_pair[0])? 1.0 : 0.0
    end
    [result.values, weights, col_scores]#.flatten
  end
  
  def self.split_file(filename, data, o={})
    result_train, result_test = [o[:header]], [o[:header]]
    data.each_with_index do |e,i|
      #puts rand(), train_ratio
      if o[:test_set]
        if !o[:test_set].include?(i)
          if o[:train_ratio] && (o[:random] ? rand() : i.to_f / data.size) > o[:train_ratio].to_f
            next
          else
            result_train << e
          end
        else
          result_test << e
        end
      elsif o[:train_ratio]
        if (o[:random] ? rand() : i.to_f / data.size) >= o[:train_ratio].to_f
          result_test << e
        else
          result_train << e
        end
      else
        puts "[split_file] No parameter specified!"
      end
    end
    File.open(filename+"#{o[:train_ratio]}.train",'w'){|f|f.puts result_train.find_valid.join}
    File.open(filename+"#{o[:train_ratio]}.test" ,'w'){|f|f.puts result_test.find_valid.join}
  end
  
  def self.conv_file(filename, method)
    col_hash = $cols.map_hash_with_index{|e,i|[e, i+1]}
    result = []
    read_csv(filename,:output=>:array).each_with_index do |l,i|
      rel_col = l[6]
      case method
      when 'liblinear'
        result << [col_hash[rel_col]].concat(l[7..-1].map_with_index{|e,j|[j+1,e].join(":")})
      when 'ranksvm'
        raise DataError, "Col size not consistent! #{l[7..-1].size}!=#{$cols.size * RubySearcher::CS_TYPES.size}" if l[7..-1].size != $cols.size * RubySearcher::CS_TYPES.size
        values_col = l[7..-1].map_with_index{|e,j|[e,j]}.group_by{|e|e[1]/RubySearcher::CS_TYPES.size}
        result.concat values_col.map{|col,features|
          [((col+1 == col_hash[rel_col])? 2 : 1), "qid:#{i+1}", features.map_with_index{|e,j|[j+1,e[0]].join(":")}].flatten
          }.sort_by{|e|e[0]}.reverse
      end
    end
    File.open(filename.gsub(/grid/,method), 'w'){|f|f.puts result.map{|e|e.join(" ")}.join("\n")}
  end
  
end