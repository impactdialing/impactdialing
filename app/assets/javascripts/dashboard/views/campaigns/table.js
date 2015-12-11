if(ImpactDialing.Dashboard.Views.Campaigns === undefined ||
   ImpactDialing.Dashboard.Views.Campaigns === null){
     ImpactDialing.Dashboard.Views.Campaigns = {}
}
ImpactDialing.Dashboard.Views.Campaigns.Table = Backbone.View.extend({
  tagName: 'tbody',

  initialize: function(){
    _.bindAll(this, 'render');
    this.collection.on('reset', this.render);
    this.collection.on('add', this.render);
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
