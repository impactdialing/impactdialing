ImpactDialing.Views.CallerActions = Backbone.View.extend({

  initialize: function(){
    this.setMessage("Not Connected.");

    ImpactDialing.Events.on('transfer.starting', function(){
      $('#hangup_call').hide();
      $('#kick_transfer').hide();
    });
    ImpactDialing.Events.on('transfer.error', function(){
      $('#hangup_call').show();
    });
    ImpactDialing.Events.on('transfer.kicked', function(){
      $('#kick_transfer').hide();
    });

    ImpactDialing.Events.bind('channel.subscribed', this.setupChannelHandlers);
  },

  render: function() {
    $(this.el).html(Mustache.to_html($('#caller-campaign-action-template').html()));
    return this;
  },

  events: {
    "click #stop_calling": "disconnectCaller",
    "click #hangup_call": "disconnectVoter",
    "click #call_voter": "callVoter",
    "click #submit_and_keep_call": "sendVoterResponse",
    "click #submit_and_stop_call": "sendVoterResponseAndDisconnect",
    "click #skip_voter" : "nextVoter",
    "click #kick_caller" : "kickCallerOff",
    "click #kick_transfer": "kickTransfer"
  },

  setupChannelHandlers: function(){
    var self = this;
    ImpactDialing.Channel.bind('warm_transfer', function(){
      $('#kick_transfer').show();
      $('#kick_caller').show();
      $("#submit_and_keep_call").hide();
      $("#submit_and_stop_call").hide();
    });
    ImpactDialing.Channel.bind('cold_transfer', function(){
      $('#hangup_call').hide();
      $('#kick_caller').hide();
      $('#schedule_callback').hide();
      $('#transfer-calls').hide();
      $("#submit_and_keep_call").show();
      $("#submit_and_stop_call").show();
    });
    ImpactDialing.Channel.bind('caller_kicked_off', function(){
      $('#kick_transfer').hide();
      $('#kick_caller').hide();
      $("#submit_and_keep_call").show();
      $("#submit_and_stop_call").show();
      $('#statusdiv').text("Status: Waiting for call results.");
    });
  },

  startCalling: function(){
    $('#stop_calling').show();
    $("#called_in").show();
  },

  conferenceStarted: function(){
    this.hideAllActions();
    $('#stop_calling').show();
    this.setMessage("Ready for calls.");
    var lead_info = this.options.lead_info;
    if(lead_info.get("campaign_out_of_leads") == true){
      this.setMessage("The campaign has run out of numbers.");
      return
    }
    if (lead_info.get("dialer") && lead_info.get("dialer").toLowerCase() == "power") {
      this.callVoter();
    }
    if (lead_info.get("dialer") && lead_info.get("dialer").toLowerCase() == "preview") {
      $("#skip_voter").show();
      $("#call_voter").show();
    }
  },

  callerConnectedDialer: function(){
    this.hideAllActions();
    $("#stop_calling").show();
    this.setMessage("Dialing.");
  },

  callingVoter: function(){
    this.setMessage('Call in progress.');
    $("#skip_voter").hide();
    $("#call_voter").hide();
  },

  voterConnected: function(){
    this.setMessage("Connected.");
    this.hideAllActions();
    this.showTransferCall();
    this.showScheduler();
    this.showHangupButton();
  },

  voterConnectedDialer: function(){
    this.hideAllActions();
    this.setMessage("Connected.")
    this.showTransferCall();
    this.showHangupButton();
    this.showScheduler();
  },

  voterDisconected: function(){
    if( this.model.get("transfer_type") !== 'warm' ){
      this.hideAllActions();
      this.hideTransferCall();
      this.setMessage("Waiting for call results.");
      this.submitResponseButtonsShow();
    }
  },

  sendVoterResponse: function(e) {
    e.stopPropagation();
    e.preventDefault();
    if(this.options.schedule_callback.validateScheduleDate() == false){
      alert('The Schedule callback date is invalid');
      return false;
    }
    this.hideAllActions();
    this.hideScheduler();
    this.setMessage("Submitting call results.");
    var self = this;
    var options = {
      data: {
        caller_session: self.model.get("session_id")
      },
      success: function(data, status, xhr){
        self.setMessage('Call results saved.');
      },
      error: function(xhr, status, error){
        self.setMessage('Call results failed to save.');
        $('#submit_and_keep_call').show();
        $('#submit_and_stop_call').show();
      }
    };

    $('#voter_responses').attr('action', "/calls/" + self.model.get("call_id") + "/submit_result");

    $('#voter_responses').ajaxSubmit(options);
  },

   sendVoterResponseAndDisconnect: function(e) {
    e.stopPropagation();
    e.preventDefault();
    if(this.options.schedule_callback.validateScheduleDate() == false){
      alert('The Schedule callback date is invalid');
      return false;
    }

    this.hideAllActions();
    this.hideScheduler();
    this.setMessage("Submitting call results.");
    var self = this;
    var options = {
      data: {stop_calling: true, caller_session: self.model.get("session_id") },
        success:  function() {
            window.location.reload();
        }
    };

    $('#voter_responses').attr('action', "/calls/" + self.model.get("call_id") + "/submit_result_and_stop");
    $('#voter_id').val(this.options.lead_info.get("fields").id);
    $('#voter_responses').submit(function() {
        $(this).ajaxSubmit(options);
        return false;
    });
    $("#voter_responses").trigger("submit");
    $("#voter_responses").unbind("submit");
  },

  transferConferenceEnded: function(){
    this.hideHangupButton();
    this.kickSelfOutOfConferenceHide();
    this.kickTransferHide();
    if (this.model.get("call_id") == this.model.get("transfer_call_id")){
      $('#transfer_button').text("Transfer");
      $("#transfer-calls").show();
      this.showHangupButton();
    }
  },

  callerKickedOff: function(){
    this.kickSelfOutOfConferenceHide();
    this.submitResponseButtonsShow();
    this.setMessage("Waiting for call results.");
  },


  setMessage: function(text) {
    $("#statusdiv").text("Status: " + text);
  },

  showTransferCall: function(){
    $("#transfer-calls").show();
  },

  hideTransferCall: function(){
    $("#transfer-calls").hide();
  },

  showScheduler: function(){
    $("#schedule_callback").show();
  },

  hideScheduler: function(){
    $("#schedule_callback").hide();
  },

  showHangupButton: function(){
    $("#hangup_call").show();
  },

  hideHangupButton: function(){
    $("#hangup_call").hide();
  },

  kickSelfOutOfConferenceHide: function(){
    $('#kick_caller').hide();
  },

  kickSelfOutOfConferenceShow: function(){
    $('#kick_caller').show();
  },

  kickTransferShow: function(){
    $('#kick_transfer').show();
  },

  kickTransferHide: function(){
    $('#kick_transfer').hide();
  },

  submitResponseButtonsShow: function(){
    $("#submit_and_keep_call").show();
    $("#submit_and_stop_call").show();
  },

  submitResponseButtonsHide: function(){
    $("#submit_and_keep_call").hide();
    $("#submit_and_stop_call").hide();
  },

  callVoter: function(e) {
    if (typeof(e) != "undefined"){
      e.stopPropagation();
      e.preventDefault();
    }
    var voter_id = this.options.lead_info.get("fields").id;
    var self = this;
    $.ajax({
        url : "/caller/" + self.model.get("caller_id") + "/call_voter",
        data : {id : self.model.get("caller_id"), voter_id : voter_id, session_id : self.model.get("session_id") },
        type : "POST",
        beforeSend: function(request)
          {
            var token = $("meta[name='csrf-token']").attr("content");
            request.setRequestHeader("X-CSRF-Token", token);
          },
    });
  },

  disconnectCaller: function(e){
    e.stopPropagation();
    e.preventDefault();
    var self = this;
    window.onbeforeunload = null;
    $.ajax({
      url : "/caller/" + self.model.get("caller_id") + "/stop_calling",
      data : {session_id : self.model.get("session_id") },
      type : "POST",
      beforeSend: function(request)
        {
            var token = $("meta[name='csrf-token']").attr("content");
            request.setRequestHeader("X-CSRF-Token", token);
        },
    });
  },

  disconnectVoter: function(e) {
    e.stopPropagation();
    e.preventDefault();
    var self = this;
    $("#hangup_call").hide();
    $("#transfer-calls").hide();
    // if (this.model.get("call_id") == this.model.get("transfer_call_id")){
      this.submitResponseButtonsShow();
    // }
    $.ajax({
        url : "/calls/" + self.model.get("call_id") + "/hangup",
        type : "POST",
        beforeSend: function(request)
          {
            var token = $("meta[name='csrf-token']").attr("content");
            request.setRequestHeader("X-CSRF-Token", token);
          },
    });
  },

  nextVoter: function(e) {
    e.stopPropagation();
    e.preventDefault();
    var self = this;
    $.ajax({
        url : "/caller/" + self.model.get("caller_id") + "/skip_voter",
        data : {id : self.model.get("caller_id"), voter_id : self.options.lead_info.get("fields").id,
        session_id : self.model.get("session_id") },
        type : "POST",
        beforeSend: function(request) {
          var token = $("meta[name='csrf-token']").attr("content");
          request.setRequestHeader("X-CSRF-Token", token);
        },
    });
  },

  hideAllActions: function(){
    $("#caller-actions a").hide();
  },

  kickCallerOff: function(e){
    e.stopPropagation();
    e.preventDefault();
    this.model.kickCaller();
  },

  kickTransfer: function(e){
    e.stopPropagation();
    e.preventDefault();
    this.model.kickTransfer();
  }
});