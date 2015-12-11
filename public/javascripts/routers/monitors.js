ImpactDialing.Routers.Monitors = Backbone.Router.extend({
  routes: {
      "": "index"
  },

  initialize: function(collections){
    console.log(collections)
    this.campaigns = new ImpactDialing.Collections.Campaigns(collections.campaigns);
    this.activeCampaigns = new ImpactDialing.Dashboard.Collections.Campaigns();
    this.activeCallers = new ImpactDialing.Dashboard.Collections.CallerSessions();
    this.monitoring = false;
    this.monitor_session();
  },

  index: function(){
    var self = this;
    var campaignTable = new ImpactDialing.Dashboard.Views.Campaigns.Table({
      collection: this.activeCampaigns
    });
    $("#campaigns-monitor").append(campaignTable.render().el);
    console.log(this.activeCallers, this.campaigns)

    var callerTable = new ImpactDialing.Dashboard.Views.CallerSessions.Table({
      collection: this.activeCallers,
      allCampaigns: this.campaigns,
    });
    $("#callers-monitor").append(callerTable.render().el);
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
        // window.setInterval(function(){
        //   self.activeCampaigns.fetch();
        // }, 5000);
        //
        // window.setInterval(function(){
        //   self.activeCallers.fetch();
        // }, 5000);
      },
    });
  },
});
