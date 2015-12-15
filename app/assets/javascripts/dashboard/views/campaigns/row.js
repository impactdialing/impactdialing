if(ImpactDialing.Dashboard.Views.Campaigns === undefined ||
   ImpactDialing.Dashboard.Views.Campaigns === null){
     ImpactDialing.Dashboard.Views.Campaigns = {}
}
ImpactDialing.Dashboard.Views.Campaigns.Row = Backbone.View.extend({
  tagName: 'tr',
  template: '#campaign-monitor-template',

  initialize: function () {
    _.bindAll(this, 'render', 'implode');
    this.model.on('change', this.render);
  },

  implode: function() {
    $(this.el).remove();
  },

  render: function () {
    $(this.el).html(_.template($(this.template).html(), this.model.toJSON()));
    return this;
  },

});
