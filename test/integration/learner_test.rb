require 'test_helper'
require 'task_include'
require 'rake'

class LearnerTest < ActiveSupport::TestCase
  def setup()
    @l = Learner.new
    Searcher.export_sim_feature('doc')
    assert(File.stat(get_feature_file('doc', 'ranksvm')).size > 0, 'exported file should not be empty!')
  end
    
  # Test GridSearch
  # - export feature
  # - learn with the file (without split)
  # - evaluate against single-feature runs
  def test_grid_learner()
    learn_result = @l.learn('doc', 'grid', get_feature_file('doc'), get_learner_output_file('doc'))
    eval_result = Evaluator.export_sim_evaluation_result('doc', ['grid'], get_feature_file('doc'), get_evaluation_file('doc'))

    assert_equal( learn_result.sort_by{|e|e[0]}[-1][0].to_f.r3, eval_result[-1][-1], "Learner output should be equal to evaluator output" )
    assert_equal( eval_result[-1][-1], eval_result[-1][1..-1].max, "Grid should outperform single-feature runs" )
    #puts `cat #{get_evaluation_file('doc')}`
  end
  
  def test_ranksvm_learner()
    learn_result = @l.learn('doc', 'ranksvm', get_feature_file('doc','ranksvm'), get_learner_output_file('doc','ranksvm'))    
  end
end