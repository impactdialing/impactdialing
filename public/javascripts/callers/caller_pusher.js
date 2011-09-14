$(document).ready(function() {
    $.fn.exists = function() {
        return jQuery(this).length > 0;
    }

    var caller_id = $("#caller").val();

    var pusher = new Pusher('<%= PUSHER_KEY %>');

    setInterval(function() {
            if (!$("#caller_session").id) {
                $.post("/caller/active_session", {id : caller_id}, function(data){})
            }
        },5000); //end setInterval
});
