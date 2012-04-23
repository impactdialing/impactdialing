Pusher.log = function(message) {
    if (window.console && window.console.log) window.console.log(message);
};

var channel = null;

function pusher_subscription_succeeded(){
	$("#start_calling").show();
	$("#callin_data").show();
	$('#connecting').hide();	
}

function set_session(session_id) {
    $("#caller_session").val(session_id);
}

function voter_connected(){
	hide_all_actions();
    show_response_panel();
	show_transfer_panel();
    cleanup_previous_call_results();
	cleanup_transfer_panel();
	set_message("Status: Connected.")
    $("#hangup_call").show();    
}




$(document).ready(function() {
    hide_all_actions();
    subscribe($('#session_key').val());
    $('#scheduled_date').datepicker();

	function subscribe(session_key) {
	 channel = pusher.subscribe(session_key);
	 channel.bind('pusher:subscription_succeeded', function() {     
		pusher_subscription_succeeded();
		
     channel.bind("conference_started", function(data){
	    set_message("Status: Ready for calls.");
        set_voter(data);
      	ready_for_calls(data);			
     });

    channel.bind('confernce_started_dialer', function(data) {
        hide_all_actions();
        $("#stop_calling").show();
        set_message("Status: Dialing.");
    });

    channel.bind('voter_connected', function(data) {
        set_call_attempt(data.attempt_id);
		voter_connected();
    });

    channel.bind('voter_connected_dialer', function(data) {
        set_call_attempt(data.attempt_id);
		voter_connected();
		set_voter(data.voter);
    });

    channel.bind('voter_disconnected', function(data) {
        hide_all_actions();
        show_response_panel();
		hide_transfer_panel();
        set_message("Status: Waiting for call results.");
        $("#submit_and_keep_call").show();
        $("#submit_and_stop_call").show();
		if ($('#transfer_type').val() == 'warm'){
			$('#kick_self_out_of_conference').show();
	        $("#submit_and_keep_call").hide();
	        $("#submit_and_stop_call").hide();
		}
    });

	channel.bind('dial_next_voter', function(data) {
		
		
	});




	   
	
	}

});
