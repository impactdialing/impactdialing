ImpactDialing.Views.LeadInfo = Backbone.View.extend({
  template: '#lead-info-template'

  render: function () {
    $(this.el).html(Mustache.to_html($('#lead-info-template').html(), _.extend(this.model.toJSON(),
      {reassignable_campaigns: this.options.reassignable_campaigns})));
    return this;
  },



});