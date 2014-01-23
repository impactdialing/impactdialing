(function() {
  var TwilioConnectionMonitor,
      __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  /*
    States currently monitored:
    - ready
    - offline
    - disconnect
    - error

    See http://twilio.com/docs/client_api_guide/client_connect
    for all documented connection events.

    State transition history is retained for the last 5 minutes.
    History is swept every minute, events older than 5 minutes are deleted.
  */
  TwilioConnectionMonitor = (function(_super) {
    __extends(TwilioConnectionMonitor, _super);

    function TwilioConnectionMonitor(device, options) {
      TwilioConnectionMonitor.__super__.constructor.apply(this, [options]);

      _.bindAll(this, 'sweep', 'updateTwilioStats');

      this.updateFrequency = this.oneMinute / 4;
      this.sweepFrequency  = this.oneMinute;

      this.errors = {};
      this.events = {};

      this.service = options.service;
      this.device = device;
      this.monitorConnection();

      return this;
    };

    TwilioConnectionMonitor.prototype.monitorConnection = function() {
      var self = this;

      this.service.ready(function(){
        console.log('TwilioConnectionMonitor.ready');
        self.addEvent('ready');
      });

      this.service.offline(function(connection){
        console.log('TwilioConnectionMonitor.offline');
        self.addEvent('offline');
      });

      this.service.incoming(function(connection){
        console.log('TwilioConnectionMonitor.incoming');
      });

      this.service.cancel(function(connection){
        console.log('TwilioConnectionMonitor.cancel');
      });

      this.service.connect(function(connection){
        console.log('TwilioConnectionMonitor.connect');
      });

      this.service.disconnect(function(connection){
        console.log('TwilioConnectionMonitor.disconnect');
        self.addEvent('disconnect');
      });

      this.service.error(function(error){
        console.log('TwilioConnectionMonitor.error');
        self.addError(error);
      });

      return this;
    };

    TwilioConnectionMonitor.prototype.addEvent = function(eventName) {
      TwilioConnectionMonitor.__super__.addEvent.apply(this, arguments);

      this.updateTwilioStats();
    };

    TwilioConnectionMonitor.prototype.addError = function(error) {
      TwilioConnectionMonitor.__super__.addError.apply(this, arguments);

      this.updateTwilioStats();
    };

    TwilioConnectionMonitor.prototype.updateTwilioStats = function() {
      this.updateStats({
        twilioConnectionEvents: this.events,
        twilioConnectionErrors: this.errors
      });

      return this;
    };

    TwilioConnectionMonitor.prototype.thresholdReached = function() {
      // todo: implement TwilioConnectionMonitor.prototype.thresholdReached
    };

    return TwilioConnectionMonitor;

  })(ImpactDialing.Utilities.PeriodStats);

  window.ImpactDialing.Services.TwilioConnectionMonitor = TwilioConnectionMonitor;

}).call(this);
