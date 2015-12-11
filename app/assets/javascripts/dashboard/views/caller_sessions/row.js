if(ImpactDialing.Dashboard.Views.CallerSessions === undefined ||
   ImpactDialing.Dashboard.Views.CallerSessions === null){
     ImpactDialing.Dashboard.Views.CallerSessions = {}
}
ImpactDialing.Dashboard.Views.CallerSessions.Row = Backbone.View.extend({
  tagName: 'tr',
  template: '#caller-monitor-template',

  events: {
    "click .kick_off" : "kickCallerOff",
    "click .break_in" : "switchMode",
    "click .eaves_drop" : "switchMode",
    "change .reassign-campaign" : "reassignCampaign"
  },

  initialize: function () {
    console.log(this.collection)
    _.bindAll(this, 'render');
    // this.collection.on('remove', this.render);
    this.model.on('change', this.render);
  },

  render: function () {
    console.log("Row Render Started", this.options.reassignable_campaigns)
    $(this.el).html(
      Mustache.to_html(
        $('#caller-monitor-template').html(),
        _.extend(this.model.toJSON(),{
          reassignable_campaigns: this.options.reassignable_campaigns
        })
      )
    );
    this.$('#reassign_caller_' + this.model.get('id')).val(this.model.get('campaign_id'));
    console.log("Render Finished")


    var time = new Date().getTime();
    $(this.el).children('#caller_time_in_status_' + this.model.get('id')).countdown(time, {elapse: true}).on('update.countdown', function(event) {
      $(this).html(event.strftime('<span>%H:%M:%S</span>'));
    });


    return this;
  },

  kickCallerOff: function(e){
    e.preventDefault();
    e.stopPropagation();
    var self = this;
    $.ajax({
      type: 'PUT',
      url : "/client/monitors/callers/kick_off",
      data : {session_id : this.model.get("id")},
      dataType: "json",
      beforeSend: function(request)
        {
          var token = $("meta[name='csrf-token']").attr("content");
          request.setRequestHeader("X-CSRF-Token", token);
        },
      success: function(){
        self.collection.remove(self.model);
      },
    });
  },

  switchMode: function(e){
    e.preventDefault();
    e.stopPropagation();
    var self = this;
    if(this.options.monitoring){
      this.connectModeratorToConference(e);
    }else{
      this.startMonitoring(e);
      this.options.monitoring = true;
    }

  },

  startMonitoring: function(e){
    params = {'session_id': this.model.get("id"), 'type': $(e.target).data("action"),
      'monitor_session_id' : $("#monitor_session_id").val()};
    $('.stop_monitoring').show();
    Twilio.Device.connect(params);
  },

  connectModeratorToConference: function(e){
    $.ajax({
      type: 'PUT',
      url : "/client/monitors/callers/switch_mode",
      data : {session_id : this.model.get("id"), type: $(e.target).data("action"), monitor_session_id: $("#monitor_session_id").val()},
      dataType: "json",
      beforeSend: function (request)
        {
          var token = $("meta[name='csrf-token']").attr("content");
          request.setRequestHeader("X-CSRF-Token", token);
        },
      success: function(data){
          $("#status").html(data["message"])
        },
      });
  },

  reassignCampaign: function(e){
    var self = this;
    e.preventDefault();
    $.ajax({
      type: 'PUT',
      url : "/client/callers/"+self.model.get("caller_id")+"/reassign_to_campaign",
      data : {campaign_id :$(e.target).val() },
      dataType: "json",
      beforeSend: function (request)
        {
          var token = $("meta[name='csrf-token']").attr("content");
          request.setRequestHeader("X-CSRF-Token", token);
        },
    });
  },

});
