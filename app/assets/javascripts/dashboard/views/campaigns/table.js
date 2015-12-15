if(ImpactDialing.Dashboard.Views.Campaigns === undefined ||
   ImpactDialing.Dashboard.Views.Campaigns === null){
     ImpactDialing.Dashboard.Views.Campaigns = {}
}
ImpactDialing.Dashboard.Views.Campaigns.Table = Backbone.View.extend({
  tagName: 'tbody',

  initialize: function(){
    _.bindAll(this, 'render', 'renderRow');
    this.collection.on('reset', this.render);
    this.collection.on('add', this.renderRow);
    this.collection.on('remove', this.implodeRow);
    this.collection.on('callerNumbers', this.callerNumbers);
  },

  renderRow: function(model) {
    var modelView = new ImpactDialing.Dashboard.Views.Campaigns.Row({
      model: model,
      collection: this.collection,
    });

    model.view = modelView

    var monitor = modelView.render().el;
    $(this.el).append(monitor);
  },

  implodeRow: function(model) {
    model.view.implode();
  },

  callerNumbers: function(model) {
    model.view.callers(model);
  },

  render: function () {
    var self = this;
    this.$el.empty();
    // $(self.el).append("<tr></tr>")
    this.collection.each(function (m) {
      var monitor = (new ImpactDialing.Dashboard.Views.Campaigns.Row({model: m})).render().el;
      $(self.el).append(monitor);
    });
    return this;
  },


});
