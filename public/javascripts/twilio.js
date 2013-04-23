Twilio = { extend: function(M) { for (var k in M) Twilio[k] = M[k] } };
Twilio.extend((function(){
    var VERSION = '1.1';
    var files = {}, cache = {};
    var require = (function(){
        function require(module) {
            if (!(module in cache)) {
                var path = "lib/" + module + ".js", exports = {};
                files[path].apply(exports, [require, exports]);
                cache[module] = exports;
            }
            return cache[module];
        };
        return require;
    })();
    files["lib/twilio/connection.js"] = (function(require, exports){ var factories = require("twilio/factories");
var eventEmitter = require("twilio/eventemitter");
var log = require("twilio/log");
var util = require("twilio/util");
var rtc = require("twilio/rtc");

/**
 * Constructor for Connections.
 *
 * @exports Connection as Twilio.Connection
 * @memberOf Twilio
 * @borrows EventEmitter#addListener as #addListener
 * @borrows EventEmitter#fire as #fire
 * @borrows EventEmitter#removeListener as #removeListener
 * @borrows EventEmitter#hasListener as #hasListener
 * @borrows Twilio.mixinLog-log as #log
 * @constructor
 * @param {object} device The device associated with this connection
 * @param {object} message Data to send over the connection
 * @param {object} [options]
 * @config {string} [bridgeToken] Used to bridge a connection
 * @config {string} [chunder="chunder.prod.twilio.com"] Hostname of chunder server
 * @config {boolean} [debug=false] Enable debugging
 * @config {boolean} [encrypt=false] Encrypt media
 * @config {MediaStream} [mediaStream] Use this MediaStream object
 * @config {string} [token] The Twilio capabilities JWT
 */
function Connection(device, message, options) {
    if (!(this instanceof Connection)) {
        return new Connection(message, options);
    }
    this.device = device;
    this.message = message || {};

    options = options || {};
    var defaults = {
        logPrefix: "[Connection]",
        bridgeToken: null,
        mediaStreamFactory: rtc.enabled() ? factories.PeerConnection
                                          : factories.MediaStream,
        chunder: "chunder.prod.twilio.com",
        chunderw: "chunderw.prod.twilio.com",
        debug: false,
        encrypt: false,
        token: null
    };
    for (var prop in defaults) {
        if (prop in options) continue;
        options[prop] = defaults[prop];
    }

    this.options = options;
    this.parameters = {};
    // Bridgetoken means it's an incoming connection
    this._status = this.options["bridgeToken"] ? "pending" : "closed";

    log.mixinLog(this, this.options["logPrefix"]);
    this.log.enabled = this.options["debug"];

    eventEmitter.mixinEventEmitter(this);

    /**
     * Reference to the Twilio.MediaStream object.
     * @type Twilio.MediaStream
     */
    this.mediaStream = this.options["mediaStreamFactory"](
        this.options["encrypt"],
        this.options[rtc.enabled() ? "chunderw" : "chunder"],
        this.device.options["simpleDialog"]
        );

    var self = this;

    this.mediaStream.onerror = function(e) {
        var error = {
            code: e.info.code,
            message: e.info.message,
            info: e.info
        };
        self.log("Received an error from MediaStream:", e);
        self.fire("error", error);
    };

    this.mediaStream.onopen = function() {
        self._status = "open";
        self.mediaStream.publish("input", "live");
        self.mediaStream.attachAudio();
        self.mediaStream.play("output");
        self.fire("accept", self);
    };

    this.mediaStream.onclose = function() {
        self._status = "closed";
        if (self.device.sounds.disconnect()) {
            self.device.soundcache.play("disconnect");
        }
        self.fire("disconnect", self);
    };
}

/**
 * @return {string}
 */
Connection.toString = function() {
    return "[Twilio.Connection class]";
};

Connection.prototype = {
    /**
     * @return {string}
     */
    toString: function() {
        return "[Twilio.Connection instance]";
    },
    sendDigits: function(digits) {
        if (digits.match(/[^0-9*#w]/)) {
            throw new util.Exception(
                "Illegal character passed into sendDigits");
        }
        this.mediaStream.exec("sendDTMF", digits);
        var sequence = [];
        for(var i = 0; i < digits.length; i++) {
            var dtmf = digits[i] != "w" ? "dtmf" + digits[i] : "";
            if (dtmf == "dtmf*") dtmf = "dtmfs";
            if (dtmf == "dtmf#") dtmf = "dtmfh";
            sequence.push([dtmf, 200, 20]);
        }
        this.device.soundcache.playseq(sequence);
    },
    status: function() {
        return this._status;
    },
    /**
     * Mute incoming audio.
     */
    mute: function() {
        this.mediaStream.detachAudio();
    },
    /**
     * Unmute incoming audio.
     */
    unmute: function() {
        this.mediaStream.attachAudio();
    },
    accept: function(handler) {
        if (typeof handler == "function") {
            return this.addListener("accept", handler);
        }
        var self = this;
        var MediaStream = factories.getClass(
            "vendor/mediastream/mediastream", "MediaStream");
        this._status = "pending";
        var connect_ = function(err,code) {
            if (err) {
                self._die(err,code);
                return;
            }
            var pairs = [];
            for (var key in self.message) {
                pairs.push(key + "=" + encodeURIComponent(self.message[key]));
            }
            var params = [ self.mediaStream.uri()
                         , self.options["token"]
                         , self.options["bridgeToken"]
                         , pairs.join("&")
                         ].concat(self.options["acceptParams"]);
            self.mediaStream.open.apply(self.mediaStream, params);
        };
        this.mediaStream.openHelper(
            connect_,
            this.device.options["simpleDialog"],
            Connection.NO_MIC_LEVEL || 0,
            function() { Device.dialog.show() },
            function(x) { self.device.showSettings(x); }
            );
    },
    reject: function(handler) {
        if (typeof handler == "function") {
            return this.addListener("reject", handler);
        }
        var payload = {
            'Response': 'reject',
            'CallSid': this.parameters.CallSid
        }
        this.device.stream.publish(payload, this.options.rejectChannel);
        this.fire("reject");
    },
    ignore: function(handler) {
        if (typeof handler == "function") {
            return this.addListener("cancel", handler);
        }
        this._status = "closed";
        this.fire("cancel");
    },
    cancel: function(handler) {
        // Connection.cancel is deprecated, use Connection.ignore
        this.ignore(handler);
    },
    disconnect: function(handler) {
        if (typeof handler == "function") {
            return this.addListener("disconnect", handler);
        }
        if (this._status == "open") {
            this.log("Disconnecting...");
            this.mediaStream.close();
        }
    },
    error: function(handler) {
        if (typeof handler == "function") {
            return this.addListener("error", handler);
        }
    },
    _die: function(message,code) {
        this.fire("error", { message: message, code: code });
    }
};

exports.Connection = Connection; });
    files["lib/twilio/device.js"] = (function(require, exports){ var factories = require("twilio/factories");
var eventEmitter = require("twilio/eventemitter");
var log = require("twilio/log");
var util = require("twilio/util");

var Options = require("twilio/options").Options;
var Dialog = require("twilio/dialog").Dialog;

/**
 * Constructor for Device objects.
 *
 * @exports Device as Twilio.Device
 * @memberOf Twilio
 * @borrows EventEmitter#addListener as #addListener
 * @borrows EventEmitter#fire as #fire
 * @borrows EventEmitter#hasListener #hasListener
 * @borrows EventEmitter#removeListener as #removeListener
 * @borrows Twilio.mixinLog-log as #log
 * @constructor
 * @param {string} token The Twilio capabilities token
 * @param {object} [options]
 * @config {boolean} [debug=false]
 */
function Device(token, options) {
    if (!(this instanceof Device)) {
        return new Device(token, options);
    }
    if (!token) {
        throw new util.Exception("Capability token is not valid or missing.");
    }
    var defaults = {
        logPrefix: "[Device]",
        host: "chunder.twilio.com",
        chunderw: "chunderw.twilio.com",
        soundCacheFactory: factories.SoundCache,
        soundFactory: factories.Sound,
        connectionFactory: factories.Connection,
        eventStreamFactory: factories.EventStream,
        presenceFactory: factories.Presence,
        eventsScheme: "wss",
        eventsHost: "matrix.twilio.com",
        noRegister: false,
        encrypt: false,
        simpleDialog: false,
        rtc: true,
        debug: false,
        confirmOnClose: false
    };
    options = options || {};
    for (var prop in defaults) {
        if (prop in options) continue;
        options[prop] = defaults[prop];
    }
    this.options = options;
    this.token = token;
    this._status = "offline";
    this.connections = [];
    this.sounds = new Options({
        incoming: true,
        outgoing: true,
        disconnect: true
    });

    if (!this.options["rtc"]) {
        require("twilio/rtc").enabled(false);
    }

    this.soundcache = this.options["soundCacheFactory"]();
    var urls =  {
        incoming: "sounds/incoming.mp3", outgoing: "sounds/outgoing.mp3",
        disconnect: "sounds/disconnect.mp3",
        dtmf1: "sounds/dtmf-1.mp3", dtmf2: "sounds/dtmf-2.mp3",
        dtmf3: "sounds/dtmf-3.mp3", dtmf4: "sounds/dtmf-4.mp3",
        dtmf5: "sounds/dtmf-5.mp3", dtmf6: "sounds/dtmf-6.mp3",
        dtmf7: "sounds/dtmf-7.mp3", dtmf8: "sounds/dtmf-8.mp3",
        dtmf9: "sounds/dtmf-9.mp3", dtmf0: "sounds/dtmf-0.mp3",
        dtmfs: "sounds/dtmf-star.mp3", dtmfh: "sounds/dtmf-hash.mp3"
    };
    var base = typeof TWILIO_ROOT === "undefined" ? "" : TWILIO_ROOT;
    for (var name in urls) {
        var sound = this.options["soundFactory"]();
        sound.load(base + urls[name]);
        this.soundcache.add(name, sound);
    }

    // Minimum duration for incoming ring
    this.soundcache.envelope("incoming", { release: 2000 });

    log.mixinLog(this, this.options["logPrefix"]);
    this.log.enabled = this.options["debug"];

    eventEmitter.mixinEventEmitter(this);

    var device = this;
    this.addListener("incoming", function(connection) {
        connection.addListener("accept", function() {
            device.soundcache.stop("incoming");
        });
        connection.addListener("cancel", function() {
            device.soundcache.stop("incoming");
        });
        connection.addListener("error", function() {
            device.soundcache.stop("incoming");
        });
        if (device.sounds.incoming()) {
            device.soundcache.play("incoming", 0, 1000);
        }
    });
    this.register(this.token);

    if (this.options["confirmOnClose"]) {
        var confirmClose = function(event) {
            var confirmationMsg;
            if (device._status == "busy") {
                confirmationMsg = "A call is currently active.";
                (event || window.event).returnValue = confirmationMsg;
                return confirmationMsg;
            }
        };
        if (window.addEventListener) {
            window.addEventListener("beforeunload", confirmClose);
        } else if (window.attachEvent) {
            window.attachEvent("onbeforeunload", confirmClose);
        }
    }
}

function makeConnection(device, token, tokenType, params, options) {
    var defaults = {
        acceptParams: [ JSON.stringify(util.getSystemInfo())
                      , util.objectize(device.token).iss
                      ],
        chunder: device.options["host"],
        chunderw: device.options["chunderw"],
        encrypt: device.options["encrypt"],
        debug: device.options["debug"]
    };

    options = options || {};
    for (var prop in defaults) {
        if (prop in options) continue;
        options[prop] = defaults[prop];
    }

    // TODO Wrap tokens in explicit classes Twilio.JWT and Twilio.BridgeToken
    if (tokenType == "bridge") {
        options["bridgeToken"] = token;
        options["token"] = null;
    } else if (tokenType == "jwt") {
        options["bridgeToken"] = null;
        options["token"] = token;
    } else {
        this.log("Unknown token type: " + tokenType);
    }

    var connection = device.options["connectionFactory"](device, params, options);

    connection.addListener("accept", function() {
        device._status = "busy";
        device.fire("connect", connection);
    });
    connection.addListener("error", function(error) {
        device.fire("error", error);
        // Only drop connection from device if it's pending
        if (connection.status() != "pending") return;
        var connections = [].concat(device.connections);
        for (var i = 0; i < connections.length; i++) {
            if (connection == connections[i]) {
                device.connections.splice(i, 1);
            }
        }
    });
    connection.addListener("cancel", function() {
        device.log("Canceled: " + connection.parameters["CallSid"]);
        var connections = [].concat(device.connections);
        for (var i = 0; i < connections.length; i++) {
            if (connection == connections[i]) {
                device.connections.splice(i, 1);
            }
        }
        device.fire("cancel", connection);
    })
    connection.addListener("disconnect", function() {
        if (device._status == "busy") device._status = "ready";
        device.fire("disconnect", connection);
        // Clone device.connections so we can modify it while iterating
        // over its elements.
        var connections = [].concat(device.connections);
        for (var i = 0; i < connections.length; i++) {
            if (connection == connections[i]) {
                device.connections.splice(i, 1);
            }
        }
    });

    return connection;
}

function makeUrl(token, scheme, host, features) {
    features = features || [];
    var fparams = [];
    for (var i = 0; i < features.length; i++) {
        fparams.push("feature=" + features[i]);
    }
    var qparams = [ "AccessToken=" + token ].concat(fparams);
    return [
        scheme + "://" + host, "2012-02-09",
        util.objectize(token).iss,
        util.objectize(token).scope["client:incoming"].params.clientName
    ].join("/") + "?" + qparams.join("&");
}

/**
 * @return {string}
 */
Device.toString = function() {
    return "[Twilio.Device class]";
};

Device.prototype = {
    /**
     * @return {string}
     */
    toString: function() {
        return "[Twilio.Device instance]";
    },
    register: function(token) {
        var features = [];
        var url = null;
        if ("client:incoming" in util.objectize(token).scope) {
            features.push("incomingCalls");
            features.push("publishPresence");
            if (this.presenceClient && this.presenceClient.handlers.length > 0) {
                features.push("presenceEvents");
            }
            url = makeUrl(token,
                          this.options["eventsScheme"],
                          this.options["eventsHost"],
                          features);
        }
        var device = this;
        if (!url || this.options["noRegister"]) {
            if (this.stream) {
                this.stream.destroy();
                if (this.presenceClient) {
                    this.presenceClient.detach(this.stream);
                }
                this.stream = null;
            }
            this.log("Unable to receive incoming calls");
            if (device._status == "offline") device._status = "ready";
            setTimeout(function() { device.fire("ready", device); }, 0);
            return;
        }
        if (this.stream) {
            this.stream.options["url"] = url;
            this.stream.reconnect(token);
            return;
        }
        this.log("Registering to stream with url: " + url);
        var streamOptions = {
            logPrefix: "[Matrix]",
            debug: this.options["debug"],
            url: url
        };
        this.stream = this.options["eventStreamFactory"](token, streamOptions);
        this.stream.addListener("ready", function() {
            device.log("Stream is ready");
            if (device._status == "offline") device._status = "ready";
            device.fire("ready", device);
        });
        this.stream.addListener("offline", function() {
            device.log("Stream is offline");
            device._status = "offline";
            device.fire("offline", device);
        })
        this.stream.addListener("error", function(error) {
            device.log("Received error: ",error);
            device.fire("error", error);
        })
        this.stream.addListener("incoming", function(message) {
            device.log("Message incoming...", message);
            switch(message["Request"]) {
                case "invite":
                    if (device._status == "busy") {
                        device.log("Device busy; ignoring incoming invite");
                        return;
                    }
                    if (!message["Token"] || !message["CallSid"]) {
                        device.fire("error", { message: "Malformed invite" });
                        return;
                    }
                    var parameters = message["Parameters"] || {};
                    var opts = { rejectChannel: message["RejectChannel"] };
                    var connection = makeConnection(device,
                                                    message["Token"],
                                                    "bridge",
                                                    {},
                                                    opts);
                    connection.parameters = parameters;
                    device.connections.push(connection);
                    device.fire("incoming", connection);
                break;
                case "cancel":
                    // Clone device.connections so we can modify it while
                    // iterating over its elements.
                    var connections = [].concat(device.connections);
                    for (var i = 0; i < connections.length; i++) {
                        var conn = connections[i];
                        if (conn.parameters["CallSid"] == message["CallSid"]
                            && conn.status() == "pending") {
                            conn.cancel();
                        }
                    }
                break;
            }
        });
        var clientName = util.objectize(token).scope["client:incoming"].params.clientName;
        this.presenceClient = this.options["presenceFactory"](clientName,
                                                              this,
                                                              this.stream,
                                                              { autoStart: true});
    },
    presence: function(handler) {
        if (!("client:incoming" in util.objectize(this.token).scope)) return;
        this.presenceClient.handlers.push(handler);
        // re-register if the # of handlers went from 0->1
        if (this.token && this.presenceClient.handlers.length == 1) {
            this.register(this.token);
        }
    },
    showSettings: function(showCallback) {
        Device.dialog.show(showCallback);
        var MediaStream = factories.getClass(
            "vendor/mediastream/mediastream", "MediaStream");
        MediaStream.showSettings();

        // IE9: after showing and hiding the dialog once,
        // often we end up with a blank permissions dialog
        // the next time around. This makes it show back up
        Device.dialog.screen.style.width = "200%";
    },
    connect: function(params) {
        if (typeof params == "function") {
            return this.addListener("connect", params);
        }
        params = params || {};
        var connection = makeConnection(this, this.token, "jwt", params);
        this.connections.push(connection);
        if (this.sounds.outgoing()) {
            var self = this;
            connection.accept(function() {
                self.soundcache.play("outgoing");
            });
        }
        connection.accept();
        return connection;
    },
    disconnectAll: function(params) {
        if (typeof params == "function") {
            return this.addListener("disconnectAll", params);
        }
        // Create a copy of connections before iterating, because disconnect
        // will trigger callbacks which modify the connections list. At the end
        // of the iteration, this.connections should be an empty list.
        var connections = [].concat(this.connections);
        for (var i = 0; i < connections.length; i++) {
            connections[i].disconnect();
        }
        if (this.connections.length > 0) {
            this.log("Connections left pending: " + this.connections.length);
        }
    },
    destroy: function() {
        this.stream.destroy();
        if (this.swf && this.swf.disconnect) {
            this.swf.disconnect();
        }
    },
    disconnect: function(handler) {
        this.addListener("disconnect", handler);
    },
    incoming: function(handler) {
        this.addListener("incoming", handler);
    },
    offline: function(handler) {
        this.addListener("offline", handler);
    },
    ready: function(handler) {
        this.addListener("ready", handler);
    },
    error: function(handler) {
        this.addListener("error", handler);
    },
    status: function() {
        return this._status;
    }
};

function singletonwrapper(cls) {
    var afterSetup = [];
    var tasks = [];
    var queue = function(task) {
        if (cls.instance) return task();
        tasks.push(task);
    };
    var defaultErrorHandler = function(error) {
        var err_msg = (error.code ? error.code + ": " : "") + error.message;
        if (cls.instance) {
            cls.instance.log(err_msg);
        }
        throw new util.Exception(err_msg);
    };
    var members = /** @lends Twilio.Device */ {
        /**
         * Instance of Twilio.Device.
         *
         * @type Twilio.Device
         */
        instance: null,
        /**
         * @param {string} token
         * @param {object} [options]
         * @return {Twilio.Device}
         */
        setup: function(token, options) {
            if (cls.instance) {
                cls.instance.log(
                    "Found existing Device; using new token but ignoring options");
                cls.instance.token = token;
                cls.instance.register(token);
            } else {
                cls.instance = new Device(token, options);
                cls.sounds = cls.instance.sounds;
                for (var i = 0; i < tasks.length; i++) {
                    tasks[i]();
                }
                cls.error(defaultErrorHandler);
            }
            for (var i = 0; i < afterSetup.length; i++) {
                afterSetup[i](token, options);
            }
            afterSetup = [];
            return cls;
        },

        /**
         * Connects to Twilio.
         *
         * @param {object} parameters
         * @return {Twilio.Connection}
         */
        connect: function(parameters) {
            if (typeof parameters == "function") {
                queue(function() {
                    cls.instance.addListener("connect", parameters);
                });
                return;
            }
            if (!cls.instance) {
                throw new util.Exception("Run Twilio.Device.setup()");
            }
            if (cls.instance.connections.length > 0) {
                cls.instance.fire("error",
                    { message: "A connection is currently active" });
                return;
            }
            return cls.instance.connect(parameters);
        },

        /**
         * @return {Twilio.Device}
         */
        disconnectAll: function() {
            queue(function() {
                cls.instance.disconnectAll();
            });
            return cls;
        },
        /**
         * @param {function} handler
         * @return {Twilio.Device}
         */
        disconnect: function(handler) {
            queue(function() {
                cls.instance.addListener("disconnect", handler);
            });
            return cls;
        },
        status: function() {
            return cls.instance._status;
        },
        /**
         * @param {function} handler
         * @return {Twilio.Device}
         */
        ready: function(handler) {
            queue(function() {
                cls.instance.addListener("ready", handler);
            });
            return cls;
        },

        /**
         * @param {function} handler
         * @return {Twilio.Device}
         */
        error: function(handler) {
            queue(function() {
                if (handler != defaultErrorHandler) {
                    cls.instance.removeListener("error", defaultErrorHandler);
                }
                cls.instance.addListener("error", handler);
            });
            return cls;
        },

        /**
         * @param {function} handler
         * @return {Twilio.Device}
         */
        presence: function(handler) {
            queue(function() {
                cls.instance.presence(handler);
            });
            return cls;
        },

        /**
         * @param {function} handler
         * @return {Twilio.Device}
         */
        offline: function(handler) {
            queue(function() {
                cls.instance.addListener("offline", handler);
            });
            return cls;
        },

        /**
         * @param {function} handler
         * @return {Twilio.Device}
         */
        incoming: function(handler) {
            queue(function() {
                cls.instance.addListener("incoming", handler);
            });
            return cls;
        },

        /**
         * @return {Twilio.Device}
         */
        destroy: function() {
            if (cls.instance) cls.instance.destroy();
            return cls;
        },

        /**
         * @return {Twilio.Device}
         */
        cancel: function(handler) {
            queue(function() {
                cls.instance.addListener("cancel", handler);
            });
            return cls;
        },

        showPermissionsDialog: function() {
            if (!cls.instance) {
                throw new util.Exception("Run Twilio.Device.setup()");
            }
            cls.instance.showSettings();
        },

        __afterSetup: function(callback) {
            afterSetup.push(callback);
        }
    };

    for (var method in members) {
        cls[method] = members[method];
    }

    return cls;
}

Device = singletonwrapper(Device);

Device.dialog = factories.Dialog();

exports.Device = Device; });
    files["lib/twilio/dialog.js"] = (function(require, exports){ var Dialog = (function() {
    function Dialog() {
        var screen = document.createElement("div");
        var dialog = document.createElement("div");
        var close = document.createElement("button");

        screen.style.position = "fixed";
        screen.style.zIndex = "99999";
        screen.style.top = "0";
        screen.style.left = "0";
        screen.style.width = "1px";
        screen.style.height = "1px";
        screen.style.overflow = "hidden";
        screen.style.visibility = "hidden";

        dialog.style.margin = "10% auto 0";
        dialog.style.width = "215px";
        dialog.style.borderRadius = "8px";
        dialog.style.backgroundColor = "#f8f8f8";
        dialog.style.border = "8px solid rgb(160, 160, 160)";

        var self = this;
        var hideFn = function() {
            self.hide();
            if (self.closeCb) {
                self.closeCb.call();
            }
        };

        close.appendChild(document.createTextNode("Close"));
        if (window.addEventListener) {
            close.addEventListener("click", hideFn, false);
        } else {
            close.attachEvent("onclick", hideFn);
        }

        screen.appendChild(dialog);
        dialog.appendChild(close);

        this.screen = screen;
        this.dialog = dialog;
        this.close = close;
        this.container = null;
        this.inserted = false;
        this.embed = function() { };


        if (document.body) {
            document.body.appendChild(screen);
            self.inserted = true;
        } else {
            var self = this;
            var fn = function() {
                document.body.appendChild(screen);
                self.inserted = true;
                self.embed();
            };
            if (window.addEventListener) {
                window.addEventListener("load", fn, false);
            } else {
                window.attachEvent("onload", fn);
            }
        }
    }

    Dialog.prototype = {
        /**
         * Inserts a DOM element into the dialog.
         *
         * @param {HTMLElement} container Content for the dialog
         */
        insert: function(container, embed) {
            if (this.container) {
                if (this.container == container) {
                    return;
                }
                this.dialog.removeChild(this.container);
            }
            this.container = container;
            this.dialog.insertBefore(container, this.close);
            this.embed = embed || this.embed();
            if (this.inserted) {
                this.embed();
            }
        },
        /**
         * Shows the dialog.
         */
        show: function(closeCb) {
            this.closeCb = closeCb;
            this.screen.style.width = "100%";
            this.screen.style.height = "auto";
            this.screen.style.visibility = "visible";
            // Firefox uses subpixel units for positioning which is incompatible
            // with Flash components: they are visible but unresponsive to user
            // inputs. The workaround is to add a subpixel left margin to the flash
            // component's container. This is a known bug:
            // http://bugs.adobe.com/jira/browse/FP-4656.
            var dw = this.dialog.style.width.replace("px", "") | 0,
                ww = window.innerWidth || document.documentElement.clientWidth || document.body.clientWidth,
                wh = window.innerHeight || document.documentElement.clientHeight || document.body.clientHeight;
            this.dialog.style.marginLeft = (((ww - dw) / 2) | 0) + "px";
            this.dialog.style.marginTop = ((wh * .1) | 0) + "px";
        },
        /**
         * Hides the dialog.
         */
        hide: function() {
            this.screen.style.width = "1px";
            this.screen.style.height = "1px";
            this.screen.style.visibility = "hidden";
        }
    };
    return Dialog;
})();

exports.Dialog = Dialog; });
    files["lib/twilio/eventemitter.js"] = (function(require, exports){ /**
 * Implementation of indexOf which uses the native indexOf if available.
 *
 * @param {string} needle
 * @param {array} haystack
 * @param {boolean} _js Always use the Javascript implementation
 *
 * @return {number} The position of the needle
 */
function _indexOf(needle, haystack, _js) {
    _js = _js || false;
    haystack = haystack || [];
    if (haystack.length == 0) {
        return -1;
    }
    if (!_js && haystack.indexOf) {
        return haystack.indexOf(needle);
    }
    else {
        for (var i = 0; i < haystack.length; i++) {
            if (haystack[i] === needle) {
                return i;
            }
        }
        return -1;
    }
}
/**
 * A collection of methods that can be mixed in to an object to assist in
 * maintaining a mapping of events to event listeners, as well as the ability
 * to invoke a class of listeners.
 *
 * @class
 * @inner
 * @name EventEmitter
 */
var EventEmitter = {
    /** @lends EventEmitter# */
    /**
     * Registers a callback for an event type.
     *
     * @param {string} type The class of event
     * @param {function} callback A function to call when its event is triggered
     *
     * @return {EventEmitter}
     */
    addListener: function(type, callback) {
        if (typeof callback != "function") {
            var util = require("twilio/util");
            throw new util.Exception(
                "Listener must be a function, not " + typeof callback);
        }
        this.handlers[type] = this.handlers[type] || [];
        this.handlers[type].push(callback);
        this.log("Registered listener for event type \"" + type + "\"");
        return this;
    },
    /**
     * Is the callback registered with the event type?
     *
     * @param {string} type The class of event
     * @param {function} callback The associated callback
     *
     * @return {bool} Return true if the callback is associated with the event
     */
    hasListener: function(type, callback) {
        return _indexOf(callback, this.handlers[type]) != -1;
    },
    /**
     * Removes a callback for an event type.
     *
     * @param {string} type The class of event
     * @param {function} callback The associated callback
     *
     * @return {EventEmitter}
     */
    removeListener: function(type, callback) {
        var index = _indexOf(callback, this.handlers[type]);
        if (index > -1) {
            this.handlers[type].splice(index, 1);
            this.log("Removed listener for event type \"" + type + "\"");
        }
        return this;
    },
    /**
     * Invokes all the registered callbacks for an event type.
     *
     * @param {string} type The class of event
     * @param *args Any number of arguments to pass to the callback
     */
    fire: function(/* type, *args */) {
        var args = Array.prototype.slice.call(arguments, 0);
        var type = args.shift();
        var handlers = this.handlers[type] || [];
        this.log("Invoke listeners for event type \"" + type + "\"");
        for (var index = 0; index < handlers.length; index++) {
            handlers[index].apply(this, args);
        }
    }
}

/**
 * Utility to mix-in the EventEmitter methods to an object.
 *
 * @exports mixinEventEmitter as Twilio.mixinEventEmitter
 * @memberOf Twilio
 *
 * @param {object} object The object to attach EventEmitter properties to
 *
 * @return {object} Return the object passed in
 */
function mixinEventEmitter(object) {
    object.handlers = object.handlers || {};
    object.log = object.log || function() {};
    for (var name in EventEmitter) {
        if (object[name]) {
            continue;
        }
        object[name] = (function(this_, name) {
            return function() {
                var args = Array.prototype.slice.call(arguments, 0);
                return EventEmitter[name].apply(this_, args)
            };
        })(object, name);
    }
}
exports.mixinEventEmitter = mixinEventEmitter; });
    files["lib/twilio/eventstream.js"] = (function(require, exports){ var eventEmitter = require("twilio/eventemitter");
var log = require("twilio/log");
var util = require("twilio/util");
var factories = require("twilio/factories");

var Heartbeat = require("twilio/heartbeat").Heartbeat;

function initEvent(object, type) {
    if (!object.fire || !object.addListener) {
        throw new util.Exception("Object is not event savvy");
    }
    return function() {
        var args = Array.prototype.slice.call(arguments, 0);
        if (typeof args[0] == "function") {
            return object.addListener(type, args[0]);
        } else {
            args.unshift(type);
            return object.fire.apply(object, args);
        }
    };
};

function trim(str) {
    if (typeof str != "string") return "";
    return str.trim
        ? str.trim()
        : str.replace(/^\s+|\s+$/g, "");
}

/**
 * Splits a concatenation of multiple JSON strings into a list of JSON strings.
 *
 * @param string json The string of multiple JSON strings
 * @param boolean validate If true, thrown an error on invalid syntax
 *
 * @return array A list of JSON strings
 */
function splitObjects(json, validate) {
    var trimmed = trim(json);
    return trimmed.length == 0 ? [] : trimmed.split("\n");
}

/**
 * Constructor for EventStream objects.
 *
 * @exports EventStream as Twilio.EventStream
 * @memberOf Twilio
 * @borrows EventEmitter#addListener as #addListener
 * @borrows EventEmitter#removeListener as #removeListener
 * @borrows EventEmitter#fire as #fire
 * @borrows EventEmitter#hasListener as #hasListener
 * @constructor
 * @param {string} token The Twilio capabilities JWT
 * @param {object} [options]
 * @config {string} [options.swfLocation] Location of WebSocket.swf
 * @config {WebSocket} [options.socket] Mock socket
 * @config {boolean} [options.reconnect=true] Try to reconnect closed connections
 * @config {int} [options.flashTimeout=5000] Time to wait for Flash to initialize
 * @config {boolean} [options.debug=false] Enable debugging
 */
function EventStream(token, options) {
    if (!(this instanceof EventStream)) {
        return new EventStream(token, options);
    }
    var defaults = {
        logPrefix: "[EventStream]",
        scheme: "wss",
        host: "stream.twilio.com",
        reconnect: true,
        url: null,
        flashTimeout: 5000,
        filters: {},
        debug: false
    };
    options = options || {};
    for (var prop in defaults) {
        if (prop in options) continue;
        options[prop] = defaults[prop];
    }
    this.options = options;
    this.token = token || "";
    this.handlers = {};
    this.status = "offline";

    log.mixinLog(this, this.options["logPrefix"]);
    this.log.enabled = this.options["debug"];

    /**
     * A utility to help detect network connection loss.
     *
     * @type Twilio.Heartbeat
     */
    this.heartbeat = new Heartbeat({ "interval": 15 });

    this._connect();

    eventEmitter.mixinEventEmitter(this);

    var events = [
        "incoming",
        "ready",
        "offline",
        "sms",
        "call",
        "twiml",
        "error"
    ];
    for (var i = 0; i < events.length; i++) {
        this[events[i]] = initEvent(this, events[i]);
    }

    // The event type publish is an alias for twiml. See the comment in the
    // onmessage handler for the websocket for more details.
    var self = this;
    this.addListener("publish", function(obj) {
        self.fire("twiml", obj);
    });
}

EventStream.initializingFlash = false;
EventStream.initializeFlash = function(stream) {
    if (EventStream.initializingFlash) return;
    EventStream.initializingFlash = true;

    if (window.WebSocket && window.WebSocket.__initialize) {
        WEB_SOCKET_SWF_LOCATION = stream.options["swfLocation"];
        window.WebSocket.__initialize();
        // We want to inform the user if there is a failure loading
        // WebSocket.swf. swfobject.embedSWF has a success/failure callback,
        // but it returns true even on a 404 response for the requested .swf.
        // http://code.google.com/p/swfobject/issues/detail?id=126#c13.
        stream.log("Waiting " + stream.options["flashTimeout"] +
            "ms for flash to initialize");
        window.setTimeout(function() {
          if (!window.WebSocket.__flash) {
              stream.log("WebSocket did not initialize");
          }
        }, stream.options["flashTimeout"]);
    }
};

/**
 * @return {string}
 */
EventStream.toString = function() {
    return "[Twilio.EventStream class]";
};

EventStream.prototype = {
    toString: function() {
        return "[Twilio.EventStream instance]";
    },
    destroy: function() {
        this.socket.close();
        this.options["reconnect"] = false;
        return this;
    },
    publish: function (payload, channel) {
        try {
            this.socket.send(JSON.stringify({
                "rt.message": "publish",
                "rt.subchannel": channel,
                "rt.payload": payload
            }));
        }
        catch (error) {
            this.log("Error while publishing to eventstream. Reconnecting socket.");
            if (this.socket) {
                this.socket.close();
            }
            this._tryReconnect();
        }
    },
    _connect: function() {
        var self = this;
        var url = this._extractUrl();
        if (!url) {
            this.log("Nothing to do");
            return;
        }
        this.log("Attempting to connect to " + url + "...");
        // _tryReconnect calls this method expecting a new WebSocket each time.
        this.socket = factories.WebSocket(url);
        this.socket.onopen = function() {
            self.log("Socket opened... sending ready signal");
            self.socket.send(JSON.stringify({
                "rt.message": "listen",
                "rt.token": self.token
            }));
        };
        this.socket.onerror = function(me) {
            if (me.data) {
                self.fire("error", {
                    message: me.data.message || "",
                    code: me.data.code || ""
                });
            } else {
                self.log("Received message event:", me);
            }
        };
        this.socket.onmessage = function(message) {
            self.heartbeat.beat();
            // Return if just keepalive newline
            if (message.data == "\n") return;
            // Message might contain more than one JSON object.
            var objects = splitObjects(message.data);
            for (var i = 0; i < objects.length; i++) {
                var obj = JSON.parse(objects[i]);
                if (obj["rt.message"] == "ready") {
                    self.status = "ready";
                    self.fire("ready", self);
                } else {
                    // Hurl sends "publish" EventTypes, but our API calls them
                    // "twiml" events. We want to have all "publish" events
                    // fire the handlers registered for "twiml". In the
                    // EventStream constructor, we add a listener for
                    // "publish", and use that to fire a "twiml" event.
                    var event_type = obj["rt.message"] || obj["EventType"];
                    if (event_type == "error" && /^4/.test(obj["code"])) {
                        self.options["reconnect"] = false;
                    }
                    if (event_type != "incoming") {
                        self.fire("incoming", obj);
                        self.fire(event_type, obj);
                    } else {
                        self.fire(event_type, obj);
                    }
                }
            }
        };
        this.socket.onclose = function() {
            self.log("Gone offline");
            self.status = "offline";
            self.fire("offline", self);
        };
        this.heartbeat.onsleep = function() {
            if (self.socket) {
                self.socket.close();
            }
            self._tryReconnect(5000);
        };
    },
    reconnect: function(token) {
        if (this.socket) {
            this.socket.close();
        }
        this.token = token;
        this.options["reconnect"] = true;
        this._tryReconnect();
    },
    _extractUrl: function() {
        if (this.options["url"]) {
            return this.options["url"];
        }
        var scopes = util.objectize(this.token).scope;
        if (!("stream:subscribe" in scopes)) {
            return null;
        }
        var scope = scopes["stream:subscribe"];
        var path = (scope.params && scope.params["path"])
            ? scope.params["path"]
            : "/";
        var filters = this.options["filters"];
        filters["AccessToken"] = this.token;
        return this.options["scheme"] + "://" + this.options["host"]
            + path + "?" + util.urlencode(filters, true);
    },
    _tryReconnect: function(delay) {
        var now = (new Date().getTime() / 1000) | 0;
        if (!this.options["reconnect"]
            || this._extractUrl() == null
        ) {
            return;
        }
        delay = delay || 5000;
        this._connect();
        var callAgain = (function(self) {
            return function() {
                self._tryReconnect(delay * 2);
            };
        })(this);
        var checkReady = (function(self) {
            return function() {
                if (self.socket.readyState != 2) return;
                window.setTimeout(callAgain, delay);
            };
        })(this);
        window.setTimeout(checkReady, 5000);
    }
};

function singletonwrapper(cls) {
    var tasks = [];
    var queue = function(task) {
        if (cls.instance) return task();
        tasks.push(task);
    };
    var members = /** @lends Twilio.EventStream */ {
        /**
         * Instance of EventStream.
         *
         * @type Twilio.EventStream
         */
        instance: null,
        /**
         * Either "offline" or "ready
         * @type string
         */
        status: "offline",
        /**
         * @param {string} token
         * @param {object} options
         * @return {Twilio.EventStream}
         */
        setup: function(token, options) {
            cls.instance = new cls(token, options);
            for (var i = 0; i < tasks.length; i++) {
                tasks[i]();
            }
            cls.ready(function() { cls.status = "ready"; });
            cls.offline(function() { cls.status = "offline"; });
            return cls;
        },
        /**
         * @param {function} handler
         * @return {Twilio.EventStream}
         */
        incoming: function(handler) {
            queue(function() {
                cls.instance.incoming(handler);
            });
            return cls;
        },
        /**
         * @param {function} handler
         * @return {Twilio.EventStream}
         */
        ready: function(handler) {
            queue(function() {
                cls.instance.ready(handler);
            });
            return cls;
        },
        /**
         * @param {function} handler
         * @return {Twilio.EventStream}
         */
        offline: function(handler) {
            queue(function() {
                cls.instance.offline(handler);
            });
            return cls;
        },
        /**
         * @param {function} handler
         * @return {Twilio.EventStream}
         */
        sms: function(handler) {
            queue(function() {
                cls.instance.sms(handler);
            });
            return cls;
        },
        /**
         * @param {function} handler
         * @return {Twilio.EventStream}
         */
        call: function(handler) {
            queue(function() {
                cls.instance.call(handler);
            });
            return cls;
        },
        /**
         * @param {function} handler
         * @return {Twilio.EventStream}
         */
        twiml: function(handler) {
            queue(function() {
                cls.instance.twiml(handler);
            });
            return cls;
        },
        /**
         * @param {function} handler
         * @return {Twilio.EventStream}
         */
        error: function(handler) {
            queue(function() {
                cls.instance.error(handler);
            });
            return cls;
        }
    };

    for (var name in members) {
        cls[name] = members[name];
    }

    return cls;
}
EventStream = singletonwrapper(EventStream);

exports.EventStream = EventStream; });
    files["lib/twilio/factories.js"] = (function(require, exports){ var classes = {};
var callbacks = {};

function create(cls, args) {
    if (!cls.apply) return create_(cls, args);
    var ctor = function() {};
    ctor.prototype = cls.prototype;
    var args = Array.prototype.slice.call(args, 0),
        child = new ctor,
        result = cls.apply(child, args);
    return typeof result === "object" ? result : child;
}

function create_(cls, args) {
    var len = args.length;
    if (len === 0) return new cls();
    else if (len === 1) return new cls(args[0]);
    else if (len === 2) return new cls(args[0], args[1]);
    else if (len === 3) return new cls(args[0], args[1], args[2]);
    else if (len === 4) return new cls(args[0], args[1], args[2], args[3]);
}

function makeFactory(path, name, callback) {
    var key = path + "/" + name;
    if (callback) callbacks[key] = callback;
    return function() {
        var cls = classes[key] || (
            callbacks[key] ? callbacks[key]() : require(path)[name]);
        return create(cls, arguments);
    };
}

exports.registerClass = function(path, name, cls) {
    classes[path + "/" + name] = cls;
}
exports.getClass = function(path, name) {
    var key = path + "/" + name;
    return classes[key] || (callbacks[key] ? callbacks[key]() : undefined);
}

exports.Presence = makeFactory("twilio/presence", "Presence");
exports.Device = makeFactory("twilio/device", "Device");
exports.Dialog = makeFactory("twilio/dialog", "Dialog");
exports.Connection = makeFactory("twilio/connection", "Connection");
exports.EventStream = makeFactory("twilio/eventstream", "EventStream");
exports.SoundCache = makeFactory("twilio/soundcache", "SoundCache");
exports.PeerConnection = makeFactory("twilio/rtc", "PeerConnection");

exports.MediaStream = makeFactory("vendor/swfobject",
    "swfobject", function() { return swfobject });
exports.Sound = makeFactory("vendor/sound/sound",
    "Sound", function() { return Twilio.Sound });
exports.WebSocket = makeFactory("vendor/web-socket-js/websocket",
    "WebSocket", function() { return WebSocket });
exports.MediaStream = makeFactory("vendor/mediastream/mediastream",
    "MediaStream", function() { return Twilio.MediaStream }); });
    files["lib/twilio/heartbeat.js"] = (function(require, exports){ /**
 * Heartbeat just wants you to call <code>beat()</code> every once in a while.
 *
 * <p>It initializes a countdown timer that expects a call to
 * <code>Hearbeat#beat</code> every n seconds. If <code>beat()</code> hasn't
 * been called for <code>#interval</code> seconds, it fires a
 * <code>onsleep</code> event and waits. The next call to <code>beat()</code>
 * fires <code>onwakeup</code> and initializes a new timer.</p>
 *
 * <p>For example:</p>
 *
 * @example
 *
 *     >>> hb = new Heartbeat({
 *     ...   interval: 10,
 *     ...   onsleep: function() { console.log('Gone to sleep...Zzz...'); },
 *     ...   onwakeup: function() { console.log('Awake already!'); },
 *     ... });
 *
 *     >>> hb.beat(); # then wait 10 seconds
 *     Gone to sleep...Zzz...
 *     >>> hb.beat();
 *     Awake already!
 *
 * @exports Heartbeat as Twilio.Heartbeat
 * @memberOf Twilio
 * @constructor
 * @param {object} opts Options for Heartbeat
 * @config {int} [interval=10] Seconds between each call to <code>beat</code>
 * @config {function} [onsleep] Callback for sleep events
 * @config {function} [onwakeup] Callback for wakeup events
 */
function Heartbeat(opts) {
    if (!(this instanceof Heartbeat)) return new Heartbeat(opts);
    opts = opts || {};
    /** @ignore */
    var noop = function() { };
    var defaults = {
        interval: 10,
        now: function() { return new Date().getTime() },
        repeat: function(f, t) { return setInterval(f, t) },
        stop: function(f, t) { return clearInterval(f, t) },
        onsleep: noop,
        onwakeup: noop
    };
    for (var prop in defaults) {
        if (prop in opts) continue;
        opts[prop] = defaults[prop];
    }
    /**
     * Number of seconds with no beat before sleeping.
     * @type number
     */
    this.interval = opts.interval;
    this.lastbeat = 0;
    this.pintvl = null;

    /**
     * Invoked when this object has not received a call to <code>#beat</code>
     * for an elapsed period of time greater than <code>#interval</code>
     * seconds.
     *
     * @event
     */
    this.onsleep = opts.onsleep;

    /**
     * Invoked when this object is sleeping and receives a call to
     * <code>#beat</code>.
     *
     * @event
     */
    this.onwakeup = opts.onwakeup;

    this.repeat = opts.repeat;
    this.stop = opts.stop;
    this.now = opts.now;
}

/**
 * @return {string}
 */
Heartbeat.toString = function() {
    return "[Twilio.Heartbeat class]";
};

Heartbeat.prototype = {
    /**
     * @return {string}
     */
    toString: function() {
        return "[Twilio.Heartbeat instance]";
    },
    /**
     * Keeps the instance awake (by resetting the count down); or if asleep,
     * wakes it up.
     */
    beat: function() {
        this.lastbeat = this.now();
        if (this.sleeping()) {
            if (this.onwakeup) {
                this.onwakeup();
            }
            var self = this;
            this.pintvl = this.repeat.call(
                null,
                function() { self.check() },
                this.interval * 1000
            );
        }
    },
    /**
     * Goes into a sleep state if the time between now and the last heartbeat
     * is greater than or equal to the specified <code>interval</code>.
     */
    check: function() {
        var timeidle = this.now() - this.lastbeat;
        if (!this.sleeping() && timeidle >= this.interval * 1000) {
            if (this.onsleep) {
                this.onsleep();
            }
            this.stop.call(null, this.pintvl);

            this.pintvl = null;
        }
    },
    /**
     * @return {boolean} True if sleeping
     */
    sleeping: function() {
        return this.pintvl == null;
    }
};
exports.Heartbeat = Heartbeat; });
    files["lib/twilio/log.js"] = (function(require, exports){ /**
 * Bestow logging powers.
 *
 * @exports mixinLog as Twilio.mixinLog
 * @memberOf Twilio
 *
 * @param {object} object The object to bestow logging powers to
 * @param {string} [prefix] Prefix log messages with this
 *
 * @return {object} Return the object passed in
 */
function mixinLog(object, prefix) {
    /**
     * Logs a message or object.
     *
     * <p>There are a few options available for the log mixin. Imagine an object
     * <code>foo</code> with this function mixed in:</p>
     *
     * <pre><code>var foo = {};
     * Twilio.mixinLog(foo);
     *
     * </code></pre>
     *
     * <p>To enable or disable the log: <code>foo.log.enabled = true</code></p>
     *
     * <p>To modify the prefix: <code>foo.log.prefix = "Hello"</code></p>
     *
     * <p>To use a custom callback instead of <code>console.log</code>:
     * <code>foo.log.handler = function() { ... };</code></p>
     *
     * @param *args Messages or objects to be logged
     */
    function log() {
        if (!log.enabled) {
            return;
        }
        var format = log.prefix ? log.prefix + " " : "";
        for (var i = 0; i < arguments.length; i++) {
            var arg = arguments[i];
            log.handler(
                typeof arg == "string"
                ? format + arg
                : arg
            );
        }
    };

    log.enabled = true;
    log.prefix = prefix || "";
    /** @ignore */
    log.defaultHandler = function(x) { window.console && console.log(x); };
    log.handler = log.defaultHandler;

    object.log = log;
}
exports.mixinLog = mixinLog; });
    files["lib/twilio/options.js"] = (function(require, exports){ var Options = (function() {
    function Options(defaults, assignments) {
        if (!(this instanceof Options)) {
            return new Options(defaults);
        }
        this.__dict__ = {};
        defaults = defaults || {};
        assignments = assignments || {};
        for (var name in defaults) {
            this[name] = makeprop(this.__dict__, name);
            this[name](defaults[name]);
        }
        for (var name in assignments) {
            this[name](assignments[name]);
        }
    }

    function makeprop(__dict__, name) {
        return function(value) {
            return typeof value == "undefined"
                ? __dict__[name]
                : __dict__[name] = value;
        };
    }
    return Options;
})();

exports.Options = Options; });
    files["lib/twilio/presence.js"] = (function(require, exports){ var Set = require("twilio/util").Set;
var bind = require("twilio/util").bind;
var Options = require("twilio/options").Options;
var state = require("twilio/state");

var PRESENCE_HEARTBEAT_INTERVAL = 5 * 60; // seconds
var PRESENCE_DELAY_VARIATION = 0.2;

var rndrange = function(l, u) { return Math.random() * (u - l) + l; };
var jitter = function(i, v) { return i + i * rndrange(-1, 1) * v; };

var Presence = (function() {
    function Presence(clientName, device, stream, options) {
        this.roster = new Set();
        this.handlers = [];
        this.clientName = clientName;
        this.options = new Options({
            autoStart: false,
            interval: PRESENCE_HEARTBEAT_INTERVAL,
            variation: PRESENCE_DELAY_VARIATION,
            clearTimeout: function(tid) { return clearTimeout(tid) },
            setTimeout: function(f, t) { return setTimeout(f, t) }
        }, options);

        this._boundPresence = bind(this.handlePresence, this);
        this._boundRoster = bind(this.handleRoster, this);

        device.addListener("offline", bind(this.handleOffline, this));
        this.attach(stream);

        this._boundHeartbeat = bind(this.heartbeat, this, stream, {
            // Give 2x interval before server times out
            ttl: this.options.interval() * 2,
            availability: "available",
            keepalive: true
        });

        var stateM = new state.StateM({ stop: "start", start: "stop" }, this);
        this.start = stateM.doStart;
        this.stop = stateM.doStop;

        if (this.options.autoStart()) {
            this.start();
        }
    }

    Presence.prototype.enterStart = function(transition, ref) {
        var ref = { tid: null }, self = this;
        (function loop() {
            var delay = jitter(self.options.interval(), self.options.variation());
            ref.tid = self.options.setTimeout()(function() {
                self._boundHeartbeat();
                loop();
            }, delay * 1000);
        })();
        return ref;
    };

    Presence.prototype.enterStop = function(transition, ref) {
        this.options.clearTimeout()(ref.tid);
    };

    Presence.prototype.heartbeat = function(stream, payload) {
        stream.publish(payload, "presence");
    };

    Presence.prototype.attach = function(stream) {
        stream.addListener("presence", this._boundPresence);
        stream.addListener("roster", this._boundRoster);
    };

    Presence.prototype.detach = function(stream) {
        stream.removeListener("presence", this._boundPresence);
        stream.removeListener("roster", this._boundRoster);
    };

    Presence.prototype.removeFromRoster = function(clientName) {
        this.roster.del(clientName);
        this.invoke(clientName, false);
    };

    Presence.prototype.addToRoster = function(clientName) {
        this.roster.put(clientName);
        this.invoke(clientName, true);
    };

    Presence.prototype.handleOffline = function() {
        var removeFromRoster = bind(this.removeFromRoster, this);
        this.roster.map(removeFromRoster);
    };

    Presence.prototype.handlePresence = function(event) {
        this[event.Available ? "addToRoster" : "removeFromRoster"](event.From);
    };

    Presence.prototype.handleRoster = function(event) {
        for (var i = 0; i < event.Roster.length; i++) {
            this.addToRoster(event.Roster[i]);
        }
    };

    Presence.prototype.invoke = function(clientName, available) {
        if (clientName === this.clientName) return;
        var event = { from: clientName, available: available };
        for (var i = 0; i < this.handlers.length; i++) {
            this.handlers[i](event);
        }
    };

    return Presence;
})();

exports.Presence = Presence; });
    files["lib/twilio/rtc.js"] = (function(require, exports){ var factories = require("twilio/factories");
var util = require("twilio/util");

var PeerConnection = function(encrypt, host) {
    var noop = function() { };
    this.onopen = noop;
    this.onerror = noop;
    this.onclose = noop;
    this.version = null;
    this.sock = null;
    this.stream = null;
    this._uri = "wss://" + host + "/signal";
    this.video = document.createElement("video");
    this.video.autoplay = "autoplay";
    this.sendHangup = true;
};

PeerConnection.prototype = {
    uri: function() {
        return this._uri;
    },
    openHelper: function(next) {
        var self = this;
        PeerConnection.getUserMedia({ audio: true }, function(stream) {
            self.stream = stream;
            next();
        }, function(error) {
            if (error.code == error.PERMISSION_DENIED)
                next("User denied access to microphone.", 31208);
            else
                next("Error occurred while accessing microphone.", 31201);
        });
    },
    _setupPeerConnection: function() {
        var version = PeerConnection.protocol;
        version.create();
        version.pc.addStream(this.stream);
        var self = this;
        version.pc.onaddstream = function(ev) {
            self.video.src = webkitURL.createObjectURL(ev.stream);
        };
        version.createOffer({ audio: true });
        return version;
    },
    _setupChannel: function(url, token, bridge, params, acceptParams, iss) {
        try {
            var sock = factories.WebSocket(url);
        }
        catch (e) {
            this.onerror({ info: { code:31000, message: e.message } });
            this.close();
            return;
        }
        var self = this;
        sock.onopen = function() {
            //Chrome 25 supports onopen
            self.version.pc.onopen = self.onopen;

            //Chrome 26 doesn't support onopen so must detect state change
            self.version.pc.onstatechange = function(stateEvent) {
                if (self.version.pc && self.version.pc.readyState == "stable")
                    self.onopen();
            };

            sock.send(JSON.stringify({
                type: "OFFER",
                sdp: self.version.getSDP(),
                fmt: self.fmt ? self.fmt : { pt: 104, name: "ISAC/32000" },
                twilio: {
                    appsid: token ? util.objectize(token).iss : null, // TODO accountsid?
                    token: token,
                    bridgeToken: bridge,
                    params: params,
                    extras: [acceptParams, iss]
                }
            }));
        };
        sock.onmessage = function(message) {
            var msg = JSON.parse(message.data);
            if (msg.type === "ANSWER") {
                self.version.processAnswer(msg.sdp);
            } else if (msg.type === "CANDIDATE") {
                self.version.processCandidate(msg.candidate, msg.label);
            } else if (msg.type === "HANGUP") {
                if (msg.error) {
                    self.onerror({ info: { code: msg.error.code
                                         , message: msg.error } });
                }
                self.sendHangup = false;
                self.close();
            }
        };
        sock.onclose = function() {
            if (self.sock) {
                self.close();
            };
        };
        return sock;
    },
    open: function(url, token, bridge, params, acceptParams, iss) {
        if (this.sock) return;
        this.version = this._setupPeerConnection();
        this.sock = this._setupChannel(url, token, bridge, params, acceptParams, iss);
    },
    exec: function(command) {
        var args = [].slice.call(arguments, 1);
        if (command === "sendDTMF") {
            var dtmf = args[0];
            if (dtmf && dtmf.length) {
                if (this.sock) {
                    this.sock.send(
                        JSON.stringify({ type: "DTMF", dtmf: args[0] }));
                }
            }
        }
    },
    close: function() {
        if (this.version.pc) {
            this.version.pc.close();
            this.version.pc = null;
        }
        if (this.sock) {
            if (this.sendHangup) {
                this.sock.send(JSON.stringify({ type: "HANGUP" }));
            }
            this.sock.close();
            this.sock = null;
        }
        if (this.stream) {
            this.stream.stop();
            this.stream = null;
        }
        this.video.src = "";
        this.onclose();
    },
    play: function() {
    },
    publish: function() {
    },
    attachAudio: function() {
        if (this.stream) {
            var audioTracks = this.stream.audioTracks || this.stream.getAudioTracks();
            audioTracks[0].enabled = true;
        }
    },
    detachAudio: function() {
        if (this.stream) {
            var audioTracks = this.stream.audioTracks || this.stream.getAudioTracks();
            audioTracks[0].enabled = false;
        }
    }
};

PeerConnection.getUserMedia = function(constraints, successCallback, errorCallback) {
    if (typeof navigator == "undefined") return;
    navigator.webkitGetUserMedia(constraints, successCallback, errorCallback);
};

var RTCPC = function() {};
RTCPC.prototype.create = function() {
    this.pc = new webkitRTCPeerConnection({ iceServers: [] });
};
RTCPC.prototype.createOffer = function(constraints) {
    var self = this;
    // createOffer differs between Chrome 23 and Chrome 24+.
    // See https://groups.google.com/forum/?fromgroups=#!topic/discuss-webrtc/JBDZtrMumyU
    // Unfortunately I haven't figured out a way to detect which format
    // is required ahead of time, so we'll first try the old way, and
    // if we get an exception, then we'll try the new way.
    var modernConstraints = function(c) {
        if (typeof c === "undefined") {
            return null;
        }
        nc = { mandatory: {} }
        if (typeof c.audio !== "undefined") {
            nc.mandatory.OfferToReceiveAudio = c.audio;
        }
        if (typeof c.video !== "undefined") {
            nc.mandatory.OfferToReceiveVideo = c.video;
        }
        return nc;
    }
    var success = function(sd) {
        self.pc.setLocalDescription(new RTCSessionDescription(sd));
    }
    var error = function(err) {
        // This callback is now mandatory.  Need to bubble this error
        // back out, though it shouldn't occur with supported clients.
    }
    try {
        this.pc.createOffer(success, error, constraints);
    } catch (e) {
        this.pc.createOffer(success, error, modernConstraints(constraints));
    }
};
RTCPC.prototype.getSDP = function() {
    return this.pc.localDescription.sdp;
};
RTCPC.prototype.processAnswer = function(sdp) {
    this.pc.setRemoteDescription(
        new RTCSessionDescription({ sdp: sdp, type: "answer" }));
};
RTCPC.prototype.processCandidate = function(candidate, label) {
    return this.pc.addIceCandidate(
        new RTCIceCandidate({ sdpMLineIndex: 0, candidate: candidate }));
};
RTCPC.test = function() {
    return (typeof navigator == "object"
        && navigator.webkitGetUserMedia
        && typeof webkitRTCPeerConnection == "function");
};

PeerConnection.protocol = (function() {
    if (RTCPC.test()) return new RTCPC();
    else return null;
})();

PeerConnection.enabled = !!PeerConnection.protocol;

exports.PeerConnection = PeerConnection;
exports.enabled = function(set) {
    if (typeof set !== "undefined") {
        PeerConnection.enabled = set;
    }
    return PeerConnection.enabled;
} });
    files["lib/twilio/soundcache.js"] = (function(require, exports){ function not(expr) { return !expr; }
function bind(ctx, fn) {
    return function() {
        var args = Array.prototype.slice(arguments);
        fn.apply(ctx, args);
    };
}

function SoundCache() {
    if (not(this instanceof SoundCache)) {
        return new SoundCache();
    }
    this.cache = {};
}

SoundCache.prototype = {
    add: function(name, sounds, envelope) {
        envelope = envelope || {};
        if (not(envelope instanceof Object)) {
            throw new TypeError(
              "Bad envelope type; expected Object");
        }
        if (not(sounds instanceof Array)) {
            sounds = [sounds];
        }
        this.cache[name] = {
            starttime: null,
            sounds: sounds,
            envelope: envelope
        };
    },
    play: function(name, position, loop) {
        position = position || 0;
        loop = loop || 1;
        if (not(name in this.cache)) {
            return;
        }
        var voice = this.cache[name];
        for (var i = 0; i < voice.sounds.length; i++) {
            voice.sounds[i].play(position, loop);
        }
        voice.starttime = new Date().getTime();
    },
    stop: function(name) {
        if (not(name in this.cache)) {
            return;
        }
        var voice = this.cache[name];
        var release = voice.envelope.release || 0;
        var pauseFn = function() {
            for (var i = 0; i < voice.sounds.length; i++) {
                voice.sounds[i].stop();
            }
        };
        var now = new Date().getTime();
        var hold = Math.max(0, release - (now - voice.starttime));
        var _ = (release == 0) ? pauseFn() : setTimeout(pauseFn, hold);
    },
    envelope: function(name, update) {
        if (not(name in this.cache)) {
            return;
        }
        var voice = this.cache[name];
        for (var prop in update) {
            voice.envelope[prop] = update[prop];
        }
    },
    playseq: (function() {
        var timer = null;
        var queue = [];
        var playFn = function() {
            var tuple = queue.shift();
            if (!tuple) {
                timer = null;
                return;
            }
            var name = tuple[0],
                duration = tuple[1] || 0,
                pause = tuple[2] || 0;
            if (name in this.cache) {
                this.play(name);
            }
            timer = setTimeout(bind(this, playFn), duration + pause);
        };
        return function (sequence) {
            for (var i = 0; i < sequence.length; i++) {
                queue.push(sequence[i]);
            }
            if (timer == null) {
                timer = setTimeout(bind(this, playFn), 0);
            }
        };
    })()
};

exports.SoundCache = SoundCache; });
    files["lib/twilio/state.js"] = (function(require, exports){ // Generated by CoffeeScript 1.4.0
var DEFAULT_EVENT_PREFIX, StateM, Transition, TransitionError, buildTransitions, isEmptyObject, titleCase,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
  __indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; },
  __slice = [].slice;

DEFAULT_EVENT_PREFIX = "do";

titleCase = function(str) {
  return str.substr(0, 1).toUpperCase() + str.slice(1);
};

isEmptyObject = function(obj) {
  var _;
  for (_ in obj) {
    return false;
  }
  return true;
};

buildTransitions = function(transT) {
  var k, v, _results;
  _results = [];
  for (k in transT) {
    v = transT[k];
    _results.push(new Transition(k, v));
  }
  return _results;
};

TransitionError = (function(_super) {

  __extends(TransitionError, _super);

  function TransitionError() {
    TransitionError.__super__.constructor.apply(this, arguments);
  }

  return TransitionError;

})(Error);

Transition = (function() {

  function Transition(froms, to, name) {
    this.froms = froms;
    this.to = to;
    this.name = name;
    if (!(this.froms instanceof Array)) {
      this.froms = [this.froms];
    }
    this.name = this.name || DEFAULT_EVENT_PREFIX + titleCase(this.to);
  }

  return Transition;

})();

StateM = (function() {

  function StateM(transT, ctx, stateData) {
    var t, transitions, _i, _len;
    this.ctx = ctx != null ? ctx : this;
    this.stateData = stateData != null ? stateData : [];
    transitions = buildTransitions(transT);
    if (transitions.length === 0) {
      throw new Error("Must initialize with at least one transition");
    }
    this.state = transitions[0].froms[0];
    if (!(this.stateData instanceof Array)) {
      this.stateData = [this.stateData];
    }
    for (_i = 0, _len = transitions.length; _i < _len; _i++) {
      t = transitions[_i];
      this.makeEvent(t);
    }
  }

  StateM.prototype.makeEvent = function(transition) {
    var _this = this;
    return this[transition.name] = function() {
      var _ref;
      if (_ref = _this.state, __indexOf.call(transition.froms, _ref) < 0) {
        throw new TransitionError("Not a valid transition");
      }
      _this.stateData = _this.invoke.apply(_this, ["leave", _this.state, transition].concat(__slice.call(_this.stateData)));
      _this.stateData = _this.invoke.apply(_this, ["enter", transition.to, transition].concat(__slice.call(_this.stateData)));
      return _this.state = transition.to;
    };
  };

  StateM.prototype.invoke = function() {
    var args, direction, method, result, state, transition, _ref;
    direction = arguments[0], state = arguments[1], transition = arguments[2], args = 4 <= arguments.length ? __slice.call(arguments, 3) : [];
    method = direction + titleCase(state);
    if (this.ctx[method]) {
      result = (_ref = this.ctx)[method].apply(_ref, [transition].concat(__slice.call(args)));
      if (typeof result === "undefined") {
        result = [];
      }
      if (result instanceof Array) {
        return result;
      } else {
        return [result];
      }
    } else {
      return args;
    }
  };

  return StateM;

})();

exports.TransitionError = TransitionError;

exports.Transition = Transition;

exports.StateM = StateM; });
    files["lib/twilio/util.js"] = (function(require, exports){ /**
 * Exception class.
 *
 * @name Exception
 * @exports _Exception as Twilio.Exception
 * @memberOf Twilio
 * @constructor
 * @param {string} message The exception message
 */
function _Exception(message) {
    if (!(this instanceof _Exception)) return new _Exception(message);
    this.message = message;
}

/**
 * Returns the exception message.
 *
 * @return {string} The exception message.
 */
_Exception.prototype.toString = function() {
    return "Twilio.Exception: " + this.message;
}

function memoize(fn) {
    return function() {
        var args = Array.prototype.slice.call(arguments, 0);
        fn.memo = fn.memo || {};
        return fn.memo[args]
            ? fn.memo[args]
            : fn.memo[args] = fn.apply(null, args);
    };
}

function decodePayload(encoded_payload) {
    var remainder = encoded_payload.length % 4;
    if (remainder > 0) {
        var padlen = 4 - remainder;
        encoded_payload += new Array(padlen + 1).join("=");
    }
    encoded_payload = encoded_payload.replace(/-/g, "+")
                                     .replace(/_/g, "/");
    var decoded_payload = _atob(encoded_payload);
    return JSON.parse(decoded_payload);
}

var memoizedDecodePayload = memoize(decodePayload);

/**
 * Decodes a token.
 *
 * @name decode
 * @exports decode as Twilio.decode
 * @memberOf Twilio
 * @function
 * @param {string} token The JWT
 * @return {object} The payload
 */
function decode(token) {
    var segs = token.split(".");
    if (segs.length != 3) {
        throw new _Exception("Wrong number of segments");
    }
    var encoded_payload = segs[1];
    var payload = memoizedDecodePayload(encoded_payload);
    return payload;
}

function makedict(params) {
    if (params == "") return {};
    if (params.indexOf("&") == -1 && params.indexOf("=") == -1) return params;
    var pairs = params.split("&");
    var result = {};
    for (var i = 0; i < pairs.length; i++) {
        var pair = pairs[i].split("=");
        result[pair[0]] = makedict(decodeURIComponent(pair[1]));
    }
    return result;
}

function makescope(uri) {
    var parts = uri.match(/^scope:(\w+):(\w+)\??(.*)$/);
    if (!(parts && parts.length == 4)) {
        throw new _Exception("Bad scope URI");
    }
    return {
        service: parts[1],
        privilege: parts[2],
        params: makedict(parts[3])
    };
}

/**
* Encodes a Javascript object into a query string.
* Based on python's urllib.urlencode.
* @name urlencode
* @memberOf Twilio
* @function
* @param {object} params_dict The key-value store of params
* @param {bool} do_seq If True, look for values as lists for multival params
*/
function urlencode(params_dict, doseq) {
    var parts = [];
    doseq = doseq || false;
    for (var key in params_dict) {
        if (doseq && (params_dict[key] instanceof Array)) {
            for(var index in params_dict[key]) {
                var value = params_dict[key][index];
                parts.push(
                    encodeURIComponent(key) + "=" + encodeURIComponent(value)
                );
            }
        } else {
            var value = params_dict[key];
            parts.push(
                encodeURIComponent(key) + "=" + encodeURIComponent(value)
            );
        }
    }
    return parts.join("&");
}

function objectize(token) {
    var jwt = decode(token);
    var scopes = (jwt.scope.length === 0 ? [] : jwt.scope.split(" "));
    var newscopes = {};
    for (var i = 0; i < scopes.length; i++) {
        var scope = makescope(scopes[i]);
        newscopes[scope.service + ":" + scope.privilege] = scope;
    }
    jwt.scope = newscopes;
    return jwt;
}

var memoizedObjectize = memoize(objectize);

/**
 * Wrapper for btoa.
 *
 * @name btoa
 * @exports _btoa as Twilio.btoa
 * @memberOf Twilio
 * @function
 * @param {string} message The decoded string
 * @return {string} The encoded string
 */
function _btoa(message) {
    try {
        return btoa(message);
    } catch (e) {
        try {
            return new Buffer(message).toString("base64");
        } catch (e) {
            return Twilio._phpjs_btoa(message);
        }
    }
}

/**
 * Wrapper for atob.
 *
 * @name atob
 * @exports _atob as Twilio.atob
 * @memberOf Twilio
 * @function
 * @param {string} encoded The encoded string
 * @return {string} The decoded string
 */
function _atob(encoded) {
    try {
        return atob(encoded);
    } catch (e) {
        try {
            return new Buffer(encoded, "base64").toString("ascii");
        } catch (e) {
            return Twilio._phpjs_atob(encoded);
        }
    }
}

/**
 * Generates JWT tokens. For simplicity, only the payload segment is viable;
 * the header and signature are garbage.
 *
 * @param object payload The payload
 * @return string The JWT
 */
function dummyToken(payload) {
    var token_defaults = {
        "iss": "AC1111111111111111111111111111111",
        "exp": 1400000000
    }
    for (var k in token_defaults) {
        payload[k] = payload[k] || token_defaults[k];
    }
    var encoded_payload = _btoa(JSON.stringify(payload));
    encoded_payload = encoded_payload.replace(/=/g, "")
                                     .replace(/\+/g, "-")
                                     .replace(/\//g, "_");
    return ["*", encoded_payload, "*"].join(".");
}

function encodescope(service, privilege, params) {
    var capability = ["scope", service, privilege].join(":");
    var empty = true;
    for (var _ in params) { empty = false; break; }
    return empty ? capability : capability + "?" + buildquery(params);
}

function buildquery(params) {
    var pairs = [];
    for (var name in params) {
        var value = typeof params[name] == "object"
            ? buildquery(params[name])
            : params[name];
        pairs.push(encodeURIComponent(name) + "=" +
                   encodeURIComponent(value));
    }
    return pairs.join("&");
}

var bind = function(fn, ctx) {
    var applied = Array.prototype.slice.call(arguments, 2);
    return function() {
        var extra = Array.prototype.slice.call(arguments);
        return fn.apply(ctx, applied.concat(extra));
    };
};

var Set = (function() {
    function Set() { this.set = {} }
    Set.prototype.clear = function() { this.set = {} };
    Set.prototype.put = function(elem) { return this.set[elem] = Set.DUMMY };
    Set.prototype.del = function(elem) { return delete this.set[elem] };
    Set.prototype.map = function(fn, this_) {
        var results = [];
        for (var item in this.set) {
            results.push(fn.call(this_, item));
        }
        return results;
    };
    Set.DUMMY = {};
    return Set;
})();

var getSystemInfo = function() {
    var factories = require("twilio/factories"),
        rtc = require("twilio/rtc"),
        swfobject = factories.getClass("vendor/swfobject", "swfobject"),
        version = typeof VERSION != "undefined" ? VERSION : "1.0",
        nav = typeof navigator != "undefined" ? navigator : {};

    var info = {
        p: "browser",
        v: version,
        browser: {
            userAgent: nav.userAgent || "unknown",
            platform: nav.platform || "unknown"
        }
    };

    if (rtc.enabled()) {
        info.plugin = "rtc";
    } else {
        info.plugin = "flash";
        info.flash = { v: swfobject.getFlashPlayerVersion() };
    }

    return info;
};

exports.encodescope = encodescope;
exports.dummyToken = dummyToken;
exports.Exception = _Exception;
exports.decode = decode;
exports.btoa = _btoa;
exports.atob = _atob;
exports.objectize = memoizedObjectize;
exports.urlencode = urlencode;
exports.Set = Set;
exports.bind = bind;
exports.getSystemInfo = getSystemInfo; });
    files["lib/twilio.js"] = (function(require, exports){ exports.Device = require("twilio/device").Device;
exports.EventStream = require("twilio/eventstream").EventStream;
exports.Connection = require("twilio/connection").Connection;
exports.require = require; });
    var TWILIO_ROOT = typeof TWILIO_ROOT != "undefined" ?  TWILIO_ROOT : (function(){
        var prot = window.location.protocol || "http:",
            uri = "//static.twilio.com/libs/twiliojs/1.0/",
            scripts = document.getElementsByTagName("script"),
            re = /(\w+:)?(\/\/.*)(twilio.min.js|twilio.js)/;
        for (var i = 0; i < scripts.length; i++) {
            var match = scripts[i].src.match(re);
            if (match) {
                prot = (match[1] || prot);
                uri = match[2];
                break;
            }
        }
        return prot + uri;
    })();
    var NS_BEEP = "Twilio",
        NS_SOUND = "Twilio",
        NS_MEDIASTREAM = "Twilio",
        WEB_SOCKET_SWF_LOCATION = TWILIO_ROOT + "WebSocket.swf";

    // web-socket.js assumes the global root is window.
    if (window) window.WEB_SOCKET_SWF_LOCATION = WEB_SOCKET_SWF_LOCATION;
/* json2.js
 * 2008-01-17
 * Public Domain
 * No warranty expressed or implied. Use at your own risk.
 * See http://www.JSON.org/js.html
*/
if(!this.JSON){JSON=function(){function f(n){return n<10?'0'+n:n;}
Date.prototype.toJSON=function(){return this.getUTCFullYear()+'-'+
f(this.getUTCMonth()+1)+'-'+
f(this.getUTCDate())+'T'+
f(this.getUTCHours())+':'+
f(this.getUTCMinutes())+':'+
f(this.getUTCSeconds())+'Z';};var m={'\b':'\\b','\t':'\\t','\n':'\\n','\f':'\\f','\r':'\\r','"':'\\"','\\':'\\\\'};function stringify(value,whitelist){var a,i,k,l,r=/["\\\x00-\x1f\x7f-\x9f]/g,v;switch(typeof value){case'string':return r.test(value)?'"'+value.replace(r,function(a){var c=m[a];if(c){return c;}
c=a.charCodeAt();return'\\u00'+Math.floor(c/16).toString(16)+
(c%16).toString(16);})+'"':'"'+value+'"';case'number':return isFinite(value)?String(value):'null';case'boolean':case'null':return String(value);case'object':if(!value){return'null';}
if(typeof value.toJSON==='function'){return stringify(value.toJSON());}
a=[];if(typeof value.length==='number'&&!(value.propertyIsEnumerable('length'))){l=value.length;for(i=0;i<l;i+=1){a.push(stringify(value[i],whitelist)||'null');}
return'['+a.join(',')+']';}
if(whitelist){l=whitelist.length;for(i=0;i<l;i+=1){k=whitelist[i];if(typeof k==='string'){v=stringify(value[k],whitelist);if(v){a.push(stringify(k)+':'+v);}}}}else{for(k in value){if(typeof k==='string'){v=stringify(value[k],whitelist);if(v){a.push(stringify(k)+':'+v);}}}}
return'{'+a.join(',')+'}';}}
return{stringify:stringify,parse:function(text,filter){var j;function walk(k,v){var i,n;if(v&&typeof v==='object'){for(i in v){if(Object.prototype.hasOwnProperty.apply(v,[i])){n=walk(i,v[i]);if(n!==undefined){v[i]=n;}}}}
return filter(k,v);}
if(/^[\],:{}\s]*$/.test(text.replace(/\\./g,'@').replace(/"[^"\\\n\r]*"|true|false|null|-?\d+(?:\.\d*)?(?:[eE][+\-]?\d+)?/g,']').replace(/(?:^|:|,)(?:\s*\[)+/g,''))){j=eval('('+text+')');return typeof filter==='function'?walk('',j):j;}
throw new SyntaxError('parseJSON');}};}();}
/*  SWFObject v2.2 <http://code.google.com/p/swfobject/>
  is released under the MIT License <http://www.opensource.org/licenses/mit-license.php>
*/
var swfobject=function(){var D="undefined",r="object",S="Shockwave Flash",W="ShockwaveFlash.ShockwaveFlash",q="application/x-shockwave-flash",R="SWFObjectExprInst",x="onreadystatechange",O=window,j=document,t=navigator,T=false,U=[h],o=[],N=[],I=[],l,Q,E,B,J=false,a=false,n,G,m=true,M=function(){var aa=typeof j.getElementById!=D&&typeof j.getElementsByTagName!=D&&typeof j.createElement!=D,ah=t.userAgent.toLowerCase(),Y=t.platform.toLowerCase(),ae=Y?/win/.test(Y):/win/.test(ah),ac=Y?/mac/.test(Y):/mac/.test(ah),af=/webkit/.test(ah)?parseFloat(ah.replace(/^.*webkit\/(\d+(\.\d+)?).*$/,"$1")):false,X=!+"\v1",ag=[0,0,0],ab=null;if(typeof t.plugins!=D&&typeof t.plugins[S]==r){ab=t.plugins[S].description;if(ab&&!(typeof t.mimeTypes!=D&&t.mimeTypes[q]&&!t.mimeTypes[q].enabledPlugin)){T=true;X=false;ab=ab.replace(/^.*\s+(\S+\s+\S+$)/,"$1");ag[0]=parseInt(ab.replace(/^(.*)\..*$/,"$1"),10);ag[1]=parseInt(ab.replace(/^.*\.(.*)\s.*$/,"$1"),10);ag[2]=/[a-zA-Z]/.test(ab)?parseInt(ab.replace(/^.*[a-zA-Z]+(.*)$/,"$1"),10):0}}else{if(typeof O.ActiveXObject!=D){try{var ad=new ActiveXObject(W);if(ad){ab=ad.GetVariable("$version");if(ab){X=true;ab=ab.split(" ")[1].split(",");ag=[parseInt(ab[0],10),parseInt(ab[1],10),parseInt(ab[2],10)]}}}catch(Z){}}}return{w3:aa,pv:ag,wk:af,ie:X,win:ae,mac:ac}}(),k=function(){if(!M.w3){return}if((typeof j.readyState!=D&&j.readyState=="complete")||(typeof j.readyState==D&&(j.getElementsByTagName("body")[0]||j.body))){f()}if(!J){if(typeof j.addEventListener!=D){j.addEventListener("DOMContentLoaded",f,false)}if(M.ie&&M.win){j.attachEvent(x,function(){if(j.readyState=="complete"){j.detachEvent(x,arguments.callee);f()}});if(O==top){(function(){if(J){return}try{j.documentElement.doScroll("left")}catch(X){setTimeout(arguments.callee,0);return}f()})()}}if(M.wk){(function(){if(J){return}if(!/loaded|complete/.test(j.readyState)){setTimeout(arguments.callee,0);return}f()})()}s(f)}}();function f(){if(J){return}try{var Z=j.getElementsByTagName("body")[0].appendChild(C("span"));Z.parentNode.removeChild(Z)}catch(aa){return}J=true;var X=U.length;for(var Y=0;Y<X;Y++){U[Y]()}}function K(X){if(J){X()}else{U[U.length]=X}}function s(Y){if(typeof O.addEventListener!=D){O.addEventListener("load",Y,false)}else{if(typeof j.addEventListener!=D){j.addEventListener("load",Y,false)}else{if(typeof O.attachEvent!=D){i(O,"onload",Y)}else{if(typeof O.onload=="function"){var X=O.onload;O.onload=function(){X();Y()}}else{O.onload=Y}}}}}function h(){if(T){V()}else{H()}}function V(){var X=j.getElementsByTagName("body")[0];var aa=C(r);aa.setAttribute("type",q);var Z=X.appendChild(aa);if(Z){var Y=0;(function(){if(typeof Z.GetVariable!=D){var ab=Z.GetVariable("$version");if(ab){ab=ab.split(" ")[1].split(",");M.pv=[parseInt(ab[0],10),parseInt(ab[1],10),parseInt(ab[2],10)]}}else{if(Y<10){Y++;setTimeout(arguments.callee,10);return}}X.removeChild(aa);Z=null;H()})()}else{H()}}function H(){var ag=o.length;if(ag>0){for(var af=0;af<ag;af++){var Y=o[af].id;var ab=o[af].callbackFn;var aa={success:false,id:Y};if(M.pv[0]>0){var ae=c(Y);if(ae){if(F(o[af].swfVersion)&&!(M.wk&&M.wk<312)){w(Y,true);if(ab){aa.success=true;aa.ref=z(Y);ab(aa)}}else{if(o[af].expressInstall&&A()){var ai={};ai.data=o[af].expressInstall;ai.width=ae.getAttribute("width")||"0";ai.height=ae.getAttribute("height")||"0";if(ae.getAttribute("class")){ai.styleclass=ae.getAttribute("class")}if(ae.getAttribute("align")){ai.align=ae.getAttribute("align")}var ah={};var X=ae.getElementsByTagName("param");var ac=X.length;for(var ad=0;ad<ac;ad++){if(X[ad].getAttribute("name").toLowerCase()!="movie"){ah[X[ad].getAttribute("name")]=X[ad].getAttribute("value")}}P(ai,ah,Y,ab)}else{p(ae);if(ab){ab(aa)}}}}}else{w(Y,true);if(ab){var Z=z(Y);if(Z&&typeof Z.SetVariable!=D){aa.success=true;aa.ref=Z}ab(aa)}}}}}function z(aa){var X=null;var Y=c(aa);if(Y&&Y.nodeName=="OBJECT"){if(typeof Y.SetVariable!=D){X=Y}else{var Z=Y.getElementsByTagName(r)[0];if(Z){X=Z}}}return X}function A(){return !a&&F("6.0.65")&&(M.win||M.mac)&&!(M.wk&&M.wk<312)}function P(aa,ab,X,Z){a=true;E=Z||null;B={success:false,id:X};var ae=c(X);if(ae){if(ae.nodeName=="OBJECT"){l=g(ae);Q=null}else{l=ae;Q=X}aa.id=R;if(typeof aa.width==D||(!/%$/.test(aa.width)&&parseInt(aa.width,10)<310)){aa.width="310"}if(typeof aa.height==D||(!/%$/.test(aa.height)&&parseInt(aa.height,10)<137)){aa.height="137"}j.title=j.title.slice(0,47)+" - Flash Player Installation";var ad=M.ie&&M.win?"ActiveX":"PlugIn",ac="MMredirectURL="+O.location.toString().replace(/&/g,"%26")+"&MMplayerType="+ad+"&MMdoctitle="+j.title;if(typeof ab.flashvars!=D){ab.flashvars+="&"+ac}else{ab.flashvars=ac}if(M.ie&&M.win&&ae.readyState!=4){var Y=C("div");X+="SWFObjectNew";Y.setAttribute("id",X);ae.parentNode.insertBefore(Y,ae);ae.style.display="none";(function(){if(ae.readyState==4){ae.parentNode.removeChild(ae)}else{setTimeout(arguments.callee,10)}})()}u(aa,ab,X)}}function p(Y){if(M.ie&&M.win&&Y.readyState!=4){var X=C("div");Y.parentNode.insertBefore(X,Y);X.parentNode.replaceChild(g(Y),X);Y.style.display="none";(function(){if(Y.readyState==4){Y.parentNode.removeChild(Y)}else{setTimeout(arguments.callee,10)}})()}else{Y.parentNode.replaceChild(g(Y),Y)}}function g(ab){var aa=C("div");if(M.win&&M.ie){aa.innerHTML=ab.innerHTML}else{var Y=ab.getElementsByTagName(r)[0];if(Y){var ad=Y.childNodes;if(ad){var X=ad.length;for(var Z=0;Z<X;Z++){if(!(ad[Z].nodeType==1&&ad[Z].nodeName=="PARAM")&&!(ad[Z].nodeType==8)){aa.appendChild(ad[Z].cloneNode(true))}}}}}return aa}function u(ai,ag,Y){var X,aa=c(Y);if(M.wk&&M.wk<312){return X}if(aa){if(typeof ai.id==D){ai.id=Y}if(M.ie&&M.win){var ah="";for(var ae in ai){if(ai[ae]!=Object.prototype[ae]){if(ae.toLowerCase()=="data"){ag.movie=ai[ae]}else{if(ae.toLowerCase()=="styleclass"){ah+=' class="'+ai[ae]+'"'}else{if(ae.toLowerCase()!="classid"){ah+=" "+ae+'="'+ai[ae]+'"'}}}}}var af="";for(var ad in ag){if(ag[ad]!=Object.prototype[ad]){af+='<param name="'+ad+'" value="'+ag[ad]+'" />'}}aa.outerHTML='<object classid="clsid:D27CDB6E-AE6D-11cf-96B8-444553540000"'+ah+">"+af+"</object>";N[N.length]=ai.id;X=c(ai.id)}else{var Z=C(r);Z.setAttribute("type",q);for(var ac in ai){if(ai[ac]!=Object.prototype[ac]){if(ac.toLowerCase()=="styleclass"){Z.setAttribute("class",ai[ac])}else{if(ac.toLowerCase()!="classid"){Z.setAttribute(ac,ai[ac])}}}}for(var ab in ag){if(ag[ab]!=Object.prototype[ab]&&ab.toLowerCase()!="movie"){e(Z,ab,ag[ab])}}aa.parentNode.replaceChild(Z,aa);X=Z}}return X}function e(Z,X,Y){var aa=C("param");aa.setAttribute("name",X);aa.setAttribute("value",Y);Z.appendChild(aa)}function y(Y){var X=c(Y);if(X&&X.nodeName=="OBJECT"){if(M.ie&&M.win){X.style.display="none";(function(){if(X.readyState==4){b(Y)}else{setTimeout(arguments.callee,10)}})()}else{X.parentNode.removeChild(X)}}}function b(Z){var Y=c(Z);if(Y){for(var X in Y){if(typeof Y[X]=="function"){Y[X]=null}}Y.parentNode.removeChild(Y)}}function c(Z){var X=null;try{X=j.getElementById(Z)}catch(Y){}return X}function C(X){return j.createElement(X)}function i(Z,X,Y){Z.attachEvent(X,Y);I[I.length]=[Z,X,Y]}function F(Z){var Y=M.pv,X=Z.split(".");X[0]=parseInt(X[0],10);X[1]=parseInt(X[1],10)||0;X[2]=parseInt(X[2],10)||0;return(Y[0]>X[0]||(Y[0]==X[0]&&Y[1]>X[1])||(Y[0]==X[0]&&Y[1]==X[1]&&Y[2]>=X[2]))?true:false}function v(ac,Y,ad,ab){if(M.ie&&M.mac){return}var aa=j.getElementsByTagName("head")[0];if(!aa){return}var X=(ad&&typeof ad=="string")?ad:"screen";if(ab){n=null;G=null}if(!n||G!=X){var Z=C("style");Z.setAttribute("type","text/css");Z.setAttribute("media",X);n=aa.appendChild(Z);if(M.ie&&M.win&&typeof j.styleSheets!=D&&j.styleSheets.length>0){n=j.styleSheets[j.styleSheets.length-1]}G=X}if(M.ie&&M.win){if(n&&typeof n.addRule==r){n.addRule(ac,Y)}}else{if(n&&typeof j.createTextNode!=D){n.appendChild(j.createTextNode(ac+" {"+Y+"}"))}}}function w(Z,X){if(!m){return}var Y=X?"visible":"hidden";if(J&&c(Z)){c(Z).style.visibility=Y}else{v("#"+Z,"visibility:"+Y)}}function L(Y){var Z=/[\\\"<>\.;]/;var X=Z.exec(Y)!=null;return X&&typeof encodeURIComponent!=D?encodeURIComponent(Y):Y}var d=function(){if(M.ie&&M.win){window.attachEvent("onunload",function(){var ac=I.length;for(var ab=0;ab<ac;ab++){I[ab][0].detachEvent(I[ab][1],I[ab][2])}var Z=N.length;for(var aa=0;aa<Z;aa++){y(N[aa])}for(var Y in M){M[Y]=null}M=null;for(var X in swfobject){swfobject[X]=null}swfobject=null})}}();return{registerObject:function(ab,X,aa,Z){if(M.w3&&ab&&X){var Y={};Y.id=ab;Y.swfVersion=X;Y.expressInstall=aa;Y.callbackFn=Z;o[o.length]=Y;w(ab,false)}else{if(Z){Z({success:false,id:ab})}}},getObjectById:function(X){if(M.w3){return z(X)}},embedSWF:function(ab,ah,ae,ag,Y,aa,Z,ad,af,ac){var X={success:false,id:ah};if(M.w3&&!(M.wk&&M.wk<312)&&ab&&ah&&ae&&ag&&Y){w(ah,false);K(function(){ae+="";ag+="";var aj={};if(af&&typeof af===r){for(var al in af){aj[al]=af[al]}}aj.data=ab;aj.width=ae;aj.height=ag;var am={};if(ad&&typeof ad===r){for(var ak in ad){am[ak]=ad[ak]}}if(Z&&typeof Z===r){for(var ai in Z){if(typeof am.flashvars!=D){am.flashvars+="&"+ai+"="+Z[ai]}else{am.flashvars=ai+"="+Z[ai]}}}if(F(Y)){var an=u(aj,am,ah);if(aj.id==ah){w(ah,true)}X.success=true;X.ref=an}else{if(aa&&A()){aj.data=aa;P(aj,am,ah,ac);return}else{w(ah,true)}}if(ac){ac(X)}})}else{if(ac){ac(X)}}},switchOffAutoHideShow:function(){m=false},ua:M,getFlashPlayerVersion:function(){return{major:M.pv[0],minor:M.pv[1],release:M.pv[2]}},hasFlashPlayerVersion:F,createSWF:function(Z,Y,X){if(M.w3){return u(Z,Y,X)}else{return undefined}},showExpressInstall:function(Z,aa,X,Y){if(M.w3&&A()){P(Z,aa,X,Y)}},removeSWF:function(X){if(M.w3){y(X)}},createCSS:function(aa,Z,Y,X){if(M.w3){v(aa,Z,Y,X)}},addDomLoadEvent:K,addLoadEvent:s,getQueryParamValue:function(aa){var Z=j.location.search||j.location.hash;if(Z){if(/\?/.test(Z)){Z=Z.split("?")[1]}if(aa==null){return L(Z)}var Y=Z.split("&");for(var X=0;X<Y.length;X++){if(Y[X].substring(0,Y[X].indexOf("="))==aa){return L(Y[X].substring((Y[X].indexOf("=")+1)))}}}return""},expressInstallCallback:function(){if(a){var X=c(R);if(X&&l){X.parentNode.replaceChild(l,X);if(Q){w(Q,true);if(M.ie&&M.win){l.style.display="block"}}if(E){E(B)}}a=false}}}}();// Copyright: Hiroshi Ichikawa <http://gimite.net/en/>
// License: New BSD License
// Reference: http://dev.w3.org/html5/websockets/
// Reference: http://tools.ietf.org/html/draft-hixie-thewebsocketprotocol

(function() {

  if (window.WebSocket) return;

  var console = window.console;
  if (!console || !console.log || !console.error) {
    console = {log: function(){ }, error: function(){ }};
  }

  if (!swfobject.hasFlashPlayerVersion("10.0.0")) {
    console.error("Flash Player >= 10.0.0 is required.");
    return;
  }
  if (location.protocol == "file:") {
    console.error(
      "WARNING: web-socket-js doesn't work in file:///... URL " +
      "unless you set Flash Security Settings properly. " +
      "Open the page via Web server i.e. http://...");
  }

  /**
   * This class represents a faux web socket.
   * @param {string} url
   * @param {string} protocol
   * @param {string} proxyHost
   * @param {int} proxyPort
   * @param {string} headers
   */
  WebSocket = function(url, protocol, proxyHost, proxyPort, headers) {
    var self = this;
    self.__id = WebSocket.__nextId++;
    WebSocket.__instances[self.__id] = self;
    self.readyState = WebSocket.CONNECTING;
    self.bufferedAmount = 0;
    self.__events = {};
    // Uses setTimeout() to make sure __createFlash() runs after the caller sets ws.onopen etc.
    // Otherwise, when onopen fires immediately, onopen is called before it is set.
    setTimeout(function() {
      WebSocket.__addTask(function() {
        WebSocket.__flash.create(
            self.__id, url, protocol, proxyHost || null, proxyPort || 0, headers || null);
      });
    }, 0);
  };

  /**
   * Send data to the web socket.
   * @param {string} data  The data to send to the socket.
   * @return {boolean}  True for success, false for failure.
   */
  WebSocket.prototype.send = function(data) {
    if (this.readyState == WebSocket.CONNECTING) {
      throw "INVALID_STATE_ERR: Web Socket connection has not been established";
    }
    // We use encodeURIComponent() here, because FABridge doesn't work if
    // the argument includes some characters. We don't use escape() here
    // because of this:
    // https://developer.mozilla.org/en/Core_JavaScript_1.5_Guide/Functions#escape_and_unescape_Functions
    // But it looks decodeURIComponent(encodeURIComponent(s)) doesn't
    // preserve all Unicode characters either e.g. "\uffff" in Firefox.
    // Note by wtritch: Hopefully this will not be necessary using ExternalInterface.  Will require
    // additional testing.
    var result = WebSocket.__flash.send(this.__id, encodeURIComponent(data));
    if (result < 0) { // success
      return true;
    } else {
      this.bufferedAmount += result;
      return false;
    }
  };

  /**
   * Close this web socket gracefully.
   */
  WebSocket.prototype.close = function() {
    if (this.readyState == WebSocket.CLOSED || this.readyState == WebSocket.CLOSING) {
      return;
    }
    this.readyState = WebSocket.CLOSING;
    WebSocket.__addTask(function() {
        WebSocket.__flash.close(this.__id);
    });
  };

  /**
   * Implementation of {@link <a href="http://www.w3.org/TR/DOM-Level-2-Events/events.html#Events-registration">DOM 2 EventTarget Interface</a>}
   *
   * @param {string} type
   * @param {function} listener
   * @param {boolean} useCapture
   * @return void
   */
  WebSocket.prototype.addEventListener = function(type, listener, useCapture) {
    if (!(type in this.__events)) {
      this.__events[type] = [];
    }
    this.__events[type].push(listener);
  };

  /**
   * Implementation of {@link <a href="http://www.w3.org/TR/DOM-Level-2-Events/events.html#Events-registration">DOM 2 EventTarget Interface</a>}
   *
   * @param {string} type
   * @param {function} listener
   * @param {boolean} useCapture
   * @return void
   */
  WebSocket.prototype.removeEventListener = function(type, listener, useCapture) {
    if (!(type in this.__events)) return;
    var events = this.__events[type];
    for (var i = events.length - 1; i >= 0; --i) {
      if (events[i] === listener) {
        events.splice(i, 1);
        break;
      }
    }
  };

  /**
   * Implementation of {@link <a href="http://www.w3.org/TR/DOM-Level-2-Events/events.html#Events-registration">DOM 2 EventTarget Interface</a>}
   *
   * @param {Event} event
   * @return void
   */
  WebSocket.prototype.dispatchEvent = function(event) {
    var events = this.__events[event.type] || [];
    for (var i = 0; i < events.length; ++i) {
      events[i](event);
    }
    var handler = this["on" + event.type];
    if (handler) handler(event);
  };

  /**
   * Handles an event from Flash.
   * @param {Object} flashEvent
   */
  WebSocket.prototype.__handleEvent = function(flashEvent) {
    if ("readyState" in flashEvent) {
      this.readyState = flashEvent.readyState;
    }

    var jsEvent;
    if (flashEvent.type == "open" || flashEvent.type == "error") {
      jsEvent = this.__createSimpleEvent(flashEvent.type);
    } else if (flashEvent.type == "close") {
      // TODO implement jsEvent.wasClean
      jsEvent = this.__createSimpleEvent("close");
    } else if (flashEvent.type == "message") {
      var data = decodeURIComponent(flashEvent.message);
      jsEvent = this.__createMessageEvent("message", data);
    } else {
      throw "unknown event type: " + flashEvent.type;
    }

    this.dispatchEvent(jsEvent);
  };

  WebSocket.prototype.__createSimpleEvent = function(type) {
    if (document.createEvent && window.Event) {
      var event = document.createEvent("Event");
      event.initEvent(type, false, false);
      return event;
    } else {
      return {type: type, bubbles: false, cancelable: false};
    }
  };

  WebSocket.prototype.__createMessageEvent = function(type, data) {
    if (document.createEvent && window.MessageEvent && !window.opera) {
      var event = document.createEvent("MessageEvent");
      event.initMessageEvent("message", false, false, data, null, null, window, null);
      return event;
    } else {
      // IE and Opera, the latter one truncates the data parameter after any 0x00 bytes.
      return {type: type, data: data, bubbles: false, cancelable: false};
    }
  };

  /**
   * Define the WebSocket readyState enumeration.
   */
  WebSocket.CONNECTING = 0;
  WebSocket.OPEN = 1;
  WebSocket.CLOSING = 2;
  WebSocket.CLOSED = 3;

  WebSocket.__flash = null;
  WebSocket.__instances = {};
  WebSocket.__tasks = [];
  WebSocket.__nextId = 0;

  /**
   * Load a new flash security policy file.
   * @param {string} url
   */
  WebSocket.loadFlashPolicyFile = function(url){
    WebSocket.__addTask(function() {
      WebSocket.__flash.loadManualPolicyFile(url);
    });
  };

  /**
   * Loads WebSocketMain.swf and creates WebSocketMain object in Flash.
   */
  WebSocket.__initialize = function() {
    if (WebSocket.__flash) return;
    if (!document.body) {
      if (window.addEventListener) {
        window.addEventListener("load", WebSocket.__initialize, false);
      } else {
        window.attachEvent("onload", WebSocket.__initialize);
      }
      return;
    }

    if (WebSocket.__swfLocation) {
      // For backword compatibility.
      window.WEB_SOCKET_SWF_LOCATION = WebSocket.__swfLocation;
    }
    if (!window.WEB_SOCKET_SWF_LOCATION) {
      console.error("[WebSocket] set WEB_SOCKET_SWF_LOCATION to location of WebSocketMain.swf");
      return;
    }
    var container = document.createElement("div");
    container.id = "webSocketContainer";
    // Hides Flash box. We cannot use display: none or visibility: hidden because it prevents
    // Flash from loading at least in IE. So we move it out of the screen at (-100, -100).
    // But this even doesn't work with Flash Lite (e.g. in Droid Incredible). So with Flash
    // Lite, we put it at (0, 0). This shows 1x1 box visible at left-top corner but this is
    // the best we can do as far as we know now.
    container.style.position = "absolute";
    if (WebSocket.__isFlashLite()) {
      container.style.left = "0px";
      container.style.top = "0px";
    } else {
      container.style.left = "-100px";
      container.style.top = "-100px";
    }
    var holder = document.createElement("div");
    holder.id = "webSocketFlash";
    container.appendChild(holder);
    document.body.appendChild(container);
    // See this article for hasPriority:
    // http://help.adobe.com/en_US/as3/mobile/WS4bebcd66a74275c36cfb8137124318eebc6-7ffd.html
    swfobject.embedSWF(
      WEB_SOCKET_SWF_LOCATION,
      "webSocketFlash",
      "1" /* width */,
      "1" /* height */,
      "10.0.0" /* SWF version */,
      null,
      null,
      {hasPriority: true, swliveconnect : true, allowScriptAccess: "always"},
      null,
      function(e) {
        if (!e.success) {
          console.error("[WebSocket] swfobject.embedSWF failed");
        }
      });
  };

  /**
   * Called by Flash to notify JS that it's fully loaded and ready
   * for communication.
   */
  WebSocket.__onFlashInitialized = function() {
    // We need to set a timeout here to avoid round-trip calls
    // to flash during the initialization process.
    setTimeout(function() {
      WebSocket.__flash = document.getElementById("webSocketFlash");
      WebSocket.__flash.setCallerUrl(location.href);
      WebSocket.__flash.setDebug(!!window.WEB_SOCKET_DEBUG);
      for (var i = 0; i < WebSocket.__tasks.length; ++i) {
        WebSocket.__tasks[i]();
      }
      WebSocket.__tasks = [];
    }, 0);
  };

  /**
   * Called by Flash to notify WebSockets events are fired.
   */
  WebSocket.__onFlashEvent = function() {
    setTimeout(function() {
      try {
        // Gets events using receiveEvents() instead of getting it from event object
        // of Flash event. This is to make sure to keep message order.
        // It seems sometimes Flash events don't arrive in the same order as they are sent.
        var events = WebSocket.__flash.receiveEvents();
        for (var i = 0; i < events.length; ++i) {
          WebSocket.__instances[events[i].webSocketId].__handleEvent(events[i]);
        }
      } catch (e) {
        console.error(e);
      }
    }, 0);
    return true;
  };

  // Called by Flash.
  WebSocket.__log = function(message) {
    console.log(decodeURIComponent(message));
  };

  // Called by Flash.
  WebSocket.__error = function(message) {
    console.error(decodeURIComponent(message));
  };

  WebSocket.__addTask = function(task) {
    if (WebSocket.__flash) {
      task();
    } else {
      WebSocket.__tasks.push(task);
    }
  };

  /**
   * Test if the browser is running flash lite.
   * @return {boolean} True if flash lite is running, false otherwise.
   */
  WebSocket.__isFlashLite = function() {
    if (!window.navigator || !window.navigator.mimeTypes) {
      return false;
    }
    var mimeType = window.navigator.mimeTypes["application/x-shockwave-flash"];
    if (!mimeType || !mimeType.enabledPlugin || !mimeType.enabledPlugin.filename) {
      return false;
    }
    return mimeType.enabledPlugin.filename.match(/flashlite/i) ? true : false;
  };

  if (!window.WEB_SOCKET_DISABLE_AUTO_INITIALIZATION) {
    WebSocket.__initialize();
  }

})();
(function(window) {

function utf8_encode (argString) {
    // http://kevin.vanzonneveld.net
    // +   original by: Webtoolkit.info (http://www.webtoolkit.info/)
    // +   improved by: Kevin van Zonneveld (http://kevin.vanzonneveld.net)
    // +   improved by: sowberry
    // +    tweaked by: Jack
    // +   bugfixed by: Onno Marsman
    // +   improved by: Yves Sucaet
    // +   bugfixed by: Onno Marsman
    // +   bugfixed by: Ulrich
    // +   bugfixed by: Rafal Kukawski
    // *     example 1: utf8_encode('Kevin van Zonneveld');
    // *     returns 1: 'Kevin van Zonneveld'

    if (argString === null || typeof argString === "undefined") {
        return "";
    }

    var string = (argString + ''); // .replace(/\r\n/g, "\n").replace(/\r/g, "\n");
    var utftext = "",
        start, end, stringl = 0;

    start = end = 0;
    stringl = string.length;
    for (var n = 0; n < stringl; n++) {
        var c1 = string.charCodeAt(n);
        var enc = null;

        if (c1 < 128) {
            end++;
        } else if (c1 > 127 && c1 < 2048) {
            enc = String.fromCharCode((c1 >> 6) | 192) + String.fromCharCode((c1 & 63) | 128);
        } else {
            enc = String.fromCharCode((c1 >> 12) | 224) + String.fromCharCode(((c1 >> 6) & 63) | 128) + String.fromCharCode((c1 & 63) | 128);
        }
        if (enc !== null) {
            if (end > start) {
                utftext += string.slice(start, end);
            }
            utftext += enc;
            start = end = n + 1;
        }
    }

    if (end > start) {
        utftext += string.slice(start, stringl);
    }

    return utftext;
}

function utf8_decode (str_data) {
    // Converts a UTF-8 encoded string to ISO-8859-1
    //
    // version: 1103.1210
    // discuss at: http://phpjs.org/functions/utf8_decode
    // +   original by: Webtoolkit.info (http://www.webtoolkit.info/)
    // +      input by: Aman Gupta
    // +   improved by: Kevin van Zonneveld (http://kevin.vanzonneveld.net)
    // +   improved by: Norman "zEh" Fuchs
    // +   bugfixed by: hitwork
    // +   bugfixed by: Onno Marsman
    // +      input by: Brett Zamir (http://brett-zamir.me)
    // +   bugfixed by: Kevin van Zonneveld (http://kevin.vanzonneveld.net)
    // *     example 1: utf8_decode('Kevin van Zonneveld');
    // *     returns 1: 'Kevin van Zonneveld'
    var tmp_arr = [],
        i = 0,
        ac = 0,
        c1 = 0,
        c2 = 0,
        c3 = 0;

    str_data += '';

    while (i < str_data.length) {
        c1 = str_data.charCodeAt(i);
        if (c1 < 128) {
            tmp_arr[ac++] = String.fromCharCode(c1);
            i++;
        } else if (c1 > 191 && c1 < 224) {
            c2 = str_data.charCodeAt(i + 1);
            tmp_arr[ac++] = String.fromCharCode(((c1 & 31) << 6) | (c2 & 63));
            i += 2;
        } else {
            c2 = str_data.charCodeAt(i + 1);
            c3 = str_data.charCodeAt(i + 2);
            tmp_arr[ac++] = String.fromCharCode(((c1 & 15) << 12) | ((c2 & 63) << 6) | (c3 & 63));
            i += 3;
        }
    }

    return tmp_arr.join('');
}

function base64_encode (data) {
    // http://kevin.vanzonneveld.net
    // +   original by: Tyler Akins (http://rumkin.com)
    // +   improved by: Bayron Guevara
    // +   improved by: Thunder.m
    // +   improved by: Kevin van Zonneveld (http://kevin.vanzonneveld.net)
    // +   bugfixed by: Pellentesque Malesuada
    // +   improved by: Kevin van Zonneveld (http://kevin.vanzonneveld.net)
    // -    depends on: utf8_encode
    // *     example 1: base64_encode('Kevin van Zonneveld');
    // *     returns 1: 'S2V2aW4gdmFuIFpvbm5ldmVsZA=='
    // mozilla has this native
    // - but breaks in 2.0.0.12!
    //if (typeof this.window['atob'] == 'function') {
    //    return atob(data);
    //}
    var b64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=";
    var o1, o2, o3, h1, h2, h3, h4, bits, i = 0,
        ac = 0,
        enc = "",
        tmp_arr = [];

    if (!data) {
        return data;
    }

    data = utf8_encode(data + '');

    do { // pack three octets into four hexets
        o1 = data.charCodeAt(i++);
        o2 = data.charCodeAt(i++);
        o3 = data.charCodeAt(i++);

        bits = o1 << 16 | o2 << 8 | o3;

        h1 = bits >> 18 & 0x3f;
        h2 = bits >> 12 & 0x3f;
        h3 = bits >> 6 & 0x3f;
        h4 = bits & 0x3f;

        // use hexets to index into b64, and append result to encoded string
        tmp_arr[ac++] = b64.charAt(h1) + b64.charAt(h2) + b64.charAt(h3) + b64.charAt(h4);
    } while (i < data.length);

    enc = tmp_arr.join('');

    switch (data.length % 3) {
    case 1:
        enc = enc.slice(0, -2) + '==';
        break;
    case 2:
        enc = enc.slice(0, -1) + '=';
        break;
    }

    return enc;
}

function base64_decode (data) {
    // http://kevin.vanzonneveld.net
    // +   original by: Tyler Akins (http://rumkin.com)
    // +   improved by: Thunder.m
    // +      input by: Aman Gupta
    // +   improved by: Kevin van Zonneveld (http://kevin.vanzonneveld.net)
    // +   bugfixed by: Onno Marsman
    // +   bugfixed by: Pellentesque Malesuada
    // +   improved by: Kevin van Zonneveld (http://kevin.vanzonneveld.net)
    // +      input by: Brett Zamir (http://brett-zamir.me)
    // +   bugfixed by: Kevin van Zonneveld (http://kevin.vanzonneveld.net)
    // -    depends on: utf8_decode
    // *     example 1: base64_decode('S2V2aW4gdmFuIFpvbm5ldmVsZA==');
    // *     returns 1: 'Kevin van Zonneveld'
    // mozilla has this native
    // - but breaks in 2.0.0.12!
    //if (typeof this.window['btoa'] == 'function') {
    //    return btoa(data);
    //}
    var b64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=";
    var o1, o2, o3, h1, h2, h3, h4, bits, i = 0,
        ac = 0,
        dec = "",
        tmp_arr = [];

    if (!data) {
        return data;
    }

    data += '';

    do { // unpack four hexets into three octets using index points in b64
        h1 = b64.indexOf(data.charAt(i++));
        h2 = b64.indexOf(data.charAt(i++));
        h3 = b64.indexOf(data.charAt(i++));
        h4 = b64.indexOf(data.charAt(i++));

        bits = h1 << 18 | h2 << 12 | h3 << 6 | h4;

        o1 = bits >> 16 & 0xff;
        o2 = bits >> 8 & 0xff;
        o3 = bits & 0xff;

        if (h3 == 64) {
            tmp_arr[ac++] = String.fromCharCode(o1);
        } else if (h4 == 64) {
            tmp_arr[ac++] = String.fromCharCode(o1, o2);
        } else {
            tmp_arr[ac++] = String.fromCharCode(o1, o2, o3);
        }
    } while (i < data.length);

    dec = tmp_arr.join('');
    dec = utf8_decode(dec);

    return dec;
}

window.Twilio = window.Twilio || {};
window.Twilio._phpjs_atob = base64_decode;
window.Twilio._phpjs_btoa = base64_encode;

})(window);
/**
 * Copyright 2010 Neuman Vong. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 *   1. Redistributions of source code must retain the above copyright notice,
 *   this list of conditions and the following disclaimer.
 *
 *   2. Redistributions in binary form must reproduce the above copyright
 *   notice, this list of conditions and the following disclaimer in the
 *   documentation and/or other materials provided with the distribution.
 */
(function(ns) {
var utils = {
    amplify: function(gain) {
        return function(sample) {
            return sample * gain;
        };
    },
    ushort: function(sample) {
        return String.fromCharCode(255 & sample,
                                   255 & sample >> 8);
    },
    ulong: function(sample) {
        return String.fromCharCode(255 & sample,
                                   255 & sample >> 8,
                                   255 & sample >> 16,
                                   255 & sample >> 24);
    },
    gcd: function(a, b) {
        while (b) {
            var a_ = a;
            a = b, b = a_ % b;
        }
        return a;
    },
    lcm: function(a, b) {
        return Math.floor(a * b / utils.gcd(a, b));
    },
    compose: function(fns) {
        return function(a) {
            for (var i = 0; i < fns.length; i++) {
                a = fns[i](a);
            }
            return a;
        };
    },
    map: function(fn, items) {
        var result = [];
        for (var i = 0; i < items.length; i++) {
            result.push(fn.call(this, items[i]));
        }
        return result;
    },
    getattr: function(attr) {
        return function(items) {
            return items[attr];
        };
    },
    zip: function() {
        if (arguments.length == 0) return [];
        var lists = Array.prototype.slice.call(arguments);
        var result = [];
        var min = Math.min.apply(null, utils.map(utils.getattr("length"), lists));
        for (var i = 0; i < min; i++) {
            result.push(utils.map(utils.getattr(i), lists));
        }
        return result;
    },
    sum: function(numbers) {
        return utils.foldl(function(a, b) { return a + b; }, numbers);
    },
    bind: function(ctx, fn) {
        return function() {
            var args = Array.prototype.slice.call(arguments);
            return fn.apply(ctx, args);
        };
    },
    foldl: function(fn, items) {
        if (items.length == 1) return items[0];
        var result = fn(items[0], items[1]);
        for (var i = 2; i < items.length; i++) {
            result = fn(result, items[i]);
        }
        return result;
    },
    mulmod: function(a, b, c) {
        return (a * b) % c;
    },
    range: function(len) {
        var result = [];
        for (var i = 0; i < len; i++) {
            result.push(i);
        }
        return result;
    }
};
function Beep(samplerate) {
    if (!(this instanceof Beep)) return new Beep(samplerate);
    if (typeof samplerate != "number" || samplerate < 1) return null;
    this.channels = 1;
    this.bitdepth = 16;
    this.samplerate = samplerate;
    this.sine = [];
    var factor = (2 * Math.PI) / parseFloat(samplerate);
    for (var n = 0; n < samplerate; n++) {
        this.sine.push(Math.sin(n * factor));
    }
}
Beep.prototype = {
    generate: function(freqs) {
        freqs = freqs instanceof Array ? freqs : [freqs];
        var map = utils.bind(this, utils.map);
        var periods = map(function(a) {
            return utils.lcm(this.samplerate, a) / a; }, freqs);
        var lcm = utils.foldl(utils.lcm, periods);
        var sample = function(time) {
            return function(freq) {
                return this.sine[utils.mulmod(time, freq, this.samplerate)];
            };
        };
        return map(function(t) { return utils.sum(map(sample(t), freqs)); },
                   utils.range(lcm));
    },
    encode: function(freqs, duration, filters) {
        freqs = freqs instanceof Array ? freqs : [freqs];
        var transforms = utils.compose(
            (filters || []).concat([utils.ushort]));
        var samples = utils.map(transforms, this.generate(freqs));
        var reps = Math.ceil(duration * this.samplerate / samples.length);
        var fulldata = new Array(reps + 1).join(samples.join(""));
        var data = fulldata.substr(0, this.samplerate * duration * 2);
        var fmtChunk = [
            ["f", "m", "t", " "].join(""),
            utils.ulong(Beep.PCM_CHUNK_SIZE),
            utils.ushort(Beep.LINEAR_QUANTIZATION),
            utils.ushort(this.channels),
            utils.ulong(this.samplerate),
            utils.ulong(this.samplerate * this.channels * this.bitdepth / 8),
            utils.ushort(this.bitdepth / 8),
            utils.ushort(this.bitdepth)
        ].join("");
        var dataChunk = [
            ["d", "a", "t", "a"].join(""),
            utils.ulong(data.length * this.channels * this.bitdepth / 8),
            data
        ].join("");
        var header = [
            ["R", "I", "F", "F"].join(""),
            utils.ulong(4 + (8 + fmtChunk.length) + (8 + dataChunk.length)),
            ["W", "A", "V", "E"].join("")
        ].join("");
        return [header, fmtChunk, dataChunk].join("");
    },
    play: function(freq, duration, filters) {
        filters = filters || [];
        var data = btoa(this.encode(freq, duration, filters));
        var audio = document.createElement("audio");
        audio.src = "data:audio/x-wav;base64," + data;
        audio.play();
    }
};
Beep.LINEAR_QUANTIZATION = 1;
Beep.PCM_CHUNK_SIZE = 16;
Beep.utils = utils;
ns.Beep = Beep;
})(window[window.NS_BEEP] || window);
(function(ns) {

function Sound(url) {
    this.id = Sound.nextId++;
    Sound.items[this.id] = this;
    this.create();
}

var audioBackend = {
    create: function() {
        this.audio = document.createElement("audio");
        this.playing = false;
    },
    buffer: function() { },
    play: function(startTime, loops) {
        if (this.playing || loops <= 0) return;
        // HACK Can't rewind. More info: stackoverflow.com/a/11004658
        if (this.audio.currentTime !== startTime) {
            try {
                this.audio.currentTime = startTime;
                if (this.audio.currentTime !== startTime) {
                    throw new Error();
                }
            } catch (_) {
                var src = this.audio.src;
                this.audio.src = "";
                this.audio.src = src;
            }
        }
        this.playing = true;
        this.audio.play();
        // HACK Can't loop. More info:
        // http://code.google.com/p/chromium/issues/detail?id=74576.
        var self = this;
        this.audio.addEventListener("ended", function loop() {
            self.audio.removeEventListener("ended", loop, false);
            if (self.playing) {
                self.playing = false;
                self.play(startTime, loops - 1);
            } else {
                self.playing = false;
            }
        }, false);
    },
    load: function(url) {
        this.audio.src = url;
    },
    stop: function() {
        this.playing = false;
    },
    destroy: function() {
        this.audio.src = "";
        delete this.audio;
    }
};

var flashBackend = {
    create: function() {
        var id = this.id;
        Sound.queue(function() {
            Sound.flash.__create(id);
        });
    },
    buffer: function(bytes) {
        var id = this.id;
        Sound.queue(function() {
            Sound.flash.__buffer(id, bytes);
        });
    },
    play: function(startTime, loops) {
        startTime = startTime || 0;
        loops = loops || 0;
        var id = this.id;
        Sound.queue(function() {
            Sound.flash.__play(id, startTime, loops);
        });
    },
    load: function(url) {
        var id = this.id;
        Sound.queue(function() {
            Sound.flash.__load(id, url);
        });
    },
    stop: function() {
        var id = this.id;
        Sound.queue(function() {
            Sound.flash.__stop(id);
        });
    },
    destroy: function() {
        var id = this.id;
        Sound.queue(function() {
            Sound.flash.__destroy(id);
            delete Sound.items[id];
        });
    }
}

var dummyBackend = {
    create: function() {},
    buffer: function(bytes) {},
    play: function(startTime, loops) {},
    load: function(url) {},
    stop: function() {},
    destroy: function() {}
}

var classMethods = {
    initializeFlash: function (options) {
        options = options || {};
        options["swfLocation"] = options["swfLocation"] || "SoundMain.swf";
        options["domId"] = options["domId"] || "__soundFlash__";

        if (Sound.flash) return;
        if (!document.body) {
            try {
                window.addEventListener("load", function() {
                    Sound.initializeFlash(options);
                }, false);
            } catch(e) {
                window.attachEvent("onload", function() {
                    Sound.initializeFlash(options);
                });
            }
            return;
        }

        var flash = document.createElement("div");
        flash.id = options["domId"];
        document.body.appendChild(flash);
        Sound.flash = flash;
        swfobject.embedSWF(
            options["swfLocation"],
            options["domId"],
            "1",
            "1",
            "10.0.0",
            null,
            { namespace: typeof NS_SOUND != "undefined" ? NS_SOUND + ".Sound"
                                                        : "Sound" },
            { hasPriority: true, allowScriptAccess: "always" },
            null,
            function(e) {
                Sound.log("Embed " +
                    (e.success ? "succeeded" : "failed"));
            }
        );
    },
    log: function(msg, obj, method) {
        if (!Sound.debug || !window.console) {
            return;
        }
        method = method || "log";
        console[method]("[Sound] " + msg);
        if (typeof obj != "undefined") {
            console[method](obj);
        }
    },
    queue: function(task) {
        if (Sound.initialized) {
            task();
        } else {
            Sound.tasks.push(task);
        }
    }
};

var flashEventHandlers = {
    __onFlashInitialized: function() {
        Sound.initialized = true;
        Sound.flash = document.getElementById(Sound.flash.id);
        setTimeout(function() {
            Sound.flash.__setDebug(Sound.debug);
            Sound.log("Initialized and ready");
            for (var i = 0; i < Sound.tasks.length; i++) {
                Sound.tasks[i]();
            }
        }, 0);
    },
    __onLog: function(msg) {
        Sound.log(msg);
    }
};

Sound.nextId = 0;
Sound.debug = false;
Sound.tasks = [];
Sound.items = {};
Sound.initialize = function(options) {
    // Priority for sounds goes to audio tag and then Flash
    // jj
    if (!options["forceFlash"] && document.createElement("audio")) {
        Sound.prototype = audioBackend;
    } else if (swfobject.hasFlashPlayerVersion("10.0.0")) {
        Sound.prototype = flashBackend;
        for (var name in classMethods) {
            Sound[name] = classMethods[name];
        }
        for (var name in flashEventHandlers) {
            Sound[name] = flashEventHandlers[name];
        }
        Sound.initializeFlash(options);
    } else {
        Sound.prototype = dummyBackend;
        if (typeof console != "undefined") {
            var log = console.error || console.log || function(){};
        }
    }
};

ns.Sound = Sound;

})(typeof NS_SOUND != "undefined" ? this[NS_SOUND] : this);
(function(ns) {

var util = require("twilio/util");

/**
 * MediaStream constructor.
 *
 * <p>Wrapper around the Flash MediaStreamMain object which encapsulates a
 * single NetConnection and two NetStream objects. The NetStream objects send
 * and receive media from a Flash Media Server.</p>
 *
 * <p>The MediaStreamMain object exposes utilities to configure the Microphone
 * and display the security settings dialog.</p>
 *
 * @constructor
 */
function MediaStream(encrypt, host) {


    this.__id = MediaStream.__nextId++;

    /** @ignore */
    var noop = function() { };

    /**
     * Invoked when the NetConnection object successfully connects.
     *
     * @function
     * @event
     */
    this.onopen = noop;

    /**
     * Invoked when an error is received.
     *
     * @function
     * @event
     * @param {object} error An error object
     */
    this.onerror = noop;

    /**
     * Invoked when a NetConnection object disconnects.
     *
     * @function
     * @event
     * @param {object} error An error object
     */
    this.onclose = noop;

    this._uri = (encrypt ? "rtmps" : "rtmp") + "://" + host + "/chunder";

    MediaStream.__instances[this.__id] = this;
}

MediaStream.prototype = {
    openHelper: function(next, simpleDialog, noMicLevel, showDialog, showSettings) {
        MediaStream.__queue(function() {
            var noMics = MediaStream.getMicrophones().length == noMicLevel;
            if (simpleDialog) {
                if (!noMics && MediaStream.isMicMuted()) showDialog();
                next();
            } else {
                if (noMics) next("No microphone is available");
                else if (!MediaStream.isMicMuted()) next();
                else {
                    showSettings(function() {
                        if (MediaStream.isMicMuted()) {
                            next("User denied access to microphone.", 31208);
                        } else next();
                    });
                }
            }
        });
    },
    uri: function() {
        return this._uri;
    },
    /**
     * Opens a new connection to the Flash Media Server. Takes an arbitrary
     * list of parameters, the first of which must be the URI of the
     * application instance. For example:
     *
     * @example mediaStream.open("rtmp://localhost/mycoolapp", ...);
     * @param *args Arguments to pass to NetStream.connect
     */
    open: function() {
        var self = this;
        var args = Array.prototype.slice.call(arguments);
        MediaStream.__queue(function() {
            MediaStream.__flash.open.apply(MediaStream.__flash,
                                           [self.__id].concat(args));
        });
    },
    /**
     * Wraps #call on the NetConnection.
     *
     * @example mediaStrea.exec("doSomething", "arg1");
     * @param *args Arguments to pass to NetStream.call
     */
    exec: function() {
        var self = this;
        var args = Array.prototype.slice.call(arguments);
        MediaStream.__queue(function() {
            MediaStream.__flash.exec.apply(MediaStream.__flash,
                                           [self.__id].concat(args));
        });
    },
    /**
     * Closes the connection.
     */
    close: function() {
        var self = this;
        MediaStream.__queue(function() {
            MediaStream.__flash.close(self.__id);
        });
    },
    /**
     * Begin receiving media.
     *
     * @example mediaStream.play("output");
     */
    play: function() {
        var self = this;
        var args = Array.prototype.slice.call(arguments);
        MediaStream.__queue(function() {
            MediaStream.__flash.playStream.apply(MediaStream.__flash,
                                           [self.__id].concat(args));
        });
    },
    /**
     * Begin publishing media.
     *
     * @example mediaStream.publish("input", "live");
     *
     * @param {string} name An identifier for the stream.
     * @param {string} type Defaults to "live".
     */
    publish: function(name, type) {
        var self = this;
        MediaStream.__queue(function() {
            MediaStream.__flash.publish(self.__id, name, type);
        });
    },
    /**
     * Attach a Microphone object to the MediaStream.
     *
     * @example mediaStream.attachAudio();
     *
     * @param {int} index The index of a Microphone, or null.
     */
    attachAudio: function(index) {
        var self = this;
        MediaStream.__queue(function() {
            MediaStream.__flash.attachAudio(self.__id, index);
        });
    },
    /**
     * Detach Microphone object from the MediaStream, effectively disabling
     * audio publishing.
     *
     * @example mediaStream.detachAudio();
     *
     * @param {int} index The index of a Microphone, or null.
     */
    detachAudio: function() {
        var self = this;
        MediaStream.__queue(function() {
            MediaStream.__flash.detachAudio(self.__id);
        });
    },
    /**
     * Handle events.
     */
    __handleEvent: function(event) {
        switch (event.type) {
            case "gatewayError":
            case "securityError":
            case "asyncError":
            case "ioError":
                this.onerror.call(this, event);
                break;
            case "netStatus":
                this.__handleNetStatus(event);
                break;
        }
    },
    __handleNetStatus: function(event) {
        MediaStream.log("Event info code: " + event.info.code);
        switch (event.info.code) {
            case "NetConnection.Connect.Failed":
            case "NetConnection.Connect.Rejected":
                MediaStream.log("Connection failed or was rejected");
                this.onerror.call(this, event);
                break;
            case "NetConnection.Connect.Closed":
                MediaStream.log("Connection closed");
                this.onclose.call(this, event);
                break;
            case "NetConnection.Connect.Success":
                MediaStream.log("Connection established");
                this.onopen.call(this);
                break;
            default:
                MediaStream.log("Unexpected event: " + event.info.code);
                break;
        }
    }
};

function defaultLoader(flash, embedCallback) {
    if (!document.body) {
        var callback = function() { defaultLoader(flash, embedCallback); };
        try {
            window.addEventListener("load", callback, false);
        } catch(e) {
            window.attachEvent("onload", callback);
        }
        return;
    }
    var container = document.createElement("div");
    container.style.position = "absolute";
    container.appendChild(flash);
    document.body.appendChild(container);
    embedCallback();
};

var classMethods = {
    /**
     * Run a task or queue it if __flash is not ready.
     *
     * @param {function} task The task to run.
     */
    __queue: function(task) {
        if (MediaStream.initialized) {
            task();
        } else {
            MediaStream.__tasks.push(task);
        }
    },
    /**
     * Embed the Flash object and instantiate the MediaStreamMain object.
     *
     * @param {array} options Initialization options.
     */
    initialize: function(options) {
        if (!swfobject.hasFlashPlayerVersion("10.0.0"))
            throw new util.Exception("Flash Player >= 10.0.0 is required.");

        if (MediaStream.__flash) return;
        options = options || {};
        options["swfLocation"] = options["swfLocation"] || "MediaStreamMain.swf";
        options["domId"] = options["domId"] || "__connectionFlash__";
        options["loader"] = options["loader"] || defaultLoader;
        if (!document.body) {
            try {
                window.addEventListener("load", function() {
                    MediaStream.initialize(options);
                }, false);
            } catch(e) {
                window.attachEvent("onload", function() {
                    MediaStream.initialize(options);
                });
            }
            return;
        }

        var flash = document.createElement("div");
        flash.id = options["domId"];

        options["loader"](flash, function() {
            MediaStream.__flash = flash;

            var flashVars = { };
            if ("objectEnc" in options) {
                flashVars["objectEnc"] = options["objectEnc"];
            }
            // MediaStreamMain uses the value of namespace to invoke methods
            // declared in Javascript land. Some of the methods it invokes are
            // __onLog which will end up being accessible via
            // MediaStream.__onLog.
            flashVars["namespace"] = NS_MEDIASTREAM ?
                NS_MEDIASTREAM + ".MediaStream" : "MediaStream";

            swfobject.embedSWF(
                options["swfLocation"],
                options["domId"],
                "215",
                "138",
                "10.0.0",
                null,
                flashVars,
                { hasPriority: true, allowScriptAccess: "always" },
                null,
                function(e) {
                    MediaStream.log("Embed " +
                        (e.success ? "succeeded" : "failed"));
                }
            );
        });
    },
    /**
     * Sets microphone gain.
     *
     * @param {int} value Gain amount (0-100)
     */
    setMicrophoneGain: function(value) {
        MediaStream.__queue(function() {
            try {
                MediaStream.__flash.setMicrophoneGain(value);
            } catch (e) {
                MediaStream.log(e);
            }
        });
    },
    /**
     * Sets the microphone.
     *
     * @param {int} index Name of microphone
     */
    setMicrophone: function(index, enhanced) {
        MediaStream.__queue(function() {
            MediaStream.__flash.setMicrophone(index, enhanced);
        });
    },
    /**
     * The name of the current microphone.
     *
     * @return {int}
     */
    getMicrophone: function() {
        return MediaStream.initialized
            ? MediaStream.__flash.getMicrophone()
            : null;
    },
    /**
     * A list of available Microphones.
     *
     * @return {Array}
     */
    getMicrophones: function() {
        return MediaStream.initialized
            ? MediaStream.__flash.getMicrophones()
            : [];
    },
    /**
     * Sets echo suppression.
     *
     * @param {boolean} enabled Uses echo suppression if true
     */
    setUseEchoSuppression: function(enabled) {
        MediaStream.__queue(function() {
            try {
                MediaStream.__flash.setUseEchoSupression(enabled);
            } catch (e) {
                MediaStream.log(e);
            }
        });
    },
    /**
     * Sets silence level.
     *
     * This function sets options for the Flash noise gate. The gate is open
     * when the amount of sound exceeds the level specified by {level}, and the
     * gate closes when the amount of sound is under the level threshold for an
     * elapsed time of {{timeout}} milliseconds.
     *
     * @param {int} level Amount of sound required to activate the mic
     * @param {int} timeout Amount of time to wait before mic deactivates
     */
    setSilenceLevel: function(level, timeout) {
        MediaStream.__queue(function() {
            try {
                MediaStream.__flash.setSilenceLevel(level, timeout);
            } catch (e) {
                MediaStream.log(e);
            }
        });
    },
    /**
     * Displays Flash security settings dialog.
     */
    showSettings: function() {
        MediaStream.__queue(function() {
            MediaStream.__flash.showSettings();
        });
    },

    /**
     * Is the microphone muted?
     *
     * @return {boolean|null} Returns null if microphone is unavailable
     */
    isMicMuted: function() {
        try {
            return MediaStream.__flash.isMicMuted();
        } catch (e) {
            if (e instanceof TypeError) return;
            throw e;
        }
    },
    /**
     * Log a message to the console.
     *
     * @param {string} msg The message to display
     * @param obj Additional object to include in the log
     * @param {string} method Defaults to log
     */
    log: function(msg, obj, method) {
        if (!MediaStream.__debug || !window.console) {
            return;
        }
        method = method || "log";
        console[method]("[MediaStream] " + msg);
        if (typeof obj != "undefined") {
            console[method](obj);
        }
    }
};

var flashEventHandlers = {
    __onFlashInitialized: function() {
        MediaStream.__flash = document.getElementById(MediaStream.__flash.id);
        setTimeout(function() {
            MediaStream.initialized = true;
            MediaStream.__flash.setDebug(MediaStream.__debug);
            if (/Mac OS X.*Chrome\/2[34]/.test(navigator.userAgent)) {
                MediaStream.setMicrophone(-1, false);
            } else {
                MediaStream.setMicrophone(-1, true);
            }
            var mic = MediaStream.getMicrophone();
            MediaStream.log(mic ? "Using " + mic : "No mics available");
            MediaStream.setMicrophoneGain(75);
            for (var i = 0; i < MediaStream.__tasks.length; i++) {
                MediaStream.__tasks[i].call();
            }
        }, 0);
    },
    __onMediaStreamEvent: function() {
        setTimeout(function() {
            var events = MediaStream.__flash.dequeueEvents();
            for (var i = 0; i < events.length; i++) {
                try {
                    MediaStream.log("Received event: " + events[i].type);
                    MediaStream
                        .__instances[events[i].mediaStreamId]
                        .__handleEvent(events[i]);
                } catch (e) {
                    MediaStream.log(
                        "Error while processing " + events[i].type + ": "
                        + e.message, e, "error");
                }
            }
        }, 0);
    },
    __onLog: function(le) {
        if (le.level == "error") {
            MediaStream.log(le.message, undefined, "error");
        } else {
            MediaStream.log(le.message);
        }
    }
};

for (var name in classMethods) {
    MediaStream[name] = classMethods[name];
}

for (var name in flashEventHandlers) {
    MediaStream[name] = flashEventHandlers[name];
}

MediaStream.__nextId = 0;
MediaStream.__flash = null;
MediaStream.__instances = {};
MediaStream.__tasks = [];
MediaStream.__debug = false;
MediaStream.initialized = false;

/** @constant */
MediaStream.AMF0 = 0;
/** @constant */
MediaStream.AMF3 = 3;

ns.MediaStream = MediaStream;

})(typeof NS_MEDIASTREAM != "undefined" ? this[NS_MEDIASTREAM] : this);
    var a = document.createElement("audio");
    var forceFlash = true;
    try {
        forceFlash = !(a.canPlayType &&
                       a.canPlayType("audio/mpeg").replace(/no/, ""));
    } catch(e) { }
    Twilio.Sound.initialize({ swfLocation: TWILIO_ROOT + "SoundMain.swf"
                            , forceFlash: forceFlash });
    // We have to call later because we don't yet have the token from which
    // to extract the subdomain of the SWF URI. This security measure is to
    // ensure the end-user has an opportunity to deny access to their
    // microphone. When we find an alternative (e.g. Flash SharedObject),
    // we should unwrap and remove __afterSetup functionality.
    var Device = require("twilio/device").Device;
    Device.__afterSetup(function(token, options) {
        var rtc = require("twilio/rtc");
        if (!rtc.enabled()) {
            var decode = require("twilio/util").decode;
            var factories = require("twilio/factories")
            var MediaStream = factories.getClass("vendor/mediastream/mediastream",
                                                 "MediaStream");
            var yoink = function(token, root) {
                if (!token) return root;
                var urlRe = /^(\w+):\/\/([^/]*)(.*)?/;
                var matches = root.match(urlRe);
                if (!matches) return root;
                var prot = matches[1],
                    host = matches[2],
                    path = matches[3];
                if (!/twilio.com$/.test(host.split(":")[0])) return root;
                var iss = decode(token)["iss"];
                if (!iss) return root;
                return prot + "://" + iss.toLowerCase() + "." + host + path;
            };
            MediaStream.initialize({
                objectEnc: MediaStream.AMF0,
                swfLocation: yoink(token, TWILIO_ROOT) + "MediaStreamMain.swf",
                loader: function(c, f) { Device.dialog.insert(c, f) }
            });
        }
    });
    var exports = require("twilio");
    exports.Sound = Twilio.Sound;
    exports.MediaStream = Twilio.MediaStream;
    exports._phpjs_atob = Twilio._phpjs_atob;
    exports._phpjs_btoa = Twilio._phpjs_btoa;
    return exports;
})());