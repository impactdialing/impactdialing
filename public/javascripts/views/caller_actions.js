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

  conferenceStarted: function(lead_info){
    this.setMessage("Status: Ready for calls.");
    if (lead_info.get("dialer") && lead_info.get("dialer").toLowerCase() == "progressive") {
      this.call_voter(lead_info.get("fields").id);
    }
    if (lead_info.get("dialer") && lead_info.get("dialer").toLowerCase() == "preview") {
      $("#skip_voter").show();
      $("#call_voter").show();
    }
  },

  callingVoter: function(){
    this.setMessage('Status: Call in progress.');
  },

  voterConnected: function(){
    this.setMessage("Status: Connected.");
    this.hideAllActions();
  }

  setMessage: function(text) {
    $("#statusdiv").html(text);
  },

  call_voter: function(voter_id) {
    var self = this;
    $.ajax({
        url : "/caller/" + self.model.get("caller_id") + "/call_voter",
        data : {id : self.model.get("caller_id"), voter_id : voter_id, session_id : self.model.get("session_id") },
        type : "POST"
    });
  },

  disconnectCaller: function(){
    var self = this;
    window.onbeforeunload = null;
    $.ajax({
      url : "/caller/" + self.model.get("caller_id") + "/stop_calling",
      data : {session_id : self.model.get("session_id") },
      type : "POST",
    });
  },

  hideAllActions: function(){
    $("#caller-actions a").hide();
  },


})