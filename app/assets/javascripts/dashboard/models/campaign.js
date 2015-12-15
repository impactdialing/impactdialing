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

  updateStatusCount: function(callerStatusCount) {
    var map = {
      "On hold": "on_hold",
      "On call": "on_call",
      "Wrap up": "wrap_up"
    }
    _.each(callerStatusCount, function(statusCount, statusName, statusObj){
      console.log(arguments);
      // first iteration
      // statusCount = callerStatusCount["On hold"]
      // statusName  = "On hold"
      // statusObj   = callerStatusCount
      // second ..
      // statusCount  = callerStatusCount["On call"]
      // statusName   = "On call"
      this.set(map[statusName], statusCount);
    }, this)
  },

  incrementCallerCount: function() {
    var currentCallerCount = this.get("callers_logged_in");
    return this.set("callers_logged_in", currentCallerCount + 1);
  },

  decrementCallerCount: function() {
    var currentCallerCount = this.get("callers_logged_in");
    if (currentCallerCount > 1) {
      this.set("callers_logged_in", currentCallerCount - 1);
    } else {
      this.view.implode();
    }
  }

});
