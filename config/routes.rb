ActionController::Routing::Routes.draw do |map|
  # The priority is based upon order of creation: first created -> highest priority.

  # Sample of regular route:
  #   map.connect 'products/:id', :controller => 'catalog', :action => 'view'
  # Keep in mind you can assign values other than :controller and :action

  # Sample of named route:
  #   map.purchase 'products/:id/purchase', :controller => 'catalog', :action => 'purchase'
  # This route can be invoked with purchase_url(:id => product.id)

  # Sample resource route (maps HTTP verbs to controller actions automatically):
  #   map.resources :products

  # Sample resource route with options:
  #   map.resources :products, :member => { :short => :get, :toggle => :post }, :collection => { :sold => :get }

  # Sample resource route with sub-resources:
  #   map.resources :products, :has_many => [ :comments, :sales ], :has_one => :seller

  # Sample resource route with more complex sub-resources
  #   map.resources :products do |products|
  #     products.resources :comments
  #     products.resources :sales, :collection => { :recent => :get }
  #   end

  # Sample resource route within a namespace:
  #   map.namespace :admin do |admin|
  #     # Directs /admin/products/* to Admin::ProductsController (app/controllers/admin/products_controller.rb)
  #     admin.resources :products
  #   end

  # You can have the root of your site routed with map.root -- just remember to delete public/index.html.
  map.root :controller => "home"

  # See how all your routes lay out with "rake routes"

  # Install the default routes as the lowest priority.
  # Note: These default routes make all actions in every controller accessible via GET requests. You should
  # consider removing or commenting them out if you're using named routes and resources.
  map.connect '/monitor', :controller=>"home", :action=>"monitor"
  map.connect '/how_were_different', :controller=>"home", :action=>"how_were_different"
  map.connect '/pricing', :controller=>"home", :action=>"pricing"
  map.connect '/contact', :controller=>"home", :action=>"contact"
  map.connect '/homecss/css/style.css', :controller=>"home", :action=>"homecss"

  map.namespace 'admin' do |admin|
    [:campaigns, :scripts, :callers].each do |entities|
      admin.resources entities, :only => [:index] do |entity|
        entity.restore '/restore', :controller => entities, :action => 'restore', :conditions => { :method => :put }
      end
    end
  end

  map.namespace 'client' do |client|
    map.campaign_new '/client/campaign_new', :action => 'campaign_new', :controller => 'client'
    map.campaign_view '/client/campaign_view/:id', :action => 'campaign_view', :controller => 'client'

    ['campaigns', 'scripts', 'callers'].each do |type_plural|
      map.send("deleted_#{type_plural}", "/client/deleted_#{type_plural}", :action => 'deleted', :controller => "/client/#{type_plural}", :conditions => { :method => :get })
      map.send(type_plural, "/client/#{type_plural}", :action => type_plural, :controller => "/client", :conditions => { :method => :get })
      client.resources type_plural, :only => [] do |type|
        type.restore 'restore', :action => 'restore', :controller => type_plural, :conditions => { :method => :put }
      end
    end
  end

  map.resources :users do |user|
    user.update_password '/update_password', :action => 'update_password', :controller => 'client/users', :conditions => { :method => :put }
  end
  map.reset_password '/reset_password', :action => 'reset_password', :controller => 'client/users', :conditions =>{ :method => :get }

  map.resources :campaigns do |campaign|
    campaign.resources :voter_lists, :member => {:add_to_db => :post}, :except => [:new]
  end

  map.connect 'admin/:action/:id', :controller=>"admin"
  map.connect 'admin/:action', :controller=>"admin"
  map.connect ':controller/:action/:id'
  map.connect ':controller/:action/:id.:format'
end
