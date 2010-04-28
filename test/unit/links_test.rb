require 'test_helper'

class LinksTest < ActiveSupport::TestCase
  

  # Test the consistency of link feature values
  def test_link_feature
    lf = LinkFeatures.new
    lf.load Link.all.map{|l|[l.ltype, l.out_id.to_i, l.in_id.to_i, l.weight]}
    assert_equal(1, lf.read('o',1,2))
    assert(lf.read('o',1,2) == lf.read('o',2,1), "return different value!")
    assert_equal(3, lf.read_sum('o',1), "invalue sum of weights")
  end
end
