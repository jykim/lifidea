require 'rubylib_include'

class TestVector < Test::Unit::TestCase 
  def setup
    @v1 = {:a=>1, :b=>2, :c=>3}
    @v2 = {:b=>1, :c=>2, :d=>3}
  end
  
  def test_normalize
    assert_equal(@v1.normalize, Math.sqrt(14))
  end
  
  def test_cosim
    assert_equal(8, @v1.product(@v2).sum{|k,v|v})
    assert_equal(8/14.0, @v1.cosim(@v2))
  end
end 
