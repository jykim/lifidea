class History < ActiveRecord::Base
  serialize :metadata, Hash
  alias_attribute :m, :metadata
  
  named_scope :between, lambda{|start_at, end_at| {:conditions=>
    ["created_at >= ? and created_at < ?", start_at, end_at]}}
end
