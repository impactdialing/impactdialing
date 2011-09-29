var channel = null;

$(document).ready(function() {
    $("#actions").hide();

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

function current_session() {
    $("#caller_session").val();
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

function show_actions() {
    $("#actions").show();
}

function hide_actions() {
    $("#actions").show();
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
        alert(data);
        set_voter(data);
        $("#voter_info_message").hide();
        $("#callin_data").hide();
        set_message("Call connected");
    });

    channel.bind('voter_push', function(data) {
        set_voter(data);
    });

    channel.bind('calling_voter', function(data) {
        set_voter(data);
        set_message('Call in progress');
    });

    channel.bind('caller_disconnected', function(data) {
        clear_voter();
        $('#voter_info').empty();
    });

    function set_voter(data) {
        $("#current_voter").val(data.fields.id);
        bind_voter(data);
        show_actions();
    }

    function clear_voter() {
        $("#current_voter").val(null);
        $('#voter_info').empty();
        hide_actions();
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
