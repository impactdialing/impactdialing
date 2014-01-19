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
      this.opts           = options || {};
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

    PeriodStats.prototype.sweep = function() {
      var self = this;

      var deleteOldTimes = function(times) {
        var isOld = function(v, k) {
          var curTime = self.time(),
              timeSinceCount = curTime - parseInt(k);
          return timeSinceCount > self.isOldThreshold;
        }

        var deleteOld = function(v, k) {
          if( isOld(v, k) ) {
            delete(times[k]);
          }
        }

        _.each(times, deleteOld);
      };
      _.each(this.times, deleteOldTimes);
      _.delay(this.sweep, this.sweepFrequency);

      return this;
    };

    PeriodStats.prototype.setClass = function(selector, cssClass){
      $(selector).removeClass([this.css.good, this.css.warning, this.css.danger].join(' '));
      $(selector).addClass(cssClass);

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
