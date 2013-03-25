ImpactDialing.Routers.CampaignCaller = Backbone.Router.extend({
  routes: {
      "": "index"
  },

initialize: function(){
  this.campaign_call = new ImpactDialing.Models.CampaignCaller();

  },

});
