(function() {
  var Debugger;

  Debugger = (function() {
    function Debugger(options) {
      _.bindAll(this, 'addData');

      this.opts      = options || {};
      this.debugData = {};
    };

    Debugger.prototype.addData = function(data) {
      _.extend(this.debugData, data);

      if( _.isFunction(this.opts.afterDataAdd) ){
        this.opts.afterDataAdd(this.debugData);
      }

      return this;
    };

    return Debugger;

  })();

  window.ImpactDialing.Utilities.Debugger = Debugger;

}).call(this);
