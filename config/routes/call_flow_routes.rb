ImpactDialing::Application.routes.draw do
  
  resources :calls, :protocol => PROTOCOL do
    member do
      post :flow
      post :hangup
      post :submit_result
      post :submit_result_and_stop
    end
  end
    
end