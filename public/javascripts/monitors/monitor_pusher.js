function subscribe_and_bind_events_monitoring(session_id){
  channel = pusher.subscribe(session_id);  
  console.log(channel)  
  channel.bind('no_voter_on_call', function(data){
    $('status').text("Currently no voter is connected, You can monitor when voter connected")
  });
  
  channel.bind('caller_session_started', function(data){
    if (!$.isEmptyObject(data)) {
      var caller = ich.caller(data);
      $('#caller_table').children().append(caller);
    }
  });
  
}

$(document).ready(function() {
  // $.ajax({
  //     url : "/monitor/active_session",
  //     data : {campaign_id : $("#campaign").val() },
  //     type : "POST",
  //     success : function(json) {
  //         if (json.user.id) {
  //             subscribe_channel(json.user.id);
  //         }
  //     }
  // })

  $('.stop_monitor').hide()

  if($('monitor_session').text()){
    monitor_session = $('monitor_session').text();
    subscribe_and_bind_events_monitoring(monitor_session);
  }
  else{
    $.ajax({
        url : "/client/monitors/monitor_session",
        type : "GET",
        success : function(response) {
           monitor_session = response;
           $('monitor_session').text(monitor_session)
           subscribe_and_bind_events_monitoring(monitor_session);
        }
    });
    
  }
  
  
});

