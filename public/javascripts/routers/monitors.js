ImpactDialing.Routers.Monitors = Backbone.Router.extend({
  routes: {
      "": "index"
  },

  initialize: function(){
    this.active_campaigns = new ImpactDialing.Collections.MonitorCampaigns();
    this.active_callers = new ImpactDialing.Collections.MonitorCallers();
    this.monitoring = false;
    this.monitor_session();
  },

  index: function(){
    var monitors_campaign = new ImpactDialing.Views.MonitorCampaignsIndex({collection: this.active_campaigns});
    var monitors_caller = new ImpactDialing.Views.MonitorCallersIndex({collection: this.active_callers,
      monitoring: this.monitoring});
    $("#campaigns-monitor").html(monitors_campaign.render().el);
    $("#callers-monitor").html(monitors_caller.render().el);
    this.active_campaigns.fetch();
    this.active_callers.fetch();
  },

  monitor_session: function(){
    var self = this;
    $.ajax({
      type: 'POST',
      url : "/client/monitors/monitor_session",
      dataType: "json",
      beforeSend: function (request)
        {
          var token = $("meta[name='csrf-token']").attr("content");
          request.setRequestHeader("X-CSRF-Token", token);
        },
      success: function(data){
        $("#monitor_session_id").val(data["moderator"]["id"])
        window.setInterval(function(){
          self.active_campaigns.fetch();
        }, 5000);

        window.setInterval(function(){
          self.active_callers.fetch();
        }, 5000);
      },
    });
  },
});

