var Monitors = {}


Monitors.prototype.setup_twilio = function(token){
  Twilio.Device.setup(token, {'debug':true});
  Twilio.Device.connect(function (conn) {});
  Twilio.Device.ready(function (device) {});
  Twilio.Device.error(function (error) {
    alert(error.message);
  });
};

Monitors.prototype.monitor = function(session_id, action, monitor_session_id){
  params = {'session_id': session_id, 'type': action, 'monitor_session' : monitor_session_id};
  $('.stop_monitor').show();
  Twilio.Device.connect(params)
};

Monitors.prototype.de_activate_monitor = function(monitor_session_id){
  $.ajax({
      url : "/client/monitors/deactivate_session",
      data : {monitor_session : monitor_session_id},
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

Monitors.prototype.switch_mode = function(session, mode, monitor_session_id){
  $.ajax({
      url : "/client/monitors/switch_mode",
      data : {session_id : session,type : mode,monitor_session : monitor_session_id},
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

Monitors.prototype.switch_caller = function(current_session_id, next_session_id, action, status){
	$.ajax({
    url : "/client/monitors/stop",
    data : {session_id : current_session_id},
    type : "GET",
    success : function(response) {
      request_to_switch(next_session_id, action, status);
    }	
};

Monitors.prototype.request_to_switch = function(next_session_id, action, status) {
  $.ajax({
    url : "/client/monitors/start",
	data : {'session_id' : next_session_id, 'type': action, 'monitor_session' : $('monitor_session').text()},
	type : "GET",
	success : function(response) {}
  });	
};

