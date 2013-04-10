ImpactDialing.Views.CallerActions = Backbone.View.extend({

  initialize: function(){
    var self = this;
    _.bindAll(this, 'render');
    $.ajax({
        type: 'POST',
        url: "/callers/campaign_calls/token",
        dataType: "json",
        beforeSend: function(request)
        {
          var token = $("meta[name='csrf-token']").attr("content");
          request.setRequestHeader("X-CSRF-Token", token);
        },
        success: function(data){
          self.caller_data = data;
          $("#callin").show();
          $("#callin-number").html(data.phone_number);
          $("#callin-pin").html(data.caller_identity.pin);
          if (!FlashDetect.installed || !flash_supported())
            $("#start_calling").hide();
            self.setupTwilio(data.twilio_token);
        },
        error: function(jqXHR, textStatus, errorThrown){
          self.callerShouldNotDial(jqXHR["responseText"]);
        },
      });
  },

  events: {
    "click #start-calling" : "startCalling"
  },

  render: function() {
    $(this.el).html(Mustache.to_html($('#caller-campaign-action-template').html()));
    return this;
  },

  startCalling: function(e){
    $("#callin_data").hide();
    params = {"PhoneNumber": this.caller_data.phone_number, 'campaign_id': this.caller_data.campaign_id, 'caller_id': this.caller_data.caller_identity.caller_id
    ,'session_key': this.caller_data.caller_identity.session_key};
    Twilio.Device.connect(params)
  },

  callerShouldNotDial:  function(error){
    $("#caller-alert p strong").html(error);
    $("#caller-alert").addClass("callout alert clearfix")
  },

  setupTwilio:  function(token){
    Twilio.Device.setup(token, {'debug':true});
    Twilio.Device.connect(function (conn) {
        $("#start_calling").hide();
    });
    Twilio.Device.ready(function (device) {
      client_ready=true;
    });
    Twilio.Device.error(function (error) {
      alert(error.message);
    });
  }

});
