Twilio = (function(loadedTwilio){
    var VERSION = "5c1f1e8";
    var CommandQueue = (function() {
        function CommandQueue(cmdList, object) {
            cmdList = cmdList || [];
            this.object = object || null;
            this.queue = [];
            for (var i = 0; i < cmdList.length; i++) {
                this.addCommand(cmdList[i]);
            }
        }
        CommandQueue.prototype.run = function(object) {
            for (var i = 0; i < this.queue.length; i++) {
                var command = this.queue[i];
                var result = object[command.name].apply(object, command.args);
                if (command.proxy) command.proxy.run(result);
            }
            this.object = object;
            this.queue = [];
        };
        CommandQueue.prototype.addCommand = function(name, proxyFactory) {
            var self = this;
            this[name] = function() {
                if (self.object) {
                    return self.object[name].apply(self.object, arguments);
                }
                var proxy = proxyFactory ? proxyFactory() : null;
                self.queue.push({ name: name, args: arguments, proxy: proxy });
                return proxy;
            };
        };
        return CommandQueue;
    })();
    var deviceCmdQ = new CommandQueue([
        "setup", "disconnectAll", "disconnect", "presence", "status", "ready",
        "error", "offline", "incoming", "destroy", "cancel",
        "showPermissionsDialog"]);
    deviceCmdQ.addCommand("status", function() { return "offline"; });
    deviceCmdQ.addCommand("connect", function() {
        var connectionCmdQ = new CommandQueue([
            "accept", "disconnect", "error", "mute", "unmute", "sendDigits"]);
        connectionCmdQ.addCommand("status", function() { return "pending" });
        return connectionCmdQ;
    });
    var eventStreamCmdQ = new CommandQueue([
        "setup", "incoming", "ready", "offline", "sms", "call", "twiml",
        "error"]);
    var url = (function(){
        var dummy = document.createElement("a");
        var scripts = document.getElementsByTagName("script");
        for (var i = 0; i < scripts.length; i++) {
            var script = scripts[i];
            dummy.href = script.src;
            if (/(twilio\.js)|(twilio\.min\.js)$/.test(dummy.pathname)) {
                return {
                    host: dummy.host,
                    minified: /\.min\.js$/.test(dummy.pathname)
                };
            }
        }
    })();
    var basename = url.minified ? "/twilio.min.js" : "/twilio.js";
    var ref = document.getElementsByTagName("script")[0];
    var el = document.createElement("script");
    el.type = "text/javascript";
    el.src = "//" + url.host + "/twiliojs/refs/" + VERSION + basename;
    el.onload = el.onreadystatechange = function() {
        if (!el.readyState || el.readyState == "loaded") {
            deviceCmdQ.run(Twilio.Device);
            eventStreamCmdQ.run(Twilio.EventStream);
        }
    };
    ref.parentNode.insertBefore(el, ref);
    var Object_create = typeof Object.create === 'function'
        ? function(prototype) { return Object.create(prototype); }
        : function(prototype) {
            function C(){}
            C.prototype = prototype;
            return new C();
        };
    var Twilio = loadedTwilio || function Twilio() { };
    Twilio.Device = deviceCmdQ;
    Twilio.EventStream = eventStreamCmdQ;
    return Twilio;
})(typeof Twilio !== 'undefined' ? Twilio : null);
