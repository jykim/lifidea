require 'rubylib_include'

class ProbabilityTest < Test::Unit::TestCase
  def setup
    @p10 = (1..10).to_a.to_pdist
  end
  # Replace this with your real tests.
  def test_operators
    assert_equal({:a=>0.5,:b=>0.5} , {:a=>0.4,:b=>0.6}.smooth(0.5, {:a=>0.6,:b=>0.4}), "smoothing")
  end
  
  def test_sampling
    assert_equal([1], (1..1).to_a.to_pdist.sample(100).to_pdist.keys, "one element sampling")
    assert_equal([1,2], (1..2).to_a.to_pdist.sample(100).to_pdist.keys, "two elements sampling")
    assert_in_delta(5.5, @p10.sample(10000).mean, 0.1, "equal dist.")
  end
  
  def test_noise
    assert(@p10.kld(@p10.add_noise(0.01)) - @p10.kld(@p10.add_noise(0.1)) < 0, 
      "higher D_KL as more noise is added")
  end

  def test_merging
    dists = []
    0.upto(10){|i| dists[i] = @p10.sample(100).to_pdist}
    result1 = dists.merge_by_sum()
    result2 = {}
    #p dists
    dists.each{|e|1.upto(10){|i|(result2[i])? (result2[i] += e[i]) : (result2[i] = e[i])}}
    assert_equal(result2, result1)
  end

end
