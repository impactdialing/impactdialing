ImpactDialing.Views.MonitorCaller = Backbone.View.extend({
  tagName: 'tr',
  template: '#caller-monitor-template',

  events: {
    "click .kick_off" : "kickCallerOff",
  },

  render: function () {
    $(this.el).html(_.template($(this.template).html(), this.model.toJSON()));
    return this;
  },

  kickCallerOff: function(e){
    e.preventDefault();
    e.stopPropagation();
    var self = this;
    $.ajax({
      type: 'PUT',
      url : "/client/monitors/callers/kick_off",
      data : {session_id : this.model.get("id")},
      dataType: "json",
      success: function(){
        self.collection.remove(self.model);
      },
    });
  },

});


ImpactDialing.Views.MonitorCallersIndex = Backbone.View.extend({
  tagName: 'tbody',

  initialize: function(){
    _.bindAll(this, 'render');
    this.collection.on('reset', this.render);
    this.collection.on('add', this.render);
    this.collection.on('remove', this.render);
  },

  render: function () {
    var self = this;
    this.$el.empty();
    if (!_.isEmpty(this.collection.models)){
      this.collection.map(function (m) {
      var monitor = (new ImpactDialing.Views.MonitorCaller({model: m, collection: self.collection})).render().el;
      $(self.el).append(monitor);
    });
    }

    return this;
  },


});