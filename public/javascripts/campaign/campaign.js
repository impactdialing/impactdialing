var Campaign = function(){
  var self = this;	

  $("#campaign_type").change(function() {
	self.dialing_mode_changed();
  });
   this.detect_answering_machine();
   this.detect_leave_voice_mail();

  $('#campaign_answering_machine_detect').click(function () {
	self.detect_answering_machine();
  });

  $('#campaign_use_recordings').click(function () {
	self.detect_leave_voice_mail();
  });


  $("#campaign_recording_id").live("change", function(){
     updatePreview();	
  });

  $('#campaign_user_recordings').live("click", function(){
	self.doRecord();
  });
  

 		
}

Campaign.prototype.doRecord = function(){
   if ($("#campaign_use_recordings").attr('checked') == true) {
       $('#campaign_answering_machine_detect').attr('checked', true);
   }
   $("#recordingsdiv").toggle($("#campaign_use_recordings").checked);	
}

Campaign.prototype.detect_answering_machine = function(){
  if ($('#campaign_answering_machine_detect').is(":checked")) {
  	 $("#campaign_use_recordings").parent().show();
   }
  else {
  	 $("#campaign_use_recordings").parent().hide();
     $("#recordingsdiv").hide();
  }
}

Campaign.prototype.detect_leave_voice_mail = function(){
	if ($("#campaign_use_recordings").is(":checked")) {
	  $("#recordingsdiv").show();
    }
    else{
	  $("#recordingsdiv").hide();
    }    
}

Campaign.prototype.display_abandonment_rate = function(){
  if ($("#campaign_type").val() == "Predictive") {
    $("#abandon_rate_edit").show();
  }  
}

Campaign.prototype.dialing_mode_changed = function(){
    var dialMode = $('#campaign_type').val();
    if (dialMode == "Predictive") {
      $('#abandon_rate_edit').show();
      $('#campaign_abandon_rate').val(0.03);
    } else {
      $('#abandon_rate_edit').hide();
    }       
}
