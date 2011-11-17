Pusher.log = function(message) {
    if (window.console && window.console.log) window.console.log(message);
};

var channel = null;

$(document).ready(function() {
    hide_all_actions();
    setInterval(function() {
        if ($("#caller_session").val()) {
            //do nothing if the caller session context already exists
        } else {
            get_session();
        }
    }, 5000); //end setInterval
})

function hide_all_actions() {
    $("#skip_voter").hide();
    $("#call_voter").hide();
    $("#stop_calling").hide();
    $("#hangup_call").hide();
    $("#submit_and_keep_call").hide();
    $("#submit_and_stop_call").hide();

}


function set_session(session_id) {
    $("#caller_session").val(session_id);
}

function get_session() {
    $.ajax({
        url : "/caller/active_session",
        data : {id : $("#caller").val(), campaign_id : $("#campaign").val() },
        type : "POST",
        success : function(json) {
            if (json.caller_session.id) {
                set_session(json.caller_session.id);
                subscribe(json.caller_session.session_key);
                $("#callin_data").hide();
                $("#called_in").show();
                get_voter();
            }
        }
    })
}

function get_voter() {
    $.ajax({
        url : "/caller/" + $("#caller_session").val() + "/preview_voter",
        data : {id : $("#caller").val(), session_id : $("#caller_session").val() },
        type : "POST",
        success : function(response) {
            // pushes 'voter_push' event to browsers
        }
    })
}


function next_voter() {
    $.ajax({
        url : "/caller/" + $("#caller_session").val() + "/preview_voter",
        data : {id : $("#caller").val(), voter_id : $("#current_voter").val(), session_id : $("#caller_session").val() },
        type : "POST",
        success : function(response) {
            // pushes 'caller_next_voter' event to browsers
        }
    })
}

function call_voter() {
    $.ajax({
        url : "/caller/" + $("#caller_session").val() + "/call_voter",
        data : {id : $("#caller").val(), voter_id : $("#current_voter").val(), session_id : $("#caller_session").val() },
        type : "POST",
        success : function(response) {
            hide_all_actions();
            // pushes 'calling_voter'' event to browsers
        }
    })
}

function ready_to_call(dialer) {
    if (dialer && dialer.toLowerCase() == "preview") {
        $("#stop_calling").show();
        $("#skip_voter").show();
        $("#call_voter").show();
    }
}


function send_voter_response() {
	$('#voter_responses').attr('action', "/call_attempts/" + $("#current_call_attempt").val() + "/voter_response");
	$('#voter_id').val($("#current_voter").val())
	$('#voter_responses').submit(function() { 
	  $(this).ajaxSubmit({}); 
	  return false; 
	  });
	$("#voter_responses").trigger("submit")
}

function send_voter_response_and_disconnect() {
	var options = { 
        success:  function(){
		  disconnect_caller();
        }
    };
    var str = $("#voter_responses").serializeArray();
	$('#voter_responses').attr('action', "/call_attempts/" + $("#current_call_attempt").val() + "/voter_response");
	$('#voter_id').val($("#current_voter").val())
	$('#voter_responses').submit(function() { 
	  $(this).ajaxSubmit(options); 
	  return false; 
	  });
	$("#voter_responses").trigger("submit")
}

function disconnect_caller() {
    $.ajax({
        url : "/caller/" + $("#caller").val() + "/stop_calling",
        data : {session_id : $("#caller_session").val() },
        type : "POST",
        success : function(response) {
			$("#start_calling").show();
            // pushes 'calling_voter'' event to browsers
        }
    })
}

function disconnect_voter() {
    $.ajax({
        url : "/call_attempts/" + $("#current_call_attempt").val() + "/hangup",
        type : "POST",
        success : function(response) {
            // pushes 'calling_voter'' event to browsers
        }
    })
}

function dial_in_caller(){  
  	
  $.ajax({
      url : "/caller/" + $("#caller").val() + "/start_calling",
	data : {campaign_id : $("#campaign").val() },
      type : "POST",
      success : function(response) {
          $('#start_calling').hide();
      }
  })

	
	
}

function show_response_panel() {
    $("#response_panel").show();
    $("#result_instruction").hide();
}

function hide_response_panel() {
    $("#response_panel").hide();
    $("#result_instruction").show();
}

function set_message(text) {
    $("#statusdiv").html(text);
}

function subscribe(session_key) {
    channel = pusher.subscribe(session_key);


    channel.bind('caller_connected', function(data) {
	    console.log('caller_connected' + data)
        hide_all_actions();
        $("#callin_data").hide();
        hide_response_panel();
        $("#stop_calling").show();
        if (!$.isEmptyObject(data.fields)) {
            set_message("Ready for calls.");
            set_voter(data);

        } else {
            set_message("There are no more numbers to call in this campaign.");
        }
    });

    channel.bind('voter_push', function(data) {
        set_voter(data);
    });

    channel.bind('voter_disconnected', function(data) {
        hide_all_actions();
        show_response_panel();
        set_message("Please enter your call results.");
    });

    channel.bind('voter_connected', function(data) {
        show_response_panel();
        set_call_attempt(data.attempt_id);
        hide_all_actions();
        $("#hangup_call").show();
    });

    channel.bind('calling_voter', function(data) {
        set_message('Call in progress.');
        hide_all_actions();
    });

    channel.bind('caller_disconnected', function(data) {
        clear_caller();
        clear_voter();
        hide_response_panel();
		set_message('Status: Not connected.');
        $("#callin_data").show();
        hide_all_actions();
    });

    channel.bind('waiting_for_result', function(data) {
        show_response_panel();
        set_message('Please enter your call results.');
        hide_all_actions();
        $("#submit_and_keep_call").show();
        $("#submit_and_stop_call").show();
    });

    function set_call_attempt(id) {
        $("#current_call_attempt").val(id);
    }

    function set_voter(data) {
        if (!$.isEmptyObject(data.fields)) {
            $("#voter_info_message").hide();
            $("#current_voter").val(data.fields.id);
            bind_voter(data);
            hide_response_panel();
            hide_all_actions();
            ready_to_call(data.dialer);

        } else {
            hide_all_actions();
            hide_response_panel();
            set_message("There are no more numbers to call in this campaign.");
            $("#stop_calling").show();
        }
    }

    function clear_caller() {
        $("#caller_session").val(null);
    }

    function clear_voter() {
        $("#voter_info_message").show();
        $("#current_voter").val(null);
        $('#voter_info').empty();
        hide_all_actions();

    }


    function bind_voter(data) {
        var voter = ich.voter(data); //using ICanHaz a moustache. js like thingamagic
        $('#voter_info').empty();
        $('#voter_info').append(voter);
    }

}
