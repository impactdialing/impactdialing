# PROTOCOL = Rails.env == 'development' || Rails.env == 'heroku_staging' ? 'http://' : 'https://'

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

  resources :caller, :only => [:index] do
    collection do
      get :login
      post :end_session # twilio
      post :phones_only
      post :start_calling
    end

    member do
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
    namespace 'lead' do
      post :answered
      post :disconnected
      post :completed
      post :play_message
    end
    resources :caller_sessions, only: [:create] do
      post :dialing_prohibited
    end
  end
  # other TwiML
  post 'caller/start_calling', :to => 'caller#start_calling'

  post 'callin/create', :to => 'callin#create', :as => :callin_caller
  post :end_caller_session, :to =>'caller/end_session'
  post :identify_caller, :to => 'callin#identify', :as => :identify_caller
  # /other TwiML

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

  post 'call_center/api/call_station', :to => 'callers/station#create'
  get 'call_center/api/twilio_token', :to => 'callers/station#twilio_token'
  get 'call_center/api/survey_fields', :to => 'callers/station#script'

  # removing :id dependency
  #post 'call_center/api/call_lead', :to => 'callers/station#call_lead' # replaces caller#call_voter
  post 'call_center/api/hangup', :to => 'callers/station#hangup_lead' # replaces calls#hangup
  #post 'call_center/api/skip_lead', :to => 'callers/station#next_lead' # replaces caller#skip_voter
  post 'call_center/api/:sid/drop_message', :to => 'callers/station#drop_message' # replaces calls#drop_message

  #post 'call_center/api/call_transfer', :to => 'callers/station#call_transfer'
  #post 'call_center/api/hangup_transfer', :to => 'callers/station#hangup_transfer'
  #post 'call_center/api/leave_transfer', :to => 'callers/station#leave_transfer'

  post 'call_center/api/disposition', :to => 'callers/station#disposition' # replaces calls#submit_result & calls#submit_result_and_stop

  #post 'call_center/api/stop_calling', :to => 'callers/station#stop_calling'

  # new api rough draft
    # include :id in path for back compat. remove later...
  #post 'call_center/api/:id/submit_result', :to => 'calls#submit_result'
  #post 'call_center/api/:id/submit_result_and_stop', :to => 'calls#submit_result_and_stop'
  #post 'call_center/api/:id/hangup', :to => 'calls#hangup'
  #post 'call_center/api/:id/drop_message', :to => 'calls#drop_message'

  post 'call_center/api/:id/call_voter', :to => 'caller#call_voter'
  post 'call_center/api/transfer/dial', :to => 'transfer#dial'
  post 'call_center/api/:id/stop_calling', :to => 'caller#stop_calling'
  post 'call_center/api/:id/skip_voter', :to => 'caller#skip_voter'
  post 'call_center/api/:id/kick', :to => 'caller#kick'
  # /new api rough draft

  get '/policies', :to => 'client#policies'
  get '/client/policies', :to => 'client#policies', :as => :client_policies

  # Webhooks
  post 'webhooks/billing/stripe', :to => 'client/billing/events#stripe', :as => :billing_events_stripe
  # /Webhooks

  namespace 'api' do
    resources :leads
    resources :callers
    resources :voter_lists do
      member do
        put :enable
        put :disable
      end
    end
    resources :reports
    resource 'account' do
      collection do
        get :id
      end
      resources :campaigns, only: [:index]
    end
  end

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
      get "/archived_#{type_plural}", :to => "#{type_plural}#archived", :as => "archived_#{type_plural}"
      resources type_plural, :only => [:new, :index, :show, :destroy, :create, :update, :edit] do
        unless type_plural == :campaigns
          member do
            patch 'restore', :to => "#{type_plural}#restore"
          end
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
        get :dials_by_dial
        get :dials_by_lead
        get :dials_by_pass
        get :account_campaigns_usage
        get :account_callers_usage
      end
    end
    get :update_report_real
    resources :users, :only => [:create, :update, :destroy] do
      member do
        post :change_role
      end
    end

    resources :tos, :only => [:index, :create] do
      collection {get :policies}
    end
    post 'user_invite', :to => 'users#invite', :as => 'user_invite'
    post 'caller_password', :to => 'users#caller_password', :as => 'caller_password'
    post 'generate_api_key', :to => 'users#generate_api_key', :as => 'generate_api_key'
  end

  get 'client', :to => 'client#index', :as => 'client_root'
  scope 'client' do
    get 'forgot', :to => 'client#forgot'
    post 'forgot', :to => 'client#forgot'
    get 'recording_add', :to => 'client#recording_add'
    post 'recording_add', :to => 'client#recording_add'
    resources :campaigns do
      resources :voter_lists do
        member do
          put :enable
          put :disable
        end
        collection do
          post :import
          post :column_mapping
        end
      end
    end

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


  resources :call_attempts, :only => [:create, :update] do
    member do
      post :connect
      post :end
      post :disconnect
      post :voter_response
      post :hangup
    end
  end

  resources :transfer do
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

  namespace :admin do
    resources :accounts do
      resource :billing_subscriptions, :only => [:show, :update]
    end
  end
  get 'admin/report', :to => 'admin#report'
  post 'admin/report', :to => 'admin#report'
  get 'admin/login/:id', :to => 'admin#login'
  get 'admin/users', :to => 'admin#users'
  get 'admin/status', :to => 'admin#state'
  post 'admin/fix_counts', :to => 'admin#fix_counts'
  get 'admin/state', :to => 'admin#state'
  get 'admin/caller_sessions/:id', :to => 'admin#caller_sessions', :as => :admin_caller_sessions
  post 'admin/twilio_limit', :to => 'admin#twilio_limit'
  put 'admin/abandonment/:id', :to => 'admin#abandonment'
  put 'admin/toggle_enterprise_trial/:id', :to => 'admin#toggle_enterprise_trial'
  put 'admin/toggle_calling/:id', :to => 'admin#toggle_calling'
  put 'admin/toggle_access/:id', :to => 'admin#toggle_access'


  resource :call_attempts, :only => :create
end
