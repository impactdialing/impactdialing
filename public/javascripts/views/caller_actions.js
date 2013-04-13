ImpactDialing.Views.CallerActions = Backbone.View.extend({

  render: function() {
    $(this.el).html(Mustache.to_html($('#caller-campaign-action-template').html()));
    return this;
  },

  events: {
    "click #stop_calling": "disconnectCaller"
  },


  startCalling: function(){
    $('#stop_calling').show();
    $("#called_in").show();
  },

  conferenceStarted: function(data){
    setMessage("Status: Ready for calls.");
    if (data.dialer && data.dialer.toLowerCase() == "progressive") {
      call_voter();
    }
    if (data.dialer && data.dialer.toLowerCase() == "preview") {
      $("#skip_voter").show();
      $("#call_voter").show();
    }
  },

  setMessage: function(text) {
    $("#statusdiv").html(text);
  },

  call_voter: function() {
    $.ajax({
        url : "/caller/" + $("#caller").val() + "/call_voter",
        data : {id : $("#caller").val(), voter_id : $("#current_voter").val(), session_id : $("#caller_session").val() },
        type : "POST"
    });
  },

  disconnectCaller: function(){
    var self = this;
    window.onbeforeunload = null;
    console.log(this.model.toJSON())
    console.log("disconnect caller")
    $.ajax({
      url : "/caller/" + self.model.get("caller_id") + "/stop_calling",
      data : {session_id : self.model.get("session_id") },
      type : "POST",
    });
  },


})