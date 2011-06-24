class ScriptsController < ClientController
  layout 'v2'
  include DeletableController

  before_filter :new_script, :only => [:new, :create]

  def type_name
    'script'
  end

  def index
    @scripts = @user.scripts.active.paginate(:page => params[:page])
  end

  def new_script
    @fields = ["CustomID","FirstName","MiddleName","LastName","Suffix","Age","Gender","Phone","Email"]
    @breadcrumb=[{"Scripts"=>"/client/scripts"},"Add Script"]
    @label = 'New Script'
    @script = @user.scripts.new(:name => 'Untitled Script')
    @incompletes = {}
    @voter_fields = []
    @numResults = 1
    @numNotes = 0
  end

  def create
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
          this_results["keypad_#{i}"] =  this_result
        else
          this_results["keypad_#{i}"] = nil
        end
      end
      logger.info "Done with #{r}: #{this_results.inspect}"
      @script.attributes =   { "result_set_#{r}" => this_results.to_json }
    end

    for i in 1..NUM_RESULT_FIELDS do
      this_note = params["note_#{i}"]
      @script.attributes = { "note_#{i}" => this_note.blank? ? nil : this_note }
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
end
