var channel = null;

$(document).ready(function() {
    $("#skip_voter").hide();
	$("#call_voter").hide();
	$("#hangup_call").hide();	
	$("#submit_call").hide();		
	
    setInterval(function() {
        if ($("#caller_session").val()) {
            //do nothing if the caller session context already exists
        } else {
            get_session();
            if ($("#caller_session").val()) {
                $("#callin_data").hide();
                $("#called_in").show();
            }
        }
    }, 5000); //end setInterval
})

function set_session(session_id) {
    $("#caller_session").val(session_id);
}

function get_session() {
    $.ajax({
        url : "/caller/active_session",
        data : {id : $("#caller").val()},
        type : "POST",
        success : function(json) {
            if (json.caller_session.id) {
                set_session(json.caller_session.id);
                subscribe(json.caller_session.session_key);
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
            // pushes 'calling_voter'' event to browsers
        }
    })
}

function send_voter_response(){
    var str = $("#voter_responses").serializeArray();
    $.ajax({
        url : "/call_attempts/" + $("#current_call_attempt").val() + "/voter_response",
        data : {voter_id : $("#current_voter").val(), answers : str },
        type : "POST",
        success : function(response) {
            // pushes 'voter_push' event to browsers
        }
    });
}
function disconnect_caller(){
    $.ajax({
        url : "/caller/hangup_on_voter",
		data : {id : $("#caller").val(), voter_id : $("#current_voter").val(), session_id : $("#caller_session").val() },
        type : "POST",
        success : function(response) {
            // pushes 'calling_voter'' event to browsers
        }
    })
  	
}





function show_response_panel(){
    $("#response_panel").show();
    $("#result_instruction").hide();
}

function hide_response_panel(){
    $("#response_panel").hide();
    $("#result_instruction").show();
}

function set_message(text) {
    $("#statusdiv").replaceData(text);
}

function subscribe(session_key) {
    channel = pusher.subscribe(session_key);

    channel.bind('test', function(data) {
        alert(data);
    });

    channel.bind('caller_connected', function(data) {
        set_voter(data);
        $("#voter_info_message").hide();
        $("#callin_data").hide();
        set_message("Call connected");
    });

    channel.bind('voter_push', function(data) {
        set_voter(data);
    });

    channel.bind('voter_disconnected', function(data) {
		$("#skip_voter").hide();
		$("#call_voter").hide();
		$("#hangup_call").hide();			
		$("#submit_call").show();		
        show_response_panel();
        set_message("Entering voter results");
    });

    channel.bind('voter_connected', function(data) {
        show_response_panel();
        set_call_attempt(data.attempt_id);
		$("#skip_voter").hide();
		$("#call_voter").hide();
		$("#hangup_call").show();		
		$("#submit_call").hide();		    
		

    });

    channel.bind('calling_voter', function(data) {
        set_voter(data);
        set_message('Call in progress');
		$("#skip_voter").hide();
		$("#call_voter").hide();
		$("#hangup_call").show();		    
		$("#submit_call").hide();		            
    });

    channel.bind('caller_disconnected', function(data) {
        clear_voter();
        hide_response_panel();
    });

    function set_call_attempt(id){
        $("#current_call_attempt").val(id);
    }


    function set_voter(data) {
        $("#current_voter").val(data.fields.id);
        bind_voter(data);
        $("#skip_voter").show();
		$("#call_voter").show();	    
		$("#hangup_call").hide();		    
		$("#submit_call").hide();		            
		
    }

    function clear_voter() {
        $("#current_voter").val(null);
        $('#voter_info').empty();
		$("#skip_voter").hide();
		$("#call_voter").hide();
		$("#hangup_call").hide();		    
		$("#submit_call").hide();		            

    }


    function bind_voter(data) {
        data.custom_fields = parse_custom_fields(data);
        var voter = ich.voter(data); //using ICanHaz a moustache. js like thingamagic
        $('#voter_info').empty();
        $('#voter_info').append(voter);
    }

    function parse_custom_fields(data) {
        var custom_fields = new Array();
        $.each(data.custom_fields, function(key, value) {
            if (value) {
                custom_fields.push(key + " : " + value);
            }
        });
        return custom_fields;
    }
}
