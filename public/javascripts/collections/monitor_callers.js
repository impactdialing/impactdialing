ImpactDialing.Collections.MonitorCallers = Backbone.Collection.extend({

  model: ImpactDialing.Models.MonitorCaller,
  url: "/client/monitors/callers",
  normalizeAdd: function(data){
    var normalized = data;
    normalized.id = data.caller_id;
    normalized.name = data.caller_name;
    this.add(normalized);
  }

});
