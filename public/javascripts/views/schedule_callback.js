ImpactDialing.Views.ScheduleCallback = Backbone.View.extend({

  initialize: function () {

  },

  events: {
    "click #schedule_callback_button": "expandScheduler",
    "click #hide_scheduler": "collapseScheduler"
  },

  render: function(){
    $(this.el).html(Mustache.to_html($('#caller-campaign-schedule-callback-template').html()));
    $('#scheduled_date').datepicker();
    return this;
  },

  expandScheduler: function(){
    $('#schedule_callback_button').hide();
    $("#callback_info").show();
  },

  collapseScheduler: function(){
    $('#schedule_callback_button').show();
    $("#callback_info").hide();
  },

  validateScheduleDate: function(){
    var temp_value = $("#scheduled_date").val();
    var scheduled_date = $.trim(temp_value);
    if (scheduled_date != "") {
      if (Date.parseExact(scheduled_date, "M/d/yyyy") == null){
        return false;
      }
    }
    return true;
  }

});