ActionController::Routing::Routes.draw do |map|


  map.resources :tags

  map.resources :games

  map.resources :sources

  map.resources :concepts

  map.resources :documents, :requirements=>{:id=>/[0-9]+/},
    :member=>{:click=>:get, :start=>:get, :show_in_frame=>:get}, :collection => {:save_judgment=>:post,:search=>:get, :links=>:get, :concepts=>:get}
  #map.resources :tags

  map.resources :users
  
  map.items "items", :controller=>"items", :action=>"index"
  map.item "items/:id", :controller=>"items", :action=>"show", :id=>/\d+/
  map.edit_item "items/:id/edit", :controller=>"items", :action=>"edit", :id=>/\d+/
  map.del_item "items/:id/destroy", :controller=>"items", :action=>"destroy", :id=>/\d+/
  map.new_item "items/new", :controller=>"items", :action=>"new"
  #map.new_concept "items/", :controller=>"items", :action=>"new"

  map.connect ':controller/:action'
  map.connect ':controller/:action/:id'
  map.connect ':controller/:action/:id.:format'
end
