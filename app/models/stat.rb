class Stat < ActiveRecord::Base
  
  named_scope :between, lambda{|start_at, end_at| {:conditions=>
    ["basedate >= ? and basedate < ?", start_at, end_at]}}
  
  # Weight-averaged value of statistics with given pattern
  # - weight is determined by document count
  def self.get_wavg(ptn_sid, cond = {})
    stats = Stat.all(:conditions=>cond).find_all{|e|ptn_sid =~ e.sid}
    #stats.each{|e|puts "#{e.sid} #{e.content}*#{e.doc_count}"}
    stats.sum{|e|parse_value(e.content)*e.doc_count} / stats.sum{|e|e.doc_count}
  end
  
  def self.select_by(ptn_sid, cond = {})
    Stat.all(:conditions=>cond).find_all{|e|ptn_sid =~ e.sid}
  end
end
