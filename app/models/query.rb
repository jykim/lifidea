# Each query in pagehunt
class Query < ActiveRecord::Base
  belongs_to :user
  belongs_to :item
  
  named_scope :between, lambda{|start_at, end_at| {:conditions=>
    ["created_at >= ? and created_at < ?", start_at, end_at]}}
  
  named_scope :valid, {:conditions=>["position > ? and position <= ?", 0, 10]}
  
  def self.valid_queries(item_id)
    Query.valid.find_all_by_item_id(item_id)
  end
end