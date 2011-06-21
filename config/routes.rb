ActionController::Routing::Routes.draw do |map|
  map.root :controller => "home"

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
    end

    client.resources :campaigns, :controller => 'client/campaigns', :only => [:index, :show, :create, :update, :destroy] do |type|
      type.restore 'restore', :action => 'restore', :controller => :campaigns, :conditions => { :method => :put }
    end
    client.resources :scripts, :only => [] do |type|
      type.restore 'restore', :action => 'restore', :controller => :scripts, :conditions => { :method => :put }
    end
    client.resources :callers, :only => [] do |type|
      type.restore 'restore', :action => 'restore', :controller => :callers, :conditions => { :method => :put }
    end
  end

  map.resources :users do |user|
    user.update_password '/update_password', :action => 'update_password', :controller => 'client/users', :conditions => { :method => :put }
  end
  map.reset_password '/reset_password', :action => 'reset_password', :controller => 'client/users', :conditions =>{ :method => :get }

  map.resources :campaigns do |campaign|
    campaign.resources :voter_lists, :collection => {:import => :post}, :except => [:new, :show]
  end

  map.connect 'admin/:action/:id', :controller=>"admin"
  map.connect 'admin/:action', :controller=>"admin"
  map.connect ':controller/:action/:id'
  map.connect ':controller/:action/:id.:format'
end
