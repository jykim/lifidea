LTYPES={"o"=>"Occurrence", "u"=>"User", "c"=>"Click"}
CLTYPES=['o','t','c']
CLTYPES_SEARCH=['o','t']

# Link between Documents
class Link < ActiveRecord::Base
  belongs_to :outitem, :class_name=>'Item', :foreign_key=>'in_id' #Outitem should return in_id
  belongs_to :initem,  :class_name=>'Item', :foreign_key=>'out_id' 
  serialize :metadata, Hash
  alias_attribute :m, :metadata
  
  def to_s
    lid
  end
  
  # Create or find DocumentLink instance
  # - d_id1 is always smaller than d_id2
  def self.find_or_create(d_id1, d_id2, ltype, o={})
    return if d_id1 == d_id2
    d_id1, d_id2 = d_id2, d_id1 if d_id1 > d_id2 # invariant : out_id < in_id
    weight = 1
    link = Link.find_or_initialize_by_lid([d_id1, d_id2, ltype].join("_"))
    if o[:weight] : weight = o[:weight]
    elsif o[:add] && link.weight : weight = o[:add] + (link.weight || 0)
    end
    link.update_attributes!(:out_id=>d_id1, :in_id=>d_id2, :ltype=>ltype, :weight=>weight, :metadata=>o)
  end
end
