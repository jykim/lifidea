class History < ActiveRecord::Base
  serialize :metadata, Hash
  belongs_to :user
  belongs_to :item
  alias_attribute :m, :metadata
  
  scope :between, lambda{|start_at, end_at| {:conditions=>
    ["created_at >= ? and created_at < ?", start_at, end_at]}}
end
