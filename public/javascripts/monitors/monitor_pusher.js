function subscribe_and_bind_events_monitoring(session_id){
  channel = pusher.subscribe(session_id);  
  function bind_voter_connected(channel){
    channel.bind('voter_connected',function(data){
      if (!$.isEmptyObject(data)){
        $.each($('tr.caller'), function(){ 
            if($(this).attr('attr_id')  == data.caller_id){
              $(this).children('.voter_phone').text(data.voter_phone);
            } 
        });

      }
    });
    
  }
  
  console.log(channel)  
  channel.bind('no_voter_on_call', function(data){
    $('status').text("Currently no voter is connected, You can monitor when voter connected")
  });
  
  channel.bind('caller_session_started', function(data){
    if (!$.isEmptyObject(data)) {
      var caller = ich.caller(data);
      $('#caller_table').children().append(caller);
      bind_voter_connected(channel)
      var campaign = ich.campaign(data);
      var campaign_present = false;
      $.each($('tr.campaign'), function(){ 
          if($(this).attr('attr_id')  == data.campaign_fields.id){
            $(this).children('.callers_logged_in').text(data.campaign_fields.callers_logged_in);
            $(this).children('.voters_count').text(data.campaign_fields.voters_count);
            campaign_present = true;
          } 
      });
      if(!campaign_present)
      {
        $('#campaign_table').children().append(campaign);
      }
    }
  });
  
  bind_voter_connected(channel)
  
  
  
}

$(document).ready(function() {

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

