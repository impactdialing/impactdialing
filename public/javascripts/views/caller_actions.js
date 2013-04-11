ImpactDialing.Views.CallerActions = Backbone.View.extend({

  initialize: function(){
    console.log(this.model.get("session_key"));
    var self = this;
    this.channel = pusher.subscribe(this.model.get("session_key"));

  },

  render: function() {
    $(this.el).html(Mustache.to_html($('#caller-campaign-action-template').html()));
    return this;
  },


})