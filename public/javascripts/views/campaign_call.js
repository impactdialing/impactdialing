ImpactDialing.Views.CampaignCall = Backbone.View.extend({

  initialize: function(){
    var self = this;

    _.bindAll(this, 'updateModelAndInitServices', 'bindPusherEvents');

    this.lead_info = new ImpactDialing.Models.LeadInfo();
    this.caller_script = new ImpactDialing.Models.CallerScript();
    this.script_view  = new ImpactDialing.Views.CallerScript({
      model: this.caller_script,
      lead_info: this.lead_info,
      campaign_call: this.model
    });
    this.start_calling_view = new ImpactDialing.Views.StartCalling({
      model: this.model
    });

    this.schedule_callback_view = new ImpactDialing.Views.ScheduleCallback();
    this.caller_actions = new ImpactDialing.Views.CallerActions({
      model: this.model,
      lead_info: this.lead_info,
      schedule_callback: this.schedule_callback_view
    });
    this.caller_session = new ImpactDialing.Models.CallerSession();
    this.lead_info_view = new ImpactDialing.Views.LeadInfo({
      model: this.lead_info
    });

    Backbone.Events.on('voter.skipped', function(data){
      self.model.unset("call_id");
      self.lead_info.clear();
      _.extend(data, {dialer: 'preview'});
      self.lead_info.set(data);
      self.renderScript();
      $("#voter_info").html(self.lead_info_view.render().el);
      self.caller_actions.conferenceStarted();
    });

    this.fetchCallerInfo();
    $("#schedule_callback").html(this.schedule_callback_view.render().el);
    $('.sticky').stickyScroll({ container: '#container' });
    $('.sticky-actions').stickyScroll({ mode: "manual", bottomBoundary: 150 });
  },

  render: function(){
    var self = this;
    this.caller_script.fetch({success: function(){
      self.renderScript();
    }});

  },

  renderScript: function(){
    $("#voter_responses").empty();
    $("#voter_responses").html(this.script_view.render().el);
    this.schedule_callback_view.render();
    $("#transfer-calls").hide();
    $('#transfer_button').html("Transfer");
    $("#schedule_callback").hide();
  },

  fetchCallerInfo: function(){
    var self = this;
    $.ajax({
      type: 'POST',
      url: "/callers/campaign_calls/token",
      dataType: "json",
      beforeSend: function(request)
        {
          var token = $("meta[name='csrf-token']").attr("content");
          request.setRequestHeader("X-CSRF-Token", token);
        },
      success: this.updateModelAndInitServices,
      error: function(jqXHR, textStatus, errorThrown){
        self.callerShouldNotDial(jqXHR["responseText"]);
      }
    });
  },

  updateModelAndInitServices: function(data){
    console.log('Views.CampaignCall.updateModelAndInitServices', data);
    this.model.set(data);
    this.initServices();
  },

  renderCallerInfo: function(){
    $("#caller-actions").html(this.start_calling_view.render().el);
    var ios_url = "inapp://capture?campaign_id=" +
                  this.model.get("campaign_id") +
                  "&phone_number=" +
                  this.model.get("phone_number") +
                  "&caller_id=" +
                  this.model.get("caller_id") +
                  "&session_key=" +
                  this.model.get("session_key") +
                  "&token=" +
                  this.model.get("twilio_token");
    $("#start-calling-mobile").attr("href", ios_url);
    $("#callin").show();
    if (!FlashDetect.installed || !flash_supported() || !browser_supported()){
      $("#start-calling").hide();
    }
    if (isNativeApp()){
      $("#start-calling-mobile").show();
      $(".webapp-callin-info").hide();
    }
    $("#callin-number").html(this.model.get("phone_number"));
    $("#callin-pin").html(this.model.get("pin"));
    this.stopCallingOnPageReload()
    this.setupTwilio();
    self.trigger('rendered.caller.info', self.model);
  },

  initPusher: function(){
    var channel     = this.model.get('session_key'),
        pusherKey   = this.model.get('pusher_key')
        self        = this;

    ImpactDialing.Events.on('channel.subscribed', this.bindPusherEvents);

    this.pusherService = new ImpactDialing.Services.Pusher(pusherKey, channel);

    this.pusherService.pusher.connection.bind('connected_in', function(delay){
      var connected_in_msg = $('<b/>').text(' Connecting in ' + delay + ' seconds.');
      // $('#voter_info_message').append(connected_in_msg);
      console.log('Pusher.connected_in', delay);
    });

    this.pusherService.pusher.connection.bind('connecting', function(){
      console.log('Pusher.connecting', this);
    });

    this.pusherService.pusher.connection.bind('connected', function(){
      console.log('Pusher.connected', this);

      self.renderCallerInfo();
    });

    this.pusherService.pusher.connection.bind('unavailable', function(){
      console.log('Pusher.unavailable', this);
    });

    this.pusherService.pusher.connection.bind('failed', function(){
      console.log('Pusher.failed', this);
    });

    this.pusherService.pusher.connection.bind('disconnected', function(){
      console.log('Pusher.disconnected', this);
    });
  },

  initServices: function(){
    this.initPusher();
    // this.initTwilio();
  },

  stopCallingOnPageReload: function(){
    var self = this;
    $(window).bind("beforeunload", function() {
      if(self.model.has("session_id")){
        $.ajax({
          url : "/caller/" + self.model.get("caller_id") + "/stop_calling",
          data : {session_id : self.model.get("session_id") },
          type : "POST",
          async : false,
          success : function(response) {
            $("#start_calling").show();
          }
        });
      }
    });

  },

  callerShouldNotDial:  function(error){
    $("#caller-alert p strong").html(error);
    $("#caller-alert").addClass("callout alert clearfix")
  },

   setupTwilio:  function(){
    var self = this;
    Twilio.Device.setup(this.model.get("twilio_token"), {'debug':true});

    Twilio.Device.connect(function (conn) {
        $("#start_calling").hide();
    });
    Twilio.Device.ready(function (device) {
      client_ready=true;
    });
    Twilio.Device.error(function (error) {
      alert(error.message);
    });
  },

  bindPusherEvents: function(channel){
    console.log('Views.CampaignCall.bindPusherEvents', channel);
    var self = this;
    /*
      Channel events
    */
    channel.bind('start_calling', function(data) {
      self.model.set("session_id", data.caller_session_id);
      $("#caller-actions").html(self.caller_actions.render().el);
      $("#caller-actions a").hide();
      $("#callin_data").hide();
      self.caller_actions.startCalling();
    });

    channel.bind('caller_connected_dialer', function(data) {
      self.model.unset("call_id");
      self.lead_info.clear();
      self.lead_info.set(data);
      self.renderScript();
      $("#voter_info_message").show();
      $("#voter_info").hide();
      self.caller_actions.callerConnectedDialer();
    });

    channel.bind('conference_started', function(data) {
      self.model.unset("call_id");
      self.lead_info.clear();
      self.lead_info.set(data);
      self.renderScript();
      $("#voter_info_message").hide();
      $("#voter_info").html(self.lead_info_view.render().el);
      self.caller_actions.conferenceStarted();
    });

    channel.bind('caller_reassigned', function(data) {
      self.caller_script.fetch({
        success: function(){
          self.renderScript();
          self.lead_info.clear();
          self.lead_info.set(data);
          $("#voter_info_message").hide();
          $("#voter_info").html(self.lead_info_view.render().el);
          self.caller_actions.conferenceStarted();
          alert("You have been re-assigned to " + data.campaign_name + ".");
        }
      });
    });

    channel.bind('calling_voter', function(data) {
      self.caller_actions.callingVoter();
    });

    channel.bind('voter_connected', function(data) {
      self.model.set("call_id", data.call_id);
      self.caller_actions.voterConnected();
    });

    channel.bind('voter_connected_dialer', function(data) {
      self.model.set("call_id", data.call_id);
      self.lead_info.clear();
      self.lead_info.set(data.voter)
      $("#voter_info_message").hide();
      $("#voter_info").show();
      $("#voter_info").html(self.lead_info_view.render().el);
      self.caller_actions.voterConnectedDialer();
    });

    channel.bind('voter_disconnected', function(data) {
      self.caller_actions.voterDisconected();
    });

    channel.bind('caller_disconnected', function(data) {
      var campaign_call = new ImpactDialing.Models.CampaignCall();
      campaign_call.set({pusher_key: data.pusher_key});
      var campaign_call_view = new ImpactDialing.Views.CampaignCall({model: campaign_call});
      campaign_call_view.render();
      self.lead_info.clear();
      $("#voter_info").html(self.lead_info_view.render().el);
      $("#voter_info_message").show();
    });

    channel.bind('transfer_busy', function(data) {
      self.caller_actions.showHangupButton();
    });

    channel.bind('transfer_connected', function(data) {
      self.model.set("transfer_type", data.type);
      self.model.set("transfer_call_id", self.model.get("call_id"));
    });

    channel.bind('transfer_conference_ended', function(data) {
      var transfer_type = self.model.get("transfer_type");
      if( self.model.isKicking('transfer') ){
        ImpactDialing.Events.trigger('transfer.kicked');
      } else {
        if( transfer_type == "warm" ){
          self.caller_actions.transferConferenceEnded();
        }
      }
      self.model.unset('kicking', {silent: true});
      self.model.unset("transfer_type");
    });

    channel.bind('warm_transfer',function(data){

    });

    channel.bind('cold_transfer',function(data){

    });

    channel.bind('caller_kicked_off',function(data){

    });
  }
});
