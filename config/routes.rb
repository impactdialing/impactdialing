PROTOCOL = Rails.env == 'development' || Rails.env == 'heroku_staging' ? 'http://' : 'https://'

ImpactDialing::Application.routes.draw do
  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

  # You can have the root of your site routed with "root"
  # root 'welcome#index'

  # Example of regular route:
  #   get 'products/:id' => 'catalog#view'

  # Example of named route that can be invoked with purchase_url(id: product.id)
  #   get 'products/:id/purchase' => 'catalog#purchase', as: :purchase

  # Example resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Example resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Example resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Example resource route with more complex sub-resources:
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', on: :collection
  #     end
  #   end

  # Example resource route with concerns:
  #   concern :toggleable do
  #     post 'toggle'
  #   end
  #   resources :posts, concerns: :toggleable
  #   resources :photos, concerns: :toggleable

  # Example resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end

  get "/v1", :to => "caller#v1", :constraints => {:subdomain => "caller"}
  get "/", :to => "callers/station#show", :constraints => {:subdomain => "caller"}
  root :to => "client#login"

  resources :calls, :protocol => PROTOCOL do
    member do
      post :flow
      post :call_ended
      post :incoming
      post :hangup
      post :disconnected
      post :submit_result
      post :submit_result_and_stop
      post :play_message
    end
  end

  resources :caller, :protocol => PROTOCOL, :only => [:index] do
    collection do
      get :login
      post :end_session # twilio
      post :phones_only
    end

    member do
      post :start_calling # twilio
      post :pause
      post :ready_to_call
      post :conference_started_phones_only_preview
      post :conference_started_phones_only_power
      post :conference_started_phones_only_predictive
      post :gather_response
      post :continue_conf
      post :callin_choice
      post :read_instruction_options
      post :submit_response
      post :next_question
      post :run_out_of_numbers
      post :next_call
      post :call_voter
      post :stop_calling
      post :skip_voter
      post :kick
      post :time_period_exceeded
      post :account_out_of_funds
      post :play_message_error
    end
  end

  namespace 'twiml' do
    resources :caller_sessions, only: [] do
      post :dialing_prohibited
    end
  end

  namespace "callers" do
    resources :campaign_calls do
      collection do
        post :token
        get :script
      end
    end
    resources :phones_only do
      collection do
        get :report
        get :usage
        get :call_details
        get :logout
      end
    end
  end

  # new customer facing end-point
  get '/app', :to => 'callers/station#show', :as => :callveyor
  get '/app/login', :to => 'callers/station#login', :as => :callveyor_login
  post '/app/login', :to => 'callers/station#login'
  post '/app/logout', :to => 'callers/station#logout', :as => :callveyor_logout
  # /new customer facing end-point
  # new api rough draft
  post 'call_center/api/call_station', :to => 'callers/station#create'
  get 'call_center/api/twilio_token', :to => 'callers/station#twilio_token'
  get 'call_center/api/survey_fields', :to => 'callers/station#script'
    # include :id in path for back compat. remove later...
  post 'call_center/api/:id/start_calling', :to => 'caller#start_calling'
  post 'call_center/api/:id/submit_result', :to => 'calls#submit_result'
  post 'call_center/api/:id/submit_result_and_stop', :to => 'calls#submit_result_and_stop'
  post 'call_center/api/:id/hangup', :to => 'calls#hangup'
  post 'call_center/api/:id/call_voter', :to => 'caller#call_voter'
  post 'call_center/api/transfer/dial', :to => 'transfer#dial'
  post 'call_center/api/:id/stop_calling', :to => 'caller#stop_calling'
  post 'call_center/api/:id/skip_voter', :to => 'caller#skip_voter'
  post 'call_center/api/:id/kick', :to => 'caller#kick'
  post 'call_center/api/:id/drop_message', :to => 'calls#drop_message'
  # /new api rough draft

  get '/policies', :to => 'client#policies'
  get '/client/policies', :to => 'client#policies', :as => :client_policies

  # Webhooks
  post 'webhooks/billing/stripe', :to => 'client/billing/events#stripe'
  # /Webhooks

  namespace 'api' do
    resources :leads
    resources :callers
    resources :voter_lists
    resources :reports
    resource 'account' do
      collection do
        get :id
      end
      resources :campaigns, only: [:index]
    end
  end

  post :receive_call, :to => 'callin#create', :protocol => PROTOCOL
  post :end_caller_session, :to =>'caller/end_session'
  post :identify_caller, :to => 'callin#identify', :protocol => PROTOCOL
  get :default_message, :to => 'callin#default_message', :protocol => PROTOCOL
  get :hold_call, :to => 'callin#hold', :protocol => PROTOCOL

  namespace 'client' do
    resource :session, :only => [:create, :destroy]
    namespace 'billing' do
      get "/", to: 'subscription#show', as: :home
      resource :credit_card, :only => [:show, :update, :create], :controller => 'credit_card'
      resource :subscription, :only => [:show, :update, :edit], :controller => 'subscription' do
        patch :cancel
        get :cancel
      end
    end
    # resources :subscriptions do
    #   member do
    #     put :update_callers
    #     put :cancel
    #     get :add_funds
    #     put :add_to_balance
    #     get :configure_auto_recharge
    #     put :auto_recharge
    #     get :update_billing
    #     put :update_billing_info
    #   end
    # end
    resources :scripts do
      collection do
        get :questions_answered
        get :possible_responses_answered
      end
      resources :script_texts, :only => [:index, :create, :show, :update, :destroy]
      resources :notes, :only => [:index, :create, :show, :update, :destroy]
      resources :questions, :only => [:index, :create, :show, :update, :destroy] do
        resources :possible_responses, :only => [:index, :create, :show, :update, :destroy]
      end
    end

    resources :caller_groups

    resources :campaigns do
      member do
        get :can_change_script
      end
    end

    [:campaigns, :scripts, :callers].each do |type_plural|
      get "/deleted_#{type_plural}", :to => "#{type_plural}#deleted", :as => "deleted_#{type_plural}"
      get "/archived_#{type_plural}", :to => "#{type_plural}#deleted", :as => "archived_#{type_plural}"
      resources type_plural, :only => [:new, :index, :show, :destroy, :create, :update, :edit] do
        member do
          put 'restore', :to => "#{type_plural}#restore"
        end
      end
    end

    resources :callers do
      member do
        get :usage
        get :call_details
      end
      member { put :reassign_to_campaign }

      resources :reports do
        collection do
          get :performance
        end
      end
    end

    resources :campaigns, :only => [] do
      resources :reports do
        collection do
          get :download_report
          post :download
          get :downloaded_reports
          get :performance
        end
      end
    end
    resource :account, :only => [:show, :create]
    resource :account_usage, :only => [:show, :create]
    resources :reports do
      collection do
        get :usage
        get :answer
        get :dials
        get :dials_summary
        get :account_campaigns_usage
        get :account_callers_usage
      end
    end
    get :update_report_real
    resources :users, :only => [:create, :update, :destroy]
    resources :tos, :only => [:index, :create] do
      collection {get :policies}
    end
    post 'user_invite', :to => 'users#invite', :as => 'user_invite'
    post 'caller_password', :to => 'users#caller_password', :as => 'caller_password'
    post 'generate_api_key', :to => 'users#generate_api_key', :as => 'generate_api_key'
    post 'change_role', :to => 'users#change_role', :as => 'change_role'
  end

  scope 'client' do
    get 'index', :to => 'client#index', :as => 'client_root'

    resources :campaigns, :only => [] do
      member { post :verify_callerid }
    end
    resources :blocked_numbers, :only => [:index, :create, :destroy]

    get "toggle_call_recording", :to => "monitors#toggle_call_recording"
    namespace "monitors" do
      resources :campaigns
      resources :callers do
        collection do
          put :kick_off
          put :switch_mode
          post :start
          get :reassignable_campaigns
        end
      end
    end
    resources :monitors , :only=>[:index, :show] , :name_prefix => 'client' do
      collection do

        get :new_index
        get :stop
        get :deactivate_session
        post :monitor_session
      end
    end
  end

  scope 'caller' do
    get '/', :to => 'caller#index', :as => 'caller_root'
    post 'logout', :to => 'caller#logout', :as => 'caller_logout'
  end

  scope 'client' do
    resources :campaigns do
      resources :voter_lists do
        collection do
          post :import
          post :column_mapping
        end
      end
    end
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

  get '/client/login', :to => 'client#login', :as => :login
  get '/caller/login', :to => 'caller#login', :as => :caller_login

  get 'admin/login/:id', :to => 'admin#login'
  get 'admin/users', :to => 'admin#users'
  get 'admin/status', :to => 'admin#state'
  get 'admin/state', :to => 'admin#state'
  get 'admin/abandonment', :to => 'admin#abandonment'
  get 'admin/caller_sessions/:id', :to => 'admin#caller_sessions', :as => :admin_caller_sessions
  post 'admin/twilio_limit', :to => 'admin#twilio_limit'
  put 'admin/toggle_enterprise_trial/:id', :to => 'admin#toggle_enterprise_trial'
  put 'admin/toggle_calling/:id', :to => 'admin#toggle_calling'
  put 'admin/toggle_access/:id', :to => 'admin#toggle_access'


  resource :call_attempts, :only => :create

  # match ':controller/:action/:id'
  # match ':controller/:action'
end
