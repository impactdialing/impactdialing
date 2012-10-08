Pusher.log = function(message) {
    if (window.console && window.console.log) window.console.log(message);
};

var channel = null;

function update_status_and_duration(caller_selector, status){
	if ($($(caller_selector).find('.status')).html() != status) {
  	  $($(caller_selector).find('.status')).html(status)
	    $($(caller_selector).find('.timer')).stopwatch('reset');
	}
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

function update_caller_row(data){
  var caller_selector = 'tr#caller_'+data.caller_session_id;
  if($(caller_selector).find('.assign_campaign').val() != data.campaign_fields.id){
    $(caller_selector).find('.assign_campaign :selected').removeAttr('selected');
    $(caller_selector).find('.assign_campaign option[value="' + data.campaign_fields.id + '"]').attr('selected','selected')
  }
}

function update_campaign_row(data){

	var campaign_selector = 'tr#campaign_'+data.campaign_fields.id;
	if($(campaign_selector).length == 0){
    var campaign = ich.campaign(data);
    $('#campaign_table').children().append(campaign);
  }
  else{
    $(campaign_selector).children('.callers_logged_in').text(data.campaign_fields.callers_logged_in);
    $(campaign_selector).children('.voters_count').text(data.campaign_fields.voters_count);
  }
	
}

function update_old_campaign_row(data){
	var old_campaign_selector = 'tr#campaign_'+data.old_campaign_id;
	if(data.no_of_callers_logged_in_old_campaign == 0){
    $(old_campaign_selector).remove();
  }
  else{
    $(old_campaign_selector).children('.callers_logged_in').text(data.no_of_callers_logged_in_old_campaign);
  }
}

function subscribe_and_bind_events_monitoring(session_id){
  channel = pusher.subscribe(session_id);  

  channel.bind('set_status', function(data){
    $('status').text(data.status_msg);
  });

  
  channel.bind('caller_session_started', function(data){
    if (!$.isEmptyObject(data)) {

	  var caller_selector = 'tr#caller_'+data.session_id;
      var caller = ich.caller(data);
      
			$('#caller_table').children().append(caller);
			$(caller_selector).find(".campaigns").html(forming_select_tag(data));
			$($(caller_selector).find('.timer')).stopwatch();
			update_campaign_row(data);		
    }
    else{
    }
  });
  
  channel.bind('caller_disconnected', function(data) {
    var caller_selector = 'tr#caller_'+data.caller_session_id;
		var campaign_selector = 'tr#campaign_'+data.campaign_id;
		
    if($(caller_selector).attr('on_call') == "true"){
      $('.stop_monitor').hide();
      $('status').text("Status: Disconnected.");
    }
    $(caller_selector).remove();
		if(!data.campaign_active){
      $(campaign_selector).remove();
    }
    else{
      $(campaign_selector).children('.callers_logged_in').text(data.no_of_callers_logged_in);
    }
  });

  channel.bind('voter_event', function(data){
	call_status = {"Call in progress": "On call", "Call completed with success.": "Wrap up", null:"On hold", "Ringing":"On hold" }
	if (!$.isEmptyObject(data)){
      var campaign_selector = 'tr#campaign_'+data.campaign_id;
	  var caller_selector = 'tr#caller_'+data.caller_session_id;
	  update_status_and_duration(caller_selector, call_status[data.call_status]);
	  if($(caller_selector).attr("on_call") == "true"){
        status = "Status: Monitoring in " + $(caller_selector).attr('mode') + " mode on " + $(caller_selector).children('td.caller_name').text().split("/")[0] + ".";
		$('status').text(status);
      }
   	  if($(caller_selector).attr("on_call") == "true"){
		$('status').text("Status: Caller is not connected to a lead.");
	 }

	}
  });

  channel.bind('update_dials_in_progress', function(data){
		if (!$.isEmptyObject(data)){
			var campaign_selector = 'tr#campaign_'+data.campaign_id;
			$(campaign_selector).children('.dials_in_progress').text(data.dials_in_progress);
			if(data.voters_remaining){
				$(campaign_selector).children('.voters_count').text(data.voters_remaining);
			}
		}
	});

  	
	channel.bind('caller_re_assigned_to_campaign', function(data){
		if (!$.isEmptyObject(data)){
			var caller_selector = 'tr#caller_'+data.caller_session_id;
			update_caller_row(data)
			update_campaign_row(data);
			update_old_campaign_row(data);
			update_status_and_duration(caller_selector, "On hold");
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

