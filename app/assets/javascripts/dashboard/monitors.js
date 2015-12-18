ImpactDialing.Routers.Monitors = Backbone.Router.extend({
  routes: {
      "": "index"
  },

  initialize: function(options){
    _.bindAll(this, 'stopWatchRestart');
    this.campaigns = new ImpactDialing.Collections.Campaigns(options.campaigns);
    this.activeCampaigns = new ImpactDialing.Dashboard.Collections.Campaigns();
    this.activeCallers = new ImpactDialing.Dashboard.Collections.CallerSessions();
    this.monitoring = false;
    this.monitor_session();
    this.stopWatch = new ImpactDialing.Utilities.StopWatch(function(){
      console.log("stopWatchfetch");
      monitorRouter.activeCallers.fetch();
      monitorRouter.activeCampaigns.fetch();
    });
    //var pusher = new Pusher(options.pusherKey);
    //var my_channel = pusher.subscribe(options.channelName);
    var my_channel = options.channel;
    // bind to all channel events.
    my_channel.bind_all(this.stopWatchRestart);
    my_channel.bind('caller_session.created', this.callerSessionCreated, this);
    my_channel.bind('caller.state_change', this.callerSessionChanged, this);
    my_channel.bind('caller.state_deleted', this.callerSessionDeleted, this);
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

  callerSessionCreated: function(data) {
    console.log('callerSessionCreated', data, this);
    this.activeCallers.normalizeAdd(data);
    var campaignObj = this.campaigns.get(data.campaign_id);
    this.activeCampaigns.add(campaignObj.attributes);
    var activeCampaign = this.activeCampaigns.get(campaignObj.get('id'));
    activeCampaign.incrementCallerCount(); // broke down increment and decrement into separate functions in backbone model.
    var callerStatusCount = this.activeCallers.callerStatusCount(activeCampaign);
    activeCampaign.updateStatusCount(callerStatusCount);
  },

  callerSessionChanged: function(data) {
    var callerObj = monitorRouter.activeCallers.get(data.caller_session_id);
    callerObj.set('status', data.status);
    var activeCampaign = monitorRouter.activeCampaigns.get(data.campaign_id);
    var callerStatusCount = monitorRouter.activeCallers.callerStatusCount(activeCampaign);
    activeCampaign.updateStatusCount(callerStatusCount);
  },

  callerSessionDeleted: function(data) {
    var callerSession = monitorRouter.activeCallers.get(data.caller_session_id);
    monitorRouter.activeCallers.remove(callerSession);
    var activeCampaign = monitorRouter.activeCampaigns.get(data.campaign_id);
    activeCampaign.decrementCallerCount();
    var callerStatusCount = monitorRouter.activeCallers.callerStatusCount(activeCampaign);
    activeCampaign.updateStatusCount(callerStatusCount);
  },

  stopWatchRestart: function() {
    console.log(this);
    this.stopWatch.restart();
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
