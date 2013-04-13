ImpactDialing.Views.LeadInfo = Backbone.View.extend({
  render: function () {
    $(this.el).html(Mustache.to_html($('#caller-campaign-script-lead-info-template').html(), this.model.toJSON()));
    return this;
  },

});
