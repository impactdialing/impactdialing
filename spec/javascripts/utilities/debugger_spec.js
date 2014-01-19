describe('ImpactDialing.Utilities.Debugger', function(){
  beforeEach(function(){
    this.afterDataAddSpy = jasmine.createSpy('afterDataAddSpy');
    this.opts = {
      afterDataAdd: this.afterDataAddSpy
    }
    this.debug = new ImpactDialing.Utilities.Debugger(this.opts);
  });
  describe('var debug = new ImpactDialing.Utilities.Debugger(options)', function(){
    it('sets debug.opts to options', function(){
      expect(this.debug.opts).toEqual(this.opts);
    });

    it('sets debug.debugData to {}', function(){
      expect(this.debug.debugData).toEqual({});
    });
  });
  describe('debug.addData(data)', function(){
    beforeEach(function(){
      this.expected = {
        neat: 'stuff'
      };
      this.debug.addData(this.expected);
    })
    it('extends debug.debugData with data', function(){
      expect(this.debug.debugData).toEqual(this.expected);
    });

    it('calls debug.opts.afterDataAdd passing data when debug.opts.afterDataAdd is a function', function(){
      expect(this.afterDataAddSpy).toHaveBeenCalledWith(this.expected);
    });
  });
});