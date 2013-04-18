ImpactDialing.Models.LeadInfo = Backbone.Model.extend({

  handleCustomFields: function(){
     var custom_fields_array = [];
     var self = this;
    _.each(_.keys(this.get("custom_fields")) , function(ele){
      custom_fields_array.push({
      'key' : ele,
      'value' : self.get("custom_fields")[ele]
     });
    })
    this.set("custom_lead_info", custom_fields_array)
  },

});