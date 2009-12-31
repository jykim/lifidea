#!/usr/bin/env ruby

# You might want to change this
ENV["RAILS_ENV"] ||= "production"

require File.dirname(__FILE__) + "/../../config/environment"

$running = true
Signal.trap("TERM") do 
  $running = false
end

load File.dirname(__FILE__) + "/../../app/batch_job_handler.rb"

Delayed::Worker.new.start