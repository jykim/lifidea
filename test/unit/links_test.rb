require 'test_helper'

class LinksTest < ActiveSupport::TestCase
  # Replace this with your real tests.
  test "link features" do
    lf = LinkFeatures.new
    lf.load Link.all.map{|l|[l.ltype, l.out_id.to_i, l.in_id.to_i, l.weight]}
    assert_equal(1, lf.read('o',1,2))
    assert(lf.read('o',1,2) == lf.read('o',2,1))
    assert_equal(3, lf.read_sum('o',1))
  end
end
