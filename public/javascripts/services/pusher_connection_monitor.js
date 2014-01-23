(function() {
  var PusherConnectionMonitor,
      __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  /*
    States currently monitored:
    - connecting
    - unavailable

    See http://pusher.com/docs/client_api_guide/client_connect
    for all documented connection events.

    State transition history is retained for the last 5 minutes.
    History is swept every minute, events older than 5 minutes are deleted.
  */
  PusherConnectionMonitor = (function(_super) {
    __extends(PusherConnectionMonitor, _super);

    function PusherConnectionMonitor(connection, options) {
      PusherConnectionMonitor.__super__.constructor.apply(this, [options]);

      _.bindAll(this, 'sweep', 'updatePusherStats');

      this.updateFrequency = this.oneMinute / 4;
      this.sweepFrequency  = this.oneMinute;

      this.events = {};

      this.connection = connection;
      this.monitorConnection();

      return this;
    };

    PusherConnectionMonitor.prototype.monitorConnection = function() {
      var self = this,
          diff = function(curTime){
            return [
              curTime - window.domLoaded,
              ' ms since DOM load'
            ];
          };

      this.connection.bind('connecting', function(){
        var d = diff(self.time());
        console.log('pusher.connecting', d[0], d[1]);
        self.addEvent('connecting');
      });

      this.connection.bind('connected', function(){
        var d = diff(self.time());
        console.log('pusher.connected', d[0], d[1]);
        self.addEvent('connected');
      });

      this.connection.bind('unavailable', function(){
        var d = diff(self.time());
        console.log('pusher.unavailable', d[0], d[1]);
        self.addEvent('unavailable');
      });

      this.connection.bind('failed', function(){
        var d = diff(self.time());
        console.log('pusher.failed', d[0], d[1]);
        self.addEvent('failed');
      });

      return this;
    };

    PusherConnectionMonitor.prototype.addEvent = function(eventName){
      PusherConnectionMonitor.__super__.addEvent.apply(this, arguments);

      this.updatePusherStats();
    };

    PusherConnectionMonitor.prototype.updatePusherStats = function() {
      this.updateStats({
        pusherConnectionEvents: this.events
      });

      return this;
    };

    PusherConnectionMonitor.prototype.thresholdReached = function() {
      var oneMinuteCounts = {},
          fiveMinuteCounts = {},
          pool = [];

      oneMinuteCounts.connecting = this.forPeriod(this.events.connecting, this.oneMinute);
      oneMinuteCounts.unavailable = this.forPeriod(this.events.unavailable, this.oneMinute);
      fiveMinuteCounts.connecting = this.forPeriod(this.events.connecting, this.fiveMinutes);
      fiveMinuteCounts.unavailable = this.forPeriod(this.events.unavailable, this.fiveMinutes);

      pool = [
        oneMinuteCounts.connecting.length,
        oneMinuteCounts.unavailable.length,
        fiveMinuteCounts.connecting.length,
        fiveMinuteCounts.unavailable.length
      ];

      var isDegrading = function() {
        return _.detect(pool, function(p){return p > 0;}) !== undefined;
      }

      var isDangerous = function() {
        return pool[0] >= 10 || pool[1] >= 1 || pool[2] >= 30 || pool[3] >= 3;
      }

      return isDegrading() || isDangerous();
    };

    return PusherConnectionMonitor;

  })(ImpactDialing.Utilities.PeriodStats);

  window.ImpactDialing.Services.PusherConnectionMonitor = PusherConnectionMonitor;

}).call(this);
