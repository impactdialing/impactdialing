ImpactDialing.Models.CampaignCaller = Backbone.Model.extend({
  url: function() {
      return "/callers/campaign_calls/" + this.campaign_id;
    }
});
