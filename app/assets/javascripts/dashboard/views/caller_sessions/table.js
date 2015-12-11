if(ImpactDialing.Dashboard.Views.CallerSessions === undefined ||
   ImpactDialing.Dashboard.Views.CallerSessions === null){
     ImpactDialing.Dashboard.Views.CallerSessions = {}
}
ImpactDialing.Dashboard.Views.CallerSessions.Table = Backbone.View.extend({
  tagName: 'tbody',

  initialize: function(){
    _.bindAll(this, 'renderRow', 'render');
    this.allCampaigns = this.options.allCampaigns;
    this.collection.on('reset', this.render);
    this.collection.on('add', this.renderRow);
    this.collection.on('remove', this.implodeRow);
    console.log("Table View Initialized")
  },

  renderRow: function(model){
    console.log(model);
    var data = this.allCampaigns.toJSON();
    console.log(data, this.allCampaigns);

    var modelView = new ImpactDialing.Dashboard.Views.CallerSessions.Row({
      model: model,
      collection: this.collection,
      reassignable_campaigns: data
    });

    model.view = modelView

    var monitor = modelView.render().el;
    $(this.el).append(monitor);
  },

  implodeRow: function(model){
    model.view.implode();
  },

  render: function () {
    console.log("Render Started")
    var self = this;
    self.$el.empty();
    if (!_.isEmpty(self.collection.models)){
      console.log("Models Exist")
      $(self.el).append("<tr></tr>")
      self.collection.each(self.renderRow);
    }
    return this;
  }
});
