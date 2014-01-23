(function() {
  var NetworkConnectionMonitor,
      __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  /*
    States currently tracked:
    - connecting
    - unavailable

    See http://pusher.com/docs/client_api_guide/client_connect
    for all documented connection events.

    State transition history is retained for the last 5 minutes.
    History is swept every minute, events older than 5 minutes are deleted.
  */
  NetworkConnectionMonitor = (function(_super) {
    __extends(NetworkConnectionMonitor, _super);

    function NetworkConnectionMonitor(options) {
      NetworkConnectionMonitor.__super__.constructor.apply(this, [options]);

      _.bindAll(this, 'sweep', 'updateNetworkStats', 'ping');

      this.updateFrequency = this.oneMinute / 3;
      this.pingFrequency   = this.oneMinute / 2;
      this.sweepFrequency  = this.oneMinute;

      this.times = {
        all: {},
        failed: {}
      };

      this.thresholds = {
        warning: [
          {time: 100, count: 1, period: this.oneMinute},
          {time: 100, count: 3, period: this.fiveMinutes},
          {time: 30000, count: 1, period: this.oneMinute},
          {average: 150, period: this.oneMinute},
          {failedCount: 1, period: this.oneMinute}
        ],
        danger: [
          {time: 175, count: 3, period: this.oneMinute},
          {time: 225, count: 6, period: this.fiveMinutes},
          {time: 30000, count: 1, period: this.oneMinute},
          {average: 200, period: this.oneMinute},
          {failedCount: 2, period: this.oneMinute}
        ]
      };

      _.delay(this.ping, this.pingFrequency);

      return this;
    };

    NetworkConnectionMonitor.prototype.ping = function() {
      var self = this,
          startTime = this.time();
      var jqxhr = $.get('/pong', function(){
        // success
      }).fail(function(){
        self.addTime(self.times.failed, startTime);
      }).always(function() {
        self.addTime(self.times.all, startTime);
        _.delay(self.ping, self.pingFrequency);
      });
    };

    NetworkConnectionMonitor.prototype.addTime = function(times, startTime){
      NetworkConnectionMonitor.__super__.addTime.apply(this, arguments);

      this.updateNetworkStats();
    };

    NetworkConnectionMonitor.prototype.updateNetworkStats = function() {
      this.updateStats({
        networkConnectionStats: {
          all: this.times.all,
          failed: this.times.failed
        }
      });

      return this;
    };

    NetworkConnectionMonitor.prototype.thresholdReached = function(arr){
      var self = this,
          pongs = [];

      _.each(arr, function(threshold){
        var fails   = false,
            all     = self.forPeriod(self.times.all, threshold.period),
            failed  = self.forPeriod(self.times.failed, threshold.period),
            pings   = {
              all: all,
              failed: failed
            };

        if( threshold.failedCount !== undefined ){
          fails = pings.failed.length >= threshold.failedCount;
        } else if( threshold.time !== undefined ){
          var longPingTimes = _.filter(pings.all, function(pingTime){
            return pingTime >= threshold.time;
          });

          fails = longPingTimes.length >= threshold.count;
        } else if( threshold.average !== undefined ){
          var total = _.reduce(pings.all, function(m,n){return m+n;}, 0);

          fails = (total / pings.all.length) >= threshold.average;
        }

        pongs.push(fails);
      });

      var failed = _.detect(pongs, function(pong){return pong;});
      return failed === true;
    };

    return NetworkConnectionMonitor;

  })(ImpactDialing.Utilities.PeriodStats);

  window.ImpactDialing.Services.NetworkConnectionMonitor = NetworkConnectionMonitor;

}).call(this);
