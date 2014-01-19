describe('ImpactDialing.Services.PusherService', function(){
  beforeEach(function(){
    var fakePusher, fakeMonitor;

    (function(self){
      var fakePusher;

      fakePusher = (function() {
        function fakePusher(){};
        return fakePusher;
      });

      self.fakePusher = fakePusher;
    })(this);

    (function(self){
      var fakeMonitor;

      fakeMonitor = (function() {
        function fakeMonitor(){};
        return fakeMonitor;
      });

      self.fakeMonitor = fakeMonitor;
    })(this);

    this.pusherDouble = jasmine.createSpyObj('pusher instance', ['subscribe', 'connection']);
    this.monitorDouble = jasmine.createSpy('monitor instance');
    this.pusherSpy = spyOn(this, 'fakePusher').andReturn(this.pusherDouble);
    this.monitorSpy = spyOn(this, 'fakeMonitor').andReturn(this.monitorDouble);
    this.afterStatsUpdateSpy = jasmine.createSpy('monitor after stats update spy');

    this.pusherKey = 'pusher-key';
    this.channel = 'subscription-channel';

    this.validOpts = {
      service: this.fakePusher,
      serviceKey: this.pusherKey,
      connectionMonitor: this.fakeMonitor,
      channel: this.channel,
      monitorAfterStatsUpdate: this.afterStatsUpdateSpy
    };
    this.pusherService = new ImpactDialing.Services.Pusher(this.validOpts);
  });

  describe('var pusher = new ImpactDialing.Services.Pusher(opts)', function(){
    describe('options obj arg: {service: pusherClass, pusherKey: "asdf", channel: "fdsa", connectionMonitor: monitorClass}', function(){
      it('instantiates options.service passing options.serviceKey', function(){
        expect(this.pusherSpy).toHaveBeenCalledWith(this.pusherKey);
      });

      it('subscribes the new options.service instance to the subscription channel', function(){
        expect(this.pusherDouble.subscribe).toHaveBeenCalledWith(this.channel);
      });

      it('instantiates options.connectionMonitor passing the new options.service instance.connection', function(){
        expect(this.fakeMonitor).toHaveBeenCalledWith(this.pusherDouble.connection, {
          afterStatsUpdate: this.afterStatsUpdateSpy
        });
      });
    });
  });

  describe('prototype.subscribe(channel)', function(){
    it('sets ImpactDialing.Channel to the subscription returned from subscribing the options.service instance to channel', function(){
      expect(ImpactDialing.Channel).toEqual(this.pusherDouble.subscribe(this.channel));
    });

    it('triggers the channel.subscribed event on ImpactDialing.Events', function(){
      var cb = jasmine.createSpy('channel.subscribed callback');
      ImpactDialing.Events.on('channel.subscribed', cb);

      this.pusherService.subscribe(this.channel);

      expect(cb).toHaveBeenCalledWith(ImpactDialing.Channel);
    });
  });
});