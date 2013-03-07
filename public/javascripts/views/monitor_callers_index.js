ImpactDialing.Views.MonitorCaller = Backbone.View.extend({
  tagName: 'tr',
  template: '#caller-monitor-template',

  events: {
    "click .kick_off" : "kickCallerOff",
    "click .break_in" : "switchMode",
    "click .eaves_drop" : "switchMode",
  },

  render: function () {
    $(this.el).html(_.template($(this.template).html(), this.model.toJSON()));
    return this;
  },

  kickCallerOff: function(e){
    e.preventDefault();
    e.stopPropagation();
    var self = this;
    $.ajax({
      type: 'PUT',
      url : "/client/monitors/callers/kick_off",
      data : {session_id : this.model.get("id")},
      dataType: "json",
      beforeSend: function(request)
        {
          var token = $("meta[name='csrf-token']").attr("content");
          request.setRequestHeader("X-CSRF-Token", token);
        },
      success: function(){
        self.collection.remove(self.model);
      },
    });
  },

  switchMode: function(e){
    e.preventDefault();
    e.stopPropagation();
    var self = this;
    console.log(this.options.monitoring)
    if(this.options.monitoring){
      this.connectModeratorToConference(e);
    }else{
      this.startMonitoring(e);
      this.options.monitoring = true;
    }

  },

  startMonitoring: function(e){
    params = {'session_id': this.model.get("id"), 'type': $(e.target).data("action"),
      'monitor_session' : $("#monitor_session_id").val()};
    $('.stop_monitoring').show();
    Twilio.Device.connect(params);
  },

  connectModeratorToConference: function(e){
    $.ajax({
      type: 'PUT',
      url : "/client/monitors/callers/switch_mode",
      data : {session_id : this.model.get("id"), type: $(e.target).data("action")},
      dataType: "json",
      beforeSend: function (request)
        {
          var token = $("meta[name='csrf-token']").attr("content");
          request.setRequestHeader("X-CSRF-Token", token);
        },
      success: function(data){
          $("#status").html(data["message"])
        },
      });
  },

});


ImpactDialing.Views.MonitorCallersIndex = Backbone.View.extend({
  tagName: 'tbody',

  initialize: function(){
    _.bindAll(this, 'render');
    this.collection.on('reset', this.render);
    this.collection.on('add', this.render);
    this.collection.on('remove', this.render);
  },

  render: function () {
    var self = this;
    this.$el.empty();
    if (!_.isEmpty(this.collection.models)){
      this.collection.map(function (m) {
      var monitor = (new ImpactDialing.Views.MonitorCaller({model: m, collection: self.collection, monitoring: self.options.monitoring})).render().el;
      $(self.el).append(monitor);
    });
    }

    return this;
  },


});