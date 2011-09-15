$(document).ready(function() {
    $.fn.exists = function() {
        return jQuery(this).length > 0;
    }


    setInterval(function() {
        if (!$("#caller_session").val()) {
            get_session();
        }
    }, 5000); //end setInterval
});

function set_session(session_id) {
    $("#caller_session").val(session_id);
}

function get_session() {
    $.ajax({
        url : "/caller/active_session",
        data : {id : $("#caller").val()},
        type : "POST",
        success : function(json) {
            set_session(json.caller_session.id)
        }
    })
}

function current_session() {
    $("#caller_session").val();
}
