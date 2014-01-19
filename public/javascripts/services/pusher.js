(function() {
  var PusherService;

  PusherService = (function() {
    function PusherService(opts) {
      this.opts = opts || {};

      this
      .connect(opts.service, opts.serviceKey)
      .subscribe(opts.channel)
      .monitor(opts.connectionMonitor);

      return this;
    };

    PusherService.prototype.connect = function(service, pusherKey) {
      this.pusher = new service(pusherKey);

      return this;
    };

    PusherService.prototype.subscribe = function(channel) {
      ImpactDialing.Channel = this.pusher.subscribe(channel);
      ImpactDialing.Events.trigger('channel.subscribed', ImpactDialing.Channel);

      return this;
    };

    PusherService.prototype.monitor = function(connectionMonitor) {
      new connectionMonitor(this.pusher.connection, {
        afterStatsUpdate: this.opts.monitorAfterStatsUpdate
      });

      return this;
    };

    return PusherService;
  })();

  window.ImpactDialing.Services.Pusher = PusherService;

}).call(this);
