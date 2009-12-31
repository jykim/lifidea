class Document < ActiveRecord::Base
  include MetadataHelper, RuleHelper, MarkupHelper, IndexHelper, CollectorHelper
  belongs_to :source
  has_many :inlinks, :foreign_key=>'out_id', :class_name=>'DocumentLink'
  has_many :indocs, :through=>:inlinks
  has_many :outlinks, :foreign_key=>'in_id', :class_name=>'DocumentLink'
  has_many :outdocs, :through=>:outlinks

  has_many :occurrences , :dependent => :destroy
  has_many :concepts, :through => :occurrences
  
  serialize :metadata, Hash
  #serialize :concept_titles, Array
  alias_attribute :m, :metadata
  alias_attribute :date_published, :basetime
  alias_attribute :tags, :concept_titles
  
  attr_accessor :score
  
  SYSTEM_SOURCE_ID = 0
  #abstract_class
  #acts_as_taggable
  #validates_uniqueness_of :did
  
  named_scope :between, lambda{|start_at, end_at| {:conditions=>
    ["basetime >= ? and basetime < ?", start_at, end_at]}}
  
  named_scope :valid, {:conditions=>{:hidden_flag=>false}}

  named_scope :normal, {:conditions=>['source_id != 0']}
  named_scope :log, {:conditions=>['source_id = 0']}
  
  named_scope :itype, lambda{|itype| {:conditions=>
      ((itype=='all')? [] : ["itype = ?", itype])}}

  
  def title
    (read_attribute(:title)||"").gsub(/\<.*?\>/,"")
  end
  
  def link_docs
    #[indocs,outdocs].flatten
    [inlinks.map{|l|[l, l.indoc]}, outlinks.map{|l|[l, l.outdoc]}].collapse
  end
  
  def concept_titles(otype = nil)
    #read_attribute(:concept_titles)|| []
    cond = otype ? {:occurrences=>{:otype=>otype}} : {}
    Concept.all(:joins=>{:occurrences=>:concept}, :conditions=>cond).map(&:title)
  end
  
  #def concept_titles(otype = nil)
  #  #occurrences.find_all{|co|!otype || co.otype==otype}.map{|co|co.concept.title}
  #  # CHANGED : concepts are not refreshed as it is changed
  #  #unless otype
  #    concepts.map(&:title)
  #  #else
  #  #  occurrences.find_all{|co|co.otype==otype}.map{|co|co.concept.title}
  #  #end
  #end
    
  def links
    [inlinks,outlinks].flatten
  end
    
  def to_s(verbose = false)
    result = "[#{itype}] #{title} #{basetime.to_s(:db) if basetime}"
    result += "\n#{metadata.inspect}\n#{content[0..50]}" if content && verbose
    result
  end
  
  def tagged_with?(title)
    concepts.find_all{|c|c.title==title}.size > 0
  end
  
  # Return if the content is actually changed
  def changed_content?(doc)
    return true if title != doc[:title] || content != doc[:content] || m[:tag_list] != doc[:metadata][:tag_list]
    false
  end
  
  # Create new document from given query
  # @param [String] did : unique ID
  def self.create_from_query(did, doc)
    doc_db = Document.find_or_initialize_by_did(did)
    doc_db.update_attributes!(doc.merge(:source_id=>SYSTEM_SOURCE_ID, :basetime=>Time.now(), :metadata=>{}))
    doc_db
  end
  
  def index
    @index ||= IR::Document.create_from_yaml(textindex)
  end

  def self.find_by_dids( dids )
    all(:conditions=>{:did=>dids})
  end
  
  def self.col_lists
    @@doc_cols  ||= columns.map{|e|e.name}
  end
  
  def self.itype_lists
    @@itypes ||=  find(:all, :select=>'distinct(itype)').map{|e|e.itype}
  end
  
  # Create concepts & occurrences
  # @param titles [String] comma-separated string of tags
  # @param otype [String] type of occurrences
  def add_concepts(titles, otype, o={})
    #debug "[add_concepts] titles = [#{titles}] otype = #{otype} (#{@concept_titles})"
    titles = titles.split(",").find_all{|e|!e.blank?} if titles.class == String
    #debugger
    concepts = titles.map{|t|Concept.find_or_create(t.strip, :ctype=>o[:ctype])}
    concepts.each{|c|Occurrence.find_or_create(self, c, otype, o)}
    #@concept_titles = concept_titles | titles
    #update_attributes!(:concept_titles=>@concept_titles)
  end
end