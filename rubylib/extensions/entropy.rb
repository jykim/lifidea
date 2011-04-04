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
    -map{|k,v| v * log2(pd[k])}.sum
  end
  
  #Kullback–Leibler divergence
  #
  def kld(pd)
    ch(pd) - h()
  end
end
