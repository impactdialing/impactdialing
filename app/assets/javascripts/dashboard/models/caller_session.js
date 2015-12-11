ImpactDialing.Dashboard.Models.CallerSession = Backbone.Model.extend({
  urlRoot: '/client/monitors/caller_sessions',
  defaults: {
    status: "On hold",
  }
});
