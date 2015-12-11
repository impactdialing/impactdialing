ImpactDialing.Dashboard.Models.Campaign = Backbone.Model.extend({
  urlRoot : '/client/monitors/campaigns',
  defaults: {
    callers_logged_in: 0,
    on_call: 0,
    wrap_up: 0,
    on_hold: 0,
    ringing_lines: 0,
    available: 0,
  },
});
