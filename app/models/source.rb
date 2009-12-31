
# Sources form which documents are collected
class Source < ActiveRecord::Base
  has_many :item
  serialize :option, Hash
  serialize :filter, Hash  
  named_scope :active, {:conditions=>{:active_flag=>true}}
  attr_accessor :last_sync_at
  
  def initialize
    @last_sync_at = nil
  end
  
  def o
    option || {}
  end
  
  
  def self.sync_interval_default()
    @sync_interval_default ||= get_config("SYNC_INTERVAL_DEFAULT").to_i
  end
  
  def sync_now?()
    return true if !@last_sync_at
    (Time.now - @last_sync_at > (sync_interval || Source.sync_interval_default))? true : false
  end
  
  def update_sync_content(content)
    hash_content =  content.to_md5
    if sync_content == hash_content
      #debug "[update_sync_content] Nothing to update!"
      false
    else
      #debug "[update_sync_content] #{sync_content.size} != #{content.size}"
      update_attributes(:sync_content => hash_content)
      true
    end
  end
end
