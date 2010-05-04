require 'ddl_include'
class DocumentsController < ApplicationController
  include AdminHelper, DocumentsHelper
  before_filter :authorize, :except => [:login, :index, :show, :search, :click]
  DL_TYPES = ['content','person','event','pubtime','caltime'].map{|e|e.to_sym}
  sidebar :pagehunt_search, :only=>[:index, :search]
  sidebar :menu, :only=>[:index]
  sidebar :pagehunt_status, :only=>[:show, :start_search, :search, :request_document]
  sidebar :pagehunt_scoreboard
  layout "doctrack"
  
  #sidebar :concept_cloud, :if=>:source_given?
  #sidebar :linked_concepts, :only=>:show
  #sidebar :linked_documents, :only=>:show
  
  def initialize
    @display_topk_result = 10   #get_config("DISPLAY_TOPK_RESULT").to_i
    @pages_per_game =      10   #get_config("PAGES_PER_GAME").to_i
    @queries_per_page =    10   #get_config("QUERIES_PER_PAGE").to_i
    @no_entry_concept =     7
    @display_page_total =   2   #get_config("DISPLAY_PAGE_NO").to_i
    @time_per_page =       15   #get_config("TIME_PER_PAGE").to_i
    @ratio_game_type = {:s=>0.33, :sb=>0.33, :b=>0.33}
    $document_list ||= Item.valid.documents.all.map{|e|e.id}
    $concept_list  ||= Item.valid.concepts.all.map{|e|e.id}
  end
  
  # GET /documents
  # GET /documents.xml
  def index
    finish_game()
    @start_at = params[:start_at] || Time.now.years_ago(1).to_date.to_s
    @end_at = params[:end_at] || Date.tomorrow.to_s
    conditions = {}
    conditions.merge!({:itype=>params[:itype]}) if params[:itype] && !params[:itype].include?("all")
    conditions.merge!({:query_flag=>true}) if params[:query_only]
    @documents = Item.valid.searchables.between(@start_at, @end_at).paginate( :conditions=>conditions, :order=>"basetime desc", :page=>params[:page],:per_page=>50)
    
    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @documents }
    end
  end
  
  # Start a new game
  def start
    @game = Game.create(:gid=>"#{session[:user_uid]}_#{Time.now.to_s(:db)}", 
      :user_id=>session[:user_id], :start_at=>Time.now)
    init_game(@game.id)
    #@query_docs_total = Item.find_all_by_query_flag(true).map{|d|d.id}
    @query_docs_found = Query.find_all_by_user_id(session[:user_id]).map{|e|e.item_id}.uniq
    #session[:query_docs] = @query_docs_total -  @query_docs_found
  end
  
  # FInalize current game
  # - store game data
  def finish
    @game = Game.find(session[:game_id])
    @game.update_attributes(:score=>session[:score], 
      :query_count=>session[:total_query_count], :finish_at=>Time.now, :comment=>params[:comment])
    session[:query_count] = nil
    if params[:comment]
      finish_game()
      redirect_to :controller=>:games 
    end
  end
  
  # User request a new document
  def request_document
    session[:total_query_count] += session[:query_count]
    if game_finished? || params[:finish]
      redirect_to :action=>:finish
      return
    else
      init_target_document()
    end
  end
  
  # User start searching
  # - determine which document to find
  def start_search
    session[:document_index]  = rand(@display_page_total) if !session[:document_index]
    if session[:game_type] == :b
      @concepts = Item.find ($concept_list.sample(@no_entry_concept).uniq - session[:display_docs])
      render :start_browse
    end
  end
      
  # Process search action
  # - add query as document
  def search
    @query = params[:query]
    info "Query : #{@query}"
    @query_did = [get_user_id(),@query].join(" ").to_id
    @rank_list = search_local('k', @query, :doc_only=>true)#search_remote('k', @query)
    if !@rank_list
      flash[:notice] = "Invalid query!"
      if !during_game?
        redirect_to :action=>:search 
      elsif query_limit_reached?
        redirect_to :action=>:request_document, :skip=>true    
      else
        redirect_to :action=>:start_search 
      end
      return
    end
    #debugger
    #@docs = Item.find_by_dids(@rank_list.map{|e|e[0]}).map_hash{|d|[d.did, d]}
    @query_doc = Item.find_or_create(@query, 'query', :did=>@query_did, 
      :uri=>request.url, :content=>@rank_list.map{|e|e[0].title}.join("\n"))
    if during_game?
      process_search_result(@rank_list.map{|e|e[0].id}, @query_doc.id, @query)
    end
  end
  
  # Judge rank list and change status
  # @arg rank_list : ranked list of document ids
  def process_search_result(rank_list, query_id, query_text = nil)
    session[:query_count] += 1 if session[:query_count]
    session[:target_document] = session[:display_docs][session[:document_index]].to_i
    @relevant_position = -1
    rank_list.each_with_index do |e,i|
      @relevant_position = i+1 if session[:target_document].to_i == e
    end
    if query_text
      Query.create(:query_text=>query_text, :query_id=>query_id, :position=>@relevant_position, :query_count=>session[:query_count],
        :item_id=>session[:target_document], :user_id=>session[:user_id], :game_id=>session[:game_id])
    end
    if page_found? || query_limit_reached?
      if page_found?
        session[:score] += (@display_topk_result.to_f / @relevant_position ).to_i
        #session[:query_docs] = session[:query_docs] - [session[:target_document]]
      end
    end
  end
  
  # GET /documents/1
  # GET /documents/1.xml
  def show
    if params[:random]
      if @display_page_total <= session[:display_page_cur] 
        redirect_to :action=>:start_search
        return
      end
      params[:id] = if session[:game_type] == :b
        $concept_list.sample[0]
      else
        $document_list.sample[0]
        #session[:query_docs][rand(session[:query_docs].size)]
      end
      session[:display_page_cur] += 1
      session[:display_docs] << params[:id].to_i
      #History.create(:htype=>"show", :basetime=>Time.now, :src_item_id=>session[:game_id], :item_id=>params[:id], :user_id=>get_user_id(),
      #  :metadata=>{:url=>request.url})
      #debug "#{session[:display_page_cur]} < #{@display_page_total} (#{session[:display_docs].inspect})"
      @document = Item.find(params[:id])
    else
      @link_docs, @link_cons = [], []
      @document = Item.find(params[:id])
      $items = {}
      if @document.itype == 'concept'
        @search_type, @feature_type, @htype = 'c', Searcher::CON_FEATURES, 'con_con'
      else
        @search_type, @feature_type, @htype = 'd', Searcher::DOC_FEATURES, 'doc_doc'        
      end
      begin
        @rel_docs = (search_local(@search_type, params[:id]) || [])[0..9]
        #info "Ranklist(doc) : #{@rel_docs.inspect}"
        #debugger
      rescue Exception => e
        error "Failed to get Ranklist!", e
        @rel_docs = []
      end
      if during_game?
        process_search_result(@rel_docs.map{|e|e[:id]}, params[:id])
      end
    end
    
    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @document }
    end
  end
  
  # Show textual content of the document (for back-up)
  def show_content
    @document = Item.find(params[:id])
    render :action=>:show_content, :layout=>"content_only"
  end
  
  # Process & log user click
  # - Add to history
  # - Add to concept occurrence (for con<->doc click)
  # - Add to concept relation (for con<->con click)
  # - Add to document relation (for doc<->doc click)
  def click
    #debug(params)
    src_item, tgt_item = params[:src_item_id].to_i, params[:id].to_i
    History.create(:htype=>params[:htype], :basetime=>Time.now, :src_item_id=>session[:target_document], :item_id=>tgt_item, :user_id=>get_user_id(),
      :game_id=>session[:game_id], :metadata=>{:real_src_item_id=>src_item, :position=>params[:position], :url=>request.url})
    Link.find_or_create(src_item, tgt_item, 'c', :add=>1)
    redirect_to :action=>:show
  end

  # GET /documents/new
  # GET /documents/new.xml
  def new
    @document = Item.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @document }
    end
  end

  # GET /documents/1/edit
  def edit
    @document = Item.find(params[:id])
  end

  # POST /documents
  # POST /documents.xml
  def create
    @document = Item.new(params[:document])

    respond_to do |format|
      if @document.save
        flash[:notice] = 'Document was successfully created.'
        format.html { redirect_to(@document) }
        format.xml  { render :xml => @document, :status => :created, :location => @document }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @document.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /documents/1
  # PUT /documents/1.xml
  def update
    @document = Item.find(params[:id])
    #@document.add_concepts(params[:document][:concept_titles], 'u')
    respond_to do |format|
      if @document.update_attributes(params[:document].merge(:modified_flag=>true))
        flash[:notice] = 'Document was successfully updated.'
        format.html { redirect_to(@document) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @document.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /documents/1
  # DELETE /documents/1.xml
  def destroy
    @document = Item.find(params[:id])
    @document.update_attributes!(:hidden_flag=>true)

    respond_to do |format|
      format.html { redirect_to(documents_url) }
      format.xml  { head :ok }
    end
  end
  
  def links
    #debugger
    params[:order] ||= "content"
    conditions = {:batch=>params[:batch]} if params[:batch]
    @links = DocumentLink.paginate(:conditions=>conditions, :order=>"#{params[:order]} desc", :page=>params[:page], :per_page=>50)
  end
  
  def save_judgment
    params[:judgment].find_all{|k,v|v.size>0}.each do |e|
      DocumentLink.find(e[0]).update_attributes!(:judgment=>e[1])
    end
    params[:remark].find_all{|k,v|v.size>0}.each do |e|
      DocumentLink.find(e[0]).update_attributes!(:remark=>e[1])
    end
    redirect_to :action=>:links
  end
  
  def concepts
    @occurrences = Occurrence.paginate(:order=>"weight desc", :page=>params[:page], :per_page=>50)
  end
end
