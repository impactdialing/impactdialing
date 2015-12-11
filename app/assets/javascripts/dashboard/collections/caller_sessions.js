ImpactDialing.Dashboard.Collections.CallerSessions = Backbone.Collection.extend({

  model: ImpactDialing.Dashboard.Models.CallerSession,
  normalizeAdd: function(data){
    var normalized = data;
    normalized.id = data.caller_session_id;
    normalized.name = data.caller_name;
    this.add(normalized);
  }

});
