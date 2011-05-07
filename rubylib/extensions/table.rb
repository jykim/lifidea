# 2D Array working as a Table
# self : [[e1-1, e1-2, ...], [e2-1, e2-2, ...], ...]
# Header/Summary row marked with ("%" )
module Table
  def add_cols(titles, data, o={})
    # Convert into Array
    o[:summary] ||= :mean
    
    titles = [titles] if titles.class == String
    data = data.map{|e|[o[:round_at] ? e.round_at(o[:round_at]) : e]} if data[0].class != Array
    #raise ArgumentError, "Invalid summary argument" if !titles.respond_to?(o[:summary])
    raise ArgumentError, "Every row should have the same size!" if [titles.size].concat(data.map{|e|e.size}).uniq.size > 1
    raise ArgumentError, "Incorrect data size! (#{data.size}+2=#{size})" if data.size + 2 != size
    self[0].concat(titles)
    1.upto(size-2) do |i|
      self[i].concat(data[i-1] )
    end
    if o[:summary] == :none
      self[-1].concat ["summary"]
    else
      self[-1].concat titles.map_with_index{|e,i|
        data.map{|e2|e2[i]}.send(o[:summary]).round_at(3)}
    end
  end
  
  # Create a column by taking difference (col1 - col2)
  def add_diff_col(cid1, cid2, o = {})
    col1 = self.map{|row|row[cid1]}
    col2 = self.map{|row|row[cid2]}
    add_cols((o[:title] || "#{col1[0]}-#{col2[0]}"), col1[1..-2].map_with_index{|e,i| e - col2[i+1]} )
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
