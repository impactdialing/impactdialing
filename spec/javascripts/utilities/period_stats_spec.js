describe('ImpactDialing.Utilities.PeriodStats', function(){
  beforeEach(function(){
    this.oneMinute = 60000;
    this.fiveMinutes = this.oneMinute * 5;

    this.afterStatsUpdateSpy = jasmine.createSpy('after period stats update spy');
    this.periodStats = new ImpactDialing.Utilities.PeriodStats({
      afterStatsUpdate: this.afterStatsUpdateSpy
    });
  });
  describe('var periodStats = new PeriodStats({afterStatsUpdate: Function(data)})', function(){
    it('sets a oneMinute property to 60000 (ms)', function(){
      expect(this.periodStats.oneMinute).toEqual(this.oneMinute);
    });

    it('sets a fiveMinutes property to this.oneMinute * 5', function(){
      expect(this.periodStats.fiveMinutes).toEqual(this.fiveMinutes);
    });

    it('sets a isOldThreshold property to this.fiveMinutes + this.oneMinute', function(){
      expect(this.periodStats.isOldThreshold).toEqual(this.fiveMinutes + this.oneMinute);
    });

    it('sets a sweepFrequency property to this.oneMinute', function(){
      expect(this.periodStats.sweepFrequency).toEqual(this.oneMinute);
    });
  });

  describe('periodStats.time(dateObj=new Date())', function(){
    it('returns the current timestamp', function(){
      var dateObj = new Date(),
          actual = this.periodStats.time(dateObj),
          expected = dateObj.getTime();
      expect(actual).toEqual(expected);
    });

    it('defaults dateObj to new Date()', function(){
      actual = new Date(this.periodStats.time()),
      expected = new Date(),
      parts = ['getDate', 'getMonth', 'getFullYear', 'getHours', 'getMinutes'];

      _.each(parts, function(method){
        expect(actual[method]()).toEqual(expected[method]());
      });
    });
  });

  describe('periodStats.addTime(times, startTime) where `times` is an object ' +
           'that will have a key of the startTime (timestamp) as String and ' +
           'the difference of the current time to startTime as the value', function(){
    it('adds a key of the startTime as String', function(){
      var times = {},
          startTime = new Date().getTime() - this.fiveMinutes,
          actual = this.periodStats.addTime(times, startTime),
          expectedKey = startTime.toString(),
          expectedValue = this.fiveMinutes;
      expect(times[expectedKey]).toEqual(expectedValue);
    });
  });

  describe('periodStats.addError(error) where `error` can be anything', function(){
    it('updates periodStats.errors object with a timestamp as key and the error as value', function(){
      var expectedError = {code: 400, message: 'Not authorized'};

      this.periodStats.addError(expectedError);

      var errorKeys = _.keys(this.periodStats.errors),
          actual = this.periodStats.errors[errorKeys[0]];

      // sanity check
      expect(errorKeys.length).toEqual(1);
      console.log('actual = ', actual, 'expected = ', expectedError);
      expect(actual).toEqual(expectedError);
    });
  });

  describe('periodStats.addEvent(event) where `event` is a String and a valid object key', function(){
    it('updates periodStats.events object with a event as key and array of timestamps as value', function(){
      var expectedEvent = 'retried',
          expectedTime = new Date().getTime();

      this.periodStats.addEvent('retried');

      var actual = this.periodStats.events.retried;

      expect(actual).toEqual([expectedTime]);
    })
  });

  describe('periodStats.sweep()', function(){
    it('iterates over periodStats[periodStats.statsKeys] and deletes entries with timestamp keys older than periodStats.isOldThreshold (five minutes by default)', function(){
      var tenMinutesAgo = new Date().getTime() - (this.fiveMinutes * 2),
          times = {
            test: {}
          },
          expected = {
            test: {}
          };
      times.test[tenMinutesAgo.toString()] = 23;
      times.test[(tenMinutesAgo - 10).toString()] = 32;
      times.test[(tenMinutesAgo - 20).toString()] = 23;

      var expectedKey = (tenMinutesAgo + (this.oneMinute * 7)).toString(),
          expectedValue = 42;

      times.test[expectedKey] = expectedValue;
      expected.test[expectedKey] = expectedValue;

      this.periodStats.statsKeys = ['times'];
      this.periodStats.times = times;
      this.periodStats.sweep();

      expect(this.periodStats.times).toEqual(expected);
    });
  });

  describe('periodStats.updateStats(data)', function(){
    beforeEach(function(){
      this.box = {
        creative: 'words'
      };
      this.periodStats.updateStats(this.box);
    });
    it('extends periodStats.stats with data', function(){
      expect(this.periodStats.stats).toEqual(this.box);

      var bin = {
        hardly: 'shakespeare'
      };
      this.periodStats.updateStats(bin);

      expect(this.periodStats.stats).toEqual(_.extend(this.box, bin));
    });
    it('calls periodStats.opts.afterStatsUpdate with periodStats.stats if it is a function', function(){
      expect(this.afterStatsUpdateSpy).toHaveBeenCalledWith(this.periodStats.stats);
    });
    it('most definitely passes periodStats.stats to the afterStatsUpdate function and NOT the data obj [regression]', function(){
      var s = jasmine.createSpy('afterStatsUpdate argument regression protection'),
          natural = {
            food: 'is good'
          },
          aggT = {
            leaving: 'on a jet plane'
          },
          pS = new ImpactDialing.Utilities.PeriodStats({
            afterStatsUpdate: s
          }),
          expected = {};
      _.extend(expected, natural, aggT);

      _.extend(pS.stats, aggT);
      pS.updateStats(natural);

      expect(s).toHaveBeenCalledWith(expected);
    });
  });

  describe('periodStats.forPeriod(times, period', function(){
    beforeEach(function(){
      this.timeAgo = function(timeAgo){
        var t = new Date().getTime();
        return (t - timeAgo).toString();
      }
      var times = {};
      this.agos = {
        oneMinute: this.timeAgo(this.oneMinute+20),
        twoMinutes: this.timeAgo((this.oneMinute*2)-20),
        thirtySeconds: this.timeAgo(this.oneMinute*0.5),
        fiveMinutes: this.timeAgo(this.fiveMinutes-20),
        sevenThirty: this.timeAgo(this.fiveMinutes*1.5)
      };
      _.each(this.agos, function(ago, k){
        times[ago] = k;
      });
      this.times = times;
    });

    it('returns a selection of properties from the last period of time (in ms)', function(){
      var actuals = [
        this.periodStats.forPeriod(this.times, this.oneMinute),
        this.periodStats.forPeriod(this.times, this.oneMinute*2),
        this.periodStats.forPeriod(this.times, this.fiveMinutes),
        this.periodStats.forPeriod(this.times, this.fiveMinutes*2)
      ];
      var A = [
            this.times[this.agos.thirtySeconds]
          ],
          B = [
            A[0],
            this.times[this.agos.oneMinute],
            this.times[this.agos.twoMinutes]
          ],
          C = [
            B[0],
            B[1],
            B[2],
            this.times[this.agos.fiveMinutes]
          ],
          D = [
            C[0],
            C[1],
            C[2],
            C[3],
            this.times[this.agos.sevenThirty]
          ],
          expecteds = [A, B, C, D];

      _.each(actuals, function(actual, i){
        expect(actual.sort()).toEqual(expecteds[i].sort());
      });
    });
  });
});