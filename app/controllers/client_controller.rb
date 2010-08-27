class ClientController < ApplicationController
  before_filter :check_login, :except=>"login"
  layout "client"
  in_place_edit_for :campaign, :name

  def check_login
    if session[:user].blank?
      redirect_to :action=>"login"
      return
    end
    begin
      @user = User.find(session[:user])
    rescue
      logout
    end
  end

  def index
    @breadcrumb=nil
    
  end

  def login
    @breadcrumb="Login"
    
    if !params[:email].blank?
      @user = User.find_by_email_and_password(params[:email],params[:password])
      if @user.blank?
        flash.now[:error]="Invalid Login"
      else
        session[:user]=@user.id
        redirect_to :action=>"index"
      end
    end

  end
  
  def logout
    session[:user]=nil
    redirect_to :controller => 'home', :action=>"index"
  end
  
  def callers
    @breadcrumb="Callers"
    @callers = Caller.paginate :page => params[:page], :conditions =>"active=1 and user_id=#{@user.id}", :order => 'name'
  end
  
  def caller_add
    @breadcrumb=[{"Callers"=>"/client/callers"},"Add Caller"]
    @caller = Caller.find_by_id_and_user_id(params[:id],@user.id) || Caller.new
    if @caller.new_record?
      @label="Add Caller"
    else
      @label="Edit Caller"
    end
    if request.post?
      @caller.update_attributes(params[:caller])
      if @caller.valid?
        @caller.user_id=@user.id
        @caller.save
        flash[:notice]="Caller saved"
        redirect_to :action=>"callers"
        return
      end
    end

  end
  
  def caller_delete
    @caller = Caller.find_by_id_and_user_id(params[:id],@user.id)
    if !@caller.blank?
      @caller.active=false
      @caller.save
    end
    flash[:notice]="Caller deleted"
    redirect_to :action=>"callers"
    return
  end
  
  
  def campaign_delete
    @campaign = Campaign.find_by_id_and_user_id(params[:id],@user.id)
    if !@campaign.blank?
      @campaign.active=false
      @campaign.save
    end
    flash[:notice]="Campaign deleted"
    redirect_to :action=>"campaigns"
    return
  end
  
  def campaigns
    @breadcrumb="Campaigns"
    @campaigns = Campaign.paginate :page => params[:page], :conditions =>"active=1 and user_id=#{@user.id}", :order => 'name'
  end

  def campaign_add
    @breadcrumb=[{"Campaigns"=>"/client/campaigns"},"Add Campaign"]
    @campaign = Campaign.find_by_id_and_user_id(params[:id],@user.id) || Campaign.new
    if @campaign.new_record?
      @label="Add Campaign"
    else
      @label="Edit Campaign"
    end
    if request.post?
      @campaign.update_attributes(params[:campaign])
      if @campaign.valid?
        @campaign.user_id=@user.id
        if @campaign.script_id.blank?
          s = Script.find_by_user_id_and_active(@user.id,1)
          @campaign.script_id=s.id if s!=nil
        end
        @campaign.save
        callers = Caller.find_all_by_user_id_and_active(@user.id,1)
        callers.each do |caller|
          @campaign.callers << caller
        end
        flash[:notice]="Campaign saved"
        redirect_to :action=>"campaign_view", :id=>@campaign.id
        return
      end
    end
  end  

  def campaign_view
    @campaign = Campaign.find_by_id_and_user_id(params[:id],@user.id) 
    @callers = Caller.find_all_by_user_id_and_active(@user.id,true)
    @lists = @campaign.voter_lists
#    @lists = VoterList.find_all_by_user_id_and_active(@user.id,true)
    @breadcrumb=[{"Campaigns"=>"/client/campaigns"},@campaign.name]
#    @voters=Voter.find_all_by_campaign_id_and_active(@campaign.id,true)
    @voters = Voter.paginate :page => params[:page], :conditions =>"active=1 and campaign_id=#{@campaign.id}", :order => 'LastName,FirstName,Phone'
  end
  
  def campaign_hash_delete
#    cache_delete("avail_campaign_hash")
    ActiveRecord::Base.connection.execute("update caller_sessions set available_for_call=0")
    @campaign = Campaign.find_all_by_user_id_and_id(@user.id,params[:id])
    @campaign.end_all_calls(TWILIO_ACCOUNT,TWILIO_AUTH,APP_URL)
    @sessions = CallerSession.find_all_by_campaign_id_and_on_call(params[:id],1)
    @sessions.each do |sess|
      sess.on_call=false
      sess.endtime = Time.now if sess.endtime==nil
      sess.save
    end
    flash[:notice]="Dialer Reset.  Callers must call back in."
    redirect_to :action=>"campaign_view", :id=>params[:id]
    return
  end
  
  def voter_upload
    @campaign = Campaign.find_by_id_and_user_id(params[:id],@user.id) 
    @breadcrumb=[{"Campaigns"=>"/client/campaigns"},{@campaign.name=>"/client/campaign_view/#{@campaign.id}"}, "Upload voters"]
    @lists=VoterList.find_all_by_user_id_and_active(@user.id,true, :order=>"name")
    if (request.post?)
      if params[:upload].blank?
        flash.now[:error]="You must select a file to upload"
        return
      end
      if params[:list_name].blank?
        flash.now[:error]="List name cannot be blank"
        return
      elsif VoterList.find_by_user_id_and_name_and_active(@user.id,params[:list_name],1)!=nil
        flash.now[:error]="List name is aleady in use in this campaign"
        return
      end
      list = VoterList.new
      list.campaign_id=@campaign.id
      list.name=params[:list_name]
      list.user_id=@user.id
      list.save

      # if params[:voterList]=="0" && params[:new_list_name].blank?
      #   flash.now[:error]="List name cannot be blank"
      #   return
      # elseif params[:voterList]=="0" 
      #   l = VoterList.find_by_name_and_user_id(params[:new_list_name], @user.id)
      #   if !l.blank?
      #     flash.now[:error]="List name cannot be blank"
      #     return
      #   end
      # end
      # if params[:voterList]=="0"
      #   list = VoterList.new
      #   list.campaign_id=@campaign.id
      #   list.name=params[:new_list_name]
      #   list.user_id=@user.id
      #   list.save
      # else
      #   list = VoterList.find(params[:voterList])
      # end
      if params[:seperator]=="tab"
        sep="\t"
      else
        sep=","
      end
      @result = @campaign.voter_upload(params[:upload], @user.id,sep, list.id)
    end
    
  end

  def voter_delete
    @voter = Voter.find_by_id_and_user_id(params[:id],@user.id)
    if !@voter.blank?
      @voter.active=false
      @voter.save
    end
    flash[:notice]="Voter deleted"
    redirect_to :action=>"campaign_view", :id=>@voter.campaign_id
    return
  end

  def voter_add
    @campaign = Campaign.find(params[:campaign_id])
    @voter = Voter.find_by_id_and_user_id(params[:id],@user.id) || Voter.new
    if @voter.new_record?
      @label="Add Voter"
    else
      @label="Edit Voter"
    end
    @breadcrumb=[{"Campaigns"=>"/client/campaigns"},{@campaign.name=>"/client/campaign_view/#{@campaign.id}"}, @label]
    if request.post?
      if params[:voterList]=="0" && params[:new_list_name].blank?
        flash.now[:error]="List name cannot be blank"
        return
      elseif params[:voterList]=="0" 
        l = VoterList.find_by_name_and_user_id(params[:new_list_name], @user.id)
        if !l.blank?
          flash.now[:error]="List name cannot be blank"
          return
        end
      end
      if params[:voterList]=="0"
        list = VoterList.new
        list.campaign_id=@campaign.id
        list.name=params[:new_list_name]
        list.user_id=@user.id
        list.save
      else
        list = VoterList.find(params[:voterList])
      end

      @voter.voter_list_id=list.id
      @voter.user_id=@user.id
      @voter.campaign_id=@campaign.id
      @voter.update_attributes(params[:voter])
      if @voter.valid?
        @voter.save
        flash[:notice]="Voter saved"
        redirect_to :action=>"campaign_view", :id=>@campaign.id
        return
      end
    end

  end
  
  def campaign_clear_calls
    ActiveRecord::Base.connection.execute("update voters set result=NULL, status='not called' where campaign_id=#{params[:id]}")
    ActiveRecord::Base.connection.execute("delete from voter_results where campaign_id=#{params[:id]}")
    flash[:notice]="Calls cleared"
    redirect_to :action=>"campaign_view", :id=>params[:id]
    return
  end
  
  def scripts
    @breadcrumb="Scripts"
    @scripts = Script.paginate :page => params[:page], :conditions =>"active=1 and user_id=#{@user.id}", :order => 'name'
  end
  
  def script_add
    if params[:id].blank?
      @breadcrumb=[{"Scripts"=>"/client/scripts"},"Add Script"]
    else
      @breadcrumb=[{"Scripts"=>"/client/scripts"},"Edit Script"]
    end
    @script = Script.find_by_id_and_user_id(params[:id],@user.id)
    if @script==nil
      @script = Script.new
      @script.keypad_1="Strong supportive"
      @script.keypad_2="Lean supportive"
      @script.keypad_3="Undecided"
      @script.keypad_4="Lean opposed"
      @script.keypad_5="Strong opposed"
      @script.keypad_6="Refused"
      @script.keypad_7="Not home/call back"
      @script.keypad_8="Language barrier"
      @script.keypad_9="Wrong number"
      @script.incompletes=["7"].to_json
    end
    if @script.new_record?
      @label="Add Result"
    else
      @label="Edit Result"
    end
    if @script.incompletes!=nil
      begin
        @incompletes = eval(@script.incompletes)
      rescue
        @incompletes=[]
      end
    else
      @incompletes=[]
    end
    
    if request.post?
      @script.update_attributes(params[:script])

      for i in 1..99 do
         thisKeypadval=eval("params[:keypad#{i}]" )
         if !isnumber(thisKeypadval)
           flash.now[:error]= "Keypad value entered '#{thisKeypadval}' must be numeric"
           return
         end
      end
      
      for i in 1..99 do
        @script.attributes = { "keypad_#{i}" => nil }
       end

      for i in 1..99 do
        thisResult=eval("params[:text#{i}]")
        thisKeypadval=eval("params[:keypad#{i}]" )
        if !thisResult.blank? && !thisKeypadval.blank?
            @script.attributes = { "keypad_#{thisKeypadval}" => thisResult }
          
#          eval("@script.keypad_#{thisKeypadval}") = thisResult
#        else
#          eval("@script.keypad_" + thisKeypadval) = nil
        end
      end
      if @script.valid?
        if params[:incomplete]
          @script.incompletes=params[:incomplete].to_json
        else
          @script.incompletes=nil
        end
        @script.user_id=@user.id
        @script.save
        flash[:notice]="Script saved"
        redirect_to :action=>"scripts"
        return
      end
    end

  end
  
  def voter_view
    @campaign = Campaign.find_by_id_and_user_id(params[:campaign_id],@user.id)
    #@voters = Voter.find_all_by_campaign_id_and_active_and_user_id(params[:campaign_id],1,@user.id)
    @voters = Voter.paginate :page => params[:page], :conditions =>"active=1 and campaign_id=#{@campaign.id}", :order => 'LastName,FirstName,Phone'
  end
  
  def reports
    if params[:id].blank?
      @breadcrumb="Reports"
    else
      @campaign = Campaign.find_by_id_and_user_id(params[:id],@user.id)
      @breadcrumb=[{"Reports"=>"/client/reports"},@campaign.name]
    end
  end
  
  def report_realtime
        if params[:id].blank?
          @breadcrumb="Reports"
        else
          @campaign=Campaign.find_by_id_and_user_id(params[:id].to_i,@user.id)
          if @campaign.blank?
            render :text=>"Unauthorized"
            return
          end
          @breadcrumb=[{"Reports"=>"/client/reports"},{"#{@campaign.name}"=>"/client/reports/#{@campaign.id}"},"Realtime Report"]
        end
    #    require "#{RAILS_ROOT}/app/models/caller_session.rb"
    #    require "#{RAILS_ROOT}/app/models/caller.rb"
  end
  
  def update_report
#    Rails.logger.silence do
      # CallerSession
      # Caller
      if params[:timeframe].blank?
        @timeframe = 10
      else
        @timeframe = params[:timeframe].to_i
      end
    
      # if !params[:clear].blank?
      #   cache_delete("avail_campaign_hash")
      # end
      # @avail_campaign_hash = cache_get("avail_campaign_hash") {{}} 
      @campaign = Campaign.find_by_id_and_user_id(params[:id],@user.id)
      render :layout=>false
#    end
  end
  
  def report_overview
    @campaign=Campaign.find_by_id_and_user_id(params[:id].to_i,@user.id)
    if @campaign.blank?
      render :text=>"Unauthorized"
      return
    end
    if params[:type]=="1"
      extra="and result is not null"
    end
    
    @breadcrumb=[{"Reports"=>"/client/reports"},{"#{@campaign.name}"=>"/client/reports/#{@campaign.id}"},"Realtime Report"]
    @records = ActiveRecord::Base.connection.execute(" SELECT count(*) as cnt, result FROM call_attempts where campaign_id=#{@campaign.id} #{extra}
    group by result order by count(*) desc")
    @total=0
    @records.each do |r|
      @total = @total + r[0].to_i
    end
    @records.data_seek(0)
    
    @voters_to_call = @campaign.voters("not called",false)
    @voters_called = @campaign.voters_called
    @totalvoters = @voters_to_call.length + @voters_called.length
  end
  
  # def show_memcached
  #   @avail_campaign_hash = cache_get("avail_campaign_hash") {{}} 
  # end

end
