class TagsController < ApplicationController
  #<%= in_place_editor_field "concept", "title", {}, {:load_text_url=> url_for(:action=>"get_concept_title", :id=>concept) } %>
  #in_place_edit_for :concept, :title
    # GET /concepts
  # GET /concepts.xml
  def index
    @tags = Tag.valid.find_by_source(params[:source]).group_by{|c|c}.
      map{|k,v|k.occurrence_count = v.size;k}.sort_by(&:occurrence_count).reverse

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @concepts }
    end
  end

  # GET /concepts/1
  # GET /concepts/1.xml
  def show
    @tag = Tag.find(params[:id])
    
    @items = @tag.items.uniq.sort_by(&:basetime).reverse
        
    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @tag }
    end
  end
  
  def click
    #debug(params)
    process_click(params)
    if params[:skipped_items].split("|").size > 1
      search_remote('c', "#{params[:src_item_id]}|#{params[:skipped_items]}", :jtype=>'log')
    end
    redirect_to :action=>:show
  end

  # GET /tags/new
  # GET /tags/new.xml
  def new
    @tag = Tag.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @tag }
    end
  end

  # GET /tags/1/edit
  def edit
    @tag = Tag.find(params[:id])
  end

  # POST /tags
  # POST /tags.xml
  def create
    @tag = Tag.new(params[:tag])

    respond_to do |format|
      if @tag.save
        flash[:notice] = 'Tag was successfully created.'
        format.html { redirect_to(@tag) }
        format.xml  { render :xml => @tag, :status => :created, :location => @tag }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @tag.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /tags/1
  # PUT /tags/1.xml
  def update
    @tag = Tag.find(params[:id])

    respond_to do |format|
      if @tag.update_attributes(params[:tag].merge(:modified_flag=>true))
        flash[:notice] = 'Tag was successfully updated.'
        format.html { redirect_to(@tag) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @tag.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /tags/1
  # DELETE /tags/1.xml
  def destroy
    @tag = Tag.find(params[:id])
    @tag.invalidate

    respond_to do |format|
      format.html { redirect_to(tags_url) }
      format.xml  { head :ok }
    end
  end
end
