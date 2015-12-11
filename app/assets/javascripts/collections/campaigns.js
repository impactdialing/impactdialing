ImpactDialing.Collections.Campaigns = Backbone.Collection.extend({

  model: ImpactDialing.Models.MonitorCampaign,
  url: '/client/campaigns?page=all'

});
