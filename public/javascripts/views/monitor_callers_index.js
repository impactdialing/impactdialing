ImpactDialing.Views.MonitorCaller = Backbone.View.extend({
  tagName: 'tr',
  template: '#caller-monitor-template',

  render: function () {
    $(this.el).html(_.template($(this.template).html(), this.model.toJSON()));
    return this;
  },

});


ImpactDialing.Views.MonitorCallersIndex = Backbone.View.extend({
  tagName: 'tbody',

  initialize: function(){
    _.bindAll(this, 'render');
    this.collection.on('reset', this.render);
    this.collection.on('add', this.render);
  },

  render: function () {
    var self = this;
    this.$el.empty();
    if (!_.isEmpty(this.collection.models)){
      this.collection.map(function (m) {
      var monitor = (new ImpactDialing.Views.MonitorCaller({model: m})).render().el;
      $(self.el).append(monitor);
    });
    }

    return this;
  },


});