var channel = null;

$(document).ready(function() {
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
            set_session(json.caller_session.id);
            subscribe(json.caller_session.session_key);
        }
    })
}

function current_session() {
    $("#caller_session").val();
}

function set_voter(voter_id) {
    $("#current_voter").val(voter_id)
}

function skip() {
    $.ajax({
        url : "/caller/" + $("#caller_session").val() + "/preview_voter",
        data : {id : $("#caller").val(), voter_id : $("#current_voter").val(), session_id : $("#caller_session").val() },
        type : "POST",
        success : function(response) {
            // pushes 'caller_next_voter' event to browsers
        }
    })
}

function subscribe(session_key) {
    channel = pusher.subscribe(session_key);

    channel.bind('test', function(data) {
        alert(data);
    });

    channel.bind('caller_connected', function(data) {
        bind_voter(data);
        $("#voter_info_message").hide();
        $("#callin_data").hide();
    });

    channel.bind('voter_changed', function(data) {
        bind_voter(data);
    });

    function bind_voter(data){
        alert(data.fields.FirstName);
        set_voter(data.fields.id);
        var custom_fields = new Array();
        $.each(data.custom_fields, function(key, value) {
            if (value) {
                custom_fields.push(key + " : " + value);
            }
        });
        data.custom_fields = custom_fields;
        var voter = ich.voter(data) //using ICanHaz a moustache like js like thingy
        $('#voter_info').empty();
        $('#voter_info').append(voter);
    }
}
