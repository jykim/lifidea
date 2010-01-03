#ENV['RAILS_ENV'] = 'production' if ARGV.find_all{|e|e=='--p'}.size > 0
$renv = ENV['RAILS_ENV']
puts "Running on #$renv environment..."
require 'ddl_include'
$start_at = if ENV['all']
  "20010101"
else
  ENV['start_at'] || Date.today.at_beginning_of_month.to_s
end
$end_at = ENV['end_at']   || (Date.tomorrow+1).to_s
$today = Time.now.to_ymd
$cols = Item.itype_lists - ['query','concept']
$type = ENV['type'] || 'col'
$remark = ENV['remark'] if ENV['remark']

def get_feature_file()
  "data/feature-#$renv-#$today-#$type-#$remark.csv"
end

def get_learner_input_file(method = nil)
  method ||= ENV['method']
  "data/learner_input/learner_input-#$renv-#$today-#$type-#{method}-#$remark#$fold.csv"
end

def get_learner_output_file(method = nil)
  method ||= ENV['method']
  "data/learner_output/learner_output_#$renv-#$today-#$type-#{method}-#$remark#$fold.csv"
end

def get_evaluation_file()
  "data/evaluation_#$renv-#$today-#$type-#$remark#$fold.csv"
end

#LEARNER_INPUT = 
