ImpactDialing.Views.LeadInfo = Backbone.View.extend({

  initialize: function(){
    this.model.on('set', this.render);
  },

  render: function () {
    this.model.handleCustomFields();
    console.log(this.model.toJSON())
    $(this.el).html(Mustache.to_html($('#caller-campaign-script-lead-info-template').html(), this.model.toJSON()));
    return this;
  },



});
