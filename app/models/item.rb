#require 'searcher/more_like_this'

class Item < ActiveRecord::Base
  include TagHelper, IndexHelper
  include MetadataHelper, RuleHelper, MarkupHelper, CollectorHelper
  ITYPE_CONCEPT = ['concept','person']
  ITYPE_DOCUMENT = ['webpage','bookmark_webpage','email','email_memo','paper','blog','tweet','pub']
  #ITYPE_QUERY = ['concept','person']
  
  belongs_to :source
  has_many :inlinks, :foreign_key=>'in_id', :class_name=>'Link'
  has_many :initems, :through=>:inlinks
  has_many :outlinks, :foreign_key=>'out_id', :class_name=>'Link'
  has_many :outitems, :through=>:outlinks

  has_many :occurrences , :dependent => :destroy
  has_many :tags, :through => :occurrences
  #has_and_belongs_to_many :tags

  has_many :links , :dependent => :destroy
  has_many :items, :through => :links
  
  serialize :metadata, Hash

  alias_attribute :m, :metadata
  alias_attribute :date_published, :basetime

  attr_accessor :score
  
  named_scope :between, lambda{|start_at, end_at| {:conditions=>
    ["basetime >= ? and basetime < ?", start_at, end_at]}}
    
  named_scope :itype, lambda{|itype| {:conditions=>
      ((itype=='all')? [] : ["itype = ?", itype])}}
  
  named_scope :valid, {:conditions=>{:hidden_flag=>false}}

  named_scope :unmodified, {:conditions=>{:modified_flag=>false}}
  
  named_scope :indexed, {:conditions=>["textindex is not null"]}
  
  named_scope :concepts, {:conditions=>{:itype=>'concept'}}
  named_scope :queries, {:conditions=>{:itype=>['query']}}
  named_scope :documents, {:conditions=>["itype != ? and itype != ?",'query', 'concept']}
  
  # Sunspot/Solr search indexing  
  searchable do
    text :title, :content, :uri, :itype
    #more_like_this :title, :content, :uri, :itype
  end
  
  def concept?
    ITYPE_CONCEPT.include?(itype)
  end
  
  def document?
    ITYPE_DOCUMENT.include?(itype)
  end
  
  def link_items
    #[inlinks.map{|l|[l, l.initem]}, outlinks.map{|l|[l, l.outitem]}].collapse
    [initems,outitems].flatten
  end

  def links
    [inlinks,outlinks].flatten
  end
      
  def to_s(verbose = false)
    result = "#{title} [#{id}:#{itype}] #{basetime.to_s(:db) if basetime}"
    result += "\n#{metadata.inspect}\n#{content[0..50]}" if content && verbose
    result
  end
  
  # Return if the content is actually changed
  def changed_content?(doc)
    return true if title != doc[:title] || content != doc[:content] || m[:tag_list] != doc[:metadata][:tag_list]
    false
  end
  
  # Create new document from given query
  # @param [String] did : unique ID
  #def self.create_from_query(did, doc)
  #  doc_db = Document.find_or_initialize_by_did(did)
  #  doc_db.update_attributes!(doc.merge(:source_id=>1, :basetime=>Time.now(), :metadata=>{}))
  #  doc_db
  #end
  
  # Initialize new document
  def self.find_or_create(title, itype, o={})
    #debugger
    did = o[:did] || title.to_id
    item = Item.find_or_initialize_by_did(did)
    item.update_attributes!(o.merge(:title=>title, :did=>did, :itype=>itype, :source_id=>(o[:source_id] || 1), 
      :basetime=>(o[:basetime] || Time.now.in_time_zone(TIMEZONE))))
    item
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

#Sunspot.setup(Item) do 
#   text :title, :content, :uri 
#   more_like_this :title, :content, :uri
#end

#Sunspot.setup(Item) do 
#   text :title, :content, :uri 
#   more_like_this do 
#      fields :title, :content, :uri 
#      min_document_frequency 10 
#      boost true 
#      max_query_terms 10 
#    end 
#end