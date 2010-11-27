require 'ddl_include'

class ItemsController < ApplicationController
  before_filter :authorize, :except => [:login, :index, :show_content, :search, :click]
  DL_TYPES = ['content','person','event','pubtime','caltime'].map{|e|e.to_sym}
  sidebar :search
  sidebar :concept_cloud, :if=>:source_given?
  sidebar :relevant_concepts, :only=>:show, :if=>:item_concept?
  sidebar :linked_concepts, :only=>:show
  #sidebar :linked_documents, :only=>:show
  
  def source_given?
    params && params[:source]
  end

  # GET /items
  # GET /items.xml
  def index_old
    @start_at = params[:start_at] || Time.now.years_ago(1).to_date.to_s
    @end_at = params[:end_at] || (Date.tomorrow+1).to_s
    #@options = 
    conditions = {:hidden_flag=>false}
    conditions.merge!({:source_id=>params[:source]}) if params[:source] && !params[:source].include?("-1")
    conditions.merge!({:itype=>params[:itype]}) if params[:itype] && !params[:itype].include?("all")
    @items = Item.documents.between(@start_at, @end_at).paginate( :conditions=>conditions, :order=>"basetime desc", :page=>params[:page],:per_page=>50)
    #Item.all(:conditions=>["basetime > ?",Time.now - 86400], :order=>"basetime desc")
    
    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @items }
    end
  end
  
  # GET /items
  # GET /items.xml
  def index
    redirect_to :action=>:search, :query=>TEXT_DUMMY, :order=>:recency, :doc_only=>true
  end
  
  # Process search action
  # - add query as item
  def search
    info params.inspect
    @query = params[:query]
    $searcher = SolrSearcher.new
    @facet = {}
    @page_title = if @query == TEXT_DUMMY
      "All Documents"
    else
      "Search Result for '#{@query}'"
    end
    begin
      #debugger
      @search_results = $searcher.process_request('k', @query, params)
      error "search_results : #{@search_results.inspect}"      
    rescue Exception => e
      error "Search failed!!", e
    end
    @rank_list = @search_results.hits.map{|e|{:item=>e.instance, :id=>e.instance.id, :score=>e.score}}
    @query_doc = Item.find_or_create(@query, 'query', :uri=>request.url, 
                   :content=>@rank_list.map{|e|e[:item].title}.join("\n"))

    @facet[:source_id] = $searcher.process_request('k', @query, params.merge(:facet=>:source_id)).
                          find_all{|e|e.instance}.map{|e|["#{e.instance.title} (#{e.count})", e.value]}    

    @facet[:itype_str] = $searcher.process_request('k', @query, params.merge(:facet=>:itype_str)).
                          map{|e|["#{e.value} (#{e.count})", e.value]}
    
    @facet[:basedate] = $searcher.process_request('k', @query, params.merge(:facet=>:basedate)).
                          find_all{|e|Time.now - e.value < 86400*7}.map{|e|["#{e.value.to_date} (#{e.count})", e.value]}.reverse

    #debugger
    Item.metadata_fields(params[:facet_itype_str]).each do |field, type|
      @facet[field] = $searcher.process_request('k', @query, params.merge(:facet=>field)).
                        map{|e|["#{e.value} (#{e.count})", e.value]}
    end
    #@docs = Item.find(@rank_list.map{|e|e[0]}).map_hash{|d|[d.id, d]}
    #debugger
  end
  
  # - Create History & Link
  # - Log pairwise preference 
  def click
    #debug(params)
    #process_click(params)
    src_item, tgt_item = params[:src_item_id].to_i, params[:id].to_i
    History.create(:htype=>params[:htype], :basetime=>Time.now, :src_item_id=>src_item, :item_id=>tgt_item, :user_id=>get_user_id(),
      :metadata=>{:position=>params[:position].to_i, :skipped_items=>params[:skipped_items], :url=>request.url})
    Link.find_or_create(src_item, tgt_item, 'c', :add=>1)
    if ['con','doc'].include?(params[:htype]) && params[:skipped_items].split("|").size > 1
      $searcher = SolrSearcher.new
      $searcher.log_preference(params[:src_item_id].to_i, params[:htype] , params[:position].to_i)
      #search_remote('c', "#{params[:src_item_id]}|#{params[:skipped_items]}", :jtype=>'log')
    end
    redirect_to :action=>:show, :id=>params[:id]
  end

  # GET /items/1
  # GET /items/1.xml
  def show
    @item = Item.find(params[:id])
    @page_title = @item.title
    @link_docs, @link_cons = [], []
    $items = {}
    #if @item.concept?
      begin
        @rel_cons = (search_local('c', @item.id) || [])[0..9]
        #info "Ranklist(con) : #{@rel_cons.inspect}"
        @rel_docs = (search_local('d', @item.id) || [])[0..9]
        #info "Ranklist(doc) : #{@rel_docs.inspect}"
        #debugger
      rescue Exception => e
        error "Failed to get Ranklist!", e
        @rel_cons = []
        @rel_docs = []
      end
      #debugger
      #puts @rel_cons.inspect
      @item.link_items.uniq.each do |e|
        (e.concept?)? (@link_cons << e) : (@link_docs << e)
      end
      #result = cache('foo') { $clf }
      #puts "Result : " + cache('foo').inspect
    #else
    #  @rank_list = []
    #end
    #debugger
    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @item }
    end    
  end
  
  # Show textual content of the document (for back-up)
  def show_content
    @item = Item.find(params[:id])
    render :action=>:show_content, :layout=>"content_only"
  end

  # GET /items/new
  # GET /items/new.xml
  def new
    @item = Item.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @item }
    end
  end

  # GET /items/1/edit
  def edit
    @item = Item.find(params[:id])
  end

  # POST /items
  # POST /items.xml
  def create
    @item = Item.new(params[:item])

    respond_to do |format|
      if @item.save
        flash[:notice] = 'Item was successfully created.'
        format.html { redirect_to(@item) }
        format.xml  { render :xml => @item, :status => :created, :location => @item }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @item.errors, :status => :unprocessable_entity }
      end
    end
  end
  
  def create_concept
    case params[:source_type]
    when 'Tag'
      @tag = Tag.find(params[:source_id])
      @item = Item.find_or_create(@tag.title, 'concept')
      @tag.items.each do |item|
        Link.find_or_create(item.id, @item.id, 'u')
      end
      @tag.invalidate
    #when 'Document'
    #  @item = Item.find_or_create_concept(params[:])
    #  @concept = Concept.find(params[:source_id])
    when 'Query'
      content = Item.find(params[:checked_docs]).map{|e|e.to_s(true)}.join("\n") if !params[:checked_docs].blank?
      @item = Item.find_by_did(params[:query].to_id)
      params[:checked_docs].each do |dno|
        Link.find_or_create(dno.to_i, @item.id, 'u')
      end
    end
    redirect_to :controller=>'items', :action=>'show', :id=>@item.id
  end

  # PUT /items/1
  # PUT /items/1.xml
  def update
    @item = Item.find(params[:id])
    respond_to do |format|
      @item.replace_tags(params[:tags]) if !params[:tags].blank?
      if @item.update_attributes(params[:item].merge(:modified_flag=>true))
        flash[:notice] = 'Item was successfully updated.'
        format.html { redirect_to(item_url(@item)) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @item.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /items/1
  # DELETE /items/1.xml
  def destroy
    @item = Item.find(params[:id])
    @item.update_attributes!(:hidden_flag=>true)

    respond_to do |format|
      format.html { redirect_to(items_url) }
      format.xml  { head :ok }
    end
  end
  
  def links
    #debugger
    params[:order] ||= "content"
    conditions = {:batch=>params[:batch]} if params[:batch]
    @links = Link.paginate(:conditions=>conditions, :order=>"#{params[:order]} desc", :page=>params[:page], :per_page=>50)
  end
  
  def save_judgment
    params[:judgment].find_all{|k,v|v.size>0}.each do |e|
      Link.find(e[0]).update_attributes!(:judgment=>e[1])
    end
    params[:remark].find_all{|k,v|v.size>0}.each do |e|
      Link.find(e[0]).update_attributes!(:remark=>e[1])
    end
    redirect_to :action=>:links
  end
end
