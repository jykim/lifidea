# Array of Data Values
module ValueArray
  # distribution of values
  # - if bucket_size is given group them by bucket
  # self : [x1,x2,...]]
  def to_dist(o={})
    if o[:bucket_size]
      bucket = o[:bucket_size] || 100
      h = Hash.new(0)
      each do |v|
       bin = v / bucket if v
        h[bin*bucket] += 1
      end
      h
    else
      group_by{|e|e}.map_hash{|k,v|[k,v.size]}
    end
  end
  
  def to_pdist(o={})
    to_dist(o).to_p
  end
end

# Set of Probability Distributions
module ProbabilityDistributionArray
  # Merge values of hash by smoothing
  # @example
  #  {:title=>{:a=>0.6,:b=>0.4}, :content=>{:a=>0.4,:b=>0.6}}.merge_elements => {:a=>0.5,:b=>0.5}
  def merge_by_smooth()
    result = {}
    each{|e| result = result.smooth(0.5, e).times(2) }
    result.times(1.0/size)
  end
  
  alias merge_elements merge_by_smooth
  
  # @example
  # {:x=>{:a=>0.4,:b=>0.6},:y=>{:a=>0.3,:b=>0.6}}.merge_by_product
  # => {:a=>0.12, :b=>0.36}
  def merge_by_product()
    #raise ArgumentError, "Every element should have same no. of keys" if values.map{|h|h.size}.uniq.size > 1
    result = {}
    each{|e| result = result.product(e) }
    result
  end
  
  def merge_by_sum()
    result = {}
    each{|e| result = result.sum_prob(e) }
    result
  end
end


module ProbabilityOperator
  # key generated by dice using value as probability
  # @example
  #  {[a,0.5],[b,0.3],[c,0.2]}
  def sample_pdist(times = 1)
    #return nil if !prob?
    seeds = [] ; results = []
    0.upto(times-1){|i| seeds[i] = rand()}
    cum_val = 0
    map{|k,v|[k , cum_val += v]}.each do |e| #sort_by{|k,v|k}.
      seeds.each_with_index do |seed, i|
        results[i] = e[0] if !results[i] && seed < e[1]
      end
    end
    return results
  end
  
  alias dice sample_pdist
  
  # linear interpolation of two distributions
  # @example
  #  {:a=>0.3,:b=>0.7}.smooth(0.5) 
  #  => a0.4b0.6
  def smooth(lambda  = 0.5, other = nil)
    other = self.map_hash{|k,v|[k,1.0/size]} if !other
    #merge(other){|k,v1,v2|v1+v2}.map_hash{|k,v|[k,v/2]}
    map_hash{|k,v|[k,v*(1-lambda)]}.merge(other.map_hash{|k,v|[k,v*lambda]}){|k,v1,v2|v1+v2}
  end
  
  # @example
  #  {:a=>1,:b=>2}.sum(:b=>5,:c=>1).inspect
  #  => {:b=>7, :c=>1, :a=>1}
  def sum_prob(other)
    self.merge(other){|k,v1,v2|v1+v2}
  end
  
  # Multiply each element by x 
  # @example
  #  {:a=>1,:b=>2}.times(2)
  #  => {:a=>2, :b=>4}
  def times(x)
    map_hash{|k,v|[k,v*x]}
  end
end

module ProbabilityTransformer
  #Convert into the log of probability
  def prob2log()
    map_hash{|k,v| [k , Math.log(v)]}
  end
  
  #Convert into the log of probability
  def log2prob()
    map_hash{|k,v| [k , Math.exp(v)]}
  end
  
  def r2
    map_hash{|k,v| [k , v.r2]}
  end
  
  def r3
    map_hash{|k,v| [k , v.r3]}
  end
    
  #Take the inverse of probability value
  def inverse()
    map_hash{|k,v|[k,1/v] if v > 0}.to_p
  end
  
  def add_noise(degree = 1.0)
    map_hash{|k,v|[k,v+rand()*degree]}.to_p
  end
  
  def times(n)
    map_hash{|k,v|[k,v*n]}
  end

  def to_cum
    to_a.to_cum.map_hash{|e|[e[0] , e[1]]}
  end
end
