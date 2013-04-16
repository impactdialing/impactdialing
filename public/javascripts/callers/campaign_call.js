var CampaignCall = function(){
  var self = this;
  $(window).bind("beforeunload", function() {
    self.stopCalling();
  });
}

CampaignCall.prototype.stopCalling = function(){
  if ($("#caller_session").val()) {
      $.ajax({
          url : "/caller/" + $("#caller").val() + "/stop_calling",
          data : {session_id : $("#caller_session").val() },
          type : "POST",
          async : false,
          success : function(response) {
              $("#start_calling").show();
          }
      });
  }

},

CampaignCall.prototype.token = function(){
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
        success: function(data){
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

CampaignCall.prototype.callerShouldNotDial = function(error){
  $("#caller-alert p strong").html(error);
  $("#caller-alert").addClass("callout alert clearfix")
}

CampaignCall.prototype.setupTwilio = function(token){
  Twilio.Device.setup(token, {'debug':true});
  Twilio.Device.connect(function (conn) {});
  Twilio.Device.ready(function (device) {
    client_ready=true;
  });
  Twilio.Device.error(function (error) {
    alert(error.message);
  });
}