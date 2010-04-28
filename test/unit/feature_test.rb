require 'test_helper'

class TestVector < Test::Unit::TestCase 
  def setup
  end
  
  def test_string_sim
    
  end
  
  def test_cosim
    
  end
  
  def test_word_sim
    assert_equal(0, "".word_sim(""))    
  end
  
  def test_path_sim
    assert_equal(0, "".path_sim(""))
    assert_equal(1/3.0, "aa/bb/cc".path_sim("aa/cc"))
    assert_equal(2/3.0, "aa/bb/cc".path_sim("aa/bb"))
    assert_equal(2/4.0, "aa/bb/cc/dd".path_sim("aa/bb"))
  end
end
