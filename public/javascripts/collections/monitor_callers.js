ImpactDialing.Collections.MonitorCallers = Backbone.Collection.extend({

  model: ImpactDialing.Models.MonitorCaller,
  url: function() {
      return "/client/monitors/callers";
    }

});
