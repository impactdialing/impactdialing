var Campaign = function(){
  var self = this;

  /**
  * Setup event handlers
  */
  $("#campaign_type").change(function() {
  	self.dialing_mode_changed();
  });

  $('#campaign_answering_machine_detect').change(function () {
    if( !self.isDetectingMachines() ) {
      $('#campaign_use_recordings').val('0');
      self.toggleCallbackAfterVoicemail();
      self.toggleRecordingsDiv();
    }

	  self.toggleAutoDetectOptions();
  });

  $(document).on('change', '#campaign_use_recordings, #campaign_caller_can_drop_message_manually', function(){
    if( !self.isUsingRecordings() ) {
      $('#campaign_call_back_after_voicemail_delivery').val('0');
    }

    self.toggleRecordingsDiv();
    self.toggleCallbackAfterVoicemail();
  });

  $(document).on("change", "#campaign_recording_id", function(){
    if( typeof(updatePreview) !== undefined ){
      updatePreview();
    }
  });

  $(document).on("change", "#campaign_script", function(){
    if ($("#campaign_id").val() == ""){
      return
    }
    var self = this;
    $.ajax({
      url : "/client/campaigns/" + $("#campaign_id").val() + "/can_change_script",
      data : {script_id : $(self).val()},
      type : "GET",
      success : function(response) {
        console.log(response);
        if( !response.message ) {
          var confirmMsg = "You have already made calls on this campaign with the existing script."+
                           " If you change scripts now, your Answered calls report and Download report "+
                           "will include results in both the old and the new scripts."+
                           " Are you sure you want to change the script?";
          if( !confirm(confirmMsg) ) {
            $("#campaign_script").val(response.script_id);
          }
        }
      }
    });
  });

  /**
  * Ensure hidden checked check boxes are shown
  */
  this.dialing_mode_changed();
  this.toggleCallbackAfterVoicemail();
  this.toggleAutoDetectOptions();
  this.toggleRecordingsDiv();
};


Campaign.prototype.checkCampaignDialed = function(){

}

Campaign.prototype.isDetectingMachines = function() {
  return $('#campaign_answering_machine_detect').is(":checked");
};

Campaign.prototype.isAutoDroppingMessages = function() {
  return $('#campaign_use_recordings').val() == '1';
};

Campaign.prototype.isUsingRecordings = function() {
  var val = this.isAutoDroppingMessages() || $('#campaign_caller_can_drop_message_manually').is(':checked')
  return val;
};

Campaign.prototype.toggle = function(el, show) {
  if( show ) {
    el.show();
  } else {
    el.hide();
  }
}

Campaign.prototype.toggleRecordingsDiv = function(){
  var el = $('#recordingsdiv').parent();
  this.toggle(el, this.isUsingRecordings());
};

Campaign.prototype.toggleCallbackAfterVoicemail = function(){
  var el = $('#campaign_call_back_after_voicemail_delivery').parent();
  this.toggle(el, this.isUsingRecordings());
};

Campaign.prototype.toggleAutoDetectOptions = function() {
  var el = $("#campaign_use_recordings").parent();
  this.toggle(el, this.isDetectingMachines());
};

Campaign.prototype.toggleAbandonmentRate = function(){
  var el  = $('#abandon_rate_edit');

  this.toggle(el, this.isPredictive());
};

Campaign.prototype.dialMode = function() {
  return $('#campaign_type').val();
};

Campaign.prototype.isPredictive = function() {
  return this.dialMode() == 'Predictive';
};

Campaign.prototype.dialing_mode_changed = function(){
    this.toggleAbandonmentRate();

    if( this.isPredictive() ) {
      $('#campaign_abandon_rate').val(0.03);
    }
};
