Pusher.log = function(message) {
    if (window.console && window.console.log) window.console.log(message);
};

var channel = null;
var browser_guid = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
    var r = Math.random()*16|0, v = c == 'x' ? r : (r&0x3|0x8);
    return v.toString(16);
});	
var active_count = 0



$(document).ready(function() {
	window.isActive = true;
    $(window).focus(function() { this.isActive = true; });
    $(window).blur(function() { this.isActive = false; });
    
    hide_all_actions();
    setInterval(function() {
	
        if ($("#caller_session").val()) {
            //do nothing if the caller session context already exists
        } else {
			if (window.isActive) {
			  active_count = active_count + 1;	
              get_session();
			}
        }
    }, 5000); //end setInterval

    $('#scheduled_date').datepicker();
})

function hide_all_actions() {
    $("#skip_voter").hide();
    $("#call_voter").hide();
    $("#stop_calling").hide();
    $("#hangup_call").hide();
    $("#submit_and_keep_call").hide();
    $("#submit_and_stop_call").hide();
	$('#kick_self_out_of_conference').hide();
}


function set_session(session_id) {
    $("#caller_session").val(session_id);
}


function get_session() {
	
    $.ajax({
        url : "/caller/active_session",
        data : {id : $("#caller").val(), campaign_id : $("#campaign").val(), browser_id: browser_guid, active_count: active_count },
        type : "POST",
        success : function(json) {
            if (json.caller_session.id && $("#caller_session").val() === ""  ) {
                set_session(json.caller_session.id);
                subscribe(json.caller_session.session_key);
            }
        }
    })
}

function get_voter() {
    $.ajax({
        url : "/caller/" + $("#caller").val() + "/preview_voter",
        data : {id : $("#caller").val(), session_id : $("#caller_session").val(), voter_id: $("#current_voter").val() },
        type : "POST"
    })
}

function pusher_subscribed() {
    $.ajax({
        url : "/caller/" + $("#caller").val() + "/pusher_subscribed",
        data : {id : $("#caller").val(), session_id : $("#caller_session").val()},
        type : "POST",
		success : function(response){			
		    $("#callin_data").hide();
	        $('#start_calling').hide();
	        $('#stop_calling').show();
	        $("#called_in").show();
	        get_voter(); 
		}
    })
}



function next_voter() {
    $.ajax({
        url : "/caller/" + $("#caller").val() + "/skip_voter",
        data : {id : $("#caller").val(), voter_id : $("#current_voter").val(), session_id : $("#caller_session").val() },
        type : "POST",
        success : function(response) {
            // pushes 'caller_next_voter' event to browsers
        }
    })
}

function call_voter() {
    hide_all_actions();
	$("#stop_calling").show();
    $.ajax({
        url : "/caller/" + $("#caller").val() + "/call_voter",
        data : {id : $("#caller").val(), voter_id : $("#current_voter").val(), session_id : $("#caller_session").val() },
        type : "POST",
        success : function(response) {
            // pushes 'calling_voter'' event to browsers
        }
    })
}


function schedule_for_later() {
    hide_all_actions();
    var date = $('#scheduled_date').val();
    var hours = $('select#callback_time_hours option:selected').val();
    var minutes = $('select#callback_time_minutes option:selected').val();
    var date_time = date + " " + hours + ":" + minutes;
    $.post("/call_attempts/" + $('#current_call_attempt').val(),
        {_method: 'PUT', call_attempt : { scheduled_date : $('#scheduled_date').val()}},
        function(response) {
        }
    );
}

function transfer_call(){
	$('#transfer_button').hide();
	$('#hangup_call').hide();
	var options = {
	    data: {voter: $("#current_voter").val(), call_attempt: $("#current_call_attempt").val(), caller_session:$("#caller_session").val()  }
    };
    $('#transfer_form').attr('action', "/transfer/dial")    
	$('#transfer_form').submit(function() {
        $(this).ajaxSubmit(options);
		$(this).unbind("submit");
        return false;
    });
}

function kick_caller_off(){
	$.ajax({
        url : "/caller/" + $("#caller").val() + "/kick_caller_off_conference",
        data : {caller_session: $("#caller_session").val() },
        type : "POST",
    })
    
	
}

function send_voter_response() {
	var options = {
	    data: {caller_session:$("#caller_session").val()},
    };
    
    $('#voter_responses').attr('action', "/call_attempts/" + $("#current_call_attempt").val() + "/voter_response");
    $('#voter_responses').submit(function() {
        $(this).ajaxSubmit(options);
        return false;
    });
    $("#voter_responses").trigger("submit");
    $("#voter_responses").unbind("submit");
}

function send_voter_response_and_disconnect() {
    var options = {
	    data: {stop_calling: true, caller_session:$("#caller_session").val() },
        success:  function() {
            disconnect_caller();
        }
    };
    $('#voter_responses').attr('action', "/call_attempts/" + $("#current_call_attempt").val() + "/voter_response");
    $('#voter_id').val($("#current_voter").val())
    $('#voter_responses').submit(function() {
        $(this).ajaxSubmit(options);
        return false;
    });
    $("#voter_responses").trigger("submit");
    $("#voter_responses").unbind("submit");
}

function disconnect_caller() {
    var session_id = $("#caller_session").val();
    if (session_id) {
        $.ajax({
            url : "/caller/" + $("#caller").val() + "/stop_calling",
            data : {session_id : session_id },
            type : "POST",
            success : function(response) {
                if (FlashDetect.installed && flash_supported())
                    $("#start_calling").show();
            }
        })
    }else{
        hide_all_actions();
        $("#start_calling").show();
    }
}

function ie8(){
	if ($.browser.msie) {
  	  window.onbeforeunload = null;
    }

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

function dial_in_caller() {

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

function show_transfer_panel(){
	$("#transfer_panel").show();
	$('#transfer_button').show();
	$('#stop_listening').hide();
}

function hide_transfer_panel(){
	$("#transfer_panel").hide();
}


function hide_response_panel() {
    $("#response_panel").hide();
	hide_transfer_panel();
    $("#result_instruction").show();

}

function set_message(text) {
    $("#statusdiv").html(text);
}

function collapse_scheduler() {
    $('#schedule_callback').show();
    $("#callback_info").hide();
}

function expand_scheduler() {
    $('#schedule_callback').hide();
    $("#callback_info").show();
}

function ready_for_calls(data) {
    if (data.dialer && data.dialer.toLowerCase() == "progressive") {
        $("#stop_calling").show();
        call_voter();
    }
    if (data.dialer && data.dialer.toLowerCase() == "preview") {
        $("#stop_calling").show();
        $("#skip_voter").show();
        $("#call_voter").show();
    }

}

function set_new_campaign_script(data) {
    $('#campaign').val(data.campaign_id);
    $('#script').text(data.script);
}

function set_response_panel(data) {
    $.ajax({
        url : "/caller/" + $("#caller").val() + "/new_campaign_response_panel",
        data : {},
        type : "POST",
        success : function(response) {
            $('#response_panel').replaceWith(response);
        }
    })
}
function set_transfer_panel(data) {
    $.ajax({
        url : "/caller/" + $("#caller").val() + "/transfer_panel",
        data : {},
        type : "POST",
        success : function(response) {
            $('#transfer_panel').replaceWith(response);
        }
    })
}

function subscribe(session_key) {
    channel = pusher.subscribe(session_key);

	channel.bind('pusher:subscription_succeeded', function() {     
		pusher_subscribed();
    channel.bind('caller_connected', function(data) {
        hide_all_actions();
        $('#browserTestContainer').hide();
        $("#start_calling").hide();
        $("#callin_data").hide();
        hide_response_panel();
        $("#stop_calling").show();
        if (!$.isEmptyObject(data.fields)) {
            set_message("Status: Ready for calls.");
            set_voter(data);
            ready_for_calls(data)
        } else {
            $("#stop_calling").show();
            set_message("Status: There are no more numbers to call in this campaign.");
        }
    });

    channel.bind('conference_started', function(data) {
	if ($("#caller_session").val() != "" ){
        ready_for_calls(data)		
	}
    });


    channel.bind('caller_connected_dialer', function(data) {
        hide_all_actions();
        $("#stop_calling").show();
        set_message("Status: Dialing.");
    });

    channel.bind('answered_by_machine', function(data) {
        if (data.dialer && data.dialer == 'preview') {
            set_message("Status: Ready for calls.");
        }
    });

    channel.bind('voter_push', function(data) {
        set_message("Status: Ready for calls.");
        set_voter(data);
        $("#start_calling").hide();
    });

    channel.bind('call_could_not_connect', function(data) {
        set_message("Status: Ready for calls.");
        set_voter(data);
        $("#start_calling").hide();
        if ($.isEmptyObject(data.fields)) {
            $("#stop_calling").show();

        }
        else {
            ready_for_calls(data);
        }
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

    channel.bind('voter_connected', function(data) {
        set_call_attempt(data.attempt_id);
        hide_all_actions();
        if (data.dialer && data.dialer != 'preview') {
            set_voter(data.voter);
            set_message("Status: Connected.")
        }
        show_response_panel();
		show_transfer_panel();
        cleanup_previous_call_results();
		cleanup_transfer_panel();
        $("#hangup_call").show();
    });

    channel.bind('calling_voter', function(data) {
        set_message('Status: Call in progress.');
        hide_all_actions();
    });
    channel.bind('transfer_busy', function(data) {
        $("#hangup_call").show();
    });
    channel.bind('transfer_connected', function(data) {
		if (data.type == 'warm'){
			$('#transfer_type').val('warm')
		}	
    });
    channel.bind('transfer_conference_ended', function(data) {
		if (data.type == 'warm'){
			$("#hangup_call").hide();
			$('#kick_self_out_of_conference').hide();
		}	
    });



    channel.bind('transfer_conference_ended', function(data) {
		if ($('#transfer_type').val() == 'warm'){
			$("#hangup_call").hide();
			$('#kick_self_out_of_conference').hide();
			$("#submit_and_keep_call").show();
	        $("#submit_and_stop_call").show();
	        
		}			
    });


    channel.bind('caller_disconnected', function(data) {
        clear_caller();
        clear_voter();
        hide_response_panel();
        set_message('Status: Not connected.');
        $("#callin_data").show();
        hide_all_actions();
        if (FlashDetect.installed && flash_supported())
            $("#start_calling").show();
    });

    channel.bind('waiting_for_result', function(data) {
        show_response_panel();
        set_message('Status: Waiting for call results.');
    });

    channel.bind('no_voter_on_call', function(data) {
        $('status').text("Status: Waiting for caller to be connected.")
    });

    channel.bind('predictive_successful_voter_response', function(data) {
        clear_voter();
        hide_response_panel();
        set_message("Status: Dialing.");
    });

	channel.bind('warm_transfer',function(data){
	 	$('#kick_self_out_of_conference').show();	
	});
	channel.bind('caller_kicked_off',function(data){
		$('#kick_self_out_of_conference').hide();	
		$("#submit_and_keep_call").show();
        $("#submit_and_stop_call").show();        
		
	});
	
	
	

    channel.bind('caller_re_assigned_to_campaign', function(data) {

        set_new_campaign_script(data);
        set_response_panel(data);
		set_transfer_panel(data)
        clear_voter();
        if (data.dialer && (data.dialer.toLowerCase() == "preview" || data.dialer.toLowerCase() == "progressive")) {
            if (!$.isEmptyObject(data.fields)) {
                set_message("Status: Ready for calls.");
                set_voter(data);
            } else {
                $("#stop_calling").show();
                set_message("Status: There are no more numbers to call in this campaign.");
            }

        }
        else {
            $("#stop_calling").show();
        }
        alert("You have been re-assigned to " + data.campaign_name + ".");

    });

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

        } else {
            clear_voter();
            hide_all_actions();
            hide_response_panel();
            set_message("Status: There are no more numbers to call in this campaign.");
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
        if (data.custom_fields) {
            var customList = []
            $.each(data.custom_fields, function(item) {
                customList.push({name:item, value:data.custom_fields[item]});
            });
            $.extend(data, {custom_field_list: customList})
        }

        var voter = ich.voter(data); //using ICanHaz a moustache. js like thingamagic
        $('#voter_info').empty();
        $('#voter_info').append(voter);
    }

    function cleanup_previous_call_results() {
        $("#response_panel select option:selected").attr('selected', false);
        $('.note_text').val('');
        $('#scheduled_date').val('')
        collapse_scheduler();
    }

    function cleanup_transfer_panel() {
        $('#transfer_type').val('');
    }

}