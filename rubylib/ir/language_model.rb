# LanguageModel Library
# - Initialize from Frequency Distribution
class LanguageModel
  attr_accessor :f, :p, :size, :ql
  PTN_TERM = /[A-Za-z0-9]+/
  def initialize(input, o = {})
    #return if !text
    #puts "#{input.inspect}"
    @ql = {} # cache of query likelihood
    @f = case input.class.to_s
    when "Hash" # fdist
      input
    when "String"
      #@text = input
      if input.blank?
        {}
      else
        input.clear_tags.scan(PTN_TERM).map{|e|e.downcase.stem}.find_all{|e|!$stopwords.has_key?(e)}.to_dist
      end
      #input.clear_tags.scan(PTN_TERM).map{|e|e.downcase.stem}.to_dist
    else
      {}#raise ArgumentError
    end
    #puts @f.inspect
    @size = @f.values.sum
  end
  
  # Background probability for smoothing
  # - reciprocal of the vocabulary size
  def bg_prob
    @bg_prob ||= 1.0 / @size
  end
  
  def prob(word)
    return $min_prob || Math::MIN_PROB if @size == 0
    return $min_prob || Math::MIN_PROB if !@f[word]
    @f[word].to_f / @size
  end
  
  def p
    @p ||= @f.map_hash{|k,v|[k,v.to_f / @size]}
  end
  
  def kld(lm)
    lm_p = lm.p
    self.p.map{|k,v|v * (Math.log(v) - Math.log(lm_p[k]||Math::MIN_NUM))}.sum
  end
  
  # Calculate tf*idf vector of current LM
  # @param [Hash<String,Float>] df : hash of df values
  def tfidf(df, doc_no)
    @f.map_hash{|k,v|[k, v * Math.log(doc_no.to_f/df[k])]}
  end
  
  def size()
    #puts "size called!" if print
    @size
  end
  
  def to_text
    @f.map{|t,f|([t]*f).join(" ")}.join("\n")
  end
  
  def to_yaml
    @f.to_yaml
  end
  
  def update(fdist)
    @f = @f.sum_prob(fdist)
  end
  
  def self.create_by_merge(fdists)
    LanguageModel.new(fdists.merge_by_sum())
  end
end