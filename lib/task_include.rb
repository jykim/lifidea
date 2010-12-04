#ENV['RAILS_ENV'] = 'production' if ARGV.find_all{|e|e=='--p'}.size > 0
$renv = ENV['RAILS_ENV'] ||= 'development'
$task_flag = true
$cache = {} if !$cache
#puts "Running on #$renv environment..."
require File.expand_path(File.dirname(__FILE__) + "/../config/environment")
#CACHE = MemCache.new('127.0.0.1') #if defined? MemCache
$start_at = if ENV['all']
  "20010101"
else
  ENV['start_at'] || Date.today.at_beginning_of_month.to_s
end
$end_at = ENV['end_at']   || (Date.tomorrow+1).to_s
$today = ENV['today'] || Time.now.ymd
$cols = ['calendar','webpage','news','file','email'] #Item.itype_lists - ['query','concept']
$type = ENV['type'] || 'csel'
$user = ENV['user'] || 'all'
$method = ENV['method'] || 'grid'
$remark = ENV['remark'] if ENV['remark']

def get_feature_file(type = nil, method = nil)
  type ||= $type
  method ||= $method
  "data/feature/feature-#$renv-#$today-#{type}-#{method}-#$user-#$remark.csv"
end

def get_learner_input_file(type = nil, method = nil)
  type ||= $type
  method ||= $method
  "data/learner_input/learner_input-#$renv-#$today-#{type}-#{method}-#$user-#$remark#$fold.csv"
end

def get_learner_output_file(type = nil, method = nil)
  type ||= $type
  method ||= $method
  "data/learner_output/learner_output_#$renv-#$today-#{type}-#{method}-#$user-#$remark#$fold.csv"
end

def get_evaluation_file(eval_type, type = nil)
  type ||= $type
  omit = "o#{ENV['omit']}" if ENV['omit']
  "data/evaluation/evaluation_#$renv-#$today-#{type}-#{eval_type}-#$user-#$remark-#$fold-#{ENV['train_ratio']}#{omit}.csv"
end

def get_file_postfix(set_type = nil)
  set_type ||= ENV['set_type']
  "#{ENV['train_ratio']}.#{set_type}"
end