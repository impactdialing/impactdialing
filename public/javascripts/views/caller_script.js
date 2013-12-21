ImpactDialing.Views.CallerScriptText = Backbone.View.extend({
  render: function (ele) {
    $(this.el).html(Mustache.to_html($('#caller-campaign-script-text-template').html(), ele));
    $(this.el).html($(this.el).html().replace(/\r\n|\n/g, "<p/>"));
    return this;
  },

});

ImpactDialing.Views.CallerQuestions = Backbone.View.extend({
  render: function (ele) {
    $(this.el).html(Mustache.to_html($('#caller-campaign-script-question-template').html(), ele));
    return this;
  },

});

ImpactDialing.Views.CallerNotes = Backbone.View.extend({
  render: function (ele) {
    $(this.el).html(Mustache.to_html($('#caller-campaign-script-notes-template').html(), ele));
    return this;
  },

});

ImpactDialing.Views.CallerTransfer = Backbone.View.extend({

  events: {
    "click #transfer_button" : "transferCall"
  },

  initialize: function(){
    ImpactDialing.Events.bind('transfer.kicked', function(){
      $('#transfer_form').show();
      $('#transfer_status').text('Transfer disconnected.');
    });
    if( _.isFunction(ImpactDialing.Channel.bind) ){
      this.setupChannelHandlers();
    } else {
      ImpactDialing.Events.bind('channel.subscribed', this.setupChannelHandlers);
    }
  },

  setupChannelHandlers: function(){
    ImpactDialing.Channel.bind('transfer_connected', function(data){
      var transfer_type = data.type;

      $('#transfer_form').hide();
      $('#transfer_status').text('Connecting parties...');
    });
    ImpactDialing.Channel.bind('warm_transfer', function(){
      $('#transfer_form').hide();
      $('#transfer_status').text('Connected: you, lead & transfer.');
    });
    ImpactDialing.Channel.bind('cold_transfer', function(){
      $('#transfer_form').show();
      $('#transfer_status').text('Connected: lead & transfer.');
    });
    ImpactDialing.Channel.bind('caller_kicked_off', function(){
      $('#transfer_status').text('Disconnected.');
      $('#transfer-calls').hide();
    });
    ImpactDialing.Channel.bind('transfer_conference_ended', function(){
      $('#transfer_form').show();
      $('#transfer_status').text('Disconnected.');
    });
  },

  render: function (ele) {
    $(this.el).html(Mustache.to_html($('#caller-campaign-script-transfer-template').html(), ele));
    return this;
  },

  transferCall: function(e){
    e.preventDefault();
    ImpactDialing.Events.trigger('transfer.starting');
    $('#transfer_status').text('Preparing transfer...');
    var options = {
      url: "/transfer/dial",
      data: {
        voter: this.options.lead_info.get("fields").id,
        call: this.options.campaign_call.get("call_id"),
        caller_session: this.options.campaign_call.get("session_id")
      },
      success: function(){
        $('#transfer_status').text('Dialing...');
        ImpactDialing.Events.trigger('transfer.success');
      },
      error: function(){
        $('#transfer_status').text('There was an error connecting to the transfer. Please try again or contact support.');
        ImpactDialing.Events.trigger('transfer.error');
      }
    };
    $('#transfer_form').ajaxSubmit(options);
  },

});

ImpactDialing.Views.VoterInfo = Backbone.View.extend({
  render: function (ele) {
    $(this.el).html(Mustache.to_html($('#caller-campaign-script-transfer-template').html(), ele));
    return this;
  }
});


ImpactDialing.Views.CallerScript = Backbone.View.extend({

  initialize: function(){
    this.model.on('reset', this.render);

  },

  parseScriptElements: function(){
    this.elements = [];
    if(this.model){
      this.elements = this.elements.concat(this.processElements("script_texts", "text"));
      this.elements = this.elements.concat(this.processElements("questions", "questions"));
      this.elements = this.elements.concat(this.processElements("notes", "notes"));
      this.elements = _.compact(this.elements);
      this.elements = _.sortBy(this.elements, function(ele){ return ele['script_order']});
    }
    return this.elements
  },

  processElements: function(field, type){
      var elements = this.model.get(field);
      return _.map(elements, function(e){
        e["type"] = type;
        return e
      });
  },

  render: function () {
    $(this.el).empty();
    var self = this,
        view;
    _.each(this.parseScriptElements(), function(ele){
      if( ele["type"] == "text" ){
        view = new ImpactDialing.Views.CallerScriptText().render(ele);
      } else if( ele["type"] == "questions" ){
        view = new ImpactDialing.Views.CallerQuestions().render(ele);
      } else {
        view = new ImpactDialing.Views.CallerNotes().render(ele);
      }
      $(self.el).append(view.el);
    });
    if( this.model && !_.isEmpty(this.model.get("transfers")) ){
      this.transfer_section = new ImpactDialing.Views.CallerTransfer({
        lead_info: this.options.lead_info,
        campaign_call: this.options.campaign_call
      });
      view = this.transfer_section.render(this.model.toJSON());
      $(self.el).append(view.el);
    }
    return this;
  }
});
