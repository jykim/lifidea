#!/usr/bin/env ruby
# Periodic indexing of updated items
require File.dirname(__FILE__) + "/../../lib/daemon_include.rb"
$index_interval = get_config('INDEX_INTERVAL') || 300
debug "Running in #{ENV['RAILS_ENV']}"
while($running) do
  $idx ||= Indexer.new
  all_docs = $idx.find_target_items
  if all_docs.size == 0
    debug "[indexer.rb] No target item!"
    sleep $index_interval
    next
  end
  warn "[indexer.rb] Started indexing #{all_docs.size} docs"
  # @TODO substitute with batch finder
  $idx.index_item_set(all_docs)
  
  #notify Searcher on the change
  sleep $index_interval / 5
end
