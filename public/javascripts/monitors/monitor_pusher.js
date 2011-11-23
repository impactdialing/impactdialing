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
  monitor_session = $('monitor_session').text()
  channel = pusher.subscribe(monitor_session);
  console.log(channel)
  channel.bind('no_voter_on_call', function(data){
    alert("xfdf")
    $('status').text("Currently no voter is connected, You can monitor when voter connected")
  });
  
  
  
});
