ImpactDialing.Views.MonitorCaller = Backbone.View.extend({
  tagName: 'tr',
  template: '#caller-monitor-template',

  events: {
    "click .kick_off" : "kickCallerOff",
    "click .break_in" : "switchMode",
    "click .eaves_drop" : "switchMode",
    "click .reassign_campaign" : "openReassignDialog"
  },

  render: function () {
    $(this.el).html(Mustache.to_html($('#caller-monitor-template').html(), _.extend(this.model.toJSON(),
      {reassignable_campaigns: this.options.reassignable_campaigns})));
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
    if(this.options.monitoring){
      this.connectModeratorToConference(e);
    }else{
      this.startMonitoring(e);
      this.options.monitoring = true;
      console.log(this.options.monitoring)
    }

  },

  startMonitoring: function(e){
    params = {'session_id': this.model.get("id"), 'type': $(e.target).data("action"),
      'monitor_session_id' : $("#monitor_session_id").val()};
    $('.stop_monitoring').show();
    Twilio.Device.connect(params);
  },

  connectModeratorToConference: function(e){
    $.ajax({
      type: 'PUT',
      url : "/client/monitors/callers/switch_mode",
      data : {session_id : this.model.get("id"), type: $(e.target).data("action"), monitor_session_id: $("#monitor_session_id").val()},
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

  openReassignDialog: function(e){
    e.preventDefault();
    e.stopPropagation();
    var self = this;
  }

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
    $.getJSON("/client/monitors/callers/reassignable_campaigns", function(data){
      self.$el.empty();
      if (!_.isEmpty(self.collection.models)){
        self.collection.map(function (m) {
          var monitor = (new ImpactDialing.Views.MonitorCaller({model: m, collection: self.collection, reassignable_campaigns: data})).render().el;
          $(self.el).append(monitor);
        });
      }
    });

    return this;
  },


});