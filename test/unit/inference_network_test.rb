require 'test_helper'

class InferenceNetworkTest < Test::Unit::TestCase 
  include InferenceNetwork
  def setup
    @query = '#combine(#wsum(0.6 t1.(a) 0.4 t1.(b)) #wsum(0.3 t2.(a) 0.7 t2.(b)))'
    @searcher = Searcher.new
  end

  def test_eval()
    InferenceNetwork.eval_indri_query(@query)
    #@searcher.score_doc(nil)
  end
end
