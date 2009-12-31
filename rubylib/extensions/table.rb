# 2D Array working as a Table
# self : [[e1-1, e1-2, ...], [e2-1, e2-2, ...], ...]
# Header/Summary row marked with ("%" )
module Table
  def add_cols(titles, data, o={})
    # Convert into Array
    o[:summary] ||= :mean
    
    titles = [titles] if titles.class == String
    data = data.map{|e|[e]} if data[0].class != Array
    raise ArgumentError, "Invalid summary argument" if !titles.respond_to?(o[:summary])
    raise ArgumentError, "Inconsistent size!" if [titles.size].concat(data.map{|e|e.size}).uniq.size > 1
    raise ArgumentError, "Incorrect data size! (#{data.size}+2=#{size})" if data.size + 2 != size
    self[0].concat(titles)
    1.upto(size-2) do |i|
      self[i].concat(data[i-1])
    end
    self[-1].concat titles.map_with_index{|e,i|data.map{|e2|e2[i]}.send(o[:summary])}
  end
  
  def export_tbl(filename,o={})
    File.open(filename, 'w'){|f|f.puts self.map{|e|e.join(",")}.join("\n")}
  end
  
  def transpose
    raise ArgumentError, "Inconsistent size!" if map{|e|e.size}.uniq.size > 1
    result = []
    0.upto(self[0].size-1){|i|result << self.map{|e|e[i]}}
    result
  end
end
