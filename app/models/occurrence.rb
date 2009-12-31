OTYPES = {"s"=>"Source", "m"=>"Markup","r"=>"Rule", "u"=>"User"}

# Model document-concept occurrence
class Occurrence < ActiveRecord::Base
  belongs_to :item
  belongs_to :tag
  
  # Find or create a new concept
  # - 
  def self.find_or_create(d_id, t_id, otype)
    #debugger
    #debug "[Occurrence::find_or_create] #{doc} <-> #{con} created"
    #error "[Occurrence::find_or_create] No document id #{d_id}" if !doc.id
    co = Occurrence.find_or_initialize_by_oid([d_id,t_id,otype].join("_"))
    co.update_attributes!(:item_id=>d_id, :tag_id=>t_id,:otype=>otype)
  end
  
  def self.find_by_source(source_id)
    all(:joins=>{:item=>:source}, :conditions=>{:sources=>{:id=>source_id}})
  end
end
