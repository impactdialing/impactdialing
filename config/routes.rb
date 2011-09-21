ActionController::Routing::Routes.draw do |map|
  map.root :controller => "home"

  map.connect '/monitor', :controller=>"home", :action=>"monitor"
  map.connect '/how_were_different', :controller=>"home", :action=>"how_were_different"
  map.connect '/pricing', :controller=>"home", :action=>"pricing"
  map.connect '/contact', :controller=>"home", :action=>"contact"
  map.policies '/policies', :controller => 'home', :action => 'policies'
  map.client_policies '/client/policies', :controller => 'client', :action => 'policies'
  map.broadcast_policies '/broadcast/policies', :controller => 'broadcast', :action => 'policies'
  map.connect '/homecss/css/style.css', :controller=>"home", :action=>"homecss"

  map.namespace 'admin' do |admin|
    [:campaigns, :scripts, :callers].each do |entities|
      admin.resources entities, :only => [:index] do |entity|
        entity.restore '/restore', :controller => entities, :action => 'restore', :conditions => { :method => :put }
      end
    end
  end

  #broadcast
  map.resources :campaigns, :path_prefix => "broadcast", :member => {:verify_callerid => :post, :start => :post, :stop => :post , :dial_statistics => :get}, :collection => {:control => :get, :running_status => :get} do |campaign|
    campaign.resources :voter_lists, :collection => {:import => :post}, :except => [:new, :show]
  end
  map.resources :reports, :path_prefix => "broadcast", :collection => {:usage => :get, :dial_details => :get}
  map.broadcast_deleted_campaigns "/deleted_campaigns", :action => "deleted", :controller => 'campaigns', :conditions => { :method => :get }, :path_prefix => 'broadcast'
  map.resources :scripts, :path_prefix => "broadcast"
  map.connect 'monitor', :controller => "monitor", :action => "index", :path_prefix => 'broadcast'

  map.broadcast_root '/broadcast', :action => 'index', :controller => 'broadcast'
  map.broadcast_login '/broadcast/login', :action => 'login', :controller => 'broadcast'

  map.namespace 'broadcast' do |broadcast|
    broadcast.resources :campaigns, :only => [:show, :index]
  end

  map.namespace 'client' do |client|
    map.campaign_new 'client/campaign_new', :action => 'campaign_new', :controller => 'client'

    client.resources :campaigns, :only => [:show, :index, :create]

    ['campaigns', 'scripts', 'callers'].each do |type_plural|
      client.send("deleted_#{type_plural}", "/deleted_#{type_plural}", :action => 'deleted', :controller => type_plural, :conditions => { :method => :get })
      map.send("client_#{type_plural}", "/client/#{type_plural}", :action => type_plural, :controller => 'client', :conditions => { :method => :get })
      client.resources type_plural, :only => [] do |type|
        type.restore 'restore', :action => 'restore', :controller => type_plural, :conditions => { :method => :put }
      end
    end

    client.report_usage 'reports/usage', :action => 'usage', :controller => 'reports'

    client.resource :account, :only => [:show, :update]
    client.resources :users, :only => [:create, :destroy]
    client.user_invite 'user_invite', :action => 'invite', :controller => 'users', :conditions => { :method => :post }
  end

  map.resources :campaigns, :member => { :verify_callerid => :post }, :path_prefix => 'client', :only => [] do |campaign|
    campaign.resources :voter_lists, :collection => { :import => :post }, :except => [:new, :show], :name_prefix => 'client_'
    campaign.clear_calls 'clear_calls', :controller => 'client/campaigns', :action => 'clear_calls', :conditions => { :method => :put }
  end

  map.resources :call_attempts, :only => [:create, :update]

  map.resources :users do |user|
    user.update_password '/update_password', :action => 'update_password', :controller => 'client/users', :conditions => { :method => :put }
  end
  map.reset_password '/reset_password', :controller => 'client/users', :action => 'reset_password', :conditions => { :method => :get }

  map.login '/client/login', :action => 'login', :controller => 'client'

  map.report '/client/reports', :action => 'reports', :controller => 'client'
  map.twilio_callback '/twilio_callback', :controller => 'twilio', :action => 'callback'
  map.twilio_report_error '/twilio_report_error', :controller => 'twilio', :action => 'report_error'
  map.twilio_call_ended '/twilio_call_ended', :controller => 'twilio', :action => 'call_ended'
  map.resource :call_attempts, :only => :create

  map.connect 'admin/:action/:id', :controller=>"admin"
  map.connect 'admin/:action', :controller=>"admin"
  map.connect ':controller/:action/:id'
  map.connect ':controller/:action/:id.:format'
end
