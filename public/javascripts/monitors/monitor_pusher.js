Pusher.log = function(message) {
    if (window.console && window.console.log) window.console.log(message);
};

var channel = null;

function subscribe_and_bind_events_monitoring(session_id){
  channel = pusher.subscribe(session_id);  
  function bind_voter_connected(channel){
    channel.bind('voter_connected',function(data){
      if (!$.isEmptyObject(data)){
        var caller_selector = 'tr#'+data.caller_id+'.caller'
        $(caller_selector).children('.voter_phone').text(data.voter_phone);
        
      }
    });
    
  }
  
  channel.bind('no_voter_on_call', function(data){
    $('status').text("Currently no voter is connected, You can monitor when voter connected")
  });
  
  channel.bind('caller_session_started', function(data){
    if (!$.isEmptyObject(data)) {
      $('div.form').hide();
      var caller = ich.caller(data);
      $('#caller_table').children().append(caller);
      bind_voter_connected(channel)
      
      var campaign_selector = 'tr#'+data.campaign_fields.id+'.campaign';
      if($(campaign_selector).length == 0){
        var campaign = ich.campaign(data);
        $('#campaign_table').children().append(campaign);
      }
      else{
        $(campaign_selector).children('.callers_logged_in').text(data.campaign_fields.callers_logged_in);
        $(campaign_selector).children('.voters_count').text(data.campaign_fields.voters_count);
      }
    }
  });
  
  bind_voter_connected(channel)
  
  channel.bind('caller_disconnected', function(data) {
    var caller_selector = 'tr#'+data.caller_id+'.caller';
    $(caller_selector).remove();
    if(!data.campaign_active){
      var campaign_selector = 'tr#'+data.campaign_id+'.campaign';
      $(campaign_selector).remove();
      if($('tr.campaign').length == 0){
        $('div.form').show();
      }
    }
    
  });
  
  
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

