PROTOCOL = Rails.env == 'development' || Rails.env == 'heroku_staging' ? 'http://' : 'https://'

ImpactDialing::Application.routes.draw do
  root :to => "home#index"

  ['monitor', 'how_were_different', 'pricing', 'contact', 'policies'].each do |path|
    match "/#{path}", :to => "home##{path}", :as => path
  end
  match '/client/policies', :to => 'client#policies', :as => :client_policies
  match '/broadcast/policies', :to => 'broadcast#policies', :as => :broadcast_policies
  match '/homecss/css/style.css', :to => 'home#homecss'

  namespace 'api' do
    resources :leads
    resources :callers
    resources :voter_lists
    resources :reports
    resources 'account' do
      collection do
        get :id
      end
      resources :campaigns, only: [:index]
    end
  end

  namespace 'admin' do
    [:campaigns, :scripts, :callers].each do |entities|
      resources entities, :only => [:index] do
        put '/restore', :controller => entities, :action => 'restore', :as => 'restore'
      end
    end
  end

  namespace "callers" do
    resources :campaigns do
      member do
        post :callin
        match :caller_ready
      end
    end
  end

  resources :caller, :protocol => PROTOCOL, :only => [:index] do
    collection do
      get :login
      post :end_session
      post :phones_only
    end

    member do
      post :assign_campaign
      post :pause
      post :active_session
      post :pusher_subscribed
      post :preview_voter
      post :skip_voter
      post :call_voter
      post :stop_calling
      post :start_calling
      post :gather_response
      post :choose_voter
      post :phones_only_progressive
      post :choose_instructions_option
      post :check_reassign
      post :kick_caller_off_conference
      post :new_campaign_response_panel
      post :transfer_panel
    end

  end

  post :receive_call, :to => 'callin#create', :protocol => PROTOCOL
  post :end_caller_session, :to =>'caller/end_session'
  post :identify_caller, :to => 'callin#identify', :protocol => PROTOCOL
  get :hold_call, :to => 'callin#hold', :protocol => PROTOCOL

  #broadcast
  scope 'broadcast', :protocol => PROTOCOL do
    resources :campaigns do
      member do
        post :verify_callerid
        post :start
        post :stop
        get :dial_statistics
      end
      collection do
        get :control
        get :running_status
      end
      resources :voter_lists, :except => [:new, :show] do
        collection do
          post :import
        end
      end
    end
    resources :reports, :protocol => PROTOCOL do
      collection do
        get :usage
        get :dials
        post :dial_details
        post :download
        get :answers
      end
    end
    get '/deleted_campaigns', :to => 'broadcast/campaigns#deleted', :as => :broadcast_deleted_campaigns
    get '/deleted_scripts', :to => 'scripts#deleted', :as => :deleted_scripts
    resources :scripts
    resources :messages
    match 'monitor', :to => 'monitor#index'
    match '/', :to => 'broadcast#index', :as => 'broadcast_root'
    match '/login', :to => 'broadcast#login', :as => 'broadcast_login'
  end

  namespace 'broadcast' do
    resources :campaigns, :only => [:show, :index,:new]
  end

  namespace 'client' do
    [:campaigns, :scripts, :callers].each do |type_plural|
      get "/deleted_#{type_plural}", :to => "#{type_plural}#deleted", :as => "deleted_#{type_plural}"
      resources type_plural, :only => [:new, :index, :show, :destroy, :create, :update] do
        put 'restore', :to => "#{type_plural}#restore"
      end
    end
    resources :callers do
      member do
        get :usage
        get :call_details
      end
      member { get :reassign_to_campaign }
    end
    resources :campaigns, :only => [] do
      resources :reports do
        collection do
          get :download_report
          post :download
        end
      end
    end
    resource :account, :only => [:show, :create]
    resources :reports do
      collection do
        get :usage
        get :answer
        get :dials
      end
    end
    get :update_report_real
    resources :users, :only => [:create, :destroy]
    post 'user_invite', :to => 'users#invite', :as => 'user_invite'
  end

  scope 'client' do
    match '/', :to => 'client#index', :as => 'client_root'
    resources :campaigns, :only => [] do
      member { post :verify_callerid }
      resources :voter_lists, :except => [:new, :show, :index], :name_prefix => 'client' do
        collection { post :import }
      end
    end
    resources :blocked_numbers, :only => [:index, :create, :destroy]
    resources :monitors do
      collection do
        get :start
        get :stop
        get :deactivate_session
        get :switch_mode
        get :monitor_session
        get :kick_off
      end
      match "toggle_call_recording" => "monitors#toggle_call_recording"
    end
  end

  scope 'caller' do
    match '/', :to => 'caller#index', :as => 'caller_root'
    match 'logout', :to => 'caller#logout', :as => 'caller_logout'
  end

  resources :campaigns, :path_prefix => 'client', :only => [] do
    member { post :verify_callerid }
    resources :voter_lists, :collection => {:import => :post}, :except => [:new, :show], :name_prefix => 'client'
    match 'clear_calls', :to => 'client/campaigns#clear_calls', :as => 'clear_calls'
  end

  resources :call_attempts, :protocol => PROTOCOL, :only => [:create, :update] do
    member do
      post :connect
      post :end
      post :disconnect
      post :voter_response
      post :hangup
    end
  end
  
  resources :transfer, :protocol => PROTOCOL do
    member do
      post :connect
      post :end
      post :disconnect      
    end
    collection do 
      post :callee
      post :caller            
      post :dial
    end
  end
  

  resources :users do
    put '/update_password', :to => 'client/users#update_password', :as => 'update_password'
  end

  get '/reset_password', :to => 'client/users#reset_password', :as => 'reset_password'

  match '/client/login', :to => 'client#login', :as => :login
  match '/caller/login', :to => 'caller#login', :as => :caller_login

  match '/client/reports', :to => 'client#reports', :as => 'report', :protocol => PROTOCOL
  match '/twilio_callback', :to => 'twilio#callback', :as => :twilio_callback, :protocol => PROTOCOL
  match '/twilio_report_error', :to => 'twilio#report_error', :as => :twilio_report_error, :protocol => PROTOCOL
  match '/twilio_call_ended', :to => 'twilio#call_ended', :as => :twilio_call_ended, :protocol => PROTOCOL

  get 'admin/status', :to => 'admin#state'

  resource :call_attempts, :only => :create

  match ':controller/:action/:id'
  match ':controller/:action'
end
