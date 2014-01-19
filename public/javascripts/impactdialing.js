_.templateSettings = {
  interpolate : /\{\{(.+?)\}\}/g,
};

window.ImpactDialing = {
  Models: {},
  Collections: {},
  Views: {},
  Routers: {},
  Events: _.extend({}, Backbone.Events),
  Channel: {},
  Services: {},
  Utilities: {},
  initialize: function() {
  }
};



$(document).ready(function(){
  ImpactDialing.initialize();
});

