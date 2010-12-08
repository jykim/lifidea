require 'test_helper'

class TestContextVector < Test::Unit::TestCase 
  def setup
    @cv = ContextVector.new
    @ss = SolrSearcher.new
    @ss.build_context_vector()
  end
  
  def test_add_context
    puts @cv.get().inspect
  end
  
  def test_get_context
    
  end
end 
