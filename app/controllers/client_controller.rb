class ClientController < ApplicationController
  before_filter :check_login, :except=>[:login,:user_add]
  before_filter :check_warning
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
  
  def user_add
    @breadcrumb="Join"
    
    @user = User.new
    
    if request.post?
      @user.attributes =  params[:user]
      if params[:tos].blank?
        flash.now[:error]="You must agree to the terms of service."
        return
      end
      
      if @user.valid? &&  !params[:tos].blank?
        @user.save
        @caller = Caller.new
        @caller.name="Default Caller"
        @caller.multi_user=true
        @caller.user_id=@user.id
        @caller.save
        @script = Script.new
        @script.name="Voter ID Example"
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
        @script.script="Hi, I'm a volunteer with the such-and-such campaign.

I'm voting for such-and-such because...

Can we count on you to vote for such-and-such?"
        @script.active=1
        @script.user_id=@user.id
        @script.save
        @script = Script.new
        @script.name="GOTV Example"
        @script.keypad_1="Will vote early"
        @script.keypad_2="Will vote on election day"
        @script.keypad_3="Already voted"
        @script.keypad_4="Will not vote"
        @script.keypad_5="Not a supporter"
        @script.keypad_6="Refused"
        @script.keypad_7="Not home/call back"
        @script.keypad_8="Language barrier"
        @script.keypad_9="Wrong number"
        @script.incompletes=["7"].to_json
        @script.script="Hi, I'm a volunteer with the such-and-such campaign.

I'm voting for such-and-such because...

Can we count on you to vote for such-and-such?"
        @script.active=1
        @script.user_id=@user.id
        @script.save
        session[:user]=@user.id
        redirect_to :action=>"index"
        flash[:notice]="Your account has been created"
      end
    end
    
    
  end

  def check_warning
    text=warning_text
    if !text.blank?
      flash.now[:warning]=text
    end
  end

  def index
    @breadcrumb=nil
    
  end

  def login
    @breadcrumb="Login"
    
    if !params[:user].blank?
      user_add
    end
    
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
        
        # add to campaigns with all callers
        all_callers = Caller.find_all_by_user_id_and_active(@user.id,1)
        all_campaings = Campaign.find_all_by_user_id_and_active(@user.id,1)
        all_campaings.each do |campaign|
          if campaign.callers.length >= (all_callers.length)-1
            campaign.callers << @caller
          end
        end
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
  
  def campaign_new
    c = Campaign.new
    c.user_id=@user.id
    count = Campaign.find_all_by_user_id(@user.id)
    c.name="Untitled #{count.length+1}"
    script = Script.find_by_user_id(@user.id)
    c.script_id=script.id if script!=nil
    c.save
    callers = Caller.find_all_by_user_id_and_active(@user.id,1)
    callers.each do |caller|
      c.callers << caller
    end
    flash[:notice]="Campaign created."
    redirect_to :action=>"campaign_view", :id=>c.id
    return
  end

  def campaign_add
    @breadcrumb=[{"Campaigns"=>"/client/campaigns"},"Add Campaign"]
    @campaign = Campaign.find_by_id_and_user_id(params[:id],@user.id) || Campaign.new
    if @campaign.new_record?
      @label="Add Campaign"
    else
      @label="Edit Campaign"
    end
    newrecord = @campaign.new_record?
    if request.post?
      last_caller_id = @campaign.caller_id
      @campaign.update_attributes(params[:campaign])
      code=""
      if @campaign.valid?
        if !@campaign.caller_id_verified || (!@campaign.caller_id.blank? && last_caller_id != @campaign.caller_id)
          #verify this callerid
          t = Twilio.new(TWILIO_ACCOUNT, TWILIO_AUTH)
          a=t.call("POST", "OutgoingCallerIds", {'PhoneNumber'=>@campaign.caller_id, 'FriendlyName' => "Campaign #{@campaign.id}"})
          require 'rubygems'
          require 'hpricot'
          @doc = Hpricot::XML(a)
          code= (@doc/"ValidationCode").inner_html
        end
        @campaign.user_id=@user.id
        if @campaign.script_id.blank?
          s = Script.find_by_user_id_and_active(@user.id,1)
          @campaign.script_id=s.id if s!=nil
        end
        @campaign.save
        if params[:listsSent]
          @campaign.voter_lists.each do |l|
            l.enabled=false
            l.save
          end
          if !params[:voter_list_ids].blank?
            params[:voter_list_ids].each do |lid|
              l = VoterList.find(lid)
              l.enabled=true
              l.save
            end
          end
        end
        if newrecord
          callers = Caller.find_all_by_user_id_and_active(@user.id,1)
          callers.each do |caller|
            @campaign.callers << caller
          end
        end
        if code.blank?
          flash[:notice]="Campaign saved"
        else
          flash[:notice]="Campaign saved.  <font color=red>Enter code #{code} when called.</font>"
        end
        redirect_to :action=>"campaign_view", :id=>@campaign.id
        return
      end
    end
  end  

  def campaign_view
    @campaign = Campaign.find_by_id_and_user_id(params[:id],@user.id) 
    @breadcrumb=[{"Campaigns"=>"/client/campaigns"},@campaign.name]

    @callers = Caller.find_all_by_user_id_and_active(@user.id,true)
    @lists = @campaign.voter_lists
    @voters = Voter.paginate :page => params[:page], :conditions =>"active=1 and campaign_id=#{@campaign.id}", :order => 'LastName,FirstName,Phone'

#    @campaign.check_valid_caller_id_and_save
#    flash.now[:error]="Your Campaign Caller ID is not verified."  if !@campaign.caller_id.blank? && !@campaign.caller_id_verified
    flash.now[:error]="You must enter a campaign Caller ID before you can take calls"  if @campaign.caller_id.blank?
    @isAdmin = @user.admin
    @show_voter_buttons = @user.show_voter_buttons
    render :layout=>"campaign_view"
  end
  
  def campaign_caller_id_verified
    @campaign = Campaign.find_by_id_and_user_id(params[:id],@user.id) 
    @campaign.check_valid_caller_id_and_save
    ret=""
    if !@campaign.caller_id.blank? && !@campaign.caller_id_verified
      ret = "<div class='msg msg-error'> <p><strong>Your Campaign Caller ID is not verified.</strong></p> </div>"  
    else
      ret = ""  
    end
    render :text=>ret
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
#    ActiveRecord::Base.connection.execute("delete from voter_results where campaign_id=#{params[:id]}")
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
    @breadcrumb=[{"Campaigns"=>"/client/campaigns"},{"#{@campaign.name}"=>"/client/campaign_view/#{@campaign.id}"},"View Voters"]
    #@voters = Voter.find_all_by_campaign_id_and_active_and_user_id(params[:campaign_id],1,@user.id)
#    @voters = Voter.paginate :page => params[:page], :conditions =>"active=1 and campaign_id=#{@campaign.id}", :order => 'LastName,FirstName,Phone'
    @voters = Voter.paginate :page => params[:page], :conditions =>"active=1 and campaign_id=#{@campaign.id} and voter_list_id in (#{@campaign.voter_lists.collect{|c| c.id.to_s + ","}}0)", :order => 'LastName,FirstName,Phone'
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


     @breadcrumb=[{"Reports"=>"/client/reports"},{"#{@campaign.name}"=>"/client/reports/#{@campaign.id}"},"Realtime Report"]
     sql="#select distinct status from call_attempts  

     select 
     count(*) as cnt,
     case WHEN ca.status='Call abandoned'  THEN 'Call abandoned'
     WHEN ca.status='Hangup or answering machine' THEN 'Hangup or answering machine'
     WHEN ca.status='No answer' THEN 'No answer'
     ELSE 'Call completed with success.' 
     END AS result

      from 
     voters v join call_attempts ca on ca.id = v.attempt_id
     where ca.campaign_id=#{@campaign.id}
     group by 
     case WHEN ca.status='Call abandoned'  THEN 'Call abandoned'
     WHEN ca.status='Hangup or answering machine' THEN 'Hangup or answering machine'
     WHEN ca.status='No answer' THEN 'No answer'
     ELSE 'Call completed with success.' 
     END 

     order by count(*) desc"
     @records = ActiveRecord::Base.connection.execute(sql)
     @total=0
     @records.each do |r|
       @total = @total + r[0].to_i
     end
     @records.data_seek(0)

     @voters_to_call = @campaign.voters("not called",false)
     @voters_called = @campaign.voters_called
     @totalvoters = @voters_to_call.length + @voters_called.length
     
     @call_attempts = CallAttempt.find_all_by_campaign_id(@campaign.id)
     @caller_sessions = CallerSession.find_all_by_campaign_id(@campaign.id)

     @talkmins=0
     @call_attempts.each do |attempt|
       @talkmins += attempt.minutes_used
     end
     @callerMins=0
     @caller_sessions.each do |session|
       @callerMins += session.minutes_used
     end

  end

  def report_overview_old
    @campaign=Campaign.find_by_id_and_user_id(params[:id].to_i,@user.id)
    if @campaign.blank?
      render :text=>"Unauthorized"
      return
    end
    if params[:type]=="1"
      extra="and result is not null"
    end
    
    @breadcrumb=[{"Reports"=>"/client/reports"},{"#{@campaign.name}"=>"/client/reports/#{@campaign.id}"},"Answered Call Report"]

    if params[:from_date]
      @from_date=Date.parse params[:from_date]
      @to_date = Date.parse params[:to_date]
    else
      firstCall = CallerSession.first(:order=>"id asc", :limit=>"1")
      lastCall = CallerSession.first(:order=>"id desc", :limit=>"1")
      if !firstCall.blank?
        @from_date  = firstCall.created_at
      end
      if !lastCall.blank?
        @to_date  = lastCall.created_at
      end
    end


    @records = ActiveRecord::Base.connection.execute("SELECT count(*) as cnt, result FROM call_attempts where campaign_id=#{@campaign.id} and created_at > '#{@from_date.strftime("%Y-%m-%d")}' and created_at < '#{(@to_date+1.day).strftime("%Y-%m-%d")}'  #{extra}
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
  def script_delete
    @script = Script.find_by_id_and_user_id(params[:id],@user.id)
    if !@script.blank?
      @script.active=false
      @script.save
    end
    flash[:notice]="Script deleted"
    redirect_to :action=>"scripts"
    return
  end
  
  def report_caller
    @campaign=Campaign.find_by_id_and_user_id(params[:id].to_i,@user.id)
    if @campaign.blank?
      render :text=>"Unauthorized"
      return
    end
    if params[:type]=="1"
      extra="and result is not null"
    end
    
    @breadcrumb=[{"Reports"=>"/client/reports"},{"#{@campaign.name}"=>"/client/reports/#{@campaign.id}"},"Caller Report"]

    if params[:from_date]
      @from_date=Date.parse params[:from_date]
      @to_date = Date.parse params[:to_date]
    else
      firstCall = CallerSession.first(:order=>"id asc", :limit=>"1")
      lastCall = CallerSession.first(:order=>"id desc", :limit=>"1")
      if !firstCall.blank?
        @from_date  = firstCall.created_at
      end
      if !lastCall.blank?
        @to_date  = lastCall.created_at
      end
    end
    caller_ids=CallerSession.all(:select=>"distinct caller_id", :conditions=>"campaign_id=#{@campaign.id}")
    @callers=[]
    caller_ids.each do |caller_session|
      @callers<< Caller.find(caller_session.caller_id)
    end
    
    #{}find_all_by_user_id(@user.id)
    @responses = Voter.all(:select=>"distinct result", :conditions=>"campaign_id = #{@campaign.id} and result is not null and result_date > '#{@from_date.strftime("%Y-%m-%d")}' and result_date < '#{(@to_date+1.day).strftime("%Y-%m-%d")}'")
    @num_responses = Voter.all(:conditions=>"campaign_id = #{@campaign.id} and result is not null and result_date > '#{@from_date.strftime("%Y-%m-%d")}' and result_date < '#{(@to_date+1.day).strftime("%Y-%m-%d")}'").length

  end
  
  def report_caller_overview
    @campaign=Campaign.find_by_id_and_user_id(params[:id].to_i,@user.id)
    if @campaign.blank?
      render :text=>"Unauthorized"
      return
    end
    if params[:type]=="1"
      extra="and result is not null"
    end
    
    @breadcrumb=[{"Reports"=>"/client/reports"},{"#{@campaign.name}"=>"/client/reports/#{@campaign.id}"},"Caller Report"]

    if params[:from_date]
      @from_date=Date.parse params[:from_date]
      @to_date = Date.parse params[:to_date]
    else
      firstCall = CallerSession.first(:order=>"id asc", :limit=>"1")
      lastCall = CallerSession.first(:order=>"id desc", :limit=>"1")
      if !firstCall.blank?
        @from_date  = firstCall.created_at
      end
      if !lastCall.blank?
        @to_date  = lastCall.created_at
      end
    end
    caller_ids=CallerSession.all(:select=>"distinct caller_id", :conditions=>"campaign_id=#{@campaign.id}")
    @callers=[]
    caller_ids.each do |caller_session|
      @callers<< Caller.find(caller_session.caller_id)
    end
    
  end

  def report_login

      @campaign=Campaign.find_by_id_and_user_id(params[:id].to_i,@user.id)
      if @campaign.blank?
        render :text=>"Unauthorized"
        return
      end
      if params[:type]=="1"
        extra="and result is not null"
      end

      @breadcrumb=[{"Reports"=>"/client/reports"},{"#{@campaign.name}"=>"/client/reports/#{@campaign.id}"},"Caller Report"]
#      @logins = CallerSession.find_all_by_campagin_id(@campagin.id, :order=>"id desc")
       @logins = CallerSession.find_all_by_campaign_id(@campaign.id, :order=>"id desc")
  end
  
  def report_real
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
    
  end
  def update_report_real
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
  end
end
