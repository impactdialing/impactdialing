(function() {
  var PusherService;

  PusherService = (function() {
    function PusherService(pusherKey, channel) {
      console.log('PusherService.initialize', pusherKey, channel);
      this.connect(pusherKey);
      this.subscribe(channel);
      this.monitorConnection();
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

    PusherService.prototype.monitorConnection = function() {
      /*
        States not currently monitored:
        - connecting_in
        - disconnected

        See http://pusher.com/docs/client_api_guide/client_connect
        for all documented connection events.
      */
      this.pusher.connection.bind('connecting', function(){
        var msg = 'Connection lost. Attempting to re-connect...';
        $('#error-info').text(msg);
        $('#error-info-container').show();
        console.log(msg);
      });

      this.pusher.connection.bind('connected', function(){
        var msg = 'Connection established.';
        var hide = function() {
          $('#error-info-container').hide();
          $('#error-info').text('');
        };
        $('#error-info').text(msg);
        $('#error-info-container').show();
        _.delay(hide, 15);
        console.log(msg);
      });

      this.pusher.connection.bind('unavailable', function(){
        var msg = 'Connection lost. Attempting to re-connect. Please verify your connection to the internet.';
        $('#error-info').text(msg);
        console.log(msg);
      });

      this.pusher.connection.bind('failed', function(){
        var msg = 'Your browser is not supported.';
        $('#error-info').text(msg);
        console.log(msg);
      });
    };

    return PusherService;

  })();

  window.ImpactDialing.Services.Pusher = PusherService;

}).call(this);
