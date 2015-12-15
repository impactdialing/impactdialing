;(function(){
  var StopWatch;
  var _setInterval = function(context) {
    context.intervalID = setInterval(context.opts.timeoutCallback, context.opts.timeout);
  };

  StopWatch = (function() {
    // constructor
    function StopWatch(options) {
      this.opts = options || {};
      _setInterval(this);
    };

    StopWatch.prototype.restart=function() {
      clearInterval(this.intervalID);
      _setInterval(this);
    };
    return StopWatch;
  })();
  window.ImpactDialing.Utilities.StopWatch = StopWatch;
}).call(this);
