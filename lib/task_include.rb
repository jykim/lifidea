#ENV['RAILS_ENV'] = 'production' if ARGV.find_all{|e|e=='--p'}.size > 0
$renv = ENV['RAILS_ENV']
$task_flag = true
$cache = {}
#puts "Running on #$renv environment..."
require 'ddl_include'
require File.expand_path(File.dirname(__FILE__) + "/../config/environment")
$start_at = if ENV['all']
  "20010101"
else
  ENV['start_at'] || Date.today.at_beginning_of_month.to_s
end
$end_at = ENV['end_at']   || (Date.tomorrow+1).to_s
$today = ENV['today'] || Time.now.ymd
$cols = ['calendar','webpage','news','file','email'] #Item.itype_lists - ['query','concept']
$type = ENV['type'] || 'csel'
#$method = ENV['method'] || 'grid'
$remark = ENV['remark'] if ENV['remark']

def get_feature_file(method = nil)
  method ||= ENV['method']
  "data/feature-#$renv-#$today-#$type-#{method}-#$remark.csv"
end

def get_learner_input_file(method = nil)
  method ||= ENV['method']
  "data/learner_input/learner_input-#$renv-#$today-#$type-#{method}-#$remark#$fold.csv"
end

def get_learner_output_file(method = nil)
  method ||= ENV['method']
  "data/learner_output/learner_output_#$renv-#$today-#$type-#{method}-#$remark#$fold.csv"
end

def get_evaluation_file(eval_type)
  "data/evaluation_#$renv-#$today-#$type-#{eval_type}-#$remark#$fold.csv"
end

#LEARNER_INPUT = 
