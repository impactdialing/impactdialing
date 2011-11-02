module Client
  class CallersController < ClientController
    include DeletableController

    def type_name
      'caller'
    end
    
    def index
      @breadcrumb="Callers"
      @callers = Caller.where(:active => true, :account_id => account.id).order(:name).paginate(:page => params[:page])
    end
    
    def new
      @breadcrumb=[{"Callers"=>"/client/callers"},"Add Caller"]
      @caller =  Caller.new
    end
    
    def show
      @breadcrumb=[{"Callers"=>"/client/callers"},"Add Caller"]
      @caller = account.callers.find_by_id(params[:id])
    end
    
    def update
      @caller = account.callers.find_by_id(params[:id])
      if @caller.update_attributes(params[:caller])      
        flash_message(:notice, "Caller updated")
        redirect_to :action=>"index"          
      else
        render :action=>"new"    
      end
    end
    
    def create
      @caller = Caller.new(params[:caller])
        @caller.account_id = account.id
        if @caller.save
          all_callers = account.callers.active
          all_campaings = account.campaigns.active
          all_campaings.each do |campaign|        
           campaign.callers << @caller if campaign.callers.length >= (all_callers.length)-1
           campaign.save
          end
         flash_message(:notice, "Caller saved")
         redirect_to :action=>"index"      
        else
        render :action=>"new"
       end
    end
    
    def delete
      @caller = account.callers.find_by_id(params[:id])
      if !@caller.blank?
        @caller.active = false
        @caller.save
      end
      flash_message(:notice, "Caller deleted")
      redirect_to :action=>"index"      
    end
    
  end
end
