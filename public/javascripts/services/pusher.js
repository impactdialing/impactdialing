(function() {
  var PusherService;

  PusherService = (function() {
    function PusherService(pusherKey, channel) {
      console.log('PusherService.initialize', pusherKey, channel);
      this.connect(pusherKey);
      this.subscribe(channel);
      return this;
    };

    PusherService.prototype.connect = function(pusherKey) {
      console.log('PusherService.connect', pusherKey);

      this.pusher = new Pusher(pusherKey);
    };

    PusherService.prototype.subscribe = function(channel) {
      console.log('PusherService.subscribe', channel);
      ImpactDialing.Channel = this.pusher.subscribe(channel);
      ImpactDialing.Events.trigger('channel.subscribed', ImpactDialing.Channel);
    };

    return PusherService;

  })();

  window.ImpactDialing.Services.Pusher = PusherService;

}).call(this);

// _.extend(window.ImpactDialing.Services.Pusher, Backbone.Events);
