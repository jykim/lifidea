# Hash as sparse Vector
module SparseVector
  def vsize
    Math.sqrt(values.inject(0){|sum,e| sum + e ** 2})
  end
  
  def product(other)
    result = 0.0
    each do |k,v|
      result += v * other[k] if v && other[k]
    end
    result
    #self.merge(other){|k,v1,v2|v1*v2}
  end
  
  def cosim(other)
    #debugger
    #p self
    #p other
    self.product(other) / (self.vsize * other.vsize)
  end
end
