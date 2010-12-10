require 'test_helper'

class TestContextVector < Test::Unit::TestCase 
  def setup
    @cv = ContextVector.new ; @cv.clear
    @ss = SolrSearcher.new
    @ss.build_context_vector()
  end
  
  def test_add_context
    #@cv.get().each{|e|puts "title : #{e[:query]}"}
    #debugger
    assert( 3, @cv.get().size )
  end
  
  def test_get_context
    assert( 1, @cv.get(1, 'doc').size )
    assert( 1, @cv.get(2, 'doc').size )
    assert( 2, @cv.get(3, 'doc').size )
    #@cv.get(3).each{|e|puts "title : #{e[:query]}"}
  end
end 
