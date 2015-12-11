ImpactDialing.Models.MonitorCaller = Backbone.Model.extend({
  urlRoot : '/client/monitors/callers',
  defaults: {
    status: "On hold",
  }
});
