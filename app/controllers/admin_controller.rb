class AdminController < ApplicationController
  layout "basic"
  USER_NAME, PASSWORD = "impact", "dial123"
  before_filter :authenticate
  require "nokogiri"
  
  def status
    
    if Time.now.hour > 0 && Time.now.hour < 6
      @calling_status="<font color=red>Unavailable, off hours</font>"
    else
      @calling_status="Available"
    end
    @logged_in_campaigns = Campaign.all(:conditions=>"id in (select distinct campaign_id from caller_sessions where on_call=1)")
    @ready_to_dial = CallAttempt.find_all_by_status("Call ready to dial", :conditions=>"call_end is null")
    @errors=""
  	t = Twilio.new(TWILIO_ACCOUNT, TWILIO_AUTH)
  	a=t.call("GET", "Calls?Status=queued", {})
    doc  = Nokogiri::XML(a)
    @queued=doc.xpath("//Calls").first.attributes["total"].value

  end
  
  def users
    @users = User.all
  end
  
  def toggle_paid
    user = User.find(params[:id])
    if user.paid==true
      user.paid=false
    else
      user.paid=true
    end
    user.save
    redirect_to :action=>"users"
  end
  
  def login
    session[:user]=params[:id]
    redirect_to :controller=>"client", :action=>"index"
  end
  
  def user
    @user = User.new
    if request.post?
      @user.update_attributes params[:user]
      if @user.valid?
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
        flash[:notice]="User created!"
        redirect_to :controller=>"client"
      end
    end
  end
  
    def cms
      @version = session[:cms_version] 
      @keys = Seo.find(:all).map{ |i| i.crmkey }.uniq
      @keys.delete_if {|x| x == nil}
      @keys.sort!
    end

    def add_cms
      if request.post?
        s = Seo.new
        s.crmkey=params[:key]
        s.content = params[:content]
        s.active=1
        s.save
        s.version=session[:cms_version]
        s.version=nil if session[:cms_version].blank?
        flash[:notice]="CMS updated successfully"
        redirect_to :action=>"cms"
      end
    end
    
    
    def edit_cms
      @seo = Seo.new
      @seoold = Seo.find(params[:id])
      @seo.crmkey = @seoold.crmkey
      @seo.content = @seoold.content
      @version = session[:cms_version]
      if request.post?
        @seo.attributes = params[:seo]
        @seoold.active=0
        @seoold.save
        @seo.active=1
        @seo.version=session[:cms_version]
        @seo.version=nil if session[:cms_version].blank?
        @seo.save
        flash[:notice]="CMS updated successfully"
        redirect_to :action=>"cms"
        return
      end
     end
     
    def pick_version
      if request.post?
        if params[:v]
          session[:cms_version]=params[:v]
          session[:cms_version]=nil if params[:v].blank? || params[:v]=="Live"
          flash[:notice]="CMS version changed"
          redirect_to :action=>"cms"
        end
        if !params[:nv].blank?
          test = Seo.find_by_version(params[:nv])
          if !test.blank?
            render :text=>"error - version already created!"
            return
          else
            # x = Seo.new
            # x.crmkey="optimizer_control_script"
            # x.active=1
            # x.version=params[:nv].strip
            # x.save
            # session[:cms_version]=x.version
            session[:cms_version]=params[:nv].strip
            flash[:notice]="CMS version added successfully"
            redirect_to :action=>"cms"
          end
        end
      end    
      @versions = Seo.find(:all).map{ |i| i.version }.uniq
    end

    def copy_cms
      @version = session[:cms_version]
      @source = Seo.find(params[:id])

      if request.post?
        s = Seo.new
        s.crmkey=params[:key]
        s.content = params[:content]
        s.active=1
        s.version=session[:cms_version]
        s.version=nil if session[:cms_version].blank?
        s.save
        flash[:notice]="CMS updated successfully"
        redirect_to :action=>"cms"
      end
    end
  private
   def authenticate
     authenticate_or_request_with_http_basic(self.class.controller_path) do |user_name, password| 
       user_name == USER_NAME && password == PASSWORD
     end
  end
end
