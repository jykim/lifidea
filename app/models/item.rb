#require 'searcher/more_like_this'

class Item < ActiveRecord::Base
  include IndexHelper
  #include TagHelper
  include MetadataHelper, RuleHelper, MarkupHelper
  ITYPE_CONCEPT = ['tag','person','query']
  ITYPE_DOCUMENT = ['webpage','bookmark_webpage','email','email_memo','paper','blog','tweet','pub']
  #ITYPE_QUERY = ['concept','person']
  
  belongs_to :source
  has_many :inlinks, :foreign_key=>'in_id', :class_name=>'Link'
  has_many :initems, :through=>:inlinks
  has_many :outlinks, :foreign_key=>'out_id', :class_name=>'Link'
  has_many :outitems, :through=>:outlinks

  has_many :occurrences , :dependent => :destroy
  #has_many :tags, :through => :occurrences # @todo : use links instead of occurrences?
  #has_and_belongs_to_many :tags

  has_many :links , :dependent => :destroy
  has_many :items, :through => :links
  
  serialize :metadata, Hash

  alias_attribute :m, :metadata
  alias_attribute :date_published, :basetime

  attr_accessor :score
  
  scope :between, lambda{|start_at, end_at| where("basetime >= ? and basetime < ?", start_at, end_at)}
    
  scope :itype, lambda{|itype| where((itype=='all')? [] : ["itype = ?", itype])}
  
  scope :valid, where(:hidden_flag=>false)

  scope :unmodified, where(:modified_flag=>false)
  
  scope :concepts, where(:itype=>ITYPE_CONCEPT)
  scope :queries, where(:itype=>['query'])
  scope :documents, where("itype != ? and itype != ? and itype != ?",'tag','query', 'concept')
  scope :searchables, where("itype != ?",'query')
  
  # List metadata fields 
  def self.metadata_fields(itype = 'all')
    #result = {:tag_list=>:multi_string}#size
    result = {}
    result.merge! :from=>:string, :to=>:string if ['email', 'all'].include? itype
    result.merge! :start_at=>:time if ['calendar', 'all'].include? itype
    result.merge! :tag_list=>:multi_string, :pub_year=>:string, :author=>:string if ['paper', 'all'].include? itype
    result.merge! :tag_list=>:multi_string if ['webpage', 'all'].include? itype
    result
  end
  
  # Sunspot/Solr search indexing  
  searchable do
    text :title, :content, :uri, :itype, :metadata, :id
    text(:dummy) {TEXT_DUMMY}
    string :hidden_flag
    time :basetime
    time(:basedate) {basetime.to_date}
    string(:itype_str) { itype.to_s.squeeze.downcase }
    integer(:source_id, :references=>Source) { source_id }
    # Index metadata fields
    Item.metadata_fields.each do |field,type|
      begin
        case type
        when :multi_string : string(field, :multiple=>true) { 
          ((metadata||{}).fetch(field,"")||"").split(',') }
        when :string       : string(field) { (metadata||{}).fetch(field,"") }
        when :integer      : integer(field){ (metadata||{}).fetch(field,"") }
        when :float        : float(field)  { (metadata||{}).fetch(field,"") }
        when :time         : time(field)   { (metadata||{}).fetch(field,"") }
        end        
      rescue Exception => e
        puts "[searchable] #{e}"
        next
      end#begin
    end
  end
  
  def concept?
    ITYPE_CONCEPT.include?(itype)
  end
  
  def document?
    !['concept','person','query'].include?(itype)
  end
  
  def link_items
    [initems,outitems].flatten
  end
  
  def link_cons
    link_items.find_all{|e|e.concept?}
  end
  
  def tagged_with?(item_title)
    link_cons.include?(item_title)
  end
  
  def con_titles
    link_cons.uniq.map{|e|e.title}
  end
  
  def tag_titles
    con_titles
  end

  def link_docs
    link_items.find_all{|e|e.document?}
  end

  def links
    [inlinks,outlinks].flatten
  end
      
  def to_s(verbose = false)
    result = "#{title} [#{id}:#{itype}] "##{basetime.to_s(:db) if basetime}
    result += "\n#{metadata.inspect}\n#{uri}\n#{content[0..1000]}" if content && verbose
    result
  end
  
  # Return if the content is actually changed
  def changed_content?(doc)
    return true if title != doc[:title] || content != doc[:content] || m[:tag_list] != doc[:metadata][:tag_list]
    false
  end
  
  # Create a new item and link with this
  def create_and_link(title, itype, ltype, o={})
    item = Item.find_or_create(title, itype, o)
    Link.find_or_create(item.id, id, ltype, o)
  end
    
  # Find an item, otherwise create a new item
  def self.find_or_create(title, itype, o={})
    #debugger
    did = o[:did] || title.to_id
    item = Item.find_or_initialize_by_did(did)
    item.update_attributes!(o.merge(:title=>title, :did=>did, :itype=>itype, :source_id=>(o[:source_id] || 1), 
      :basetime=>(o[:basetime] || Time.now.in_time_zone(TIMEZONE))))
    item
  end
  
  def process_all
    process_metadata
    process_markup if source && source.o[:use_markup]
    process_rules(Rule.tag_rules)
  end
  
  def self.count_docs
    @count_docs ||= Item.documents.size
  end
  
  
  def self.count_cons
    @count_cons ||= find_all_by_itype(ITYPE_CONCEPT).size
  end

  def self.find_by_dids( dids )
    all(:conditions=>{:did=>dids})
  end
  
  def self.col_lists
    @@doc_cols  ||= columns.map{|e|e.name}
  end
  
  def self.itype_lists()
    @@itypes ||=  find(:all, :select=>'distinct(itype)').map{|e|e.itype}
  end
end
