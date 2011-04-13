
module Enumerable
  #Iterate in parallel using thread
  #[1,2,3,4,5].each_with_thread{|e,i|sleep i ; puts i}
  def each_with_thread
    tg = ThreadGroup.new
    self.each_with_index do |elt,i|
      thr = Thread.new(elt,i) do |elt,i|
        yield elt, i
      end
      tg.add thr  
    end
    tg.list.each_with_index do |thr , i|
      thr.join
    end
    self
  end

  def map_hash
    result = {}
    self.each do |elt|
      key, value = yield elt
      result[key] = value if key
    end
    result
  end

  def map_hash_with_index
    result = {}
    self.each_with_index do |elt, i|
      key, value = yield elt, i
      result[key] = value if key
    end
    result
  end

  def map_with_index
    # Ugly, but I need the yield to be the last statement in the map.
    i = -1 
    return map { |item|
      i += 1
      yield item, i
    }
  end

  def find_with_index
    # Ugly, but I need the yield to be the last statement in the map.
    i = -1 
    return find_all { |item|
      i += 1
      yield item, i
    }
  end
end


class Array
  include Statistics, Table, ProbabilityOperator
  include ValueArray, ProbabilityDistributionArray
  # Collapse the outermost array
  # [[1].[2],[[3]]].collapse -> [1,2,[3]]
  def collapse()
    result = []
    each{|e|result.concat(e) if e.class == Array }
    result
  end

  def map_cons(n)
    result = []
    each_cons(n){|e|result << e }
    result
  end
  
  #  combination of members
  # [a,b,c] => [[a,b],[a,c],[b,c]]
  def to_comb
    a = []
    map_with_index{|e1,i| map_with_index{|e2,j| a << [e1,e2] if i < j}}
    a
  end
  
  def pad(n, pad_elem = nil)
    if size < n
      self.concat([pad_elem]*(n-size))
    else
      self[0..(n-1)]
    end
  end

  #def to_s
  #  join("\n")
  #end
  
  def find_valid
    find_all{|e| !e.blank? }
  end
  
  # Given array of numbers
  # return the multiplication of all
  def multiply
    inject(1){|e,r|e*r}
  end
  
  # Given array of numbers
  # return the multiplication of log
  def multiply_log
    find_all{|e|e>0}.inject(0){|e,r|e+Math.log(r)}
  end
  
  #Iterate over both items
  def each_both(a)
    return false if size != a.size
    length.times do |i|
      yield at(i) , a.at(i)
    end
    return true
  end
  
  #'each' without return value
  # DEPRECATED
  def each2
    length.times do |i|
      yield at(i)
    end
    return
  end
  
  # Normalize value into probability
  # self : [[k1,v1],...], [v1,v2,...]
  def to_p()
    if self[0].class == Array
      v_sum = map{|e|e[1]}.sum
      map{|e|[e[0] , e[1]/v_sum.to_f]}
    else
      collect{|e| e.to_f / sum}
    end
  end
end

class Hash
  include ProbabilityOperator, ProbabilityTransformer
  include Entropy, SparseVector
  
  def max_pair
    max{|e1,e2|e1[1]<=>e2[1]}
  end
  
  def prob?()
    #assert_in_delta(1, values.sum, 0.0001)
    size > 0
  end
  
  def to_p()
    sum = values.sum
    map_hash{|k,v| [k , v.to_f / sum]}
  end

  def each2
    self.each{|k,v| yield k , v }
    return
  end

  #Ordered Each
  def oeach2
    self.keys.sort.each{|k| yield k , self[k]}
    return
  end
  
  #Iterate with given hash
  def each_both(h)
    self.each{|k,v| yield v , h[k]}
    return
  end
end