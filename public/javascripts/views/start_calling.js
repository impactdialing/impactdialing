ImpactDialing.Views.StartCalling = Backbone.View.extend({

  initialize: function(){
    _.bindAll(this, 'startCalling');
  },

  events: {
    "click #start-calling" : "startCalling"
  },

  render: function() {
    $(this.el).html(Mustache.to_html($('#caller-campaign-start-calling-template').html()));
    return this;
  },

  startCalling: function(e){
    $("#callin_data").hide();
    params = {"PhoneNumber": this.model.get("phone_number"), 'campaign_id': this.model.get("campaign_id"),
    'caller_id': this.model.get("caller_id"),'session_key': this.model.get("session_key")};
    Twilio.Device.connect(params)
  },




});
