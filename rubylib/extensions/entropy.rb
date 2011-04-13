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
    map{|k,v| !(v == 0 || pd[k] || pd[k] == 0) ? 0 : (v * log2(v / pd[k])) }.sum
  end
  
  # KL Divergence with smoothing
  def kld_s(pd, mu = 0.00001)    
    p = self.to_p.smooth(mu)
    q = pd.to_p.smooth(mu, p.map_hash{|k,v|[k,1.0/p.size]})
    p.kld(q)
  end
end
