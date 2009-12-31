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
$remark = '_' + ENV['remark'] if ENV['remark']

def get_learner_input_file(fold = nil)
  $fold = "_k#{ENV['folds']}-#{fold}" if fold
  "data/learner_input/learner_input_#{$renv}_#$today#$remark#$fold.txt"
end

def get_learner_output_file(method = 'svm', fold = nil)
  $fold = "_k#{ENV['folds']}-#{fold}" if fold
  "data/learner_output/learner_output_#{$renv}_#{$today}_#{method}#$remark#$fold.txt"
end

#LEARNER_INPUT = 
