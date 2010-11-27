class Rule < ActiveRecord::Base
  validates_uniqueness_of :rid
  serialize :condition, Hash
  serialize :option, Hash
  
  def o
    option
  end
  
  def self.stat_rules(unit = "")
    @stat_rules ||= Rule.where("rtype != 'tag' and (unit = 'all' or unit like ?)","%#{unit}%")
  end
  
  def self.tag_rules
    @tag_rules ||= Rule.where("rtype = 'tag'")
  end
  
  def match_itype(target)
    return true if itype == "all"
    itype.split("|").include?(target)
  end
  
  def match_unit()
    return true if unit == "all"
    itype.split("|").include?(target)    
  end
end
