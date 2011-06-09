module Client
  class ScriptsController < ClientController
    def deleted
      @scripts = Script.deleted.for_user(@user).paginate :page => params[:page], :order => 'id desc'
    end

    def restore
      Script.find(params[:script_id]).tap do |s|
        s.restore
        s.save
      end
      redirect_to :back
    end
  end
end
