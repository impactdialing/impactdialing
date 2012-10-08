Pusher.log = function(message) {
    if (window.console && window.console.log) window.console.log(message);
};

var Monitors = function(channel){
	this.monitoring = false;
	this.channel = channel;	
	this.update_campaign_info();
	this.add_caller_connected();
	this.update_caller_info();
	this.remove_caller();
	this.bind_caller_actions();
	this.call_status = {"Call in progress": "On call", "Call completed with success.": "Wrap up", "On hold": "On hold", "Ringing":"On hold" }
};


Monitors.prototype.bind_caller_actions = function(){
  var self = this;	
  $( function() {
	
	$.each($('.timer'), function(){
	      $(this).stopwatch('start');
	  });
	
	$('.break_in').live('click', function(){
		self.start_monitoring_call(this, 'breakin')
    });

	$('.eaves_drop').live('click', function(){
	  self.start_monitoring_call(this, 'eaves_drop')
    });    
	
    $('.kick_off').live('click', function(){
	  var session_id = $(this).attr("session_id");
	  self.kick_off(session_id);
	  return;
    });

    $('.stop_monitor').live('click', function(){
	  self.disconnect_all();
	  return;
    });

  });
}


Monitors.prototype.setup_twilio = function(token){
  Twilio.Device.setup(token, {'debug':true});
  Twilio.Device.connect(function (conn) {});
  Twilio.Device.ready(function (device) {});
  Twilio.Device.error(function (error) {
    alert(error.message);
  });
};

Monitors.prototype.create_monitor_session = function(){
	$.ajax({
        url : "/client/monitors/monitor_session",
        type : "GET",
        success : function(response) {
           monitor_session = response;
           $('monitor_session').text(monitor_session)
           subscribe_and_bind_events_monitoring(monitor_session);
        }
    });      
};

Monitors.prototype.update_caller_info = function(){
  var self = this;	
  this.channel.bind('update_caller_info', function(data){
	if (!$.isEmptyObject(data)){
	  var caller_selector = 'tr#caller_'+data.caller_session;
	  status = data.event
	  $(caller_selector).attr('on_call', status == 'On call')	
	  self.update_status_and_duration(caller_selector, self.call_status[data.event]);
	}	
  });
};

Monitors.prototype.update_status_and_duration = function(caller_selector, status){
  if ($($(caller_selector).find('.status')).html() != status) {
    $($(caller_selector).find('.status')).html(status)
	$($(caller_selector).find('.timer')).stopwatch('reset');
  }	
};

Monitors.prototype.update_campaign_info = function(){
  this.channel.bind('update_campaign_info', function(data){
	Pusher.log(data);
    $("#campaign_info").children('#callers_logged_in').text(data.callers_logged_in);			
    $("#campaign_info").children('#on_call').text(data.on_call);			
    $("#campaign_info").children('#wrap_up').text(data.wrapup);
    $("#campaign_info").children('#on_hold').text(data.on_hold);
    $("#campaign_info").children('#live_lines').text(data.live_lines);						
    $("#campaign_info").children('#ringing_lines').text(data.ringing_lines);						
    $("#campaign_info").children('#numbers_available').text(data.available);						
    $("#campaign_info").children('#numbers_remaining').text(data.remaining);						
   });	
};

Monitors.prototype.add_caller_connected = function(){
  this.channel.bind('caller_connected', function(data){
	Pusher.log(data);
    if (!$.isEmptyObject(data)) {
	  var caller_selector = 'tr#caller_'+data.caller_session;
      var caller = ich.caller(data);
	  $('#caller_table').children().append(caller);
	  $($(caller_selector).find('.timer')).stopwatch('start');
    }
  });  
}

Monitors.prototype.remove_caller = function(){
  this.channel.bind('caller_disconnected', function(data) {
    var caller_selector = 'tr#caller_'+data.caller_session;
    $(caller_selector).remove();
  });  
};

Monitors.prototype.start_monitoring_call = function(element, action) {
  if($(element).parent().parent().attr("on_call") == "true"){
    var session_id = $(element).attr("session_id");
    this.monitor_caller(session_id, action);
    $(element).parent().parent().attr("mode", action)	
  }
  else{
    alert("Caller is not connected to a lead.")	
  }
}

Monitors.prototype.monitor_caller = function(session_id, action) {
	if (this.monitoring) {
		this.switch_mode(session_id, action)		
	}
	else{
		this.monitor(session_id, action)
	}	
}



Monitors.prototype.monitor = function(session_id, action){
  params = {'session_id': session_id, 'type': action, 'monitor_session' : $("#monitor_session_id").val()};
  $('.stop_monitor').show();
  Twilio.Device.connect(params)
  this.monitoring = true;
};

Monitors.prototype.de_activate_monitor = function(campaign_id, monitor_session_id){
  $.ajax({
      url : "/client/monitors/deactivate_session",
      data : {campaign_id: campaign_id, monitor_session : monitor_session_id},
      type : "GET",
      async : false,
      success : function(response) {}
    });
};

Monitors.prototype.disconnect_all = function(){
  $('status').text("Status: Disconnected.");
  $('.stop_monitor').hide();

  $.each($('tr.caller'), function(){
    $(this).removeAttr("on_call");
	$(this).removeAttr("mode");
  });
  Twilio.Device.disconnectAll();
  return false;	
};

Monitors.prototype.switch_mode = function(session, mode){
  $.ajax({
      url : "/client/monitors/switch_mode",
      data : {session_id : session, type : mode, monitor_session : $('monitor_session').val()},
      type : "GET",
      success : function(response) {
        $('status').text(response)
        }
  });	
};

Monitors.prototype.kick_off = function(session){
  $.ajax({
      url : "/client/monitors/kick_off",
      data : {session_id : session},
      type : "GET"
  })
	
};

// Monitors.prototype.switch_caller = function(current_session_id, next_session_id, action, status){
// 	$.ajax({
//     url : "/client/monitors/stop",
//     data : {session_id : current_session_id},
//     type : "GET",
//     success : function(response) {
//       request_to_switch(next_session_id, action, status);
//     }	
// };

Monitors.prototype.request_to_switch = function(next_session_id, action, status) {
  $.ajax({
    url : "/client/monitors/start",
	data : {'session_id' : next_session_id, 'type': action, 'monitor_session' : $('monitor_session').val()},
	type : "GET",
	success : function(response) {}
  });	
};

