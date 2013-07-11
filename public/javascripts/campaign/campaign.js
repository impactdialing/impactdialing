var Campaign = function(){
  var self = this;

  $("#campaign_type").change(function() {
  	self.dialing_mode_changed();
  });
   this.dialing_mode_changed();
   this.detect_answering_machine();
   this.dialing_mode_changed();

  $('#campaign_answering_machine_detect').click(function () {
	  $("#campaign_use_recordings").parent().toggle($('#campaign_answering_machine_detect').is(":checked"));
    $("#campaign_use_recordings").attr("checked", false);
    $("#recordingsdiv").toggle($('#campaign_use_recordings').is(":checked"))
  });

  $('#campaign_use_recordings').click(function () {
	self.detect_leave_voice_mail();
  });

  $(document).on("change", "#campaign_recording_id", function(){
     updatePreview();
  });

  $(document).on("click", "#campaign_user_recordings", function(){
     self.doRecord();
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
              console.log(response)
              if(!response.message){
                if (!confirm("You have already made calls on this campaign with the existing script. If you change scripts now, your Answered calls report and Download report will include results in both the old and the new scripts. Are you sure you want to change the script?")){
                  $("#campaign_script").val(response.script_id)
                }
              }
            }
        });
  });
}

Campaign.prototype.checkCampaignDialed = function(){

}

Campaign.prototype.doRecord = function(){
   if ($("#campaign_use_recordings").attr('checked') == true) {
       $('#campaign_answering_machine_detect').attr('checked', true);
   }
   $("#recordingsdiv").toggle($("#campaign_use_recordings").checked);
}

Campaign.prototype.detect_answering_machine = function(){
	$("#campaign_use_recordings").parent().toggle($('#campaign_answering_machine_detect').is(":checked"))
	$("#recordingsdiv").toggle($('#campaign_use_recordings').is(":checked"))
}

Campaign.prototype.detect_leave_voice_mail = function(){
	$("#recordingsdiv").toggle($("#campaign_use_recordings").is(":checked"));
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
