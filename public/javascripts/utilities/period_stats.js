(function() {
  var PeriodStats;

  /*
    Stats are swept every minute and any older than this.isOldThreshold (6 minutes by default) are removed.
  */
  PeriodStats = (function() {
    function PeriodStats(options) {
      _.bindAll(this, 'sweep');

      this.oneMinute      = 60000;
      this.fiveMinutes    = this.oneMinute * 5;
      this.isOldThreshold = this.fiveMinutes + this.oneMinute;
      this.sweepFrequency = this.oneMinute;
      this.stats          = {};
      this.times          = {};
      this.events         = {};
      this.errors         = {};

      this.opts           = options || {};

      _.delay(this.sweep, this.isOldThreshold);
    };

    PeriodStats.prototype.time = function(dateObj) {
      dateObj = dateObj || new Date();
      return dateObj.getTime();
    };

    PeriodStats.prototype.addTime = function(times, startTime) {
      var endTime = this.time(),
          diff    = endTime - startTime;
      times[startTime.toString()] = diff;

      return this;
    };

    PeriodStats.prototype.addEvent = function(eventName) {
      var t = this.time();

      if( this.events[eventName] === undefined || this.events[eventName] === null ){
        this.events[eventName] = [];
      }

      this.events[eventName].push(t);
    };

    PeriodStats.prototype.addError = function(error) {
      var t = this.time();

      this.errors[t] = error;
    };

    PeriodStats.prototype.sweep = function() {
      var self = this;

      var deleteOldTimes = function(items) {
        var isOld = function(v, timestamp) {
          var curTime = self.time(),
              timeSinceCount = curTime - parseInt(timestamp);
          return timeSinceCount > self.isOldThreshold;
        }

        var deleteOld = function(v, timestamp) {
          if( isOld(v, timestamp) ) {
            delete(items[timestamp]);
          }
        }

        _.each(items, deleteOld);
      };

      _.each(this.times, deleteOldTimes);

      _.delay(this.sweep, this.sweepFrequency);
      return this;
    };

    PeriodStats.prototype.updateStats = function(data) {
      _.extend(this.stats, data);

      if( _.isFunction(this.opts.afterStatsUpdate) ){
        this.opts.afterStatsUpdate(this.stats);
      }

      return this;
    };

    // Retrieve event counts from last period milliseconds
    PeriodStats.prototype.forPeriod = function(times, period){
      var self = this;

      var periodFilter = function(v, k){
        var i = parseInt(k),
            t = self.time(),
            r = i >= (t - period);
        return r;
      };
      var r = _.select(times, periodFilter);
      return r;
    };

    return PeriodStats;
  })();

  window.ImpactDialing.Utilities.PeriodStats = PeriodStats;

}).call(this);
