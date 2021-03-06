Ddl::Application.routes.draw do
  resources :tags
  resources :games
  resources :sources
  resources :concepts
  #resources :documents do
  #  collection do
  #    get :links
  #    get :concepts
  #    post :save_judgment
  #    get :search
  #  end
  #  member do
  #    #get :start
  #    get :click
  #    get :show_in_frame
  #  end
  #end
  
  resources :users

  match 'documents' => 'documents#index'
  match 'documents/:id' => 'documents#show', :as => :item, :id => /\d+/
  match 'documents/:id/edit' => 'documents#edit', :as => :edit_document, :id => /\d+/
  match 'documents/start' => 'documents#start'
  
  match 'doctrack' => 'doctrack#index'
  match 'doctrack/:id' => 'doctrack#show', :as => :item, :id => /\d+/
  match 'doctrack/start' => 'doctrack#start'
  
  match 'items' => 'items#index', :as => :items
  match 'items/:id' => 'items#show', :as => :item, :id => /\d+/
  match 'items/:id/edit' => 'items#edit', :as => :edit_item, :id => /\d+/
  match 'items/:id/destroy' => 'items#destroy', :as => :del_item, :id => /\d+/
  match 'items/new' => 'items#new', :as => :new_item

  match ':controller/:action' => '#index'
  match '/:controller(/:action(/:id))'
end
