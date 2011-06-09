module Client
  class CallersController < ClientController
    def deleted
      @callers = Caller.deleted.for_user(@user).paginate :page => params[:page], :order => 'id desc'
    end

    def restore
      Caller.find(params[:caller_id]).tap do |c|
        c.restore
        c.save
      end
      redirect_to :back
    end
  end
end
