(function() {
  var TwilioService;

  TwilioService = (function() {
    function TwilioService(opts) {
      var isPresent = function(a){ return a !== undefined && a !== null; };
      if( !isPresent(opts) ||
          !isPresent(opts.service) ||
          !isPresent(opts.connectionMonitor) ||
          !isPresent(opts.token) ){
        return this;
      }

      this.opts = opts || {};

      this
      .connect(opts.service, opts.token)
      .monitor(opts.connectionMonitor);

      return this;
    };

    TwilioService.prototype.connect = function(service, token) {
      console.log('TwilioService.connect', service, token);
      this.device = service.setup(token, {
        'debug':true
      });

      return this;
    };

    TwilioService.prototype.monitor = function(connectionMonitor) {
      new connectionMonitor(this.device, {
        afterStatsUpdate: this.opts.monitorAfterStatsUpdate,
        service: this.opts.service
      });

      return this;
    };

    return TwilioService;
  })();

  window.ImpactDialing.Services.Twilio = TwilioService;

}).call(this);
