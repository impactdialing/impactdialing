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

  render: function (ele) {
    $(this.el).html(Mustache.to_html($('#caller-campaign-script-transfer-template').html(), ele));
    return this;
  },

  transferCall: function(e){
    e.preventDefault();
    $("#hangup_call").hide();
    $('#transfer_button').html("Transferring...");
    var options = {
      data: {voter: this.options.lead_info.get("fields").id, call: this.options.campaign_call.get("call_id"),
       caller_session: this.options.campaign_call.get("session_id")  }
    };
    $('#transfer_form').attr('action', "/transfer/dial")
    $('#transfer_form').submit(function() {

        $('#transfer_button').html("Transfered");
        $(this).ajaxSubmit(options);
        $(this).unbind("submit");
        return false;
    });
    $("#transfer_form").trigger("submit");
    $("#transfer_form").unbind("submit");
  },

});

ImpactDialing.Views.VoterInfo = Backbone.View.extend({
  render: function (ele) {
    $(this.el).html(Mustache.to_html($('#caller-campaign-script-transfer-template').html(), ele));
    return this;
  },

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
    var self = this;
    _.each(this.parseScriptElements(), function(ele){
      if(ele["type"] == "text") {
        $(self.el).append(new ImpactDialing.Views.CallerScriptText().render(ele).el);
      }else if(ele["type"] == "questions"){
        $(self.el).append(new ImpactDialing.Views.CallerQuestions().render(ele).el);
      }else{
        $(self.el).append(new ImpactDialing.Views.CallerNotes().render(ele).el);
      }
    });
    if(this.model && !_.isEmpty(this.model.get("transfers"))){
      self.transfer_section = new ImpactDialing.Views.CallerTransfer({lead_info: this.options.lead_info,
        campaign_call: this.options.campaign_call})
      $(self.el).append(self.transfer_section.render(this.model.toJSON()).el);
    }
    return this;
  },

});