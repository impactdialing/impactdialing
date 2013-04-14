Pusher.log = function(message) {
    if (window.console && window.console.log) window.console.log(message);
};

var channel = null;



$(document).ready(function() {
    hide_all_actions();
    subscribe($('#session_key').val());
    $('#scheduled_date').datepicker();
})

function hide_all_actions() {
	$("#start_calling").hide();
	$("#callin_data").hide();
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


function transfer_call(){
	$('#transfer_button').html("Transferring...");
	$('#hangup_call').hide();
	var options = {
	    data: {voter: $("#current_voter").val(), call: $("#current_call").val(), caller_session:$("#caller_session").val()  }
    };
    $('#transfer_form').attr('action', "/transfer/dial")
	$('#transfer_form').submit(function() {
				$('#transfer_button').html("Transfered");
        $(this).ajaxSubmit(options);
		    $(this).unbind("submit");
        return false;
    });
}

function kick_caller_off(){
	$.ajax({
        url : "/caller/" + $("#caller").val() + "/kick_caller_off_conference",
        data : {caller_session: $("#caller_session").val() },
        type : "POST"
    })


}

function validate_schedule_date(){
  var temp_value = $("#scheduled_date").val();
  var scheduled_date = $.trim(temp_value);
  if (scheduled_date != "") {
	if (Date.parseExact(scheduled_date, "M/d/yyyy") == null){
		return false;
	}
  }
  return true;

}


function send_voter_response() {
	var options = {
	    data: {caller_session:$("#caller_session").val()},
    };
    if (validate_schedule_date() == false){
	  alert('The Schedule callback date is invalid');
	  return false;
    }

    $('#voter_responses').attr('action', "/calls/" + $("#current_call").val() + "/submit_result");
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
            window.location.reload();
        }
    };
    if (validate_schedule_date() == false){
	  alert('The Schedule callback date is invalid');
	  return false;
    }

    $('#voter_responses').attr('action', "/calls/" + $("#current_call").val() + "/submit_result_and_stop");
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
					$("#callin_data").show();
            }
        })
    }else{
        hide_all_actions();
        $("#start_calling").show();
		$("#callin_data").show();
    }
}

function ie8(){
	if ($.browser.msie) {
  	  window.onbeforeunload = null;
    }

}

function disconnect_voter() {
	$("#hangup_call").hide();
    $.ajax({
        url : "/calls/" + $("#current_call").val() + "/hangup",
        type : "POST",
        success : function(response) {
            // pushes 'calling_voter'' event to browsers
        }
    })
}


function show_response_panel() {
    $("#response_panel").show();
    $("#result_instruction").hide();
}

function show_transfer_panel(){
	$('#transfer_button').html("Transfer")
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
		$("#start_calling").show();
		$("#callin_data").show();
		$('#connecting').hide();

	channel.bind('start_calling', function(data) {
		set_session(data.caller_session_id)
		$("#callin_data").hide();
	    $('#start_calling').hide();
	    $('#stop_calling').show();
	    $("#called_in").show();
	});

	channel.bind('conference_started', function(data) {
	if ($("#caller_session").val() != "" ){
		set_message("Status: Ready for calls.");
        set_voter(data);
        ready_for_calls(data)
	}
    });

    channel.bind('voter_connected', function(data) {
        set_current_call(data.call_id);
        hide_all_actions();
        set_message("Status: Connected.");
        show_response_panel();
		show_transfer_panel();
        $("#hangup_call").show();
    });

    channel.bind('voter_connected_dialer', function(data) {
        set_current_call(data.call_id);
		set_voter(data.voter);
		hide_all_actions();
		set_message("Status: Connected.")
	    show_response_panel();
		show_transfer_panel();
		$("#hangup_call").show();
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

    channel.bind('calling_voter', function(data) {
        set_message('Status: Call in progress.');
        hide_all_actions();
    });

    channel.bind('caller_disconnected', function(data) {
        clear_caller();
        clear_voter();
        hide_response_panel();
        set_message('Status: Not connected.');
        hide_all_actions();
        $("#callin_data").show();
        if (FlashDetect.installed && flash_supported())
            $("#start_calling").show();
    });


    channel.bind('caller_connected_dialer', function(data) {
        hide_all_actions();
        $("#stop_calling").show();
        set_message("Status: Dialing.");
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

    function set_current_call(id) {
        $("#current_call").val(id);
    }

    function set_voter(data) {
        if (!$.isEmptyObject(data.fields)) {
            $("#voter_info_message").hide();
            $("#current_voter").val(data.fields.id);
            bind_voter(data);
            cleanup_previous_call_results();
			cleanup_transfer_panel();
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
        Pusher.log(data)
        var voter = ich.voter(data); //using ICanHaz a moustache. js like thingamagic
        $('#voter_info').empty();
        $('#voter_info').append(voter);
    }

    function cleanup_previous_call_results() {
		$(".script_element select").each(function(index) {
			$(this).children('option:selected').attr('selected',false)
		});

		$(".script_element select").each(function(index) {
			$(this).children('option:first').attr('selected', 'selected');
		});

        $('.note_text').val('');
        $('#scheduled_date').val('')
        collapse_scheduler();
    }

    function cleanup_transfer_panel() {
        $('#transfer_type').val('');
    }

	function voter_connected(){
		hide_all_actions();
	    show_response_panel();
		show_transfer_panel();
		set_message("Status: Connected.")
	    $("#hangup_call").show();
	}


}
