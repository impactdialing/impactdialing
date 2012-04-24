class ScriptsController < ClientController
  include DeletableController
  before_filter :full_access
  before_filter :new_script, :only => [:new, :create]
  before_filter :load_script, :only => [:update, :show, :destroy, :edit]
  before_filter :apply_changes, :only => [:create, :update]
  


  def type_name
    'script'
  end

  def load_script
    @script = Script.find(params[:id])
  end

  def index
  @scripts = @user.account.scripts.active.robo.paginate(:page => params[:page])
  end
  
  def load_deleted
    self.instance_variable_set("@#{type_name.pluralize}", @user.account.scripts.deleted.robo.for_account(@user.account).paginate(:page => params[:page], :order => 'id desc'))
  end    
  
  
  def deleted
    render 'scripts/deleted'
  end
  
  
  def new_script
    @fields = ["CustomID", "FirstName", "MiddleName", "LastName", "Suffix", "Age", "Gender", "Phone", "Email"]
    @breadcrumb=[{"Scripts"=>"/client/scripts"}, "Add Script"]
    @label = 'New Script'
    @script = @user.account.scripts.new(:name => 'Untitled Script', :robo=>true)
    @incompletes = {}
    @voter_fields = []
    @numResults = 1
    @numNotes = 0
  end

  def new
    @script.robo_recordings.build
  end

  def create
    #before filter apply_changes triggered here
  end

  def update
    #before filter apply_changes triggered here
  end

  def apply_changes
    @script.update_attributes(params[:script])
    numResults = params[:numResults]
    for r in 1..numResults.to_i do

      for i in 1..99 do
        this_keypadval = params["keypad_#{r}_#{i}"]
        if !this_keypadval.blank? && !isnumber(this_keypadval)
          flash_now(:error, "Keypad value for call results #{r} entered '#{this_keypadval}' must be numeric")
          return
        end
      end

      this_results={}
      for i in 1..99 do
        this_result = params["text_#{r}_#{i}"]
        this_keypadval = params["keypad_#{r}_#{i}"]
        if !this_result.blank? && !this_keypadval.blank?
          this_results["keypad_#{i}"] = this_result
        else
          this_results["keypad_#{i}"] = nil
        end
      end
      logger.info "Done with #{r}: #{this_results.inspect}"
      @script.attributes = {"result_set_#{r}" => this_results.to_json}
    end

    for i in 1..NUM_RESULT_FIELDS do
      this_note = params["note_#{i}"]
      @script.attributes = {"note_#{i}" => this_note.blank? ? nil : this_note}
    end

    all_incompletes={}
    for i in 1..NUM_RESULT_FIELDS do
      all_incompletes[i] = params["incomplete_#{i}_"] || []
    end

    @script.incompletes = all_incompletes.to_json

    if @script.valid?
      @script.voter_fields = params[:voter_field] ? params[:voter_field].to_json : nil

      @script.save
      flash_message(:notice, "Script saved")
      redirect_to scripts_path
    else
      render :action => 'new'
    end
  end

  def show
    @fields = ["CustomID", "FirstName", "MiddleName", "LastName", "Suffix", "Age", "Gender", "Phone", "Email"]
    @breadcrumb=[{"Scripts"=>"/client/scripts"}, "Edit Script"]
    @label = "Add script"

    @numResults = 0
    for i in 1..NUM_RESULT_FIELDS do
      @numResults+=1 if !eval("@script.result_set_#{i}").blank?
    end
    @numNotes = 0
    for i in 1..NUM_RESULT_FIELDS do
      @numNotes+=1 if !eval("@script.note_#{i}").blank?
    end

    if @script.incompletes!=nil
      begin
        @incompletes = JSON.parse(@script.incompletes)
      rescue
        @incompletes={}
      end
    else
      @incompletes={}
    end

    if @script.voter_fields!=nil
      begin
        @voter_fields = eval(@script.voter_fields)
      rescue
        @voter_fields=[]
      end
    else
      @voter_fields=[]
    end
    render :template => 'scripts/new'
  end
  
end
