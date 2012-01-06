$(document).ready(function() {

	$('.assign_campaign').live('change', function(){
		var campaign_id = this.value;
		var caller_id = $(this).closest('tr').attr('id');
		$.ajax({
        url : "/client/callers/"+ caller_id + "/reassign_to_campaign?campaign_id=" + campaign_id,
				type : "GET",
        success : function(response) {}
    });
	});
	
});