class Tag < ActiveRecord::Base
  has_many :occurrences , :dependent => :destroy
  has_many :items, :through => :occurrences
  #has_and_belongs_to_many :items
  attr_accessor :occurrence_count
  
  named_scope :valid, {:conditions=>{:hidden_flag=>false}}
  named_scope :unmodified, {:conditions=>{:modified_flag=>false}}
  
  # Initialize new tag
  def self.find_or_create(title)
    #debugger
    tid = title.to_id
    tag = Tag.find_or_initialize_by_tid(tid)
    tag.update_attributes!(:title=>title, :tid=>tid)
    tag
  end
  
  #def self.find_by_tids( tids )
  #  all(:conditions=>{:tid=>tids})
  #end
  
  def self.find_by_source(source_id = nil)
    cond = source_id ? {:sources=>{:id=>source_id}} : {}
    all(:joins=>{:occurrences=>{:item=>:source}}, :conditions=>cond)
  end
  
  def invalidate
    update_attributes!(:hidden_flag=>true,:modified_flag=>true)
  end
end
