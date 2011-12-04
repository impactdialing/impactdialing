Pusher.log = function(message) {
    if (window.console && window.console.log) window.console.log(message);
};

var channel = null;

function subscribe_and_bind_events_monitoring(session_id){
  channel = pusher.subscribe(session_id);  

  channel.bind('no_voter_on_call', function(data){
    $('status').text("Status: Caller is not connected to a lead.")
  });
  
  channel.bind('caller_session_started', function(data){
    console.log(data)
    if (!$.isEmptyObject(data)) {
      console.log("pusher event caller session started")
      var caller = ich.caller(data);
      $('#caller_table').children().append(caller);
      
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
    else{
      console.log("pusher event caller session started but no data")
    }
  });
  
  channel.bind('caller_disconnected', function(data) {
    var caller_selector = 'tr#'+data.caller_id+'.caller';
    console.log(caller_selector)
    if($(caller_selector).attr('on_call') == "true"){
      $('.stop_monitor').hide();
      $('status').text("Status: Disconnected.")
    }
    $(caller_selector).remove();
    var campaign_selector = 'tr#'+data.campaign_id+'.campaign';
    if(!data.campaign_active){
      $(campaign_selector).remove();
    }
    else{
      $(campaign_selector).children('.callers_logged_in').text(data.no_of_callers_logged_in);
    }
  });
  
  channel.bind('voter_disconnected', function(data) {
    console.log(data);
    if (!$.isEmptyObject(data)){
      var campaign_selector = 'tr#'+data.campaign_id+'.campaign';
			var caller_selector = 'tr#'+data.caller_id+'.caller';
      $(campaign_selector).children('.dials_in_progress').text(data.dials_in_progress);
      $(campaign_selector).children('.voters_count').text(data.voters_remaining);
 			if($(caller_selector).attr("on_call") == "true"){
				$('status').text("Status: Caller is not connected to a lead.")
			}
    }
  });
  
  channel.bind('voter_connected',function(data){
    console.log(data);
    if (!$.isEmptyObject(data)){
      var campaign_selector = 'tr#'+data.campaign_id+'.campaign';
			var caller_selector = 'tr#'+data.caller_id+'.caller';
      $(campaign_selector).children('.dials_in_progress').text(data.dials_in_progress);
			status = "Status: Monitoring in " + $(caller_selector).attr('mode') + " mode on " + $(caller_selector).children('td.caller_name').text().split("/").first() + ".";
    	$('status').text(status);
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

