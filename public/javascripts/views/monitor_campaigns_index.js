ImpactDialing.Views.MonitorCampaign = Backbone.View.extend({
  tagName: 'tr',
  template: '#campaign-monitor-template',

  render: function () {
    $(this.el).html(_.template($(this.template).html(), this.model.toJSON()));
    return this;
  },

});


ImpactDialing.Views.MonitorCampaignsIndex = Backbone.View.extend({
  tagName: 'tbody',

  initialize: function(){
    _.bindAll(this, 'render');
    this.collection.on('reset', this.render);
    this.collection.on('add', this.render);
  },

  render: function () {
    var self = this;
    this.$el.empty();
    $(self.el).append("<tr></tr>")
    this.collection.map(function (m) {
      var monitor = (new ImpactDialing.Views.MonitorCampaign({model: m})).render().el;
      $(self.el).append(monitor);
    });
    return this;
  },


});