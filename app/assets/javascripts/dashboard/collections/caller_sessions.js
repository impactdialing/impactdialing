ImpactDialing.Dashboard.Collections.CallerSessions = Backbone.Collection.extend({

  model: ImpactDialing.Dashboard.Models.CallerSession,
  normalizeAdd: function(data){
    var normalized = data;
    normalized.id = data.caller_session_id;
    normalized.name = data.caller_name;
    this.add(normalized);
  },

  callers: function(model) {
    var onHold = this.where({campaign_id: model.id, status: "On hold" }).length;
    var onCall = this.where({campaign_id: model.id, status: "On call" }).length;
    var wrapUp = this.where({campaign_id: model.id, status: "Wrap up" }).length;
    // var callersLoggedIn = this.where({campaign_id: model.id, status: "callers_logged_in" }).length;
    var callerStatusCount = { "On hold": onHold, "On call": onCall, "Wrap up": wrapUp };
    return callerStatusCount;
  },

});
