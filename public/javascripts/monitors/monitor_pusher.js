Pusher.log = function(message) {
    if (window.console && window.console.log) window.console.log(message);
};

var channel = null;

function update_status_and_duration(caller_selector, status){
	$($(caller_selector).find('.status')).html(status)
	$($(caller_selector).find('.timer')).stopwatch('reset');
	//$($(caller_selector).find('.timer')).stopwatch('start');
}

function forming_select_tag(data){
	var select_tag = "<select class='assign_campaign'>";
	var option_tag = "";
	for(i=0;i<data.campaign_ids.length;i++){
		if(data.campaign_ids[i] == data.current_campaign_id){
			option_tag = "<option selected='selected' value="+data.campaign_ids[i]+">"+data.campaign_names[i]+"</option>"
		}
		else{
			option_tag = "<option value="+data.campaign_ids[i]+">"+data.campaign_names[i]+"</option>"
		}
		select_tag += option_tag
	}
	select_tag += "</select>";
	return select_tag;
}

function subscribe_and_bind_events_monitoring(session_id){
  channel = pusher.subscribe(session_id);  

  channel.bind('set_status', function(data){
    $('status').text(data.status_msg);
  });

	console.log('stopwatch: inside monitoring', $.fn.stopwatch, $('body').stopwatch);
  
  channel.bind('caller_session_started', function(data){
    if (!$.isEmptyObject(data)) {
      console.log("pusher event caller session started")
			var caller_selector = 'tr#'+data.id+'.caller';
			var campaign_selector = 'tr#'+data.campaign_fields.id+'.campaign';
      var caller = ich.caller(data);
      $('#caller_table').children().append(caller);

			$(caller_selector).find(".campaigns").html(forming_select_tag(data));
      
      if($(campaign_selector).length == 0){
        var campaign = ich.campaign(data);
        $('#campaign_table').children().append(campaign);
      }
      else{
        $(campaign_selector).children('.callers_logged_in').text(data.campaign_fields.callers_logged_in);
        $(campaign_selector).children('.voters_count').text(data.campaign_fields.voters_count);
      }

			$($(caller_selector).find('.timer')).stopwatch();			
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
      $('status').text("Status: Disconnected.");
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
			update_status_and_duration(caller_selector, "Wrap up");
      $(campaign_selector).children('.voters_count').text(data.voters_remaining);
 			if($(caller_selector).attr("on_call") == "true"){
				$('status').text("Status: Caller is not connected to a lead.");
			}
    }
  });
  
  channel.bind('voter_connected',function(data){
    console.log(data);
    if (!$.isEmptyObject(data)){
      var campaign_selector = 'tr#'+data.campaign_id+'.campaign';
			var caller_selector = 'tr#'+data.caller_id+'.caller';
			update_status_and_duration(caller_selector, "On call");
			if($(caller_selector).attr("on_call") == "true"){
				status = "Status: Monitoring in " + $(caller_selector).attr('mode') + " mode on " + $(caller_selector).children('td.caller_name').text().split("/")[0] + ".";
    		$('status').text(status);
			}
		}
  });

	channel.bind('update_dials_in_progress', function(data){
		if (!$.isEmptyObject(data)){
			var campaign_selector = 'tr#'+data.campaign_id+'.campaign';
			$(campaign_selector).children('.dials_in_progress').text(data.dials_in_progress);
			console.log(data);
			if(data.voters_remaining){
				$(campaign_selector).children('.voters_count').text(data.voters_remaining);
			}
		}
	});
	channel.bind('voter_response_submitted', function(data){
		if (!$.isEmptyObject(data)){
			var caller_selector = 'tr#'+data.caller_id+'.caller';
			var campaign_selector = 'tr#'+data.campaign_id+'.campaign';
			update_status_and_duration(caller_selector, "On hold");
			$(campaign_selector).children('.dials_in_progress').text(data.dials_in_progress);
			$(campaign_selector).children('.voters_count').text(data.voters_remaining);
		}
	});
  
}

$(document).ready(function() {

	// Start timers for caller status
	var timers = $('.timer');
	$.each(timers, function(){
		$(this).stopwatch('start');
	});

	// Monitoring
  $('.stop_monitor').hide();
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

