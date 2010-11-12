#require File.expand_path(File.dirname(__FILE__) + "/../config/environment")
$LOAD_PATH << "#{RAILS_ROOT}/rubylib" <<"#{RAILS_ROOT}/app" <<"#{RAILS_ROOT}/lib"
#debugger
require "rubylib_include.rb"
#require 'feed-normalizer'
#require 'tmail'
#require 'ruby-debug'
#require 'fastercsv'
#require 'ri_cal'#'icalendar'
#require 'icalendar'#'icalendar'
#require 'sunspot'
#require 'sunspot/rails'

require "searcher/pd_lib.rb"
require 'ddl_extensions'
require 'ddl_global'
require 'collector/collector'
require 'collector/imap_collector'
require 'collector/file_collector'
require 'collector/log_collector'
require 'collector/rss_collector'
require 'collector/ical_collector'
require 'collector/websearch_collector'
require 'collector/collector_runner'
require 'extractor/stat_extractor'
require 'extractor/document_link_extractor'
require 'extractor/concept_extractor'
require 'searcher/indexer'
require 'searcher/searcher'
require 'searcher/ruby_searcher'
require 'searcher/solr_searcher'
require 'searcher/link_features'
require 'searcher/searcher_client'
require 'learner/weight_learner'

$lgr_e = Logger.new( File.expand_path(File.dirname(__FILE__) + "/../log/#{ENV["RAILS_ENV"]}_error.log") )

require 'memcache'
#require 'memcache-client'
#CACHE = Memcache.new('127.0.0.1') #if defined? MemCache
