#require File.expand_path(File.dirname(__FILE__) + "/../config/environment")
$LOAD_PATH << "#{::Rails.root.to_s}/rubylib" <<"#{::Rails.root.to_s}/app" <<"#{::Rails.root.to_s}/lib"
TEXT_DUMMY = 'dummydummy'
#debugger
require "rubylib_include.rb"
#require "searcher/pd_lib.rb"
require 'ddl_extensions'
require 'ddl_global'
require 'ddl_logger'
require 'collector/collector'
require 'collector/imap_collector'
require 'collector/file_collector'
require 'collector/log_collector'
require 'collector/rss_collector'
require 'collector/ical_collector'
require 'collector/websearch_collector'
require 'collector/collector_runner'
require 'extractor/stat_extractor'
require 'extractor/taxonomy_extractor'
#require 'extractor/document_link_extractor'
require 'extractor/concept_extractor'
require 'searcher/indexer'
require 'searcher/searcher'
#require 'searcher/ruby_searcher'
require 'searcher/solr_searcher'
require 'searcher/context_vector'
require 'searcher/link_features'
require 'searcher/searcher_client'
require 'learner/learner'
require 'learner/evaluator'

#ENV['RAILS_ENV'] = Rails.env
# For graceful termination of daemon processes
$running = true
Signal.trap("TERM") do 
  $running = false
end
