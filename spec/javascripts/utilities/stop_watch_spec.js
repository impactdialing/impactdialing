describe('ImpactDialing.Utilities.StopWatch', function(){
  var subject = function(timeoutSpy, timeout) {
    return new ImpactDialing.Utilities.StopWatch({
      timeoutCallback:timeoutSpy,
      timeout:timeout,
    });
  };

  beforeEach(function() {
    jasmine.clock().install();
    this.timeoutSpy = jasmine.createSpy('timeoutSpy');
  });

  afterEach(function() {
    jasmine.clock().uninstall();
  });

  describe('initialization', function(){
    it('calls timeoutCallback after timeout ms', function(){
      subject(this.timeoutSpy, 100);
      jasmine.clock().tick(101);
      expect(this.timeoutSpy).toHaveBeenCalled();
    });
  });

  describe('restart', function(){
    it('resets the interval', function() {
      var stopWatch = subject(this.timeoutSpy, 100);
      jasmine.clock().tick(95);
      stopWatch.restart();
      jasmine.clock().tick(110);
      expect(this.timeoutSpy.calls.count()).toEqual(1);
    });
  });
});
