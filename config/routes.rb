ActionController::Routing::Routes.draw do |map|
  map.root :controller => "home"

  map.connect '/monitor', :controller=>"home", :action=>"monitor"
  map.connect '/how_were_different', :controller=>"home", :action=>"how_were_different"
  map.connect '/pricing', :controller=>"home", :action=>"pricing"
  map.connect '/contact', :controller=>"home", :action=>"contact"
  map.policies '/policies', :controller => 'home', :action => 'policies'
  map.connect '/homecss/css/style.css', :controller=>"home", :action=>"homecss"

  map.namespace 'admin' do |admin|
    [:campaigns, :scripts, :callers].each do |entities|
      admin.resources entities, :only => [:index] do |entity|
        entity.restore '/restore', :controller => entities, :action => 'restore', :conditions => { :method => :put }
      end
    end
  end

  #v2
  map.resources :campaigns, :path_prefix => "v2", :member => {:verify_callerid => :post} do |campaign|
    campaign.resources :voter_lists, :collection => {:import => :post}, :except => [:new, :show]
  end
  map.resources :scripts, :path_prefix => "v2"
  map.connect '/v2/monitor', :controller => "monitor", :action => "index"

  map.namespace 'client' do |client|
    map.campaign_new 'client/campaign_new', :action => 'campaign_new', :controller => 'client'
    map.campaign_view 'client/campaign_view/:id', :action => 'campaign_view', :controller => 'client'

    ['campaigns', 'scripts', 'callers'].each do |type_plural|
      client.send("deleted_#{type_plural}", "/deleted_#{type_plural}", :action => 'deleted', :controller => type_plural, :conditions => { :method => :get })
      map.send("client_#{type_plural}", "/client/#{type_plural}", :action => type_plural, :controller => 'client', :conditions => { :method => :get })
      client.resources type_plural, :only => [] do |type|
        type.restore 'restore', :action => 'restore', :controller => type_plural, :conditions => { :method => :put }
      end
    end
  end

  map.resources :users do |user|
    user.update_password '/update_password', :action => 'update_password', :controller => 'client/users', :conditions => { :method => :put }
  end
  map.reset_password '/reset_password', :action => 'reset_password', :controller => 'client/users', :conditions =>{ :method => :get }
  map.resources :campaigns, :member => {:verify_callerid => :post}, :only => [] do |campaign|
    campaign.resources :voter_lists, :collection => {:import => :post}, :except => [:new, :show]
  end

  map.login '/client/login', :action => 'login', :controller => 'client'

  map.report '/client/reports', :action => 'reports', :controller => 'client'
  map.report_usage '/client/reports/usage', :action => 'usage', :controller => 'client/reports'
  map.twilio_callback '/twilio_callback', :controller => 'twilio', :action => 'callback'

  map.connect 'admin/:action/:id', :controller=>"admin"
  map.connect 'admin/:action', :controller=>"admin"
  map.connect ':controller/:action/:id'
  map.connect ':controller/:action/:id.:format'
end
