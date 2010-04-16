require 'test_helper'

class TestConceptHash < Test::Unit::TestCase 
  def setup
    @ch = ConceptHash.new
    @words = ['korean','korean boy','korean handsome boy', 'korean food','korean food kimchi',
      'japanese','japanese food', 'chinese food', 'french', 'dannish'].map_hash_with_index{|e,i|[i,e]}
    @words.each{|k,v| @ch.put_concepts(k,v)}
    debug @ch
  end
  
  # 
  def test_word_lookup
    @words.each do |k,v| 
      debug "Concept : #{v}(#{k}th)"
      assert_equal(1, @ch.find_concepts(v).size, "only one concept is returned")
      assert_equal(k, @ch.find_concepts(v)[0][0], "right concept was returned")
    end
  end
  
  # 
  def test_multiple_match
    str = "boy korean food"
    assert_equal([], @ch.find_concepts(str).map{|c|c[0]} - [3])
    str += " kimchi japanese"
    assert_equal([], @ch.find_concepts(str).map{|c|c[0]} - [4,5])
  end
end 
