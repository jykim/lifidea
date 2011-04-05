#Information-theoretic Operations
# - Instance is assumed to be a ProbabilityDistribution (sum of element = 1)
module Entropy
  include Math
  def h
    return nil if !prob?
    -inject(0){|total,e| total + e[1] * log2(e[1]) }
  end
  
  #Cross Entropy
  # - Bits when encoding self with suboptimal distribution p
  def ch(pd)
    -map{|k,v| !(pd[k]) ? 0 : (v * log2(pd[k])) }.sum
  end
  
  #Kullback–Leibler divergence
  # {:a=>0.5,:b=>0.5}.kld(:a=>0.4,:b=>0.6)
  def kld(pd)
    ch(pd) - h()
  end
end
