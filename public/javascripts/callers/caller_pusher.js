var channel = null;

$(document).ready(function() {
    setInterval(function() {
        if ($("#caller_session").val()) {
           //do nothing if the caller session context already exists
        } else {
            get_session();
            if (current_session()) {
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

function subscribe(session_key) {
    channel = pusher.subscribe(session_key);

    channel.bind('test', function(data) {
        alert(data);
    });
}
