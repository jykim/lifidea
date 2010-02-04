load 'extensions/rails_extensions.rb'
load 'extensions/table.rb'
load 'extensions/statistics.rb'
load 'extensions/vector.rb'
load 'extensions/probability.rb'
load 'extensions/entropy.rb'

class MyException < Exception
  
end

class Time
  def ymdhms
    strftime('%Y%m%d%H%M%S')
  end
  
  # never redefine a method of standard library unless you know what you're doing 
  #def to_s
  #  strftime('%Y-%m-%d %H:%M:%S')
  #end
  
  def ymd
    strftime('%Y%m%d')
  end
end

module Math
  MIN_PROB = 0.0000001
  MIN_NUM = -99999
  def log2(numeric)
    #raise ArgumentError if !numeric
    log(numeric) / log(2)
  end

  def log10(numeric)
    log(numeric) / log(10)
  end
  
  #Safe log
  def slog(numeric)
    (numeric > 0)? log(numeric) : (puts "[slog] arg = #{numeric}"; MIN_NUM)
  end
  
  def self.max(a, b)
    a > b ? a : b
  end

  def self.min(a, b)
    a < b ? a : b
  end
end

class String
  #include Stemmable

  #Detect Korean Language
  # alternative : comparing each_byte & each_char 
  # just use mbchar?'
  def utf8?
    self =~ String::RE_UTF8
  end
  
  def clear_tags()
    gsub(/\<\/?\w+?\>/, "")
  end
  
  def round(at = 5)
    gsub(/\.[0-9]{#{at},}/){|match|match[0..at]}
  end
  
  def find_tag(tag_name)
    r = scan(/\<#{tag_name}\>(.*?)\<\/#{tag_name}\>/im)
    r.map{|e|e.first}
  end

  #  Replace the name of given tag into another
  # "<a>sdssd</a>".replace_tag('a','b')
  # => <b>sdssd</b>
  def replace_tag(tag_name, tag_name_after)
    gsub(/\<#{tag_name}\>(.*?)\<\/#{tag_name}\>/im, "<#{tag_name_after}>\\1</#{tag_name_after}>")
  end
end

class Array
  include Statistics, Table
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

class Float
  def round_at(places)
   temp = self.to_s.length
   sprintf("%#{temp}.#{places}f",self).to_f
  end

  def r3
    round_at(3)
  end

  def r1
    round_at(1)
  end

  def r2
    round_at(2)
  end
end

class Fixnum
  def round_at(places)
    self.to_f
  end
end

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


class NilClass
  def to_hash
    {}
  end
  
  def in_time_zone(arg)
    nil
  end
end
