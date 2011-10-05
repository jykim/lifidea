class String
  #include Stemmable

  #Detect Korean Language
  # alternative : comparing each_byte & each_char 
  # @todo just use mbchar?'
  def utf8?
    self =~ String::RE_UTF8
  end
  
  # Convert key-value into hash
  # self : "k1=v1|k2=v2"
  def to_hash
    split("|").map_hash{|e|e2 = e.split("=") ; [e2[0].to_sym, e2[1]]}
  end
  
  # Clean up newline to unix format
  def to_lf
    self.gsub("\n\r","\n").gsub("\r","\n")
  end
  
  def clear_tags(replace_with = "")
    gsub("&lt;","<").gsub("&gt;",">").gsub(/\<\/?\w+?\>/, replace_with)
  end
  
  def round(at = 5)
    gsub(/\.[0-9]{#{at},}/){|match|match[0..at]}
  end
  
  # Find the content of xml tag
  def find_tag(tag_name)
    r = scan(/\<#{tag_name}\>(.*?)\<\/#{tag_name}\>/im)
    r.map{|e|e.first}
  end

  #  Replace the name of given tag into another
  # "<a>sdssd</a>".replace_tag('a','b')
  # => "<b>sdssd</b>"
  def replace_tag(tag_name, tag_name_after)
    gsub(/\<#{tag_name}\>(.*?)\<\/#{tag_name}\>/im, "<#{tag_name_after}>\\1</#{tag_name_after}>")
  end
  
  # Path overlap measure
  # - count word overlap from the beginning of the path
  def path_sim(other)
    path_arr = self.scan(/\w+/)
    path_arr2 = other.scan(/\w+/)
    return 0 if path_arr.size == 0 || path_arr2.size == 0
    max_length = Math.max(path_arr.size, path_arr2.size)
    path_overlap = 0 ; 0.upto(max_length-1){|i|
      if path_arr[i] == path_arr2[i]
        path_overlap += 1
      else
        break
      end
    }
    path_overlap / max_length.to_f
  end
  
  # Word-level overlap measure
  def word_sim(other)
    word_arr = self.scan(/\w+/)
    word_arr2 = other.scan(/\w+/)
    word_arr.overlap(word_arr2)
  end
  
  # String similarity based on normalized Levenshetein Distance
  def str_sim(other)
    max = Math.max(self.size, other.size)
    min = (self.size - other.size).abs.to_f
    1 - (self.levenshtein(other)-min) / (max - min)
  end
  
  # Levenshetein Distance
  def levenshtein(other, ins=1, del=1, sub=1)
    # ins, del, sub are weighted costs
    return nil if self.nil?
    return nil if other.nil?
    dm = []        # distance matrix

    # Initialize first row values
    dm[0] = (0..self.length).collect { |i| i * ins }
    fill = [0] * (self.length - 1)

    # Initialize first column values
    for i in 1..other.length
      dm[i] = [i * del, fill.flatten]
    end

    # populate matrix
    for i in 1..other.length
      for j in 1..self.length
    # critical comparison
        dm[i][j] = [
             dm[i-1][j-1] +
               (self[j-1] == other[i-1] ? 0 : sub),
                 dm[i][j-1] + ins,
             dm[i-1][j] + del
       ].min
      end
    end

    # The last value in matrix is the
    # Levenshtein distance between the strings
    dm[other.length][self.length]
  end
end
