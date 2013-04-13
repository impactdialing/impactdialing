ImpactDialing.Views.CallerScriptText = Backbone.View.extend({
  render: function (ele) {
    $(this.el).html(Mustache.to_html($('#caller-campaign-script-text-template').html(), ele));
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
  render: function (ele) {
    $(this.el).html(Mustache.to_html($('#caller-campaign-script-transfer-template').html(), ele));
    return this;
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
    if(this.model){
      $(self.el).append(new ImpactDialing.Views.CallerTransfer().render(this.model.toJSON()).el);
    }
    return this;
  },

});