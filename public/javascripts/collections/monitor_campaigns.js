ImpactDialing.Collections.MonitorCampaigns = Backbone.Collection.extend({

  model: ImpactDialing.Models.MonitorCampaign,
  url: function() {
      return "/client/monitors/campaigns";
    }

});
