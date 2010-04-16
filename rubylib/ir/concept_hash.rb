
#Hash Data Structure for Storing Multi-word Concept
# - 
class ConceptHash
  MAX_WORDS_IN_TERM = 10
  attr_reader :ch
  
  def initialize
    clear
  end

  def inspect
    p @ch
  end
  
  def clear
    @ch = {} # Concept Hash
    @ct = {} # Concept ID -> Title
  end
    
  # Find Concept(s) from Given Word Sequence
  # - match the longest word
  # @param <String> s : word seq. 
  # @return <Array> ret : array of found tag_ids
  def find_concepts( s )
    jump_count = 0 #prevent matched word from matching again
    ret = []
    return ret if s.blank?
      
    words = s.scan(LanguageModel::PTN_TERM).map{|w|w.downcase}
    0.upto(words.length-1) do |i| #foreach word in sentence
      h = @ch
      if jump_count > 0 then jump_count-=1 ; next end
      
      i.upto(words.length-1) do |j| #foreach word try matching with concept table
        #p " >Checking words[#{i},#{j}] = #{w}"
        w = words[j] #'current word
        wn = words[j+1] if j+1 < words.length # next word
        if !h[w] # no concept is matched
          break 
        elsif h[w].class == Hash #many concepts are matched
          # Next Word doesn't match & key was found
          if !h[w][wn] && h[w][:_key_]
            if block_given?
              yield h[w][:_key_] , words[i..j].join(' ')
            else
              #puts "Found: #{words[i..j].join(' ')}"
              ret << [h[w][:_key_], words[i..j].join(' ')]
            end
            break
          else  #Move to Next Word
            jump_count += 1
            h = h[w]
          end
        elsif h[w].class == Fixnum #one concept is matched
          if block_given?
            yield h[w] , words[i..j].join(' ')
          else
            #puts "Found: #{words[i..j].join(' ')}"
            ret << [h[w], words[i..j].join(' ')]
          end
          break
        else
          error "[ConceptStorage#find_concept] Invalid value #{h[w].inspect}"
        end
      end#do
    end#do
    ret
  end
  
  # Replace concept occurrence with explicit expression:
  def replace_concepts(s)
    concepts = find_concepts(s).uniq
    #debugger
    concepts.each do |e|
      title = @ct[e[0]]
      #puts "Replacing #{title}"
      s.gsub!(/#{title}/i, "#{e[0]}_#{title.to_id}")
    end
  end
    
  #Populate given concept in the ConceptTable
  # - Recursive Hash for storing multi-word concept efficiently
  #  - Hash(3rd Word) of Hash(2nd Word) of Hash(1st Word)
  #  - Integer is the final element
  def put_concepts( id , title )
    @ct[id] = title
    words = title.scan(LanguageModel::PTN_TERM).map{|w|w.downcase}
    if words.length > MAX_WORDS_IN_TERM then $lgr.error("Length exceeded!") end
    h = @ch #Current Position in Rec
    words.each_with_index do |w,i|
      w.downcase!
      if h[w] == nil #value doesn't exist
        if last_index?(words,i)
          h[w] = id
        else
          h = h[w] = { }
        end
      elsif h[w].class == Fixnum #terminal value exists (final word)
        if last_index?(words,i)
          return :exists
        else
          h = h[w] = { :_key_ => h[w] } #current concept is longer than existing concept
        end
      else #non-terminal value exists (h[w].class == Hash)
        h = h[w]
      end
      #p "h: "+h.inspect
    end#do
    #p "@ch : "+@ch.inspect
  end

private
  def last_index?( arr , index  )
    arr.length == index+1
  end
end