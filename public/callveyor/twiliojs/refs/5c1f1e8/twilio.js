(function e(t,n,r){function s(o,u){if(!n[o]){if(!t[o]){var a=typeof require=="function"&&require;if(!u&&a)return a(o,!0);if(i)return i(o,!0);var f=new Error("Cannot find module '"+o+"'");throw f.code="MODULE_NOT_FOUND",f}var l=n[o]={exports:{}};t[o][0].call(l.exports,function(e){var n=t[o][1][e];return s(n?n:e)},l,l.exports,e,t,n,r)}return n[o].exports}var i=typeof require=="function"&&require;for(var o=0;o<r.length;o++)s(r[o]);return s})({1:[function(require,module,exports){
Twilio = (function(loadedTwilio) {
var Twilio = loadedTwilio || function Twilio() { };
function extend(M) { for (var k in M) Twilio[k] = M[k] }
extend((function(){
    var util = require('./twilio/util');
    var VERSION = util.getSDKVersion();

    // Hack for determining asset path.
    var TWILIO_ROOT = typeof TWILIO_ROOT != "undefined" ?  TWILIO_ROOT : (function(){
        var prot = location.protocol || "http:",
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

    // Needed for sounds.
    util.setTwilioRoot(TWILIO_ROOT);

    // Set vendor library settings constants.
    // TODO(mroberts): I'm not sure that these are even necessary.
    var NS_SOUND = "Twilio",
        NS_MEDIASTREAM = "Twilio",
        WEB_SOCKET_SWF_LOCATION = TWILIO_ROOT + "WebSocket.swf";

    // web-socket.js assumes the global root is window.
    if (typeof window !== 'undefined') window.WEB_SOCKET_SWF_LOCATION = WEB_SOCKET_SWF_LOCATION;

    // Initialize flash libraries.
    var a = document.createElement("audio");
    var forceFlash = true;
    try {
        forceFlash = !(a.canPlayType &&
                       (a.canPlayType("audio/mpeg").replace(/no/, "")
                       || a.canPlayType('audio/ogg;codecs="vorbis"').replace(/no/, "")));
    } catch(e) { }
    Twilio.Sound = require('../vendor/sound/sound').Sound;
    Twilio.Sound.initialize({ swfLocation: TWILIO_ROOT + "SoundMain.swf"
                            , forceFlash: forceFlash });
    // We have to call later because we don't yet have the token from which
    // to extract the subdomain of the SWF URI. This security measure is to
    // ensure the end-user has an opportunity to deny access to their
    // microphone. When we find an alternative (e.g. Flash SharedObject),
    // we should unwrap and remove __afterSetup functionality.
    var Device = require("./twilio/device").Device;
    var MediaStream = require('../vendor/mediastream/mediastream').MediaStream;
    Device.__afterSetup(function(token, options) {
        var rtc = require("./twilio/rtc");
        if (!rtc.enabled()) {
            var decode = util.decode;
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

    // Fin.
    var exports = require("./twilio");
    exports.Sound = Twilio.Sound;
    exports.MediaStream = MediaStream;
    return exports;
})());
return Twilio;
})(typeof Twilio !== 'undefined' ? Twilio : null);

},{"../vendor/mediastream/mediastream":35,"../vendor/sound/sound":36,"./twilio":2,"./twilio/device":4,"./twilio/rtc":14,"./twilio/util":21}],2:[function(require,module,exports){
exports.Device = require("./twilio/device").Device;
exports.EventStream = require("./twilio/eventstream").EventStream;
exports.PStream = require("./twilio/pstream").PStream;
exports.Connection = require("./twilio/connection").Connection;

// Remove this once require() is completely phased out.
var util = require('./twilio/util');
exports.require = function(path) {
  var warning = 'Twilio.require() is a private function and will be removed!';
  switch (path) {
    // There's only one "valid" use of require() while we're phasing it out.
    case 'twilio/rtc':
      // And we'll still warn if it is used.
      if (typeof console !== 'undefined') {
        if (typeof console.error === 'function') {
          console.error(warning);
        } else if (typeof console.warn === 'function') {
          console.warn(warning);
        } else if (typeof console.log === 'function') {
          console.log(warning);
        }
      }
      return {
        enabled: function() {
          var Device = exports.Device;
          return Device.getMediaEngine() === Device.getMediaEngine.WEBRTC;
        }
      };
    // Otherwise, we throw an Exception.
    default:
      throw new util.Exception(warning);
  }
};

},{"./twilio/connection":3,"./twilio/device":4,"./twilio/eventstream":6,"./twilio/pstream":13,"./twilio/util":21}],3:[function(require,module,exports){
var EventEmitter = require('events').EventEmitter;
var util = require('util');
var twutil = require('./util');
var log = require("./log");
var Exception = require("./util").Exception;
var rtc = require("./rtc");

var DTMF_INTER_TONE_GAP = 70;
var DTMF_PAUSE_DURATION = 500;
var DTMF_TONE_DURATION = 160;

/**
 * Constructor for Connections.
 *
 * @exports Connection as Twilio.Connection
 * @memberOf Twilio
 * @borrows EventEmitter#addListener as #addListener
 * @borrows EventEmitter#emit as #emit
 * @borrows EventEmitter#removeListener as #removeListener
 * @borrows EventEmitter#hasListener as #hasListener
 * @borrows Twilio.mixinLog-log as #log
 * @constructor
 * @param {object} device The device associated with this connection
 * @param {object} message Data to send over the connection
 * @param {object} [options]
 * @config {string} [chunder="chunder.prod.twilio.com"] Hostname of chunder server
 * @config {boolean} [debug=false] Enable debugging
 * @config {boolean} [encrypt=false] Encrypt media
 * @config {MediaStream} [mediaStream] Use this MediaStream object
 * @config {string} [token] The Twilio capabilities JWT
 */
function Connection(device, message, options) {
    if (!(this instanceof Connection)) {
        return new Connection(device, message, options);
    }
    twutil.monitorEventEmitter('Twilio.Connection', this);
    this.device = device;
    this.message = message || {};

    options = options || {};
    var defaults = {
        logPrefix: "[Connection]",
        mediaStreamFactory: rtc.PeerConnection,
        offerSdp: null,
        debug: false,
        encrypt: false,
        audioConstraints: device.options['audioConstraints']
    };
    for (var prop in defaults) {
        if (prop in options) continue;
        options[prop] = defaults[prop];
    }

    this.options = options;
    this.parameters = {};
    this._status = this.options["offerSdp"] ? "pending" : "closed";
    this.sendHangup = true;

    log.mixinLog(this, this.options["logPrefix"]);
    this.log.enabled = this.options["debug"];
    this.log.warnings = this.options['warnings'];

    // These are event listeners we need to remove from PStream.
    function noop(){}
    this._onCancel = noop;
    this._onHangup = noop;
    this._onAnswer = function(payload) {
        if (typeof payload.callsid !== 'undefined') {
            self.parameters.CallSid = payload.callsid;
            self.mediaStream.callSid = payload.callsid;
        }
    };

    /**
     * Reference to the Twilio.MediaStream object.
     * @type Twilio.MediaStream
     */
    this.mediaStream = new this.options["mediaStreamFactory"](
        this.options["encrypt"],
        this.device);

    var self = this;

    this.mediaStream.onerror = function(e) {
        if (e.disconnect === true) {
            self.disconnect(e.info && e.info.message);
        }
        var error = {
            code: e.info.code,
            message: e.info.message || "Error with mediastream",
            info: e.info,
            connection: self
        };
        self.log("Received an error from MediaStream:", e);
        self.emit("error", error);
    };

    this.mediaStream.onopen = function() {
        // NOTE(mroberts): While this may have been happening in previous
        // versions of Chrome, since Chrome 45 we have seen the
        // PeerConnection's onsignalingstatechange handler invoked multiple
        // times in the same signalingState "stable". When this happens, we
        // invoke this onopen function. If we invoke it twice without checking
        // for _status "open", we'd accidentally close the PeerConnection.
        //
        // See <https://code.google.com/p/webrtc/issues/detail?id=4996>.
        if (self._status === "open") {
            return;
        } else if (self._status === "connecting") {
            self._status = "open";
            //self.mediaStream.publish("input", "live"); //only for flash
            self.mediaStream.attachAudio();
            self.mediaStream.play("output"); //only for flash
            self.emit("accept", self);
        } else {
            // call was probably canceled sometime before this
            self.mediaStream.close();
        }
    };

    this.mediaStream.onclose = function() {
        self._status = "closed";
        if (self.device.sounds.disconnect()) {
            self.device.soundcache.play("disconnect");
        }
        self.emit("disconnect", self);
    };

    this.pstream = this.device.stream;

    this._onCancel = function(payload) {
        var callsid = payload.callsid;
        if (self.parameters.CallSid == callsid) {
            self.ignore();
            self.pstream.removeListener("cancel", self._onCancel);
        }
    };

    // NOTE(mroberts): The test "#sendDigits throws error" sets this to `null`.
    if (this.pstream)
        this.pstream.addListener("cancel", this._onCancel);

    this.on('error', function() {
        if (self.pstream && self.pstream.status === 'disconnected') {
            cleanupEventListeners(self);
        }
    });

    this.on('disconnect', function() {
        cleanupEventListeners(self);
    });

    return this;
}

util.inherits(Connection, EventEmitter);

/**
 * @return {string}
 */
Connection.toString = function() {
    return "[Twilio.Connection class]";
};

    /**
     * @return {string}
     */
Connection.prototype.toString = function() {
        return "[Twilio.Connection instance]";
};
Connection.prototype.sendDigits = function(digits) {
        if (digits.match(/[^0-9*#w]/)) {
            throw new Exception(
                "Illegal character passed into sendDigits");
        }

        var sequence = [];
        for(var i = 0; i < digits.length; i++) {
            var dtmf = digits[i] != "w" ? "dtmf" + digits[i] : "";
            if (dtmf == "dtmf*") dtmf = "dtmfs";
            if (dtmf == "dtmf#") dtmf = "dtmfh";
            sequence.push([dtmf, 200, 20]);
        }
        this.device.soundcache.playseq(sequence);

        var dtmfSender = this.mediaStream.getOrCreateDTMFSender();
        if (dtmfSender) {
            if (dtmfSender.canInsertDTMF) {
              this.log('Sending digits using RTCDTMFSender');
              // NOTE(mroberts): We can't just map "w" to "," since
              // RTCDTMFSender's pause duration is 2 s and Twilio's is more
              // like 500 ms. Instead, we will fudge it with setTimeout.
              var dtmfs = digits.split('w');
              function insertDTMF() {
                var dtmf = dtmfs.shift();
                if (dtmf.length) {
                  dtmfSender.insertDTMF(dtmf, DTMF_TONE_DURATION, DTMF_INTER_TONE_GAP);
                }
                if (dtmfs.length) {
                  setTimeout(insertDTMF, DTMF_PAUSE_DURATION);
                }
              }
              if (dtmfs.length) {
                insertDTMF();
              }
              return;
            }
            this.log('RTCDTMFSender cannot insert DTMF');
        }

        // send pstream message to send DTMF
        this.log('Sending digits over PStream');
        if (this.pstream != null && this.pstream.status != "disconnected") {
            var payload = { dtmf: digits, callsid: this.parameters.CallSid };
            this.pstream.publish("dtmf", payload);
        } else {
            var payload = { error: {} };
            var error = {
                code: payload.error.code || 31000,
                message: payload.error.message || "Could not send DTMF: Signaling channel is disconnected",
                connection: this
            };
            this.emit("error", error);
        }
};
Connection.prototype.status = function() {
        return this._status;
};
    /**
     * Mute incoming audio.
     */
Connection.prototype.mute = function(muteParam) {
        if (arguments.length === 0) {
          this.log.deprecated('.mute() is deprecated. Please use .mute(true) or .mute(false) to mute or unmute a call instead.');
        }

        if (typeof muteParam == "function") {
            // if handler, register listener
            return this.addListener("mute",muteParam);
        }

        // change state if call results in transition
        var origState = this.isMuted();
        var self = this;
        var callback = function() {
            var newState = self.isMuted();
            if (origState != newState) {
                self.emit("mute",newState,self);
            }
        }

        if (muteParam == false) {
            // if explicitly false, unmute connection
            this.mediaStream.attachAudio(callback);
        } else {
            // if undefined or true, mute connection
            this.mediaStream.detachAudio(callback);
        }
};
    /**
     * Check if connection is muted
     */
Connection.prototype.isMuted = function() {
        return !this.mediaStream.isAudioAttached();
};
    /**
     * Unmute (Deprecated)
     */
Connection.prototype.unmute = function() {
        this.log.deprecated('.unmute() is deprecated. Please use .mute(false) to unmute a call instead.');
        this.mute(false);
};
Connection.prototype.accept = function(handler) {
        if (typeof handler == "function") {
            return this.addListener("accept", handler);
        }
        var audioConstraints = handler || this.options.audioConstraints;
        var self = this;
        this._status = "connecting";
        var connect_ = function(err,code) {
            if (self._status != "connecting") {
                // call must have been canceled
                cleanupEventListeners(self);
                self.mediaStream.close();
                return;
            }

            if (err) {
                self._die(err,code);
                return;
            }

            var pairs = [];
            for (var key in self.message) {
                pairs.push(encodeURIComponent(key) + "=" + encodeURIComponent(self.message[key]));
            }
            var params = pairs.join("&");
            if (self.parameters.CallSid) {
                self.mediaStream.answerIncomingCall.call(self.mediaStream, self.parameters.CallSid, self.options["offerSdp"]);
            } else {
                // temporary call sid to be used for outgoing calls
                self.outboundConnectionId = twutil.generateConnectionUUID();

                self.mediaStream.makeOutgoingCall.call(self.mediaStream, params, self.outboundConnectionId);

                self.pstream.once("answer", self._onAnswer);
            }

            self._onHangup = function(payload) {
                /**
                 *  see if callsid passed in message matches either callsid or outbound id
                 *  connection should always have either callsid or outbound id
                 *  if no callsid passed hangup anyways
                 */
                if (payload.callsid && (self.parameters.CallSid || self.outboundConnectionId)) {
                    if (payload.callsid != self.parameters.CallSid && payload.callsid != self.outboundConnectionId) {
                        return;
                    }
                } else if (payload.callsid) {
                    // hangup is for another connection
                    return;
                }

                self.log("Received HANGUP from gateway");
                if (payload.error) {
                    var error = {
                        code: payload.error.code || 31000,
                        message: payload.error.message || "Error sent from gateway in HANGUP",
                        connection: self
                    };
                    self.log("Received an error from the gateway:", error);
                    self.emit("error", error);
                }
                self.sendHangup = false;
                self.disconnect();
                cleanupEventListeners(self);
            };
            self.pstream.addListener("hangup", self._onHangup);
        };
        this.mediaStream.openHelper(connect_, audioConstraints);
};
Connection.prototype.reject = function(handler) {
        if (typeof handler == "function") {
            return this.addListener("reject", handler);
        }
        if (this._status == "pending") {
            var payload = { callsid: this.parameters.CallSid }
            this.pstream.publish("reject", payload);
            this.emit("reject");
        }
};
Connection.prototype.ignore = function(handler) {
        if (typeof handler == "function") {
            return this.addListener("cancel", handler);
        }
        if (this._status == "pending") {
            this._status = "closed";
            this.emit("cancel");
        }
};
Connection.prototype.cancel = function(handler) {
        this.log.deprecated('.cancel() is deprecated. Please use .ignore() instead.');
        this.ignore(handler);
};
Connection.prototype.disconnect = function(handler) {
        if (typeof handler == "function") {
            return this.addListener("disconnect", handler);
        }
        var message = typeof handler === 'string' ? handler : null;
        if (this._status == "open" || this._status == "connecting") {
            this.log("Disconnecting...");

            // send pstream hangup message
            if (this.pstream != null && this.pstream.status != "disconnected" && this.sendHangup) {
                var callId = this.parameters.CallSid || this.outboundConnectionId;
                if (callId) {
                    var payload = { callsid: callId };
                    if (message) {
                        payload.message = message;
                    }
                    this.pstream.publish("hangup", payload);
                }
            }

            cleanupEventListeners(this);

            this.mediaStream.close();
        }
};
Connection.prototype.error = function(handler) {
        if (typeof handler == "function") {
            return this.addListener("error", handler);
        }
};
Connection.prototype._die = function(message,code) {
        this.emit("error", { message: message, code: code });
};

function cleanupEventListeners(connection) {
  function cleanup() {
      connection.pstream.removeListener('answer', connection._onAnswer);
      connection.pstream.removeListener('cancel', connection._onCancel);
      connection.pstream.removeListener('hangup', connection._onHangup);
  }
  cleanup();
  // This is kind of a hack, but it lets us avoid rewriting more code.
  // Basically, there's a sequencing problem with the way PeerConnection raises
  // the
  //
  //   Cannot establish connection. Client is disconnected
  //
  // error in Connection#accept. It calls PeerConnection#onerror, which emits
  // the error event on Connection. An error handler on Connection then calls
  // cleanupEventListeners, but then control returns to Connection#accept. It's
  // at this point that we add a listener for the answer event that never gets
  // removed. setTimeout will allow us to rerun cleanup again, _after_
  // Connection#accept returns.
  setTimeout(cleanup, 0);
}

exports.Connection = Connection;

},{"./log":8,"./rtc":14,"./util":21,"events":27,"util":31}],4:[function(require,module,exports){
var EventEmitter = require('events').EventEmitter;
var util = require('util');
var log = require("./log");
var twutil = require("./util");
var rtc = require("./rtc");

var Options = require("./options").Options;

var SoundCache = require('./soundcache').SoundCache;
var Sound = require('../../vendor/sound/sound').Sound;
var Connection = require('./connection').Connection;
var PStream = require('./pstream').PStream;
var Presence = require('./presence').Presence;
var OldDevice = require('./olddevice').Device;
var EventStream = require('./eventstream').EventStream;
var MediaStream = require('../../vendor/mediastream/mediastream').MediaStream;

var REG_INTERVAL = 30000;

/**
 * Constructor for Device objects.
 *
 * @exports Device as Twilio.Device
 * @memberOf Twilio
 * @borrows EventEmitter#addListener as #addListener
 * @borrows EventEmitter#emit as #emit
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
    twutil.monitorEventEmitter('Twilio.Device', this);
    if (!token) {
        throw new twutil.Exception("Capability token is not valid or missing.");
    }

    // copy options
    var origOptions = {};
    for (i in options) {
        origOptions[i] = options[i];
    }

    var defaults = {
        logPrefix: "[Device]",
        host: "chunder.twilio.com",
        chunderw: "chunderw-gll.twilio.com",
        soundCacheFactory: SoundCache,
        soundFactory: Sound,
        connectionFactory: Connection,
        pStreamFactory: PStream,
        presenceFactory: Presence,
        noRegister: false,
        encrypt: false,
        simplePermissionDialog: false,
        rtc: true,
        debug: false,
        closeProtection: false,
        secureSignaling: true,
        warnings: true,
        audioConstraints: true,
        chrome3940Workaround: false
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
        rtc.enabled(false);
    }

    // if flash, use old device
    if (!rtc.enabled()) {
        console.warn('Warning: Twilio Client will discontinue support for Flash in twilio.js 1.3.');
        return new OldDevice(token,origOptions);
    }

    this.soundcache = this.options["soundCacheFactory"]();

    // NOTE(mroberts): Node workaround.
    if (typeof document === 'undefined')
        var a = {};
    else
        var a = document.createElement("audio");
    canPlayMp3 = false;
    try {
       canPlayMp3 = !!(a.canPlayType && a.canPlayType('audio/mpeg').replace(/no/, ''));
    }
    catch (e) {
    }
    canPlayVorbis = false;
    try {
       canPlayVorbis = !!(a.canPlayType && a.canPlayType('audio/ogg;codecs="vorbis"').replace(/no/, ''));
    }
    catch (e) {
    }
    var ext = "mp3";
    if (canPlayVorbis && !canPlayMp3) {
       ext = "ogg";
    }
    var urls = {
        incoming: "sounds/incoming." + ext, outgoing: "sounds/outgoing." + ext,
        disconnect: "sounds/disconnect." + ext,
        dtmf1: "sounds/dtmf-1." + ext, dtmf2: "sounds/dtmf-2." + ext,
        dtmf3: "sounds/dtmf-3." + ext, dtmf4: "sounds/dtmf-4." + ext,
        dtmf5: "sounds/dtmf-5." + ext, dtmf6: "sounds/dtmf-6." + ext,
        dtmf7: "sounds/dtmf-7." + ext, dtmf8: "sounds/dtmf-8." + ext,
        dtmf9: "sounds/dtmf-9." + ext, dtmf0: "sounds/dtmf-0." + ext,
        dtmfs: "sounds/dtmf-star." + ext, dtmfh: "sounds/dtmf-hash." + ext
    };
    var base = twutil.getTwilioRoot();
    for (var name in urls) {
        var sound = this.options["soundFactory"]();
        sound.load(base + urls[name]);
        this.soundcache.add(name, sound);
    }

    // Minimum duration for incoming ring
    this.soundcache.envelope("incoming", { release: 2000 });

    log.mixinLog(this, this.options["logPrefix"]);
    this.log.enabled = this.options["debug"];

    var device = this;
    this.addListener("incoming", function(connection) {
        connection.once("accept", function() {
            device.soundcache.stop("incoming");
        });
        connection.once("cancel", function() {
            device.soundcache.stop("incoming");
        });
        connection.once("error", function() {
            device.soundcache.stop("incoming");
        });
        connection.once("reject", function() {
            device.soundcache.stop("incoming");
        });
        if (device.sounds.incoming()) {
            device.soundcache.play("incoming", 0, 1000);
        }
    });

    // setup flag for allowing presence for media types
    this.mediaPresence = { audio: !this.options["noRegister"] };

    // setup stream
    this.register(this.token);

    var closeProtection = this.options["closeProtection"];
    if (closeProtection) {
        var confirmClose = function(event) {
            if (device._status == "busy") {
                var defaultMsg = "A call is currently in-progress. Leaving or reloading this page will end the call.";
                var confirmationMsg = closeProtection == true ? defaultMsg : closeProtection;
                (event || window.event).returnValue = confirmationMsg;
                return confirmationMsg;
            }
        }; 
        if (typeof window !== 'undefined') {
            if (window.addEventListener) {
                window.addEventListener("beforeunload", confirmClose);
            } else if (window.attachEvent) {
                window.attachEvent("onbeforeunload", confirmClose);
            }
        }
    }

    // close connections on unload
    var onClose = function() {
        device.disconnectAll();
    }
    if (typeof window !== 'undefined') {
        if (window.addEventListener) {
            window.addEventListener("unload", onClose);
        } else if (window.attachEvent) {
            window.attachEvent("onunload", onClose);
        }
    }

    // NOTE(mroberts): EventEmitter requires that we catch all errors.
    this.on('error', function(){});

    return this;
}

util.inherits(Device, EventEmitter);
twutil.mixinGetMediaEngine(Device.prototype);

function makeConnection(device, params, options) {
    var defaults = {
        encrypt: device.options["encrypt"],
        debug: device.options["debug"],
        warnings: device.options['warnings']
    };

    options = options || {};
    for (var prop in defaults) {
        if (prop in options) continue;
        options[prop] = defaults[prop];
    }

    var connection = device.options["connectionFactory"](device, params, options);

    connection.once("accept", function() {
        device._status = "busy";
        device.emit("connect", connection);
    });
    connection.addListener("error", function(error) {
        device.emit("error", error);
        // Only drop connection from device if it's pending
        if (connection.status() != "pending" || connection.status() != "connecting") return;
        device._removeConnection(connection);
    });
    connection.once("cancel", function() {
        device.log("Canceled: " + connection.parameters["CallSid"]);
        device._removeConnection(connection);
        device.emit("cancel", connection);
    });
    connection.once("disconnect", function() {
        if (device._status == "busy") device._status = "ready";
        device.emit("disconnect", connection);
        device._removeConnection(connection);
    });
    connection.once("reject", function() {
        device.log("Rejected: " + connection.parameters["CallSid"]);
        device._removeConnection(connection);
    });

    return connection;
}

/**
 * @return {string}
 */
Device.toString = function() {
    return "[Twilio.Device class]";
};

    /**
     * @return {string}
     */
Device.prototype.toString = function() {
        return "[Twilio.Device instance]";
};
Device.prototype.register = function(token) {

        if (this.stream && this.stream.status != "disconnected") {
            this.stream.setToken(token);
        } else {
            this._setupStream();
        }

        this._setupEventStream(token);
        /*
         * Presence has nothing to do with incoming capabilities anymore so revisit this when
         * presence spec is established.
         * Plus this logic is probably wrong for restarting/stoping presenceClient
        var tokenIncomingObject = twutil.objectize(token).scope["client:incoming"];
        if (tokenIncomingObject) {
            var clientName = tokenIncomingObject.params.clientName;

            if (this.presenceClient) {
                this.presenceClient.clientName = clientName;
                this.presenceClient.start();
            } else {
                this.presenceClient = this.options["presenceFactory"](clientName,
                        this,
                        this.stream,
                        { autoStart: true});
            }
        } else {
            if (this.presenceClient) {
                this.presenceClient.stop();
                this.presenceClient.detach();
                this.presenceClient = null;
            }
        }*/
};
Device.prototype.registerPresence = function() {
        if (!this.token) {
            return;
        }

        // check token, if incoming capable then set mediaPresence capability to true
        var tokenIncomingObject = twutil.objectize(this.token).scope["client:incoming"];
        if (tokenIncomingObject) {
            this.mediaPresence.audio = true;

            // create the eventstream if needed
            if (!this.eventStream) {
                this._setupEventStream(this.token);
            }
        }

        this._sendPresence();
};
Device.prototype.unregisterPresence = function() {
        this.mediaPresence.audio = false;
        this._sendPresence();
        this._disconnectEventStream();
};
Device.prototype.presence = function(handler) {
        console.warn('Warning: Twilio Client will discontinue support for Presence in twilio.js 1.3.');
        if (!("client:incoming" in twutil.objectize(this.token).scope)) return;
        this.presenceClient.handlers.push(handler);
        // resetup eventstream if the # of handlers went from 0->1
        if (this.token && this.presenceClient.handlers.length == 1) {
            this._setupEventStream(this.token);
        }
};
Device.prototype.showSettings = function(showCallback) {
        console.warn('Warning: Twilio Client will discontinue support for Flash '
            + 'in twilio.js 1.3. As a result, Device.showSettings will be removed.');

        showCallback = showCallback || function() {};
        Device.dialog.show(showCallback);
        MediaStream.showSettings();

        // IE9: after showing and hiding the dialog once,
        // often we end up with a blank permissions dialog
        // the next time around. This makes it show back up
        Device.dialog.screen.style.width = "200%";
};
Device.prototype.connect = function(params, audioConstraints) {
        if (typeof params == "function") {
            return this.addListener("connect", params);
        }
        params = params || {};
        audioConstraints = audioConstraints || this.options.audioConstraints;
        var connection = makeConnection(this, params);
        this.connections.push(connection);
        if (this.sounds.outgoing()) {
            var self = this;
            connection.accept(function() {
                self.soundcache.play("outgoing");
            });
        }
        connection.accept(audioConstraints);
        return connection;
};
Device.prototype.disconnectAll = function() {
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
};
Device.prototype.destroy = function() {
        if (this.stream) {
            this.stream.destroy();
            this.stream = null;
        }

        //backwards compatibility
        this._disconnectEventStream();

        if (this.swf && this.swf.disconnect) {
            this.swf.disconnect();
        }
};
Device.prototype.disconnect = function(handler) {
        this.addListener("disconnect", handler);
};
Device.prototype.incoming = function(handler) {
        this.addListener("incoming", handler);
};
Device.prototype.offline = function(handler) {
        this.addListener("offline", handler);
};
Device.prototype.ready = function(handler) {
        this.addListener("ready", handler);
};
Device.prototype.error = function(handler) {
        this.addListener("error", handler);
};
Device.prototype.status = function() {
        return this._status;
};
Device.prototype.activeConnection = function() {
        // TODO: fix later, for now just pass back first connection
        return this.connections[0];
};
Device.prototype._sendPresence = function() {
        this.stream.register(this.mediaPresence);
        if (this.mediaPresence.audio) {
            this._startRegistrationTimer();
        } else {
            this._stopRegistrationTimer();
        }
};
Device.prototype._startRegistrationTimer = function() {
        clearTimeout(this.regTimer);
        var self = this;
        this.regTimer = setTimeout( function() {
            self._sendPresence();
        },REG_INTERVAL);
};
Device.prototype._stopRegistrationTimer = function() {
        clearTimeout(this.regTimer);
};
Device.prototype._setupStream = function() {
        var device = this;
        this.log("Setting up PStream");
        var streamOptions = {
            chunder: this.options["host"],
            chunderw: this.options["chunderw"],
            debug: this.options["debug"],
            secureSignaling: this.options["secureSignaling"]
        };
        this.stream = this.options["pStreamFactory"](this.token, streamOptions);
        this.stream.addListener("connected", function() {
            device._sendPresence();
        });
        this.stream.addListener("ready", function() {
            device.log("Stream is ready");
            if (device._status == "offline") device._status = "ready";
            device.emit("ready", device);
        });
        this.stream.addListener("offline", function() {
            device.log("Stream is offline");
            device._status = "offline";
            device.emit("offline", device);
        });
        this.stream.addListener("error", function(payload) {
            var error = payload.error;
            if (error) {
                if (payload.callsid) {
                    error.connection = device._findConnection(payload.callsid);
                }
                device.log("Received error: ",error);
                device.emit("error", error);
            }
        });
        this.stream.addListener("invite", function(payload) {
            if (device._status == "busy") {
                device.log("Device busy; ignoring incoming invite");
                return;
            }

            if (!payload["callsid"] || !payload["sdp"]) {
                device.emit("error", { message: "Malformed invite from gateway" });
                return;
            }

            var connection = makeConnection(device, {}, { offerSdp: payload["sdp"] });
            connection.parameters = payload["parameters"] || {};
            connection.parameters["CallSid"] = connection.parameters["CallSid"] || payload["callsid"];
            device.connections.push(connection);
            device.emit("incoming", connection);
        });
};
Device.prototype._setupEventStream = function(token) {
        /*
         * eventstream for presence backwards compatibility
         */
        this.options["eventStreamFactory"] = this.options["eventStreamFactory"] || EventStream;
        this.options["eventsScheme"] = this.options["eventsScheme"] ||  "wss";
        this.options["eventsHost"] = this.options["eventsHost"] ||  "matrix.twilio.com";

        var features = [];
        var url = null;
        if ("client:incoming" in twutil.objectize(token).scope) {
            features.push("publishPresence");
            if (this.presenceClient && this.presenceClient.handlers.length > 0) {
                features.push("presenceEvents");
            }
            var makeUrl = function (token, scheme, host, features) {
                features = features || [];
                var fparams = [];
                for (var i = 0; i < features.length; i++) {
                    fparams.push("feature=" + features[i]);
                }
                var qparams = [ "AccessToken=" + token ].concat(fparams);
                return [
                    scheme + "://" + host, "2012-02-09",
                           twutil.objectize(token).iss,
                           twutil.objectize(token).scope["client:incoming"].params.clientName
                               ].join("/") + "?" + qparams.join("&");
            }
            url = makeUrl(token,
                          this.options["eventsScheme"],
                          this.options["eventsHost"],
                          features);
        }
        var device = this;
        if (!url || !this.mediaPresence.audio) {
            this._disconnectEventStream();
            return;
        }
        if (this.eventStream) {
            this.eventStream.options["url"] = url;
            this.eventStream.reconnect(token);
            return;
        }
        this.log("Registering to eventStream with url: " + url);
        var eventStreamOptions = {
            logPrefix: "[Matrix]",
            debug: this.options["debug"],
            url: url
        };
        this.eventStream = new this.options["eventStreamFactory"](token, eventStreamOptions);
        this.eventStream.addListener("error", function(error) {
            device.log("Received error: ",error);
            device.emit("error", error);
        })
        var clientName = twutil.objectize(token).scope["client:incoming"].params.clientName;
        this.presenceClient = this.options["presenceFactory"](clientName,
                                                              this,
                                                              this.eventStream,
                                                              { autoStart: true});
 };
Device.prototype._disconnectEventStream = function() {
        if (this.eventStream) {
            this.eventStream.destroy();
            if (this.presenceClient) {
                this.presenceClient.detach(this.eventStream);
            }
            this.eventStream = null;
        }
        this.log("Destroyed eventstream.");
};
Device.prototype._removeConnection = function(connection) {
        for (var i = this.connections.length - 1; i >= 0; i--) {
            if (connection == this.connections[i]) {
                this.connections.splice(i, 1);
            }
        }
};
Device.prototype._findConnection = function(callsid) {
        for (var i = 0; i < this.connections.length; i++) {
            var conn = this.connections[i];
            if (conn.parameters.CallSid == callsid || conn.outboundConnectionId == callsid) {
                return conn;
            }
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
            // The defaultErrorHandler throws an Exception iff there are no
            // other error handlers registered on a Device instance. To check
            // this, we need to count up the number of error handlers
            // registered, excluding our own defaultErrorHandler.
            var n = 0;
            var listeners = cls.instance.listeners('error');
            for (var i = 0; i < listeners.length; i++) {
                if (listeners[i] !== defaultErrorHandler) {
                    n++;
                }
            }
            // Note that there is always one default, noop error handler on
            // each of our EventEmitters.
            if (n > 1) {
                return;
            }
            cls.instance.log(err_msg);
        }
        throw new twutil.Exception(err_msg);
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
                cls.instance.log("Found existing Device; using new token but ignoring options");
                cls.instance.token = token;
                cls.instance.register(token);
            } else {
                cls.instance = new Device(token, options);
                cls.error(defaultErrorHandler);
                cls.sounds = cls.instance.sounds;
                for (var i = 0; i < tasks.length; i++) {
                    tasks[i]();
                }
                tasks = [];
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
        connect: function(parameters, audioConstraints) {
            if (typeof parameters == "function") {
                queue(function() {
                    cls.instance.addListener("connect", parameters);
                });
                return;
            }
            if (!cls.instance) {
                throw new twutil.Exception("Run Twilio.Device.setup()");
            }
            if (cls.instance.connections.length > 0) {
                cls.instance.emit("error",
                    { message: "A connection is currently active" });
                return;
            }
            return cls.instance.connect(parameters, audioConstraints);
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
                throw new twutil.Exception("Run Twilio.Device.setup()");
            }
            cls.instance.showSettings();
        },

        activeConnection: function() {
            if (!cls.instance) {
                return null;
            }
            return cls.instance.activeConnection();
        },

        __afterSetup: function(callback) {
            afterSetup.push(callback);
        }
    };

    for (var method in members) {
        cls[method] = members[method];
    }

    cls.getMediaEngine = function() {
      return cls.instance ? cls.instance.getMediaEngine()
                          : twutil.getMediaEngine();
    };
    cls.getMediaEngine.FLASH = twutil.getMediaEngine.FLASH;
    cls.getMediaEngine.WEBRTC = twutil.getMediaEngine.WEBRTC;

    return cls;
}

Device = singletonwrapper(Device);

Device.dialog = OldDevice.dialog;

exports.Device = Device;

},{"../../vendor/mediastream/mediastream":35,"../../vendor/sound/sound":36,"./connection":3,"./eventstream":6,"./log":8,"./olddevice":10,"./options":11,"./presence":12,"./pstream":13,"./rtc":14,"./soundcache":18,"./util":21,"events":27,"util":31}],5:[function(require,module,exports){
function Dialog() {
    if (!(this instanceof Dialog))
        return new Dialog();
    // NOTE(mroberts): Node workaround.
    if (typeof document === 'undefined')
        return;

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
    if (typeof window !== 'undefined') {
        if (window.addEventListener) {
            close.addEventListener("click", hideFn, false);
        } else {
            close.attachEvent("onclick", hideFn);
        }
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
        if (typeof window !== 'undefined') {
            if (window.addEventListener) {
                window.addEventListener("load", fn, false);
            } else {
                window.attachEvent("onload", fn);
            }
        }
    }
}

/**
 * Inserts a DOM element into the dialog.
 *
 * @param {HTMLElement} container Content for the dialog
 */
Dialog.prototype.insert = function(container, embed) {
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
};
/**
 * Shows the dialog.
 */
Dialog.prototype.show = function(closeCb) {
        // NOTE(mroberts): Node workaround.
        if (typeof window === 'undefined' || typeof document === 'undefined')
            return;
        if (closeCb)
            this.close.style.display = "";
        else
            this.close.style.display = "none";
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
};
/**
 * Hides the dialog.
 */
Dialog.prototype.hide = function() {
        this.screen.style.width = "1px";
        this.screen.style.height = "1px";
        this.screen.style.visibility = "hidden";
};

exports.Dialog = Dialog;

},{}],6:[function(require,module,exports){
// NOTE(mroberts): `JSON` is special.
JSON = typeof JSON !== 'undefined' ? JSON : require('../../vendor/json2');
var EventEmitter = require('events').EventEmitter;
var util = require('util');
var log = require("./log");
var twutil = require("./util");

var Heartbeat = require("./heartbeat").Heartbeat;

var WebSocket = require('../../vendor/web-socket-js/web_socket').WebSocket;

function initEvent(object, type) {
    //if (!object.emit || !object.addListener) {
    //    throw new twutil.Exception("Object is not event savvy");
    //}
    return function() {
        var args = Array.prototype.slice.call(arguments, 0);
        if (typeof args[0] == "function") {
            return object.addListener(type, args[0]);
        } else {
            args.unshift(type);
            return object.emit.apply(object, args);
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
 * @borrows EventEmitter#emit as #emit
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
    twutil.monitorEventEmitter('Twilio.EventStream', this);
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
        self.emit("twiml", obj);
    });

    // NOTE(mroberts): EventEmitter requires that we catch all errors.
    this.on('error', function(){});

    return this;
}

util.inherits(EventStream, EventEmitter);

EventStream.initializingFlash = false;
EventStream.initializeFlash = function(stream) {
    if (EventStream.initializingFlash) return;
    EventStream.initializingFlash = true;

    if (WebSocket && WebSocket.__initialize) {
        WEB_SOCKET_SWF_LOCATION = stream.options["swfLocation"];
        WebSocket.__initialize();
        // We want to inform the user if there is a failure loading
        // WebSocket.swf. swfobject.embedSWF has a success/failure callback,
        // but it returns true even on a 404 response for the requested .swf.
        // http://code.google.com/p/swfobject/issues/detail?id=126#c13.
        stream.log("Waiting " + stream.options["flashTimeout"] +
            "ms for flash to initialize");
        setTimeout(function() {
          if (!WebSocket.__flash) {
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

EventStream.prototype.toString = function() {
        return "[Twilio.EventStream instance]";
};
EventStream.prototype.destroy = function() {
        this.socket.close();
        this.options["reconnect"] = false;
        return this;
};
EventStream.prototype.publish = function (payload, channel) {
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
};
EventStream.prototype._cleanupSocket = function(socket) {
        if (socket) {
            var noop = function() {};
            socket.onopen = function() { socket.close(); };
            socket.onmessage = noop;
            socket.onerror = noop;
            socket.onclose = noop;

            if (socket.readyState < 2) {
                socket.close();
            }
        }
};
EventStream.prototype._connect = function(attempted) {
        var self = this;
        var url = this._extractUrl();
        var attempt = ++attempted || 1;
        if (!url) {
            this.log("Nothing to do");
            return;
        }

        var oldSocket = this.socket;
        this.log("Attempting to connect to " + url + "...");
        // _tryReconnect calls this method expecting a new WebSocket each time.
        try {
            this.socket = new WebSocket(url);
        } catch (e) {
            this.log("Connection to " + url + " failed: " + (e.message || ""));
            return;
        }

        this.socket.onopen = function() {
            self.log("Socket opened... sending ready signal");
            self._cleanupSocket(oldSocket);
            self.socket.send(JSON.stringify({
                "rt.message": "listen",
                "rt.token": self.token
            }));
        };
        this.socket.onerror = function(me) {
            if (me.data) {
                self.emit("error", {
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
                    if (self.status != "ready") {
                        self.status = "ready";
                        self.emit("ready", self);
                    }
                } else {
                    // Hurl sends "publish" EventTypes, but our API calls them
                    // "twiml" events. We want to have all "publish" events
                    // emit the handlers registered for "twiml". In the
                    // EventStream constructor, we add a listener for
                    // "publish", and use that to emit a "twiml" event.
                    var event_type = obj["rt.message"] || obj["EventType"];
                    if (event_type == "error") {
                        var errMessage = obj["message"] || "";
                        self.log("Connection to " + url + " failed: " + errMessage);
                        if (/^4/.test(obj["code"])) {
                            self.options["reconnect"] = false;
                        } else {
                            //Attempt to reconnect up to 5 times using exponential random backoff
                            if (attempt < 5) {
                                var minBackoff = 30;
                                var backoffRange = Math.pow(2,attempt)*50;
                                var backoff = minBackoff + Math.round(Math.random()*backoffRange);
                                setTimeout(function() {
                                    if (self.socket) {
                                        self.socket.close();
                                    }
                                    self._connect(attempt);
                                }, backoff);
                            } else {
                                self.emit("error", {
                                    message: "Connection to Twilio failed: " + errMessage,
                                    code: obj["code"] || ""
                                });
                            }
                        }
                    }
                    if (event_type != "incoming") {
                        self.emit("incoming", obj);
                        self.emit(event_type, obj);
                    } else {
                        self.emit(event_type, obj);
                    }
                }
            }
        };
        this.socket.onclose = function() {
            self._cleanupSocket(oldSocket);
            if (self.status != "offline") {
                self.log("Gone offline");
                self.status = "offline";
                self.emit("offline", self);
            }
        };
        this.heartbeat.onsleep = function() {
            self.log("Connection heartbeat timed out.");
            if (self.socket) {
                self.socket.close();
            }
            self._tryReconnect(5000);
        };
};
EventStream.prototype.reconnect = function(token) {
        if (this.socket) {
            if (this.socket.readyState == 0) {
                socket = this.socket;
                socket.onopen = function () { socket.close(); }
            } else {
                this.socket.close();
            }
        }
        this.token = token;
        this.options["reconnect"] = true;
        this._tryReconnect();
};
EventStream.prototype._extractUrl = function() {
        if (this.options["url"]) {
            return this.options["url"];
        }
        var scopes = twutil.objectize(this.token).scope;
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
            + path + "?" + twutil.urlencode(filters, true);
};
EventStream.prototype._tryReconnect = function(delay) {
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
                switch(self.socket.readyState) {
                    case 0:
                        setTimeout(checkReady,1000);
                        break;
                    case 1:
                        return;
                    case 2:
                    case 3:
                    default:
                        setTimeout(callAgain, delay);
                        break;
                }
            };
        })(this);
        setTimeout(checkReady, 5000);
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

exports.EventStream = EventStream;

},{"../../vendor/json2":34,"../../vendor/web-socket-js/web_socket":38,"./heartbeat":7,"./log":8,"./util":21,"events":27,"util":31}],7:[function(require,module,exports){
/**
 * Heartbeat just wants you to call <code>beat()</code> every once in a while.
 *
 * <p>It initializes a countdown timer that expects a call to
 * <code>Hearbeat#beat</code> every n seconds. If <code>beat()</code> hasn't
 * been called for <code>#interval</code> seconds, it emits a
 * <code>onsleep</code> event and waits. The next call to <code>beat()</code>
 * emits <code>onwakeup</code> and initializes a new timer.</p>
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

    /**
     * @return {string}
     */
Heartbeat.prototype.toString = function() {
        return "[Twilio.Heartbeat instance]";
};
    /**
     * Keeps the instance awake (by resetting the count down); or if asleep,
     * wakes it up.
     */
Heartbeat.prototype.beat = function() {
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
};
    /**
     * Goes into a sleep state if the time between now and the last heartbeat
     * is greater than or equal to the specified <code>interval</code>.
     */
Heartbeat.prototype.check = function() {
        var timeidle = this.now() - this.lastbeat;
        if (!this.sleeping() && timeidle >= this.interval * 1000) {
            if (this.onsleep) {
                this.onsleep();
            }
            this.stop.call(null, this.pintvl);

            this.pintvl = null;
        }
};
    /**
     * @return {boolean} True if sleeping
     */
Heartbeat.prototype.sleeping = function() {
        return this.pintvl == null;
};
exports.Heartbeat = Heartbeat;

},{}],8:[function(require,module,exports){
/**
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

    function defaultWarnHandler(x) {
      if (typeof console !== 'undefined') {
        if (typeof console.warn === 'function') {
          console.warn(x);
        } else if (typeof console.log === 'function') {
          console.log(x);
        }
      }
    }

    function deprecated() {
        if (!log.warnings) {
            return;
        }
        for (var i = 0; i < arguments.length; i++) {
            var arg = arguments[i];
            log.warnHandler(arg);
        }
    };

    log.enabled = true;
    log.prefix = prefix || "";
    /** @ignore */
    log.defaultHandler = function(x) { typeof console !== 'undefined' && console.log(x); };
    log.handler = log.defaultHandler;
    log.warnings = true;
    log.defaultWarnHandler = defaultWarnHandler;
    log.warnHandler = log.defaultWarnHandler;
    log.deprecated = deprecated;

    object.log = log;
}
exports.mixinLog = mixinLog;

},{}],9:[function(require,module,exports){
var EventEmitter = require('events').EventEmitter;
var util = require('util');
var twutil = require('./util');
var log = require("./log");
var Exception = require("./util").Exception;
var rtc = require("./rtc");

var MediaStream = require('../../vendor/mediastream/mediastream').MediaStream;

/**
 * Constructor for Connections.
 *
 * @exports Connection as Twilio.Connection
 * @memberOf Twilio
 * @borrows EventEmitter#addListener as #addListener
 * @borrows EventEmitter#emit as #emit
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
        return new Connection(device, message, options);
    }
    twutil.monitorEventEmitter('Twilio.Connection', this);
    this.device = device;
    this.message = message || {};

    options = options || {};
    var defaults = {
        logPrefix: "[Connection]",
        bridgeToken: null,
        mediaStreamFactory: rtc.enabled() ? rtc.PeerConnection : MediaStream,
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
    this.log.warnings = this.options['warnings'];

    /**
     * Reference to the Twilio.MediaStream object.
     * @type Twilio.MediaStream
     */
    this.mediaStream = new this.options["mediaStreamFactory"](
        this.options["encrypt"],
        this.options[rtc.enabled() ? "chunderw" : "chunder"],
        this.device.options["simplePermissionDialog"]
        );

    var self = this;

    this.mediaStream.onerror = function(e) {
        var error = {
            code: e.info.code,
            message: e.info.message,
            info: e.info
        };
        self.log("Received an error from MediaStream:", e);
        self.emit("error", error);
    };

    this.mediaStream.onopen = function() {
        self._status = "open";
        self.mediaStream.attachAudio();
        self.mediaStream.play("output");
        self.emit("accept", self);
    };

    this.mediaStream.onclose = function() {
        self._status = "closed";
        if (self.device.sounds.disconnect()) {
            self.device.soundcache.play("disconnect");
        }
        self.emit("disconnect", self);
    };

    this.mediaStream.onCallSid = function(callsid) {
        self.parameters.CallSid = callsid;
    }

    // NOTE(mroberts): EventEmitter requires that we catch all errors.
    this.on('error', function(){});

    return this;
}

util.inherits(Connection, EventEmitter);

/**
 * @return {string}
 */
Connection.toString = function() {
    return "[Twilio.Connection class]";
};

    /**
     * @return {string}
     */
Connection.prototype.toString = function() {
        return "[Twilio.Connection instance]";
};
Connection.prototype.sendDigits = function(digits) {
        if (digits.match(/[^0-9*#w]/)) {
            throw new Exception(
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
};
Connection.prototype.status = function() {
        return this._status;
};
    /**
     * Mute incoming audio.
     */
Connection.prototype.mute = function(muteParam) {
        if (arguments.length === 0) {
          this.log.deprecated('.mute() is deprecated. Please use .mute(true) or .mute(false) to mute or unmute a call instead.');
        }

        if (typeof muteParam == "function") {
            // if handler, register listener
            return this.addListener("mute",muteParam);
        }

        // change state if call results in transition
        var origState = this.isMuted();
        var self = this;
        var callback = function() {
            var newState = self.isMuted();
            if (origState != newState) {
                self.emit("mute",newState,self);
            }
        }

        if (muteParam == false) {
            // if explicitly false, unmute connection
            this.mediaStream.attachAudio(callback);
        } else {
            // if undefined or true, mute connection
            this.mediaStream.detachAudio(callback);
        }
};
    /**
     * Check if connection is muted
     */
Connection.prototype.isMuted = function() {
        return !this.mediaStream.isAudioAttached();
};
    /**
     * Unmute (Deprecated)
     */
Connection.prototype.unmute = function() {
        this.log.deprecated('.unmute() is deprecated. Please use .mute(false) to unmute a call instead.');
        this.mute(false);
};
Connection.prototype.accept = function(handler) {
        if (typeof handler == "function") {
            return this.addListener("accept", handler);
        }
        var self = this;
        this._status = "pending";
        var connect_ = function(err,code) {
            if (err) {
                self._die(err,code);
                return;
            }
            var pairs = [];
            for (var key in self.message) {
                pairs.push(encodeURIComponent(key) + "=" + encodeURIComponent(self.message[key]));
            }
            var params = [ self.mediaStream.uri()
                         , self.options["token"]
                         , self.options["bridgeToken"]
                         , pairs.join("&")
                         ].concat(self.options["acceptParams"]);
            params.push(twutil.getSDKVersion());
            self.mediaStream.open.apply(self.mediaStream, params);
        };
        var Device = self.device.constructor;
        this.mediaStream.openHelper(
            connect_,
            this.device.options["simplePermissionDialog"],
            Connection.NO_MIC_LEVEL || 0,
            {   showDialog: function() { Device.dialog.show() }, 
                closeDialog: function(accessGranted) { 
                    Device.dialog.hide();
                    self.device.options["simplePermissionDialog"] = accessGranted;
                    if (!accessGranted) {
                        self._die("Access to microphone has been denied");
                        self.disconnect();
                    }
                }
            },
            function(x) { self.device.showSettings(x); }
            );
};
Connection.prototype.reject = function(handler) {
        if (typeof handler == "function") {
            return this.addListener("reject", handler);
        }
        var payload = {
            'Response': 'reject',
            'CallSid': this.parameters.CallSid
        }
        this.device.stream.publish(payload, this.options.rejectChannel);
        this.emit("reject");
};
Connection.prototype.ignore = function(handler) {
        if (typeof handler == "function") {
            return this.addListener("cancel", handler);
        }
        this._status = "closed";
        this.emit("cancel");
};
Connection.prototype.cancel = function(handler) {
        this.log.deprecated('.cancel() is deprecated. Please use .ignore() instead.');
        this.ignore(handler);
};
Connection.prototype.disconnect = function(handler) {
        if (typeof handler == "function") {
            return this.addListener("disconnect", handler);
        }
        if (this._status == "open") {
            this.log("Disconnecting...");
            this.mediaStream.close();
        }
};
Connection.prototype.error = function(handler) {
        if (typeof handler == "function") {
            return this.addListener("error", handler);
        }
};
Connection.prototype._die = function(message,code) {
        this.emit("error", { message: message, code: code });
};

exports.Connection = Connection;

},{"../../vendor/mediastream/mediastream":35,"./log":8,"./rtc":14,"./util":21,"events":27,"util":31}],10:[function(require,module,exports){
// NOTE(mroberts): `JSON` is special.
JSON = typeof JSON !== 'undefined' ? JSON : require('../../vendor/json2');
var EventEmitter = require('events').EventEmitter;
var util = require('util');
var log = require("./log");
var twutil = require("./util");
var rtc = require("./rtc");

var Options = require("./options").Options;
var Dialog = require("./dialog").Dialog;

var SoundCache = require('./soundcache').SoundCache;
var Sound = require('../../vendor/sound/sound').Sound;
var Connection = require('./oldconnection').Connection;
var PStream = require('./pstream').PStream;
var Presence = require('./presence').Presence;
var OldDevice = require('./olddevice').Device;
var EventStream = require('./eventstream').EventStream;
var MediaStream = require('../../vendor/mediastream/mediastream').MediaStream;

/**
 * Constructor for Device objects.
 *
 * @exports Device as Twilio.Device
 * @memberOf Twilio
 * @borrows EventEmitter#addListener as #addListener
 * @borrows EventEmitter#emit as #emit
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
    twutil.monitorEventEmitter('Twilio.Device', this);
    if (!token) {
        throw new twutil.Exception("Capability token is not valid or missing.");
    }
    var defaults = {
        logPrefix: "[Device]",
        host: "chunder.twilio.com",
        chunderw: "chunderw.twilio.com",
        soundCacheFactory: SoundCache,
        soundFactory: Sound,
        connectionFactory: Connection,
        eventStreamFactory: EventStream,
        presenceFactory: Presence,
        eventsScheme: "wss",
        eventsHost: "matrix.twilio.com",
        noRegister: false,
        encrypt: false,
        simplePermissionDialog: false,
        rtc: true,
        debug: false,
        closeProtection: false,
        warnings: true
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
        rtc.enabled(false);
    }

    this.soundcache = this.options["soundCacheFactory"]();

    // NOTE(mroberts): Node workaround.
    if (typeof document === 'undefined')
        var a = {};
    else
        var a = document.createElement('audio');
    canPlayMp3 = false;
    try {
       canPlayMp3 = !!(a.canPlayType && a.canPlayType('audio/mpeg').replace(/no/, ''));
    }
    catch (e) {
    }
    canPlayVorbis = false;
    try {
       canPlayVorbis = !!(a.canPlayType && a.canPlayType('audio/ogg;codecs="vorbis"').replace(/no/, ''));
    }
    catch (e) {
    }
    var ext = "mp3";
    if (canPlayVorbis && !canPlayMp3) {
       ext = "ogg";
    }
    var urls = {
        incoming: "sounds/incoming." + ext, outgoing: "sounds/outgoing." + ext,
        disconnect: "sounds/disconnect." + ext,
        dtmf1: "sounds/dtmf-1." + ext, dtmf2: "sounds/dtmf-2." + ext,
        dtmf3: "sounds/dtmf-3." + ext, dtmf4: "sounds/dtmf-4." + ext,
        dtmf5: "sounds/dtmf-5." + ext, dtmf6: "sounds/dtmf-6." + ext,
        dtmf7: "sounds/dtmf-7." + ext, dtmf8: "sounds/dtmf-8." + ext,
        dtmf9: "sounds/dtmf-9." + ext, dtmf0: "sounds/dtmf-0." + ext,
        dtmfs: "sounds/dtmf-star." + ext, dtmfh: "sounds/dtmf-hash." + ext
    };
    var base = twutil.getTwilioRoot();
    for (var name in urls) {
        var sound = this.options["soundFactory"]();
        sound.load(base + urls[name]);
        this.soundcache.add(name, sound);
    }

    // Minimum duration for incoming ring
    this.soundcache.envelope("incoming", { release: 2000 });

    log.mixinLog(this, this.options["logPrefix"]);
    this.log.enabled = this.options["debug"];

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

    var closeProtection = this.options["closeProtection"];
    if (closeProtection) {
        var confirmClose = function(event) {
            if (device._status == "busy") {
                var defaultMsg = "A call is currently in-progress. Leaving or reloading this page will end the call.";
                var confirmationMsg = closeProtection == true ? defaultMsg : closeProtection;
                (event || window.event).returnValue = confirmationMsg;
                return confirmationMsg;
            }
        }; 
        if (addEventListener) {
            addEventListener("beforeunload", confirmClose);
        } else if (attachEvent) {
            attachEvent("onbeforeunload", confirmClose);
        }
    }

    // close connections on unload
    var onClose = function() {
        device.disconnectAll();
    }
    // NOTE(mroberts): Node workaround.
    if (typeof window !== 'undefined') {
        if (window.addEventListener) {
            window.addEventListener("unload", onClose);
        } else if (window.attachEvent) {
            window.attachEvent("onunload", onClose);
        }
    }

    // NOTE(mroberts): EventEmitter requires that we catch all errors.
    this.on('error', function(){});

    return this;
}

util.inherits(Device, EventEmitter);
twutil.mixinGetMediaEngine(Device.prototype);

/**
 * @return {string}
 */
Device.toString = function() {
    return "[Twilio.Device class]";
};

    /**
     * @return {string}
     */
Device.prototype.toString = function() {
        return "[Twilio.Device instance]";
};
Device.prototype.makeConnection = function(device, token, tokenType, params, options) {
        var defaults = {
            acceptParams: [ JSON.stringify(twutil.getSystemInfo())
                          , twutil.objectize(device.token).iss
                          ],
            chunder: device.options["host"],
            chunderw: device.options["chunderw"],
            encrypt: device.options["encrypt"],
            debug: device.options["debug"],
            warnings: device.options['warnings']
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
            device.emit("connect", connection);
        });
        connection.addListener("error", function(error) {
            device.emit("error", error);
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
            device.emit("cancel", connection);
        })
        connection.addListener("disconnect", function() {
            if (device._status == "busy") device._status = "ready";
            device.emit("disconnect", connection);
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
};
Device.prototype.register = function(token) {
        var features = [];
        var url = null;
        if ("client:incoming" in twutil.objectize(token).scope) {
            features.push("incomingCalls");
            features.push("publishPresence");
            if (this.presenceClient && this.presenceClient.handlers.length > 0) {
                features.push("presenceEvents");
            }
            var makeUrl = function (token, scheme, host, features) {
                features = features || [];
                var fparams = [];
                for (var i = 0; i < features.length; i++) {
                    fparams.push("feature=" + features[i]);
                }
                var qparams = [ "AccessToken=" + token ].concat(fparams);
                return [
                    scheme + "://" + host, "2012-02-09",
                           twutil.objectize(token).iss,
                           twutil.objectize(token).scope["client:incoming"].params.clientName
                               ].join("/") + "?" + qparams.join("&");
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
            setTimeout(function() { device.emit("ready", device); }, 0);
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
            device.emit("ready", device);
        });
        this.stream.addListener("offline", function() {
            device.log("Stream is offline");
            device._status = "offline";
            device.emit("offline", device);
        })
        this.stream.addListener("error", function(error) {
            device.log("Received error: ",error);
            device.emit("error", error);
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
                        device.emit("error", { message: "Malformed invite" });
                        return;
                    }
                    var parameters = message["Parameters"] || {};
                    var opts = { rejectChannel: message["RejectChannel"] };
                    var connection = device.makeConnection(device,
                                                    message["Token"],
                                                    "bridge",
                                                    {},
                                                    opts);
                    connection.parameters = parameters;
                    device.connections.push(connection);
                    device.emit("incoming", connection);
                break;
                case "cancel":
                    // Clone device.connections so we can modify it while
                    // iterating over its elements.
                    var connections = [].concat(device.connections);
                    for (var i = 0; i < connections.length; i++) {
                        var conn = connections[i];
                        if (conn.parameters["CallSid"] == message["CallSid"]
                            && conn.status() == "pending") {
                            conn.ignore();
                        }
                    }
                break;
            }
        });
        var clientName = twutil.objectize(token).scope["client:incoming"].params.clientName;
        this.presenceClient = this.options["presenceFactory"](clientName,
                                                              this,
                                                              this.stream,
                                                              { autoStart: true});
};
Device.prototype.presence = function(handler) {
        if (!("client:incoming" in twutil.objectize(this.token).scope)) return;
        this.presenceClient.handlers.push(handler);
        // re-register if the # of handlers went from 0->1
        if (this.token && this.presenceClient.handlers.length == 1) {
            this.register(this.token);
        }
};
Device.prototype.showSettings = function(showCallback) {
        showCallback = showCallback || function() {};
        Device.dialog.show(showCallback);
        MediaStream.showSettings();

        // IE9: after showing and hiding the dialog once,
        // often we end up with a blank permissions dialog
        // the next time around. This makes it show back up
        Device.dialog.screen.style.width = "200%";
};
Device.prototype.connect = function(params) {
        if (typeof params == "function") {
            return this.addListener("connect", params);
        }
        params = params || {};
        var connection = this.makeConnection(this, this.token, "jwt", params);
        this.connections.push(connection);
        if (this.sounds.outgoing()) {
            var self = this;
            connection.accept(function() {
                self.soundcache.play("outgoing");
            });
        }
        connection.accept();
        return connection;
};
Device.prototype.disconnectAll = function(params) {
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
};
Device.prototype.destroy = function() {
        this.stream.destroy();
        if (this.swf && this.swf.disconnect) {
            this.swf.disconnect();
        }
};
Device.prototype.disconnect = function(handler) {
        this.addListener("disconnect", handler);
};
Device.prototype.incoming = function(handler) {
        this.addListener("incoming", handler);
};
Device.prototype.offline = function(handler) {
        this.addListener("offline", handler);
};
Device.prototype.ready = function(handler) {
        this.addListener("ready", handler);
};
Device.prototype.error = function(handler) {
        this.addListener("error", handler);
};
Device.prototype.status = function() {
        return this._status;
};
Device.prototype.activeConnection = function() {
        // TODO: fix later, for now just pass back first connection
        return this.connections[0];
};

Device.dialog = Dialog();

exports.Device = Device;

},{"../../vendor/json2":34,"../../vendor/mediastream/mediastream":35,"../../vendor/sound/sound":36,"./dialog":5,"./eventstream":6,"./log":8,"./oldconnection":9,"./olddevice":10,"./options":11,"./presence":12,"./pstream":13,"./rtc":14,"./soundcache":18,"./util":21,"events":27,"util":31}],11:[function(require,module,exports){
var Options = (function() {
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

exports.Options = Options;

},{}],12:[function(require,module,exports){
var Set = require("./util").Set;
var bind = require("./util").bind;
var Options = require("./options").Options;
var state = require("./state");

var PRESENCE_HEARTBEAT_INTERVAL = 5 * 60; // seconds
var PRESENCE_DELAY_VARIATION = 0.2;

var rndrange = function(l, u) { return Math.random() * (u - l) + l; };
var jitter = function(i, v) { return i + i * rndrange(-1, 1) * v; };

var Presence = (function() {
    function Presence(clientName, device, stream, options) {
        if (!(this instanceof Presence)) {
          return new Presence(clientName, device, stream, options);
        }
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

        this._boundPresence = bind(handlePresence, this);
        this._boundRoster = bind(handleRoster, this);

        stream.addListener("offline", bind(this.handleOffline, this));
        this.attach(stream);
        /*device.addListener("offline", bind(handleOffline, this));
        // NOTE(mroberts): The test "Ready/offline works" leaves this undefined.
        if (this.stream)
          this.attach(stream);
        stream.addListener("presence", this._boundPresence);
        stream.addListener("roster", this._boundRoster);*/

        this._boundHeartbeat = bind(heartbeat, this, stream, {
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

    function heartbeat(stream, payload) {
        stream.publish(payload, "presence");
    };
    Presence.prototype.heartbeat = heartbeat;

    Presence.prototype.attach = function(stream) {
        stream.addListener("presence", this._boundPresence);
        stream.addListener("roster", this._boundRoster);
    };

    Presence.prototype.detach = function(stream) {
        stream.removeListener("presence", this._boundPresence);
        stream.removeListener("roster", this._boundRoster);
    };

    function removeFromRoster(clientName) {
        this.roster.del(clientName);
        this.invoke(clientName, false);
    };
    Presence.prototype.removeFromRoster = removeFromRoster;

    Presence.prototype.addToRoster = function(clientName) {
        this.roster.put(clientName);
        this.invoke(clientName, true);
    };

    function handleOffline() {
        var removeFromRoster = bind(this.removeFromRoster, this);
        this.roster.map(removeFromRoster);
    };
    Presence.prototype.handleOffline = handleOffline;

    function handlePresence(event) {
        this[event.Available ? "addToRoster" : "removeFromRoster"](event.From);
    };
    Presence.prototype.handlePresence = handlePresence;

    function handleRoster(event) {
        for (var i = 0; i < event.Roster.length; i++) {
            this.addToRoster(event.Roster[i]);
        }
    };
    Presence.prototype.handleRoster = handleRoster;

    Presence.prototype.invoke = function(clientName, available) {
        if (clientName === this.clientName) return;
        var event = { from: clientName, available: available };
        for (var i = 0; i < this.handlers.length; i++) {
            this.handlers[i](event);
        }
    };

    return Presence;
})();

exports.Presence = Presence;

},{"./options":11,"./state":19,"./util":21}],13:[function(require,module,exports){
// NOTE(mroberts): `JSON` is special.
JSON = typeof JSON !== 'undefined' ? JSON : require('../../vendor/json2');
var EventEmitter = require('events').EventEmitter;
var util = require('util');
var log = require("./log");
var twutil = require("./util");
var rtc = require("./rtc");

var Heartbeat = require("./heartbeat").Heartbeat;
var WSTransport = require('./wstransport').WSTransport;

/**
 * Constructor for PStream objects.
 *
 * @exports PStream as Twilio.PStream
 * @memberOf Twilio
 * @borrows EventEmitter#addListener as #addListener
 * @borrows EventEmitter#removeListener as #removeListener
 * @borrows EventEmitter#emit as #emit
 * @borrows EventEmitter#hasListener as #hasListener
 * @constructor
 * @param {string} token The Twilio capabilities JWT
 * @param {object} [options]
 * @config {boolean} [options.debug=false] Enable debugging
 */
function PStream(token, options) {
    if (!(this instanceof PStream)) {
        return new PStream(token, options);
    }
    twutil.monitorEventEmitter('Twilio.PStream', this);
    var defaults = {
        logPrefix: "[PStream]",
        chunder: "chunder.twilio.com",
        chunderw: "chunderw-gll.twilio.com",
        secureSignaling: true,
        transportFactory: WSTransport,
        debug: false
    };
    options = options || {};
    for (var prop in defaults) {
        if (prop in options) continue;
        options[prop] = defaults[prop];
    }
    this.options = options;
    this.token = token || "";
    this.status = "disconnected";
    this.host = rtc.enabled() ? this.options["chunderw"] : this.options["chunder"];

    log.mixinLog(this, this.options["logPrefix"]);
    this.log.enabled = this.options["debug"];

    // NOTE(mroberts): EventEmitter requires that we catch all errors.
    this.on('error', function(){});

    /*
    *events used by device
    *"invite",
    *"ready",
    *"error",
    *"offline",
    *
    *"cancel",
    *"presence",
    *"roster",
    *"answer",
    *"candidate",
    *"hangup"
    */

    var self = this;

    this.addListener("ready", function() {
        self.status = "ready";
    });
    this.addListener("offline", function() {
        self.status = "offline";
    });
    this.addListener("close", function() {
        self.destroy();
    });

    var opt = {
        host: this.host,
        debug: this.options["debug"],
        secureSignaling: this.options["secureSignaling"]
    };
    this.transport = this.options["transportFactory"](opt);
    this.transport.onopen = function() {
        self.status = "connected";
        self.setToken(self.token);
    };
    this.transport.onclose = function() {
        if (self.status != "disconnected") {
            if (self.status != "offline") {
                self.emit("offline", self);
            }
            self.status = "disconnected";
        }
    };
    this.transport.onerror = function(err) {
        self.emit("error", err);
    };
    this.transport.onmessage = function(msg) {
        var objects = twutil.splitObjects(msg.data);
        for (var i = 0; i < objects.length; i++) {
            var obj = JSON.parse(objects[i]);
            var event_type = obj["type"];
            var payload = obj["payload"] || {};

            // emit event type and pass the payload
            self.emit(event_type, payload);
        }
    };
    this.transport.open();

    return this;
}

util.inherits(PStream, EventEmitter);

/**
 * @return {string}
 */
PStream.toString = function() {
    return "[Twilio.PStream class]";
};

PStream.prototype.toString = function() {
                  return "[Twilio.PStream instance]";
};
PStream.prototype.setToken = function(token) {
                  this.log("Setting token and publishing listen");
                  this.token = token;
                  var payload = {
                      "token": token,
                      "browserinfo": twutil.getSystemInfo()
                  };
                  this.publish("listen", payload);
};
PStream.prototype.register = function(mediaCapabilities) {
                  var regPayload = {
                      media: mediaCapabilities
                  };
                  this.publish("register", regPayload);
};
PStream.prototype.destroy = function() {
                 this.log("Closing PStream");
                 this.transport.close();
                 return this;
};
PStream.prototype.publish = function (type, payload) {
                      var msg = JSON.stringify(
                              {
                                "type": type,
                                "version": twutil.getSDKVersion(),
                                "payload": payload
                              });
                      this.transport.send(msg);
};

exports.PStream = PStream;

},{"../../vendor/json2":34,"./heartbeat":7,"./log":8,"./rtc":14,"./util":21,"./wstransport":22,"events":27,"util":31}],14:[function(require,module,exports){
var PeerConnection = require('./peerconnection');

function enabled(set) {
  if (typeof set !== 'undefined') {
    PeerConnection.enabled = set;
  }
  return PeerConnection.enabled;
}

module.exports = {
  PeerConnection: require('./peerconnection'),
  enabled: enabled
}

},{"./peerconnection":16}],15:[function(require,module,exports){
var getStats = require('./stats');

var N = 20; // 2 seconds

function dummyPeerConnection(stream, done) {
  if (typeof webkitRTCPeerConnection === 'undefined') {
    return done(new Error('This does not appear to be Chrome 38'));
  }
  var local = new webkitRTCPeerConnection({'iceServers':[]});
  var remote = new webkitRTCPeerConnection({'iceServers':[]});
  local.addStream(stream);
  local.createOffer(function(offer) {
    var offerSDP = new RTCSessionDescription(offer);
    local.setLocalDescription(offerSDP, function() {
      remote.setRemoteDescription(offerSDP, function() {
        remote.createAnswer(function(answer) {
          var answerSDP = new RTCSessionDescription(answer);
          remote.setLocalDescription(answerSDP, function() {
            local.setRemoteDescription(answerSDP, function() {
              done(null, local);
            }, done);
          }, done);
        }, done);
      }, done);
    }, done);
  }, done);
}

function monitorStream(stream, done) {
  var pc = null;
  var i = 0;
  var audioInputLevel = 0;
  function next(error, stats) {
    if (error) {
      pc.close();
      return done(error);
    } else if (++i === N || audioInputLevel !== 0) {
      pc.close();
      return done(null, audioInputLevel !== 0);
    } else if (!('audioInputLevel' in stats)) {
      return setTimeout(function() {
        getStats(pc, next);
      }, 100);
    }
    audioInputLevel += stats.audioInputLevel;
    setTimeout(function() {
      getStats(pc, next);
    }, 100);
  }
  dummyPeerConnection(stream, function(error, local) {
    if (error) {
      return done(error);
    }
    pc = local;
    getStats(pc, next);
  });
}

module.exports = monitorStream;

},{"./stats":17}],16:[function(require,module,exports){
var log = require('../log');
var util = require("../util");
var getStatistics = require('./stats');
var monitorStream = require('./issue3940');
var stackTrace = require('stacktrace-js');
var StateMachine = require('../statemachine');

var STATS_SAMPLE_INTERVAL = 1000;
var STATS_PUBLISH_INTERVAL = STATS_SAMPLE_INTERVAL * 10;

// Refer to <http://www.w3.org/TR/2015/WD-webrtc-20150210/#rtciceconnectionstate-enum>.
var ICE_CONNECTION_STATES = {
  'new': [
    'checking',
    'closed'
  ],
  'checking': [
    'new',
    'connected',
    'failed',
    'closed',
    // Not in the spec, but Chrome can go to completed.
    'completed'
  ],
  'connected': [
    'new',
    'disconnected',
    'completed',
    'closed'
  ],
  'completed': [
    'new',
    'disconnected',
    'closed',
    // Not in the spec, but Chrome can go to completed.
    'completed'
  ],
  'failed': [
    'new',
    'disconnected',
    'closed'
  ],
  'disconnected': [
    'connected',
    'completed',
    'failed',
    'closed'
  ],
  'closed': []
};

var INITIAL_ICE_CONNECTION_STATE = 'new';

// These differ slightly from the normal WebRTC state transitions: since we
// never expect the "have-local-pranswer" or "have-remote-pranswer" states, we
// filter them out.
var SIGNALING_STATES = {
  'stable': [
    'have-local-offer',
    'have-remote-offer',
    'closed'
  ],
  'have-local-offer': [
    'stable',
    'closed'
  ],
  'have-remote-offer': [
    'stable',
    'closed'
  ],
  'closed': []
};

var INITIAL_SIGNALING_STATE = 'stable';

/* This is part of a workaround for Issue 3940, "One-way audio in Chrome 38
   when using a USB mic/headset and HTTPS":

       https://code.google.com/p/webrtc/issues/detail?id=3940

   We'll save the local MediaStream here and, on subsequent calls to
   .openHelper(), we'll skip the call to .getUserMedia() and pass localStream
   straight to the success callback. A consequence of this is that, in Chrome
   36+, only the first set of audioConstraints will ever be considered.

   This behavior is opt-in by calling

       Twilio.Device.setup(token, { chrome3940Workaround: true });

*/
var issue3940 = (function() {
    var detectedBrowser = util.detectBrowser();
    return detectedBrowser[0] === util.detectBrowser.CHROME
        && 36 <= detectedBrowser[1]
        && { audioConstraints: null,
             localStream: null };
})();

function PeerConnection(encrypt, device) {
    if (!(this instanceof PeerConnection))
      return new PeerConnection(encrypt, device);
    var noop = function() { };
    this.onopen = noop;
    this.onerror = noop;
    this.onclose = noop;
    this.version = null;
    this.pstream = device.stream;
    this.stream = null;
    this.video = typeof document !== 'undefined' && document.createElement("video");
    this.video.autoplay = "autoplay";
    this.device = device;
    this.status = "connecting";
    this.callSid = null;
    this._dtmfSender = null;
    this._dtmfSenderUnsupported = false;
    this._publishStatistics = null;
    this._sampleStatistics = null;
    this._statistics = [];
    this._nextTimeToPublish = Date.now();
    this._onAnswer = noop;
    log.mixinLog(this, '[Twilio.PeerConnection]');
    this.log.enabled = this.device.options['debug'];
    this.log.warnings = this.device.options['warnings'];
    if (!this.device.options['chrome3940Workaround']) {
      issue3940 = false;
    }

    this._iceConnectionStateMachine = new StateMachine(ICE_CONNECTION_STATES,
      INITIAL_ICE_CONNECTION_STATE);
    this._signalingStateMachine = new StateMachine(SIGNALING_STATES,
      INITIAL_SIGNALING_STATE);

    return this;
}

PeerConnection.prototype.uri = function() {
    return this._uri;
};
PeerConnection.prototype.openHelper = function(next, audioConstraints) {
    var self = this;

    if (issue3940) {
        // audioConstraints can be set exactly once with the workaround, so
        // warn the user if we won't be able to satisfy new constraints.
        issue3940.audioConstraints
          = issue3940.audioConstraints || audioConstraints;
        if (!util.deepEqual(issue3940.audioConstraints, audioConstraints)) {
            console.warn('Due to a bug in Chrome 38, only the first set of ' +
                         'audioConstraints will take effect.');
            self.log('Ignoring new audioConstraints: ' +
                     JSON.stringify(audioConstraints));
            self.log('Reusing existing audioConstraints: ' +
                     JSON.stringify(audioConstraints));
        }
        // If we've already set the local MediaStream, reuse it.
        if (issue3940.localStream) {
            self.log('Reusing local MediaStream');
            self.stream = issue3940.localStream;
            next();
            return;
        }
    }

    PeerConnection.getUserMedia({ audio: audioConstraints }, onSuccess, onFailure);

    // Retry .getUserMedia() a maximum of 10 times.
    var maxTries = 10;

    function onSuccess(stream) {
        // Save the local MediaStream for reuse.
        if (issue3940) {
            self.log('Got MediaStream; starting monitor');
            return monitorStream(stream, function(error, good) {
                if (error) {
                    self.log('Monitor failed; ' + error);
                    self.log('Setting local MediaStream anyway');
                    self.stream = stream;
                    return next();
                }
                if (!good) {
                    self.log('Local MediaStream is bad! ' +
                             'Requesting new MediaStream');
                    issue3940.audioConstraints = null;
                    stopStream(stream);
                    if (--maxTries > 0)  {
                        return PeerConnection.getUserMedia({ audio: audioConstraints }, onSuccess, onFailure);
                    } else {
                        next("Error occurred while accessing microphone.", 31201);
                    }
                }
                self.log('Local MediaStream appears good; saving');
                issue3940.localStream = stream;
                self.stream = stream;
                next();
            })
        }

        self.stream = stream;
        next(); 
    }

    function onFailure(error) {
        // audioConstraints weren't actually set due to error.
        if (issue3940) {
            issue3940.audioConstraints = null;
        }

        if (error.code == error.PERMISSION_DENIED)
            next("User denied access to microphone, or the web browser did not allow microphone access at this address.", 31208);
        else
            next("Error occurred while accessing microphone.", 31201);
    }
};
PeerConnection.prototype._setupPeerConnection = function() {
        var version = PeerConnection.protocol;
        version.create(this.log);
        version.pc.addStream(this.stream);
        var self = this;
        version.pc.onaddstream = function(ev) {
            if (typeof self.video.srcObject !== 'undefined') {
                self.video.srcObject = ev.stream;
            }
            else if (typeof self.video.mozSrcObject !== 'undefined') {
                self.video.mozSrcObject = ev.stream;
            }
            else if (typeof self.video.src !== 'undefined') {
                var url = window.URL || window.webkitURL;
                self.video.src = url.createObjectURL(ev.stream);
            }
            else {
                self.log('Error attaching stream to element.');
            }

            // Log the onaddstream event over PStream.
            var stats = convertToPStreamFormat(null, getPCInfo(version.pc));
            var stream = {};
            if (ev.stream) {
                stream.active = ev.stream.active;
                stream.id = ev.stream.id;
                var audioTracks = typeof ev.stream.getAudioTracks === 'function'
                  ? ev.stream.getAudioTracks() : ev.stream.audioTracks;
                stream.tracks = audioTracks.map(function(track) {
                    return {
                        enabled: track.enabled,
                        id: track.id,
                        kind: track.kind,
                        label: track.label,
                        muted: track.muted,
                        readonly: track.readonly,
                        readyState: track.readyState,
                        remote: track.remote
                    };
                });
            }
            stats.pc.onaddstream = stream;
            recordStatistics(self, stats);
        };
        return version;
    };
PeerConnection.prototype._setupChannel = function() {
        var self = this;
        var pc = this.version.pc;

        //Chrome 25 supports onopen
        self.version.pc.onopen = function() {
            self.status = "open";
            self.onopen();
        };

        //Chrome 26 doesn't support onopen so must detect state change
        self.version.pc.onstatechange = function(stateEvent) { 
            if (self.version.pc && self.version.pc.readyState == "stable") {
                self.status = "open";
                self.onopen();
            }
        };

        //Chrome 27 changed onstatechange to onsignalingstatechange
        self.version.pc.onsignalingstatechange = function(signalingEvent) {
            var state = pc.signalingState;
            self.log('signalingState is "' + state + '"');

            // Publish the onsignalingstatechange event over PStream.
            var stats = convertToPStreamFormat(null, getPCInfo(pc));
            recordStatistics(self, stats);

            // Update our internal state machine.
            try {
              self._signalingStateMachine.transition(state);
            } catch (error) {
              var stats = convertToPStreamFormat(null, getPCInfo(pc));
              stats.pc.invalidsignalingtransition = error.message;
              recordStatistics(self, stats);
            }

            if (self.version.pc && self.version.pc.signalingState == "stable") {
                self.status = "open";
                self.onopen();
            }
        };

        pc.onicecandidate = function onicecandidate(event) {
            // Publish the onicecandidate event over PStream.
            var candidate = event.candidate || 'end-of-candidates';
            var stats = convertToPStreamFormat(null, getPCInfo(pc));
            stats.pc.oncandidate = candidate;
            recordStatistics(self, stats);
        };

        pc.oniceconnectionstatechange = function() {
            var state = pc.iceConnectionState;
            var logMessage = 'iceConnectionState is "' + state + '"';

            // Publish the iceconnectionstatechange event over PStream.
            var stats = convertToPStreamFormat(null, getPCInfo(pc));
            recordStatistics(self, stats);

            // Update our internal state machine.
            try {
              self._iceConnectionStateMachine.transition(state);
            } catch (error) {
              var stats = convertToPStreamFormat(null, getPCInfo(pc));
              stats.pc.invalidiceconnectiontransition = error.message;
              recordStatistics(self, stats);
            }

            var errorMessage = null;
            switch (state) {
                case 'disconnected':
                    errorMessage = 'ICE liveness checks failed. May be having '
                                 + 'trouble connecting to Twilio.';
                case 'failed':
                    var disconnect = state === 'failed';
                    self.log(logMessage + (disconnect ? '; disconnecting' : ''));
                    errorMessage = errorMessage
                                || 'ICE negotiation with Twilio failed. '
                                 + 'Call will terminate.';
                    self.onerror({
                       info: {
                          code: 31003,
                          message: errorMessage
                       },
                       disconnect: disconnect
                    });
                    break;
                default:
                    self.log(logMessage);
            }
        };

        // setup listeners for call and setup
        if (self.pstream.status != "disconnected") {
            var onCandidate = function(payload) {
                if (self.status === 'closed') {
                    self.pstream.removeListener('candidate', onCandidate);
                    return;
                } else if (payload.callsid != self.callSid) {
                    return;
                }

                // Publish addIceCandidate event over PStream.
                var stats = convertToPStreamFormat(null, getPCInfo(pc));
                stats.pc.addcandidate = payload.candidate;
                recordStatistics(self, stats);

                self.version.processCandidate(payload.candidate, payload.label,
                    function onAddIceCandidateSuccess() {
                        // Publish success result of addIceCandidate over PStream.
                        var stats = convertToPStreamFormat(null, getPCInfo(pc));
                        stats.pc.addcandidatesuccess = payload.candidate;
                        recordStatistics(self, stats);
                    }, function onAddIceCandidateFailure(error) {
                        // Publish failure result of addIceCandidate over PStream.
                        var stats = convertToPStreamFormat(null, getPCInfo(pc));
                        stats.pc.addcandidatefailure = {
                            candidate: payload.candidate
                        };
                        if (error && error.message) {
                            stats.pc.addcandidatefailure.error = error.message;
                        }
                        recordStatistics(self, stats);
                    });
            };
            self.pstream.addListener("candidate", onCandidate);
        }
    };
PeerConnection.prototype._initializeMediaStream = function() {
        // if mediastream already open then do nothing
        if (this.status == "open") {
            return false;
        }
        if (this.pstream.status == "disconnected") {
            this.onerror({ info: { code: 31000, message: "Cannot establish connection. Client is disconnected" } });
            this.close();
            return false;
        }
        this.version = this._setupPeerConnection();
        this._setupChannel();
        return true;
};
PeerConnection.prototype.makeOutgoingCall = function(params, callsid) {
        if (!this._initializeMediaStream()) {
            return;
        }

        var self = this;
        this.callSid = callsid;
        var onAnswerSuccess = function() {}
        var onAnswerError = function(err) {
            var errMsg = err.message || err;
            self.onerror({ info: { code: 31000, message: "Error processing answer: " + errMsg } });
        }
        this._onAnswer = function(payload) {
            if (self.status != "closed") {
                self.version.processAnswer(payload.sdp, onAnswerSuccess, onAnswerError);
            }
        };
        this.pstream.once("answer", this._onAnswer);

        var onOfferSuccess = function() {
            if (self.status != "closed") {
                self.pstream.publish("invite", {
                    sdp: self.version.getSDP(),
                    callsid: self.callSid,
                    twilio: {
                        accountsid: self.device.token ? util.objectize(self.device.token).iss : null,
                        params: params
                    }
                });
                self.startSamplingStatistics();
            }
        };
        var onOfferError = function(err) {
            var errMsg = err.message || err;
            self.onerror({ info: { code: 31000, message: "Error creating the offer: " + errMsg } });
        };
        this.version.createOffer({ audio: true }, onOfferSuccess, onOfferError);
};
PeerConnection.prototype.answerIncomingCall = function(callSid, sdp) {
        if (!this._initializeMediaStream()) {
            return;
        }
        this.callSid = callSid;

        var self = this;
        var onAnswerSuccess = function() {
            if (self.status != "closed") {
                self.pstream.publish("answer", {
                    callsid: callSid,
                    sdp: self.version.getSDP()
                });
                self.startSamplingStatistics();
            }
        };
        var onAnswerError = function(err) {
            var errMsg = err.message || err;
            self.onerror({ info: { code: 31000, message: "Error creating the answer: " + errMsg } });
        };
        this.version.processSDP(sdp, { audio: true }, onAnswerSuccess, onAnswerError);
};
PeerConnection.prototype.close = function() {
        this.stopSamplingStatistics();
        if (this.version && this.version.pc) {
            var whoClosed;
            if (this.version.pc.signalingState !== 'closed') {
                // We closed the PeerConnection; log it.
                whoClosed = 'client';
                this.version.pc.close();
            } else {
                // PeerConnection was already closed; log it.
                whoClosed = 'unknown';
            }

            // Record who closed the PeerConnection and get a stacktrace.
            var stats = convertToPStreamFormat(null, getPCInfo(this.version.pc));
            stats.pc.whoclosed = whoClosed;
            try {
              stats.pc.stacktraceonclose = stackTrace().map(function(stackFrame) {
                return stackFrame.toString();
              }).join('\n');
            } catch (error) {
              stats.pc.stacktraceoncloseerror = error ? error.message : null;
            }

            // Record our history of state transitions.
            stats.pc.signalingtransitions = this._signalingStateMachine.transitions.map(function(transition) {
              return transition.from;
            });
            stats.pc.iceconnectiontransitions = this._iceConnectionStateMachine.transitions.map(function(transition) {
              return transition.from;
            });

            recordStatistics(this, stats);

            this.version.pc = null;
        }
        if (this.stream) {
            if (!issue3940) {
                stopStream(this.stream);
            }
            this.stream = null;
        }
        if (this.pstream) {
            this.pstream.removeListener('answer', this._onAnswer);
        }
        this.video.src = "";
        this.status = "closed";
        this.onclose();
};
PeerConnection.prototype.play = function(){};
PeerConnection.prototype.publish = function(){};
PeerConnection.prototype.attachAudio = function(callback) {
        if (this.stream) {
            var audioTracks = typeof this.stream.getAudioTracks === 'function'
              ? this.stream.getAudioTracks() : this.stream.audioTracks;
            audioTracks[0].enabled = true;
        }
        if (callback && typeof callback == "function") {
            callback();
        }
};
PeerConnection.prototype.detachAudio = function(callback) {
        if (this.stream) {
            var audioTracks = typeof this.stream.getAudioTracks === 'function'
              ? this.stream.getAudioTracks() : this.stream.audioTracks;
            audioTracks[0].enabled = false;
        }
        if (callback && typeof callback == "function") {
            callback();
        }
};
PeerConnection.prototype.isAudioAttached = function() {
        if (this.stream) {
            var audioTracks = typeof this.stream.getAudioTracks === 'function'
              ? this.stream.getAudioTracks() : this.stream.audioTracks;
            return audioTracks[0].enabled;
        }
        return false;
};

/**
 * Start publishing WebRTC statistics for this {@link PeerConnection}.
 */
PeerConnection.prototype.startPublishingStatistics = function() {
    if (this._publishStatistics) {
        return;
    }
    var self = this;
    var timeout = Math.max(this._nextTimeToPublish - Date.now(), 0);
    this._publishStatistics = setTimeout(function() {
        self._publishStatistics = null;
        publishStatistics(self, self.pstream, self.callSid);
        self._nextTimeToPublish += STATS_PUBLISH_INTERVAL;
    }, timeout);
};

/**
 * Stop sampling WebRTC statistics for this {@link PeerConnection}.
 */
PeerConnection.prototype.stopSamplingStatistics = function() {
    clearInterval(this._sampleStatistics);
    this._sampleStatistics = null;
};

/**
 * Start sampling WebRTC statistics for this {@link PeerConnection}.
 * Statistics will be sampled multiple times in a publishing interval.
 */
PeerConnection.prototype.startSamplingStatistics = function() {
    this.stopSamplingStatistics();
    var self = this;
    this._sampleStatistics = setInterval(function() {
        var pcInfo = getPCInfo(self.version.pc);
        getStatistics(self.version.pc, function(error, stats) {
            if (error) {
                self.stopSamplingStatistics();
                return;
            }
            stats = convertToPStreamFormat(stats, pcInfo);
            recordStatistics(self, stats);
        });
    }, STATS_SAMPLE_INTERVAL);
};

function getPCInfo(pc) {
  return {
    iceconnection: pc.iceConnectionState,
    icegathering: pc.iceGatheringState,
    signaling: pc.signalingState
  };
}

/**
 * Record WebRTC statistics for the given {@link PeerConnection}.
 * @param {PeerConnection} peerConnection - The {@link PeerConnection} to
 *                                          record for
 * @parma {?object} stats - The WebRTC statistics
 */
function recordStatistics(peerConnection, stats) {
    if (stats) {
        peerConnection._statistics.push(stats)
        peerConnection.startPublishingStatistics();
    }
}

/**
 * Publish WebRTC statistics for the given {@link PeerConnection} if we have
 * a call SID and the PStream is not disconnected.
 * @param {PeerConnection} peerConnection - The {@link PeerConnection} to
 *                                          publish for
 * @param {PStream} pstream - The {@link PStream} connection
 * @param {?string} callSid - The call SID
 * @returns {boolean}
 */
function publishStatistics(peerConnection, pstream, callSid) {
    if (callSid && pstream.status !== 'disconnected') {
        var stats = peerConnection._statistics.splice(0);
        if (stats.length) {
            pstream.publish('meta', {
                callsid: callSid,
                quality: stats
            });
            return true;
        }
    }
    return false;
}

/**
 * Convert the WebRTC statistics we get from {@link getStatistics} into the
 * format we'll send out over the {@link PStream} connection.
 * @param {object} stats - The WebRTC statistics
 * @param {object} pcInfo
 * @returns object
 */
function convertToPStreamFormat(stats, pcInfo) {
  var pstreamStat = stats ?
    {
      timestamp: stats.timestamp,
      packets: {
          recvlost: stats.packetsLost,
          recvtot: stats.packetsReceived,
          senttot: stats.packetsSent
      },
      bytes: {
          recvtot: stats.bytesReceived,
          senttot: stats.bytesSent
      },
      jitter: stats.jitter,
      rtt: stats.rtt,
      audio: {
        inlvl: stats.audioInputLevel,
        outlvl: stats.audioOutputLevel
      }
    } : {};
  pstreamStat.timestamp = pstreamStat.timestamp || Math.floor(new Date()/1000);
  pstreamStat.pc = pcInfo;
  return pstreamStat;
}

PeerConnection.getUserMedia = function(constraints, successCallback, errorCallback) {
    if (typeof navigator == "undefined") return;
    if (typeof navigator.webkitGetUserMedia == "function") {
        navigator.webkitGetUserMedia(constraints, successCallback, errorCallback);
    }
    else if (typeof navigator.mozGetUserMedia == "function") {
        navigator.mozGetUserMedia(constraints, successCallback, errorCallback);
    }
    else {
        this.log("No getUserMedia() implementation available");
    }
};

/**
 * Get or create an RTCDTMFSender for the first local audio MediaStreamTrack
 * we can get from the RTCPeerConnection. Return null if unsupported.
 * @instance
 * @returns ?RTCDTMFSender
 */
PeerConnection.prototype.getOrCreateDTMFSender =
  function getOrCreateDTMFSender()
{
  if (this._dtmfSender) {
    return this._dtmfSender;
  } else if (this._dtmfSenderUnsupported) {
    return null;
  }

  var pc = this.version.pc;
  if (!pc) {
    this.log('No RTCPeerConnection available to call createDTMFSender on');
    return null;
  }

  if (typeof pc.createDTMFSender !== 'function') {
    this.log('RTCPeerConnection does not support createDTMFSender');
    this._dtmfSenderUnsupported = true;
    return null;
  }

  // Select a local audio MediaStreamTrack.
  var streams = pc.getLocalStreams();
  var stream;
  var tracks;
  var track;
  for (var i = 0; i < streams.length; i++) {
    stream = streams[i];
    tracks = typeof stream.getAudioTracks === 'function'
      ? stream.getAudioTracks() : stream.audioTracks;
    if (tracks.length) {
      track = tracks[0];
      break;
    }
  }
  if (!track) {
    this.log('No local audio MediaStreamTrack available on the ' +
             'RTCPeerConnection to pass to createDTMFSender');
    return null;
  }

  this.log('Creating RTCDTMFSender');
  var dtmfSender = pc.createDTMFSender(track);
  this._dtmfSender = dtmfSender;
  return dtmfSender;
};

var RTCPC = function() {
    if (typeof window == "undefined") return;
    if (typeof window.webkitRTCPeerConnection == "function") {
        this.RTCPeerConnection = webkitRTCPeerConnection;
    } else if (typeof window.mozRTCPeerConnection == "function") {
        this.RTCPeerConnection = mozRTCPeerConnection;
        RTCSessionDescription = mozRTCSessionDescription;
        RTCIceCandidate = mozRTCIceCandidate;
    } else {
        this.log("No RTCPeerConnection implementation available");
    }
};

RTCPC.prototype.create = function(log) {
    this.log = log;
    this.pc = new this.RTCPeerConnection({ iceServers: [] });
};
RTCPC.prototype.createModernConstraints = function(c) {
    // createOffer differs between Chrome 23 and Chrome 24+.
    // See https://groups.google.com/forum/?fromgroups=#!topic/discuss-webrtc/JBDZtrMumyU
    // Unfortunately I haven't figured out a way to detect which format
    // is required ahead of time, so we'll first try the old way, and
    // if we get an exception, then we'll try the new way.
    if (typeof c === "undefined") {
        return null;
    }
    // NOTE(mroberts): As of Chrome 38, Chrome still appears to expect
    // constraints under the "mandatory" key, and with the first letter of each
    // constraint capitalized. Firefox, on the other hand, has deprecated the
    // "mandatory" key and does not expect the first letter of each constraint
    // capitalized.
    var nc = {};
    if (typeof webkitRTCPeerConnection !== 'undefined') {
        nc.mandatory = {};
        if (typeof c.audio !== "undefined") {
            nc.mandatory.OfferToReceiveAudio = c.audio;
        }
        if (typeof c.video !== "undefined") {
            nc.mandatory.OfferToReceiveVideo = c.video;
        }
    } else {
        if (typeof c.audio !== "undefined") {
            nc.offerToReceiveAudio = c.audio;
        }
        if (typeof c.video !== "undefined") {
            nc.offerToReceiveVideo = c.video;
        }
    }
    return nc;
};
RTCPC.prototype.createOffer = function(constraints, onSuccess, onError) {
    var self = this;

    var success = function(sd) {
        if (self.pc) {
            self.pc.setLocalDescription(new RTCSessionDescription(sd), onSuccess, onError);
        }
    }
    this.pc.createOffer(success, onError, this.createModernConstraints(constraints));
};
RTCPC.prototype.createAnswer = function(constraints, onSuccess, onError) {
    var self = this;

    var success = function(sd) {
        if (self.pc) {
            self.pc.setLocalDescription(new RTCSessionDescription(sd), onSuccess, onError);
        }
    }
    this.pc.createAnswer(success, onError, this.createModernConstraints(constraints));
};
RTCPC.prototype.processSDP = function(sdp, constraints, onSuccess, onError) {
    var self = this;

    var success = function() {
        self.createAnswer(constraints, onSuccess, onError);
    };
    this.pc.setRemoteDescription(new RTCSessionDescription({ sdp: sdp, type: "offer" }), success, onError);
};
RTCPC.prototype.getSDP = function() {
    return this.pc.localDescription.sdp;
};
RTCPC.prototype.processAnswer = function(sdp, onSuccess, onError) {
    if (!this.pc) {
        return;
    }
    this.pc.setRemoteDescription(
        new RTCSessionDescription({ sdp: sdp, type: "answer" }), onSuccess, onError);
};
RTCPC.prototype.processCandidate = function(candidate, label, onSuccess, onFailure) {
    if (!this.pc) {
        return;
    }
    var self = this;
    return this.pc.addIceCandidate(
        new RTCIceCandidate({ sdpMLineIndex: 0, candidate: candidate }),
        onSuccess, onFailure);
};
/* NOTE(mroberts): Firefox 18 through 21 include a `mozRTCPeerConnection`
   object, but attempting to instantiate it will throw the error

       Error: PeerConnection not enabled (did you set the pref?)

   unless the `media.peerconnection.enabled` pref is enabled. So we need to test
   if we can actually instantiate `mozRTCPeerConnection`; however, if the user
   *has* enabled `media.peerconnection.enabled`, we need to perform the same
   test that we use to detect Firefox 24 and above, namely:

       typeof (new mozRTCPeerConnection()).getLocalStreams === 'function'

 */
RTCPC.test = function() {
    if (typeof navigator == 'object') {
        if (navigator.webkitGetUserMedia &&
            typeof window.webkitRTCPeerConnection == 'function') {
            return true;
        } else if (navigator.mozGetUserMedia &&
                   typeof window.mozRTCPeerConnection == 'function') {
            try {
                var test = new window.mozRTCPeerConnection();
                if (typeof test.getLocalStreams !== 'function')
                    return false;
            } catch (e) {
                return false;
            }
            return true;
        }
    }
};

PeerConnection.protocol = (function() {
    if (RTCPC.test()) return new RTCPC();
    else return null;
})();

PeerConnection.enabled = !!PeerConnection.protocol;

function stopStream(stream) {
  if (typeof MediaStreamTrack.prototype.stop === 'function') {
    var audioTracks = typeof stream.getAudioTracks === 'function'
      ? stream.getAudioTracks() : stream.audioTracks;
    audioTracks.forEach(function(track) {
      track.stop();
    });
  }
  // NOTE(mroberts): This is just a fallback to any ancient browsers that may
  // not implement MediaStreamTrack.stop.
  else {
    stream.stop();
  }
}

module.exports = PeerConnection;

},{"../log":8,"../statemachine":20,"../util":21,"./issue3940":15,"./stats":17,"stacktrace-js":32}],17:[function(require,module,exports){
/**
 * Collect any WebRTC statistics for the given {@link PeerConnection} and pass
 * them to an error-first callback.
 * @param {PeerConnection} peerConnection - The {@link PeerConnection}
 * @param {function} callback - The callback
 */
function getStatistics(peerConnection, callback) {
  var error = new Error('WebRTC statistics are unsupported');
  if (!peerConnection) {
    callback(new Error('PeerConnection is null'));
  } else if (typeof navigator === 'undefined' || typeof peerConnection.getStats !== 'function') {
    callback(error);
  } else if (navigator.webkitGetUserMedia) {
    peerConnection.getStats(chainCallback(withStats, callback), callback);
  } else if (navigator.mozGetUserMedia) {
    peerConnection.getStats(null, chainCallback(mozWithStats, callback), callback);
  } else {
    callback(error);
  }
}

/**
 * Handle any WebRTC statistics for Google Chrome and pass them to an error-
 * first callback.
 * @param {RTCStatsResponse} response - WebRTC statistics for Google Chrome
 * @param {function} callback - The callback
 */
function withStats(response, callback) {
  var knownStats = [];
  var unknownStats = [];
  var results = response.result();
  results.forEach(function(report) {
    var processedReport = null;
    switch (report.type) {
      case 'googCandidatePair':
        processedReport = processCandidatePair(report);
        break;
      case 'ssrc':
        processedReport = processSSRC(report);
        break;
      // Unknown
      default:
        unknownStats.push(report);
    }
    if (processedReport) {
      knownStats.push(processedReport);
    }
  });
  if (knownStats.length === 0 || (knownStats = filterKnownStats(knownStats)).length === 0) {
    return callback(null, {});
  }
  var mergedStats = knownStats.reduceRight(function(mergedStat, knownStat) {
    for (var name in knownStat) {
      mergedStat[name] = knownStat[name];
    }
    return mergedStat;
  }, {});
  callback(null, mergedStats);
}

function processCandidatePair(report) {
  var knownStats = {};
  var unknownStats = {};
  var names = report.names();
  var timestamp = report.timestamp ? Math.floor(report.timestamp/1000) : null;
  for (var i = 0; i < names.length; i++) {
    var name = names[i];
    var value = report.stat(name);
    switch (name) {
      // If the connection represented by this report is inactive, bail out.
      case 'googActiveConnection':
        if (value !== 'true') {
          return null;
        }
        break;
      // Rename "goog"-prefixed stats.
      case 'googLocalAddress':
        knownStats['localAddress'] = value;
        break;
      case 'googRemoteAddress':
        knownStats['remoteAddress'] = value;
        break;
      case 'googRtt':
        knownStats['rtt'] = Number(value);
        break;
      // Ignore empty stat names (annoying, I know).
      case '':
        break;
      // Unknown
      default:
        unknownStats[name] = value;
    }
  }
  knownStats.timestamp = timestamp;
  return packageStats(knownStats, unknownStats);
}

function processSSRC(report) {
  var knownStats = {};
  var unknownStats = {};
  var names = report.names();
  var timestamp = report.timestamp ? Math.floor(report.timestamp/1000) : null;
  names.forEach(function(name) {
    var value = report.stat(name);
    switch (name) {
      // Rename "goog"-prefixed stats.
      case 'googCodecName':
        // Filter out the empty case.
        var codecName = value;
        if (codecName !== '') {
          knownStats['codecName'] = value;
        }
        break;
      case 'googJitterBufferMs':
        knownStats['googJitterBufferMs'] = Number(value);
        break;
      case 'googJitterReceived':
        // Filter out the -1 case.
        var jitterReceived = Number(value);
        if (jitterReceived !== -1) {
          knownStats['jitter'] = jitterReceived;
        }
        break;
      // Pass these stats through unmodified.
      case 'bytesReceived':
      case 'bytesSent':
      case 'packetsReceived':
      case 'packetsSent':
      case 'timestamp':
      case 'audioInputLevel':
      case 'audioOutputLevel':
        knownStats[name] = Number(value);
        break;
      case 'packetsLost':
        // Filter out the -1 case.
        var packetsLost = Number(value);
        if (packetsLost !== -1) {
          knownStats[name] = packetsLost;
        }
        break;
      // Unknown
      default:
        unknownStats[name] = value;
    }
  });
  knownStats.timestamp = timestamp;
  return packageStats(knownStats, unknownStats);
}

/**
 * Handle any WebRTC statistics for Mozilla Firefox and pass them to an error-
 * first callback.
 * @param {RTCStatsReport} reports - WebRTC statistics for Mozilla Firefox
 * @param {function} callback - The callback
 */
function mozWithStats(reports, callback) {
  var knownStats = [];
  var unknownStats = []
  reports.forEach(function(report) {
    var processedReport = null;
    switch (report.type) {
      case 'inboundrtp':
        processedReport = processInbound(report);
        break;
      case 'outboundrtp':
        if (report.isRemote === false) {
          processedReport = processOutbound(report);
        }
        break;
      // Unknown
      default:
        unknownStats.push(report);
    }
    if (processedReport) {
      knownStats.push(processedReport);
    }
  });
  if (knownStats.length === 0 || (knownStats = filterKnownStats(knownStats)).length === 0) {
    return callback(null, {});
  }
  var mergedStats = knownStats.reduceRight(function(mergedStat, knownStat) {
    for (var name in knownStat) {
      mergedStat[name] = knownStat[name];
    }
    return mergedStat;
  }, {});
  callback(null, mergedStats);
}

function processOutbound(report) {
  var knownStats = {};
  var unknownStats = {};
  for (var name in report) {
    var value = report[name];
    switch (name) {
      // Convert to UNIX timestamp.
      case 'timestamp':
          knownStats[name] = Math.floor(value/1000);
      // Pass these stats through unmodified.
      case 'bytesSent':
      case 'packetsSent':
        knownStats[name] = value;
        break;
      // Unknown
      default:
        unknownStats[name] = value;
    }
  }
  return packageStats(knownStats, unknownStats);
}

function processInbound(report) {
  var knownStats = {};
  var unknownStats = {};
  for (var name in report) {
    var value = report[name];
    switch (name) {
      // Rename "moz"-prefixed stats.
      case 'mozRtt':
        knownStats['rtt'] = value;
        break;
      // Convert to UNIX timestamp.
      case 'timestamp':
        knownStats[name] = Math.floor(value/1000);
        break;
      // Convert to milliseconds.
      case 'jitter':
        knownStats[name] = value * 1000;
        break;
      // Pass these stats through unmodified.
      case 'bytesReceived':
      case 'packetsLost':
      case 'packetsReceived':
        knownStats[name] = value;
        break;
      // Unknown
      default:
        unknownStats[name] = value;
    }
  }
  return packageStats(knownStats, unknownStats);
}

/**
 * Given two objects containing known and unknown WebRTC statistics, include
 * each in an object keyed by "known" or "unkown" if they are non-empty. If
 * both are empty, return null.
 * @param {?object} knownStats - Known WebRTC statistics
 * @param {?object} unknownStats - Unkown WebRTC statistics
 * @returns ?object
 */
function packageStats(knownStats, unknownStats) {
  var stats = null;
  if (!empty(knownStats)) {
    stats = stats || {};
    stats.known = knownStats;
  }
  if (!empty(unknownStats)) {
    stats = stats || {};
    stats.unknown = unknownStats;
  }
  return stats;
}

/**
 * Given a list of objects containing known and/or unknown WebRTC statistics,
 * return only the known statistics.
 * @param {Array} stats - A list of objects containing known and/or unknown
 *                        WebRTC statistics
 * @returns Array
 */
function filterKnownStats(stats) {
  var knownStats = [];
  for (var i = 0; i < stats.length; i++) {
    var stat = stats[i];
    if (stat.known) {
      knownStats.push(stat.known);
    }
  }
  return knownStats;
}

/**
 * Check if an object is "empty" in the sense that it contains no keys.
 * @param {?object} obj - The object to check
 * @returns boolean
 */
function empty(obj) {
  if (!obj) {
    return true;
  }
  for (var key in obj) {
    return false;
  }
  return true;
}

/**
 * Given a function that takes a callback as its final argument, fix that final
 * argument to the provided callback.
 * @param {function} function - The function
 * @param {function} callback - The callback
 * @returns function
 */
function chainCallback(func, callback) {
  return function() {
    var args = Array.prototype.slice.call(arguments);
    args.push(callback);
    return func.apply(null, args);
  };
}

module.exports = getStatistics;

},{}],18:[function(require,module,exports){
function not(expr) { return !expr; }
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

SoundCache.prototype.add = function(name, sounds, envelope) {
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
};
SoundCache.prototype.play = function(name, position, loop) {
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
};
SoundCache.prototype.stop = function(name) {
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
};
SoundCache.prototype.envelope = function(name, update) {
        if (not(name in this.cache)) {
            return;
        }
        var voice = this.cache[name];
        for (var prop in update) {
            voice.envelope[prop] = update[prop];
        }
};
SoundCache.prototype.playseq = (function() {
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
})();

exports.SoundCache = SoundCache;

},{}],19:[function(require,module,exports){
// Generated by CoffeeScript 1.9.3
var DEFAULT_EVENT_PREFIX, StateM, Transition, TransitionError, buildTransitions, isEmptyObject, titleCase,
  extend = function(child, parent) { for (var key in parent) { if (hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
  hasProp = {}.hasOwnProperty,
  indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; },
  slice = [].slice;

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
  var k, results, v;
  results = [];
  for (k in transT) {
    v = transT[k];
    results.push(new Transition(k, v));
  }
  return results;
};

TransitionError = (function(superClass) {
  extend(TransitionError, superClass);

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
    var i, len, t, transitions;
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
    for (i = 0, len = transitions.length; i < len; i++) {
      t = transitions[i];
      this.makeEvent(t);
    }
  }

  StateM.prototype.makeEvent = function(transition) {
    return this[transition.name] = (function(_this) {
      return function() {
        var ref;
        if (ref = _this.state, indexOf.call(transition.froms, ref) < 0) {
          throw new TransitionError("Not a valid transition");
        }
        _this.stateData = _this.invoke.apply(_this, ["leave", _this.state, transition].concat(slice.call(_this.stateData)));
        _this.stateData = _this.invoke.apply(_this, ["enter", transition.to, transition].concat(slice.call(_this.stateData)));
        return _this.state = transition.to;
      };
    })(this);
  };

  StateM.prototype.invoke = function() {
    var args, direction, method, ref, result, state, transition;
    direction = arguments[0], state = arguments[1], transition = arguments[2], args = 4 <= arguments.length ? slice.call(arguments, 3) : [];
    method = direction + titleCase(state);
    if (this.ctx[method]) {
      result = (ref = this.ctx)[method].apply(ref, [transition].concat(slice.call(args)));
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

exports.StateM = StateM;

},{}],20:[function(require,module,exports){
'use strict';

var inherits = require('util').inherits;

/**
 * Construct a {@link StateMachine}.
 * @class
 * @classdesc A {@link StateMachine} is defined by an object whose keys are
 *   state names and whose values are arrays of valid states to transition to.
 *   All state transitions, valid or invalid, are recorded.
 * @param {?string} initialState
 * @param {object} states
 * @property {string} currentState
 * @proeprty {object} states
 * @property {Array<StateTransition>} transitions
 */
function StateMachine(states, initialState) {
  if (!(this instanceof StateMachine)) {
    return new StateMachine(states, initialState);
  }
  var currentState = initialState;
  Object.defineProperties(this, {
    _currentState: {
      get: function() {
        return currentState;
      },
      set: function(_currentState) {
        currentState = _currentState;
      }
    },
    currentState: {
      enumerable: true,
      get: function() {
        return currentState;
      }
    },
    states: {
      enumerable: true,
      value: states
    },
    transitions: {
      enumerable: true,
      value: []
    }
  });
  Object.freeze(this);
}

/**
 * Transition the {@link StateMachine}, recording either a valid or invalid
 * transition. If the transition was valid, we complete the transition before
 * throwing the {@link InvalidStateTransition}.
 * @param {string} to
 * @throws {InvalidStateTransition}
 * @returns {this}
 */
StateMachine.prototype.transition = function transition(to) {
  var from = this.currentState;
  var valid = this.states[from];
  var transition = valid && valid.indexOf(to) !== -1
    ? new StateTransition(from, to)
    : new InvalidStateTransition(from, to);
  this.transitions.push(transition);
  this._currentState = to;
  if (transition instanceof InvalidStateTransition) {
    throw transition;
  }
  return this;
};

/**
 * Construct a {@link StateTransition}.
 * @class
 * @param {?string} from
 * @param {string} to
 * @property {?string} from
 * @property {string} to
 */
function StateTransition(from, to) {
  Object.defineProperties(this, {
    from: {
      enumerable: true,
      value: from
    },
    to: {
      enumerable: true,
      value: to
    }
  });
}

/**
 * Construct an {@link InvalidStateTransition}.
 * @class
 * @augments Error
 * @augments StateTransition
 * @param {?string} from
 * @param {string} to
 * @property {?string} from
 * @property {string} to
 * @property {string} message
 */
function InvalidStateTransition(from, to) {
  if (!(this instanceof InvalidStateTransition)) {
    return new InvalidStateTransition(from, to);
  }
  Error.call(this);
  StateTransition.call(this, from, to);
  var errorMessage = 'Invalid transition from ' +
    (typeof from === 'string' ? '"' + from + '"' : 'null') + ' to "' + to + '"';
  Object.defineProperties(this, {
    message: {
      enumerable: true,
      value: errorMessage
    }
  });
  Object.freeze(this);
}

inherits(InvalidStateTransition, Error);

module.exports = StateMachine;

},{"util":31}],21:[function(require,module,exports){
(function (Buffer){
var EventEmitter = require('events').EventEmitter;

// NOTE(mroberts): `JSON` is special.
JSON = typeof JSON !== 'undefined' ? JSON : require('../../vendor/json2');
var base64 = require('../../vendor/base64');
var swfobject = require('../../vendor/swfobject').swfobject;

function getSDKVersion() {
  // NOTE(mroberts): Set by `Makefile'.
  return "1.2" || '1.0';
}

function getSDKHash() {
  // NOTE(mroberts): Set by `Makefile'.
  return "5c1f1e8";
}

/**
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
        result[decodeURIComponent(pair[0])] = makedict(decodeURIComponent(pair[1]));
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
            return base64.encode(message);
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
            return base64.decode(encoded);
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
    var rtc = require("./rtc"),
        version = getSDKVersion(),
        hash = getSDKHash(),
        nav = typeof navigator != "undefined" ? navigator : {};
    
    var info = {
        p: "browser",
        v: version,
        h: hash,
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

function generateConnectionUUID() {
    return 'TJSxxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
        var r = Math.random()*16|0, v = c == 'x' ? r : (r&0x3|0x8);
        return v.toString(16);
    });
}

var TWILIO_ROOT = "";

function getTwilioRoot() {
  return TWILIO_ROOT;
}

function setTwilioRoot(twilioRoot) {
  TWILIO_ROOT = twilioRoot;
}

/**
 * Returns the "media engine" currently in use by a {@link Device}, i.e. Flash
 * or WebRTC. It's not sufficient to just check if WebRTC is supported. We must
 * also check the "rtc" option.
 *
 * If no {@link Device} is provided, this method returns the preferred media
 * engine.
 * @param {?Device} device - the {@link Device} to queury
 * @returns {string}
 */
function getMediaEngine(device) {
  var rtc = require('./rtc');
  return (device ? device.options['rtc'] : true) && rtc.enabled()
    ? getMediaEngine.WEBRTC
    : getMediaEngine.FLASH;
}
getMediaEngine.FLASH = 'Flash';
getMediaEngine.WEBRTC = 'WebRTC';

/**
 * Mixin the function {@link getMediaEngine} on a given {@link Device}
 * prototype.
 * @param {object} prototype - the {@link Device} prototype to modify
 * @returns {object}
 */
function mixinGetMediaEngine(prototype) {
  var getMediaEngineForDevice = getMediaEngine;
  prototype.getMediaEngine = function getMediaEngine() {
    return getMediaEngineForDevice(this);
  };
  prototype.getMediaEngine.FLASH = getMediaEngine.FLASH;
  prototype.getMediaEngine.WEBRTC = getMediaEngine.WEBRTC;
  return prototype;
}

function monitorEventEmitter(name, object) {
  object.setMaxListeners(0);
  var MAX_LISTENERS = 10;
  function monitor(event) {
    var n = EventEmitter.listenerCount(object, event);
    var warning = 'The number of ' + event + ' listeners on ' + name + ' ' +
                  'exceeds the recommended number of ' + MAX_LISTENERS + '. ' +
                  'While twilio.js will continue to function normally, this ' +
                  'may be indicative of an application error. Note that ' +
                  event + ' listeners exist for the lifetime of the ' +
                  name + '.';
    if (n >= MAX_LISTENERS) {
      if (typeof console !== 'undefined') {
        if (console.warn) {
          console.warn(warning);
        } else if (console.log) {
          console.log(warning);
        }
      }
      object.removeListener('newListener', monitor);
    }
  }
  object.on('newListener', monitor);
}

/**
 * Attempt to detect the browser name and major version.
 * @returns {Array}
 */
function detectBrowser() {
  var webrtcDetectedBrowser = detectBrowser.UNKNOWN;
  var webrtcDetectedVersion = 999;
  if (typeof navigator !== 'undefined') {
    if (navigator.mozGetUserMedia) {
      webrtcDetectedBrowser = detectBrowser.FIREFOX;
      try {
        webrtcDetectedVersion =
          parseInt(navigator.userAgent.match(/Firefox\/([0-9]+)\./)[1], 10);
      } catch (e) {
        // Do nothing
      }
    } else if (navigator.webkitGetUserMedia) {
      webrtcDetectedBrowser = detectBrowser.CHROME;
      var result = navigator.userAgent.match(/Chrom(e|ium)\/([0-9]+)\./);
      if (result !== null) {
        try {
          webrtcDetectedVersion = parseInt(result[2], 10);
        } catch (e) {
          // Do nothing
        }
      }
    }
  }
  return [webrtcDetectedBrowser, webrtcDetectedVersion];
}

detectBrowser.CHROME = 'chrome';
detectBrowser.FIREFOX = 'firefox';
detectBrowser.UNKNOWN = 'unknown';

// This definition of deepEqual is adapted from Node's deepEqual.
function deepEqual(a, b) {
  if (a === b) {
    return true;
  } else if (typeof a !== typeof b) {
    return false;
  } else if (a instanceof Date && b instanceof Date) {
    return a.getTime() === b.getTime();
  } else if (typeof a !== 'object' && typeof b !== 'object') {
    return a == b;
  } else {
    return objectDeepEqual(a, b);
  }
}

var objectKeys = typeof Object.keys === 'function' ? Object.keys : function(obj) {
  var keys = [];
  for (var key in obj) {
    keys.push(key);
  }
  return keys;
};

function isUndefinedOrNull(a) {
  return a === undefined || a === null;
}

function objectDeepEqual(a, b) {
  if (isUndefinedOrNull(a) || isUndefinedOrNull(b)) {
    return false;
  } else if (a.prototype !== b.prototype) {
    return false;
  } else {
    try {
      var ka = objectKeys(a);
      var kb = objectKeys(b);
    } catch (e) {
      return false;
    }
    if (ka.length !== kb.length) {
      return false;
    }
    ka.sort();
    kb.sort();
    for (var i = ka.length - 1; i >= 0; i--) {
      var k = ka[i];
      if (!deepEqual(a[k], b[k])) {
        return false;
      }
    }
    return true;
  }
}

exports.getSDKVersion = getSDKVersion;
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
exports.getSystemInfo = getSystemInfo;
exports.splitObjects = splitObjects;
exports.generateConnectionUUID = generateConnectionUUID;
exports.getTwilioRoot = getTwilioRoot;
exports.setTwilioRoot = setTwilioRoot;
exports.getMediaEngine = getMediaEngine;
exports.mixinGetMediaEngine = mixinGetMediaEngine;
exports.monitorEventEmitter = monitorEventEmitter;
exports.detectBrowser = detectBrowser;
exports.deepEqual = deepEqual;

}).call(this,require("buffer").Buffer)
},{"../../vendor/base64":33,"../../vendor/json2":34,"../../vendor/swfobject":37,"./rtc":14,"buffer":23,"events":27}],22:[function(require,module,exports){
var Heartbeat = require("./heartbeat").Heartbeat;
var log = require("./log");

var WebSocket = require('../../vendor/web-socket-js/web_socket').WebSocket;

/*
 * WebSocket transport class
 */
function WSTransport(options) { 
    var self = this instanceof WSTransport ? this : new WSTransport(options);
    self.sock = null;
    var noop = function() {};
    self.onopen = noop;
    self.onclose = noop;
    self.onmessage = noop;
    self.onerror = noop;

    var defaults = {
        logPrefix:  "[WSTransport]",
        host:       "chunderw-gll.twilio.com",
        reconnect:  true,
        debug:      false,
        secureSignaling: true
    };
    options = options || {};
    for (var prop in defaults) {
        if (prop in options) continue;
        options[prop] = defaults[prop];
    }
    self.options = options;

    log.mixinLog(self, self.options["logPrefix"]);
    self.log.enabled = self.options["debug"];

    self.defaultReconnect = self.options["reconnect"];

    var scheme = self.options["secureSignaling"] ? "wss://" : "ws://";
    self.uri = scheme + self.options["host"] + "/signal";
    return self;
}

WSTransport.prototype.msgQueue = [];
WSTransport.prototype.open = function(attempted) {
        this.log("Opening socket");
        if (this.sock && this.sock.readyState < 2) {
            this.log("Socket already open.");
            return;
        }

        this.options["reconnect"] = this.defaultReconnect;

        // cancel out any previous heartbeat
        if (this.heartbeat) {
            this.heartbeat.onsleep = function() {};
        }
        this.heartbeat = new Heartbeat({ "interval": 15 });
        this.sock = this._connect(attempted);
};
WSTransport.prototype.send = function(msg) {
        if (this.sock) {
            if (this.sock.readyState == 0) {
                this.msgQueue.push(msg);
                return;
            }

            try {
                this.sock.send(msg);
            } catch (error) {
                this.log("Error while sending. Closing socket: " + error.message);
                this.sock.close();
            }
        }
};
WSTransport.prototype.close = function() {
        this.log("Closing socket");
        this.options["reconnect"] = false;
        if (this.sock) {
            this.sock.close();
            this.sock = null;
        }
        this.heartbeat.onsleep = function() {};
};
WSTransport.prototype._cleanupSocket = function(socket) {
        if (socket) {
            this.log("Cleaning up socket");
            var noop = function() {};
            socket.onopen = function() { socket.close(); };
            socket.onmessage = noop;
            socket.onerror = noop;
            socket.onclose = noop;

            if (socket.readyState < 2) {
                socket.close();
            }
        }
};
WSTransport.prototype._connect = function(attempted) {
        var attempt = ++attempted || 1;

        this.log("attempting to connect");
        var sock = null;
        try {
            sock = new WebSocket(this.uri);
        }
        catch (e) {
            this.onerror({ code: 31000, message: e.message || "Could not connect to " + this.uri});
            this.close(); //close connection for good
            return;
        }

        var self = this;

        // clean up old socket to avoid any race conditions with the callbacks
        var oldSocket = this.sock;
        var getTime = function() { return new Date().getTime(); };
        var timeOpened = null;

        var connectTimeout = setTimeout(function() {
            self.log("connection attempt timed out");
            sock.onclose = function() {};
            sock.close();
            self.onclose();
            self._tryReconnect(attempt);
        }, 5000);

        sock.onopen = function() {
            clearTimeout(connectTimeout);
            self._cleanupSocket(oldSocket);
            timeOpened = getTime();
            self.log("Socket opened");

            // setup heartbeat onsleep and beat it once to get timer started
            self.heartbeat.onsleep = function() {
                // treat it like the socket closed because when network drops onclose does not get called right away
                self.log("Heartbeat timed out. closing socket");
                self.sock.onclose = function() {};
                self.sock.close();
                self.onclose();
                self._tryReconnect(attempt);
            }
            self.heartbeat.beat();

            self.onopen();

            // send after onopen to preserve order
            for (var i = 0; i < self.msgQueue.length; i++) {
                self.sock.send(self.msgQueue[i]);
            }
            self.msgQueue = [];
        };
        sock.onclose = function() {
            clearTimeout(connectTimeout);
            self._cleanupSocket(oldSocket);

            // clear the heartbeat onsleep callback
            self.heartbeat.onsleep = function() {};

            // reset backoff counter if connection was open for enough time to be considered successful
            if (timeOpened) {
                var socketDuration = (getTime() - timeOpened)/1000;
                if (socketDuration > 10) {
                    attempt = 1;
                }
            }

            self.log("Socket closed");
            self.onclose();
            self._tryReconnect(attempt);
        };
        sock.onerror = function(e) {
            self.log("Socket received error: " + e.message);
            self.onerror({ code: 31000, message: e.message || "WSTransport socket error"});
        };
        sock.onmessage = function(message) {
            self.heartbeat.beat();
            if (message.data == "\n") {
                self.send("\n");
                return;
            }

            //TODO check if error passed back from gateway is 5XX error
            // if so, retry connection with exponential backoff
            self.onmessage(message);
        };

        return sock;
};
WSTransport.prototype._tryReconnect = function(attempted) {
        attempted = attempted || 0;
        if (this.options["reconnect"]) {
            this.log("Attempting to reconnect.");
            var self = this;
            var backoff = 0;
            if (attempted < 5) {
                // setup exponentially random backoff
                var minBackoff = 30;
                var backoffRange = Math.pow(2,attempted)*50;
                backoff = minBackoff + Math.round(Math.random()*backoffRange);
            } else {
                // continuous reconnect attempt
                backoff = 3000;
            }
            setTimeout( function() {
                self.open(attempted);
            }, backoff);
        }
};

exports.WSTransport = WSTransport;

},{"../../vendor/web-socket-js/web_socket":38,"./heartbeat":7,"./log":8}],23:[function(require,module,exports){
/*!
 * The buffer module from node.js, for the browser.
 *
 * @author   Feross Aboukhadijeh <feross@feross.org> <http://feross.org>
 * @license  MIT
 */

var base64 = require('base64-js')
var ieee754 = require('ieee754')
var isArray = require('is-array')

exports.Buffer = Buffer
exports.SlowBuffer = Buffer
exports.INSPECT_MAX_BYTES = 50
Buffer.poolSize = 8192 // not used by this implementation

var kMaxLength = 0x3fffffff

/**
 * If `Buffer.TYPED_ARRAY_SUPPORT`:
 *   === true    Use Uint8Array implementation (fastest)
 *   === false   Use Object implementation (most compatible, even IE6)
 *
 * Browsers that support typed arrays are IE 10+, Firefox 4+, Chrome 7+, Safari 5.1+,
 * Opera 11.6+, iOS 4.2+.
 *
 * Note:
 *
 * - Implementation must support adding new properties to `Uint8Array` instances.
 *   Firefox 4-29 lacked support, fixed in Firefox 30+.
 *   See: https://bugzilla.mozilla.org/show_bug.cgi?id=695438.
 *
 *  - Chrome 9-10 is missing the `TypedArray.prototype.subarray` function.
 *
 *  - IE10 has a broken `TypedArray.prototype.subarray` function which returns arrays of
 *    incorrect length in some situations.
 *
 * We detect these buggy browsers and set `Buffer.TYPED_ARRAY_SUPPORT` to `false` so they will
 * get the Object implementation, which is slower but will work correctly.
 */
Buffer.TYPED_ARRAY_SUPPORT = (function () {
  try {
    var buf = new ArrayBuffer(0)
    var arr = new Uint8Array(buf)
    arr.foo = function () { return 42 }
    return 42 === arr.foo() && // typed array instances can be augmented
        typeof arr.subarray === 'function' && // chrome 9-10 lack `subarray`
        new Uint8Array(1).subarray(1, 1).byteLength === 0 // ie10 has broken `subarray`
  } catch (e) {
    return false
  }
})()

/**
 * Class: Buffer
 * =============
 *
 * The Buffer constructor returns instances of `Uint8Array` that are augmented
 * with function properties for all the node `Buffer` API functions. We use
 * `Uint8Array` so that square bracket notation works as expected -- it returns
 * a single octet.
 *
 * By augmenting the instances, we can avoid modifying the `Uint8Array`
 * prototype.
 */
function Buffer (subject, encoding, noZero) {
  if (!(this instanceof Buffer))
    return new Buffer(subject, encoding, noZero)

  var type = typeof subject

  // Find the length
  var length
  if (type === 'number')
    length = subject > 0 ? subject >>> 0 : 0
  else if (type === 'string') {
    if (encoding === 'base64')
      subject = base64clean(subject)
    length = Buffer.byteLength(subject, encoding)
  } else if (type === 'object' && subject !== null) { // assume object is array-like
    if (subject.type === 'Buffer' && isArray(subject.data))
      subject = subject.data
    length = +subject.length > 0 ? Math.floor(+subject.length) : 0
  } else
    throw new TypeError('must start with number, buffer, array or string')

  if (this.length > kMaxLength)
    throw new RangeError('Attempt to allocate Buffer larger than maximum ' +
      'size: 0x' + kMaxLength.toString(16) + ' bytes')

  var buf
  if (Buffer.TYPED_ARRAY_SUPPORT) {
    // Preferred: Return an augmented `Uint8Array` instance for best performance
    buf = Buffer._augment(new Uint8Array(length))
  } else {
    // Fallback: Return THIS instance of Buffer (created by `new`)
    buf = this
    buf.length = length
    buf._isBuffer = true
  }

  var i
  if (Buffer.TYPED_ARRAY_SUPPORT && typeof subject.byteLength === 'number') {
    // Speed optimization -- use set if we're copying from a typed array
    buf._set(subject)
  } else if (isArrayish(subject)) {
    // Treat array-ish objects as a byte array
    if (Buffer.isBuffer(subject)) {
      for (i = 0; i < length; i++)
        buf[i] = subject.readUInt8(i)
    } else {
      for (i = 0; i < length; i++)
        buf[i] = ((subject[i] % 256) + 256) % 256
    }
  } else if (type === 'string') {
    buf.write(subject, 0, encoding)
  } else if (type === 'number' && !Buffer.TYPED_ARRAY_SUPPORT && !noZero) {
    for (i = 0; i < length; i++) {
      buf[i] = 0
    }
  }

  return buf
}

Buffer.isBuffer = function (b) {
  return !!(b != null && b._isBuffer)
}

Buffer.compare = function (a, b) {
  if (!Buffer.isBuffer(a) || !Buffer.isBuffer(b))
    throw new TypeError('Arguments must be Buffers')

  var x = a.length
  var y = b.length
  for (var i = 0, len = Math.min(x, y); i < len && a[i] === b[i]; i++) {}
  if (i !== len) {
    x = a[i]
    y = b[i]
  }
  if (x < y) return -1
  if (y < x) return 1
  return 0
}

Buffer.isEncoding = function (encoding) {
  switch (String(encoding).toLowerCase()) {
    case 'hex':
    case 'utf8':
    case 'utf-8':
    case 'ascii':
    case 'binary':
    case 'base64':
    case 'raw':
    case 'ucs2':
    case 'ucs-2':
    case 'utf16le':
    case 'utf-16le':
      return true
    default:
      return false
  }
}

Buffer.concat = function (list, totalLength) {
  if (!isArray(list)) throw new TypeError('Usage: Buffer.concat(list[, length])')

  if (list.length === 0) {
    return new Buffer(0)
  } else if (list.length === 1) {
    return list[0]
  }

  var i
  if (totalLength === undefined) {
    totalLength = 0
    for (i = 0; i < list.length; i++) {
      totalLength += list[i].length
    }
  }

  var buf = new Buffer(totalLength)
  var pos = 0
  for (i = 0; i < list.length; i++) {
    var item = list[i]
    item.copy(buf, pos)
    pos += item.length
  }
  return buf
}

Buffer.byteLength = function (str, encoding) {
  var ret
  str = str + ''
  switch (encoding || 'utf8') {
    case 'ascii':
    case 'binary':
    case 'raw':
      ret = str.length
      break
    case 'ucs2':
    case 'ucs-2':
    case 'utf16le':
    case 'utf-16le':
      ret = str.length * 2
      break
    case 'hex':
      ret = str.length >>> 1
      break
    case 'utf8':
    case 'utf-8':
      ret = utf8ToBytes(str).length
      break
    case 'base64':
      ret = base64ToBytes(str).length
      break
    default:
      ret = str.length
  }
  return ret
}

// pre-set for values that may exist in the future
Buffer.prototype.length = undefined
Buffer.prototype.parent = undefined

// toString(encoding, start=0, end=buffer.length)
Buffer.prototype.toString = function (encoding, start, end) {
  var loweredCase = false

  start = start >>> 0
  end = end === undefined || end === Infinity ? this.length : end >>> 0

  if (!encoding) encoding = 'utf8'
  if (start < 0) start = 0
  if (end > this.length) end = this.length
  if (end <= start) return ''

  while (true) {
    switch (encoding) {
      case 'hex':
        return hexSlice(this, start, end)

      case 'utf8':
      case 'utf-8':
        return utf8Slice(this, start, end)

      case 'ascii':
        return asciiSlice(this, start, end)

      case 'binary':
        return binarySlice(this, start, end)

      case 'base64':
        return base64Slice(this, start, end)

      case 'ucs2':
      case 'ucs-2':
      case 'utf16le':
      case 'utf-16le':
        return utf16leSlice(this, start, end)

      default:
        if (loweredCase)
          throw new TypeError('Unknown encoding: ' + encoding)
        encoding = (encoding + '').toLowerCase()
        loweredCase = true
    }
  }
}

Buffer.prototype.equals = function (b) {
  if(!Buffer.isBuffer(b)) throw new TypeError('Argument must be a Buffer')
  return Buffer.compare(this, b) === 0
}

Buffer.prototype.inspect = function () {
  var str = ''
  var max = exports.INSPECT_MAX_BYTES
  if (this.length > 0) {
    str = this.toString('hex', 0, max).match(/.{2}/g).join(' ')
    if (this.length > max)
      str += ' ... '
  }
  return '<Buffer ' + str + '>'
}

Buffer.prototype.compare = function (b) {
  if (!Buffer.isBuffer(b)) throw new TypeError('Argument must be a Buffer')
  return Buffer.compare(this, b)
}

// `get` will be removed in Node 0.13+
Buffer.prototype.get = function (offset) {
  console.log('.get() is deprecated. Access using array indexes instead.')
  return this.readUInt8(offset)
}

// `set` will be removed in Node 0.13+
Buffer.prototype.set = function (v, offset) {
  console.log('.set() is deprecated. Access using array indexes instead.')
  return this.writeUInt8(v, offset)
}

function hexWrite (buf, string, offset, length) {
  offset = Number(offset) || 0
  var remaining = buf.length - offset
  if (!length) {
    length = remaining
  } else {
    length = Number(length)
    if (length > remaining) {
      length = remaining
    }
  }

  // must be an even number of digits
  var strLen = string.length
  if (strLen % 2 !== 0) throw new Error('Invalid hex string')

  if (length > strLen / 2) {
    length = strLen / 2
  }
  for (var i = 0; i < length; i++) {
    var byte = parseInt(string.substr(i * 2, 2), 16)
    if (isNaN(byte)) throw new Error('Invalid hex string')
    buf[offset + i] = byte
  }
  return i
}

function utf8Write (buf, string, offset, length) {
  var charsWritten = blitBuffer(utf8ToBytes(string), buf, offset, length)
  return charsWritten
}

function asciiWrite (buf, string, offset, length) {
  var charsWritten = blitBuffer(asciiToBytes(string), buf, offset, length)
  return charsWritten
}

function binaryWrite (buf, string, offset, length) {
  return asciiWrite(buf, string, offset, length)
}

function base64Write (buf, string, offset, length) {
  var charsWritten = blitBuffer(base64ToBytes(string), buf, offset, length)
  return charsWritten
}

function utf16leWrite (buf, string, offset, length) {
  var charsWritten = blitBuffer(utf16leToBytes(string), buf, offset, length, 2)
  return charsWritten
}

Buffer.prototype.write = function (string, offset, length, encoding) {
  // Support both (string, offset, length, encoding)
  // and the legacy (string, encoding, offset, length)
  if (isFinite(offset)) {
    if (!isFinite(length)) {
      encoding = length
      length = undefined
    }
  } else {  // legacy
    var swap = encoding
    encoding = offset
    offset = length
    length = swap
  }

  offset = Number(offset) || 0
  var remaining = this.length - offset
  if (!length) {
    length = remaining
  } else {
    length = Number(length)
    if (length > remaining) {
      length = remaining
    }
  }
  encoding = String(encoding || 'utf8').toLowerCase()

  var ret
  switch (encoding) {
    case 'hex':
      ret = hexWrite(this, string, offset, length)
      break
    case 'utf8':
    case 'utf-8':
      ret = utf8Write(this, string, offset, length)
      break
    case 'ascii':
      ret = asciiWrite(this, string, offset, length)
      break
    case 'binary':
      ret = binaryWrite(this, string, offset, length)
      break
    case 'base64':
      ret = base64Write(this, string, offset, length)
      break
    case 'ucs2':
    case 'ucs-2':
    case 'utf16le':
    case 'utf-16le':
      ret = utf16leWrite(this, string, offset, length)
      break
    default:
      throw new TypeError('Unknown encoding: ' + encoding)
  }
  return ret
}

Buffer.prototype.toJSON = function () {
  return {
    type: 'Buffer',
    data: Array.prototype.slice.call(this._arr || this, 0)
  }
}

function base64Slice (buf, start, end) {
  if (start === 0 && end === buf.length) {
    return base64.fromByteArray(buf)
  } else {
    return base64.fromByteArray(buf.slice(start, end))
  }
}

function utf8Slice (buf, start, end) {
  var res = ''
  var tmp = ''
  end = Math.min(buf.length, end)

  for (var i = start; i < end; i++) {
    if (buf[i] <= 0x7F) {
      res += decodeUtf8Char(tmp) + String.fromCharCode(buf[i])
      tmp = ''
    } else {
      tmp += '%' + buf[i].toString(16)
    }
  }

  return res + decodeUtf8Char(tmp)
}

function asciiSlice (buf, start, end) {
  var ret = ''
  end = Math.min(buf.length, end)

  for (var i = start; i < end; i++) {
    ret += String.fromCharCode(buf[i])
  }
  return ret
}

function binarySlice (buf, start, end) {
  return asciiSlice(buf, start, end)
}

function hexSlice (buf, start, end) {
  var len = buf.length

  if (!start || start < 0) start = 0
  if (!end || end < 0 || end > len) end = len

  var out = ''
  for (var i = start; i < end; i++) {
    out += toHex(buf[i])
  }
  return out
}

function utf16leSlice (buf, start, end) {
  var bytes = buf.slice(start, end)
  var res = ''
  for (var i = 0; i < bytes.length; i += 2) {
    res += String.fromCharCode(bytes[i] + bytes[i + 1] * 256)
  }
  return res
}

Buffer.prototype.slice = function (start, end) {
  var len = this.length
  start = ~~start
  end = end === undefined ? len : ~~end

  if (start < 0) {
    start += len;
    if (start < 0)
      start = 0
  } else if (start > len) {
    start = len
  }

  if (end < 0) {
    end += len
    if (end < 0)
      end = 0
  } else if (end > len) {
    end = len
  }

  if (end < start)
    end = start

  if (Buffer.TYPED_ARRAY_SUPPORT) {
    return Buffer._augment(this.subarray(start, end))
  } else {
    var sliceLen = end - start
    var newBuf = new Buffer(sliceLen, undefined, true)
    for (var i = 0; i < sliceLen; i++) {
      newBuf[i] = this[i + start]
    }
    return newBuf
  }
}

/*
 * Need to make sure that buffer isn't trying to write out of bounds.
 */
function checkOffset (offset, ext, length) {
  if ((offset % 1) !== 0 || offset < 0)
    throw new RangeError('offset is not uint')
  if (offset + ext > length)
    throw new RangeError('Trying to access beyond buffer length')
}

Buffer.prototype.readUInt8 = function (offset, noAssert) {
  if (!noAssert)
    checkOffset(offset, 1, this.length)
  return this[offset]
}

Buffer.prototype.readUInt16LE = function (offset, noAssert) {
  if (!noAssert)
    checkOffset(offset, 2, this.length)
  return this[offset] | (this[offset + 1] << 8)
}

Buffer.prototype.readUInt16BE = function (offset, noAssert) {
  if (!noAssert)
    checkOffset(offset, 2, this.length)
  return (this[offset] << 8) | this[offset + 1]
}

Buffer.prototype.readUInt32LE = function (offset, noAssert) {
  if (!noAssert)
    checkOffset(offset, 4, this.length)

  return ((this[offset]) |
      (this[offset + 1] << 8) |
      (this[offset + 2] << 16)) +
      (this[offset + 3] * 0x1000000)
}

Buffer.prototype.readUInt32BE = function (offset, noAssert) {
  if (!noAssert)
    checkOffset(offset, 4, this.length)

  return (this[offset] * 0x1000000) +
      ((this[offset + 1] << 16) |
      (this[offset + 2] << 8) |
      this[offset + 3])
}

Buffer.prototype.readInt8 = function (offset, noAssert) {
  if (!noAssert)
    checkOffset(offset, 1, this.length)
  if (!(this[offset] & 0x80))
    return (this[offset])
  return ((0xff - this[offset] + 1) * -1)
}

Buffer.prototype.readInt16LE = function (offset, noAssert) {
  if (!noAssert)
    checkOffset(offset, 2, this.length)
  var val = this[offset] | (this[offset + 1] << 8)
  return (val & 0x8000) ? val | 0xFFFF0000 : val
}

Buffer.prototype.readInt16BE = function (offset, noAssert) {
  if (!noAssert)
    checkOffset(offset, 2, this.length)
  var val = this[offset + 1] | (this[offset] << 8)
  return (val & 0x8000) ? val | 0xFFFF0000 : val
}

Buffer.prototype.readInt32LE = function (offset, noAssert) {
  if (!noAssert)
    checkOffset(offset, 4, this.length)

  return (this[offset]) |
      (this[offset + 1] << 8) |
      (this[offset + 2] << 16) |
      (this[offset + 3] << 24)
}

Buffer.prototype.readInt32BE = function (offset, noAssert) {
  if (!noAssert)
    checkOffset(offset, 4, this.length)

  return (this[offset] << 24) |
      (this[offset + 1] << 16) |
      (this[offset + 2] << 8) |
      (this[offset + 3])
}

Buffer.prototype.readFloatLE = function (offset, noAssert) {
  if (!noAssert)
    checkOffset(offset, 4, this.length)
  return ieee754.read(this, offset, true, 23, 4)
}

Buffer.prototype.readFloatBE = function (offset, noAssert) {
  if (!noAssert)
    checkOffset(offset, 4, this.length)
  return ieee754.read(this, offset, false, 23, 4)
}

Buffer.prototype.readDoubleLE = function (offset, noAssert) {
  if (!noAssert)
    checkOffset(offset, 8, this.length)
  return ieee754.read(this, offset, true, 52, 8)
}

Buffer.prototype.readDoubleBE = function (offset, noAssert) {
  if (!noAssert)
    checkOffset(offset, 8, this.length)
  return ieee754.read(this, offset, false, 52, 8)
}

function checkInt (buf, value, offset, ext, max, min) {
  if (!Buffer.isBuffer(buf)) throw new TypeError('buffer must be a Buffer instance')
  if (value > max || value < min) throw new TypeError('value is out of bounds')
  if (offset + ext > buf.length) throw new TypeError('index out of range')
}

Buffer.prototype.writeUInt8 = function (value, offset, noAssert) {
  value = +value
  offset = offset >>> 0
  if (!noAssert)
    checkInt(this, value, offset, 1, 0xff, 0)
  if (!Buffer.TYPED_ARRAY_SUPPORT) value = Math.floor(value)
  this[offset] = value
  return offset + 1
}

function objectWriteUInt16 (buf, value, offset, littleEndian) {
  if (value < 0) value = 0xffff + value + 1
  for (var i = 0, j = Math.min(buf.length - offset, 2); i < j; i++) {
    buf[offset + i] = (value & (0xff << (8 * (littleEndian ? i : 1 - i)))) >>>
      (littleEndian ? i : 1 - i) * 8
  }
}

Buffer.prototype.writeUInt16LE = function (value, offset, noAssert) {
  value = +value
  offset = offset >>> 0
  if (!noAssert)
    checkInt(this, value, offset, 2, 0xffff, 0)
  if (Buffer.TYPED_ARRAY_SUPPORT) {
    this[offset] = value
    this[offset + 1] = (value >>> 8)
  } else objectWriteUInt16(this, value, offset, true)
  return offset + 2
}

Buffer.prototype.writeUInt16BE = function (value, offset, noAssert) {
  value = +value
  offset = offset >>> 0
  if (!noAssert)
    checkInt(this, value, offset, 2, 0xffff, 0)
  if (Buffer.TYPED_ARRAY_SUPPORT) {
    this[offset] = (value >>> 8)
    this[offset + 1] = value
  } else objectWriteUInt16(this, value, offset, false)
  return offset + 2
}

function objectWriteUInt32 (buf, value, offset, littleEndian) {
  if (value < 0) value = 0xffffffff + value + 1
  for (var i = 0, j = Math.min(buf.length - offset, 4); i < j; i++) {
    buf[offset + i] = (value >>> (littleEndian ? i : 3 - i) * 8) & 0xff
  }
}

Buffer.prototype.writeUInt32LE = function (value, offset, noAssert) {
  value = +value
  offset = offset >>> 0
  if (!noAssert)
    checkInt(this, value, offset, 4, 0xffffffff, 0)
  if (Buffer.TYPED_ARRAY_SUPPORT) {
    this[offset + 3] = (value >>> 24)
    this[offset + 2] = (value >>> 16)
    this[offset + 1] = (value >>> 8)
    this[offset] = value
  } else objectWriteUInt32(this, value, offset, true)
  return offset + 4
}

Buffer.prototype.writeUInt32BE = function (value, offset, noAssert) {
  value = +value
  offset = offset >>> 0
  if (!noAssert)
    checkInt(this, value, offset, 4, 0xffffffff, 0)
  if (Buffer.TYPED_ARRAY_SUPPORT) {
    this[offset] = (value >>> 24)
    this[offset + 1] = (value >>> 16)
    this[offset + 2] = (value >>> 8)
    this[offset + 3] = value
  } else objectWriteUInt32(this, value, offset, false)
  return offset + 4
}

Buffer.prototype.writeInt8 = function (value, offset, noAssert) {
  value = +value
  offset = offset >>> 0
  if (!noAssert)
    checkInt(this, value, offset, 1, 0x7f, -0x80)
  if (!Buffer.TYPED_ARRAY_SUPPORT) value = Math.floor(value)
  if (value < 0) value = 0xff + value + 1
  this[offset] = value
  return offset + 1
}

Buffer.prototype.writeInt16LE = function (value, offset, noAssert) {
  value = +value
  offset = offset >>> 0
  if (!noAssert)
    checkInt(this, value, offset, 2, 0x7fff, -0x8000)
  if (Buffer.TYPED_ARRAY_SUPPORT) {
    this[offset] = value
    this[offset + 1] = (value >>> 8)
  } else objectWriteUInt16(this, value, offset, true)
  return offset + 2
}

Buffer.prototype.writeInt16BE = function (value, offset, noAssert) {
  value = +value
  offset = offset >>> 0
  if (!noAssert)
    checkInt(this, value, offset, 2, 0x7fff, -0x8000)
  if (Buffer.TYPED_ARRAY_SUPPORT) {
    this[offset] = (value >>> 8)
    this[offset + 1] = value
  } else objectWriteUInt16(this, value, offset, false)
  return offset + 2
}

Buffer.prototype.writeInt32LE = function (value, offset, noAssert) {
  value = +value
  offset = offset >>> 0
  if (!noAssert)
    checkInt(this, value, offset, 4, 0x7fffffff, -0x80000000)
  if (Buffer.TYPED_ARRAY_SUPPORT) {
    this[offset] = value
    this[offset + 1] = (value >>> 8)
    this[offset + 2] = (value >>> 16)
    this[offset + 3] = (value >>> 24)
  } else objectWriteUInt32(this, value, offset, true)
  return offset + 4
}

Buffer.prototype.writeInt32BE = function (value, offset, noAssert) {
  value = +value
  offset = offset >>> 0
  if (!noAssert)
    checkInt(this, value, offset, 4, 0x7fffffff, -0x80000000)
  if (value < 0) value = 0xffffffff + value + 1
  if (Buffer.TYPED_ARRAY_SUPPORT) {
    this[offset] = (value >>> 24)
    this[offset + 1] = (value >>> 16)
    this[offset + 2] = (value >>> 8)
    this[offset + 3] = value
  } else objectWriteUInt32(this, value, offset, false)
  return offset + 4
}

function checkIEEE754 (buf, value, offset, ext, max, min) {
  if (value > max || value < min) throw new TypeError('value is out of bounds')
  if (offset + ext > buf.length) throw new TypeError('index out of range')
}

function writeFloat (buf, value, offset, littleEndian, noAssert) {
  if (!noAssert)
    checkIEEE754(buf, value, offset, 4, 3.4028234663852886e+38, -3.4028234663852886e+38)
  ieee754.write(buf, value, offset, littleEndian, 23, 4)
  return offset + 4
}

Buffer.prototype.writeFloatLE = function (value, offset, noAssert) {
  return writeFloat(this, value, offset, true, noAssert)
}

Buffer.prototype.writeFloatBE = function (value, offset, noAssert) {
  return writeFloat(this, value, offset, false, noAssert)
}

function writeDouble (buf, value, offset, littleEndian, noAssert) {
  if (!noAssert)
    checkIEEE754(buf, value, offset, 8, 1.7976931348623157E+308, -1.7976931348623157E+308)
  ieee754.write(buf, value, offset, littleEndian, 52, 8)
  return offset + 8
}

Buffer.prototype.writeDoubleLE = function (value, offset, noAssert) {
  return writeDouble(this, value, offset, true, noAssert)
}

Buffer.prototype.writeDoubleBE = function (value, offset, noAssert) {
  return writeDouble(this, value, offset, false, noAssert)
}

// copy(targetBuffer, targetStart=0, sourceStart=0, sourceEnd=buffer.length)
Buffer.prototype.copy = function (target, target_start, start, end) {
  var source = this

  if (!start) start = 0
  if (!end && end !== 0) end = this.length
  if (!target_start) target_start = 0

  // Copy 0 bytes; we're done
  if (end === start) return
  if (target.length === 0 || source.length === 0) return

  // Fatal error conditions
  if (end < start) throw new TypeError('sourceEnd < sourceStart')
  if (target_start < 0 || target_start >= target.length)
    throw new TypeError('targetStart out of bounds')
  if (start < 0 || start >= source.length) throw new TypeError('sourceStart out of bounds')
  if (end < 0 || end > source.length) throw new TypeError('sourceEnd out of bounds')

  // Are we oob?
  if (end > this.length)
    end = this.length
  if (target.length - target_start < end - start)
    end = target.length - target_start + start

  var len = end - start

  if (len < 1000 || !Buffer.TYPED_ARRAY_SUPPORT) {
    for (var i = 0; i < len; i++) {
      target[i + target_start] = this[i + start]
    }
  } else {
    target._set(this.subarray(start, start + len), target_start)
  }
}

// fill(value, start=0, end=buffer.length)
Buffer.prototype.fill = function (value, start, end) {
  if (!value) value = 0
  if (!start) start = 0
  if (!end) end = this.length

  if (end < start) throw new TypeError('end < start')

  // Fill 0 bytes; we're done
  if (end === start) return
  if (this.length === 0) return

  if (start < 0 || start >= this.length) throw new TypeError('start out of bounds')
  if (end < 0 || end > this.length) throw new TypeError('end out of bounds')

  var i
  if (typeof value === 'number') {
    for (i = start; i < end; i++) {
      this[i] = value
    }
  } else {
    var bytes = utf8ToBytes(value.toString())
    var len = bytes.length
    for (i = start; i < end; i++) {
      this[i] = bytes[i % len]
    }
  }

  return this
}

/**
 * Creates a new `ArrayBuffer` with the *copied* memory of the buffer instance.
 * Added in Node 0.12. Only available in browsers that support ArrayBuffer.
 */
Buffer.prototype.toArrayBuffer = function () {
  if (typeof Uint8Array !== 'undefined') {
    if (Buffer.TYPED_ARRAY_SUPPORT) {
      return (new Buffer(this)).buffer
    } else {
      var buf = new Uint8Array(this.length)
      for (var i = 0, len = buf.length; i < len; i += 1) {
        buf[i] = this[i]
      }
      return buf.buffer
    }
  } else {
    throw new TypeError('Buffer.toArrayBuffer not supported in this browser')
  }
}

// HELPER FUNCTIONS
// ================

var BP = Buffer.prototype

/**
 * Augment a Uint8Array *instance* (not the Uint8Array class!) with Buffer methods
 */
Buffer._augment = function (arr) {
  arr.constructor = Buffer
  arr._isBuffer = true

  // save reference to original Uint8Array get/set methods before overwriting
  arr._get = arr.get
  arr._set = arr.set

  // deprecated, will be removed in node 0.13+
  arr.get = BP.get
  arr.set = BP.set

  arr.write = BP.write
  arr.toString = BP.toString
  arr.toLocaleString = BP.toString
  arr.toJSON = BP.toJSON
  arr.equals = BP.equals
  arr.compare = BP.compare
  arr.copy = BP.copy
  arr.slice = BP.slice
  arr.readUInt8 = BP.readUInt8
  arr.readUInt16LE = BP.readUInt16LE
  arr.readUInt16BE = BP.readUInt16BE
  arr.readUInt32LE = BP.readUInt32LE
  arr.readUInt32BE = BP.readUInt32BE
  arr.readInt8 = BP.readInt8
  arr.readInt16LE = BP.readInt16LE
  arr.readInt16BE = BP.readInt16BE
  arr.readInt32LE = BP.readInt32LE
  arr.readInt32BE = BP.readInt32BE
  arr.readFloatLE = BP.readFloatLE
  arr.readFloatBE = BP.readFloatBE
  arr.readDoubleLE = BP.readDoubleLE
  arr.readDoubleBE = BP.readDoubleBE
  arr.writeUInt8 = BP.writeUInt8
  arr.writeUInt16LE = BP.writeUInt16LE
  arr.writeUInt16BE = BP.writeUInt16BE
  arr.writeUInt32LE = BP.writeUInt32LE
  arr.writeUInt32BE = BP.writeUInt32BE
  arr.writeInt8 = BP.writeInt8
  arr.writeInt16LE = BP.writeInt16LE
  arr.writeInt16BE = BP.writeInt16BE
  arr.writeInt32LE = BP.writeInt32LE
  arr.writeInt32BE = BP.writeInt32BE
  arr.writeFloatLE = BP.writeFloatLE
  arr.writeFloatBE = BP.writeFloatBE
  arr.writeDoubleLE = BP.writeDoubleLE
  arr.writeDoubleBE = BP.writeDoubleBE
  arr.fill = BP.fill
  arr.inspect = BP.inspect
  arr.toArrayBuffer = BP.toArrayBuffer

  return arr
}

var INVALID_BASE64_RE = /[^+\/0-9A-z]/g

function base64clean (str) {
  // Node strips out invalid characters like \n and \t from the string, base64-js does not
  str = stringtrim(str).replace(INVALID_BASE64_RE, '')
  // Node allows for non-padded base64 strings (missing trailing ===), base64-js does not
  while (str.length % 4 !== 0) {
    str = str + '='
  }
  return str
}

function stringtrim (str) {
  if (str.trim) return str.trim()
  return str.replace(/^\s+|\s+$/g, '')
}

function isArrayish (subject) {
  return isArray(subject) || Buffer.isBuffer(subject) ||
      subject && typeof subject === 'object' &&
      typeof subject.length === 'number'
}

function toHex (n) {
  if (n < 16) return '0' + n.toString(16)
  return n.toString(16)
}

function utf8ToBytes (str) {
  var byteArray = []
  for (var i = 0; i < str.length; i++) {
    var b = str.charCodeAt(i)
    if (b <= 0x7F) {
      byteArray.push(b)
    } else {
      var start = i
      if (b >= 0xD800 && b <= 0xDFFF) i++
      var h = encodeURIComponent(str.slice(start, i+1)).substr(1).split('%')
      for (var j = 0; j < h.length; j++) {
        byteArray.push(parseInt(h[j], 16))
      }
    }
  }
  return byteArray
}

function asciiToBytes (str) {
  var byteArray = []
  for (var i = 0; i < str.length; i++) {
    // Node's code seems to be doing this and not & 0x7F..
    byteArray.push(str.charCodeAt(i) & 0xFF)
  }
  return byteArray
}

function utf16leToBytes (str) {
  var c, hi, lo
  var byteArray = []
  for (var i = 0; i < str.length; i++) {
    c = str.charCodeAt(i)
    hi = c >> 8
    lo = c % 256
    byteArray.push(lo)
    byteArray.push(hi)
  }

  return byteArray
}

function base64ToBytes (str) {
  return base64.toByteArray(str)
}

function blitBuffer (src, dst, offset, length, unitSize) {
  if (unitSize) length -= length % unitSize;
  for (var i = 0; i < length; i++) {
    if ((i + offset >= dst.length) || (i >= src.length))
      break
    dst[i + offset] = src[i]
  }
  return i
}

function decodeUtf8Char (str) {
  try {
    return decodeURIComponent(str)
  } catch (err) {
    return String.fromCharCode(0xFFFD) // UTF 8 invalid char
  }
}

},{"base64-js":24,"ieee754":25,"is-array":26}],24:[function(require,module,exports){
var lookup = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';

;(function (exports) {
	'use strict';

  var Arr = (typeof Uint8Array !== 'undefined')
    ? Uint8Array
    : Array

	var PLUS   = '+'.charCodeAt(0)
	var SLASH  = '/'.charCodeAt(0)
	var NUMBER = '0'.charCodeAt(0)
	var LOWER  = 'a'.charCodeAt(0)
	var UPPER  = 'A'.charCodeAt(0)

	function decode (elt) {
		var code = elt.charCodeAt(0)
		if (code === PLUS)
			return 62 // '+'
		if (code === SLASH)
			return 63 // '/'
		if (code < NUMBER)
			return -1 //no match
		if (code < NUMBER + 10)
			return code - NUMBER + 26 + 26
		if (code < UPPER + 26)
			return code - UPPER
		if (code < LOWER + 26)
			return code - LOWER + 26
	}

	function b64ToByteArray (b64) {
		var i, j, l, tmp, placeHolders, arr

		if (b64.length % 4 > 0) {
			throw new Error('Invalid string. Length must be a multiple of 4')
		}

		// the number of equal signs (place holders)
		// if there are two placeholders, than the two characters before it
		// represent one byte
		// if there is only one, then the three characters before it represent 2 bytes
		// this is just a cheap hack to not do indexOf twice
		var len = b64.length
		placeHolders = '=' === b64.charAt(len - 2) ? 2 : '=' === b64.charAt(len - 1) ? 1 : 0

		// base64 is 4/3 + up to two characters of the original data
		arr = new Arr(b64.length * 3 / 4 - placeHolders)

		// if there are placeholders, only get up to the last complete 4 chars
		l = placeHolders > 0 ? b64.length - 4 : b64.length

		var L = 0

		function push (v) {
			arr[L++] = v
		}

		for (i = 0, j = 0; i < l; i += 4, j += 3) {
			tmp = (decode(b64.charAt(i)) << 18) | (decode(b64.charAt(i + 1)) << 12) | (decode(b64.charAt(i + 2)) << 6) | decode(b64.charAt(i + 3))
			push((tmp & 0xFF0000) >> 16)
			push((tmp & 0xFF00) >> 8)
			push(tmp & 0xFF)
		}

		if (placeHolders === 2) {
			tmp = (decode(b64.charAt(i)) << 2) | (decode(b64.charAt(i + 1)) >> 4)
			push(tmp & 0xFF)
		} else if (placeHolders === 1) {
			tmp = (decode(b64.charAt(i)) << 10) | (decode(b64.charAt(i + 1)) << 4) | (decode(b64.charAt(i + 2)) >> 2)
			push((tmp >> 8) & 0xFF)
			push(tmp & 0xFF)
		}

		return arr
	}

	function uint8ToBase64 (uint8) {
		var i,
			extraBytes = uint8.length % 3, // if we have 1 byte left, pad 2 bytes
			output = "",
			temp, length

		function encode (num) {
			return lookup.charAt(num)
		}

		function tripletToBase64 (num) {
			return encode(num >> 18 & 0x3F) + encode(num >> 12 & 0x3F) + encode(num >> 6 & 0x3F) + encode(num & 0x3F)
		}

		// go through the array every three bytes, we'll deal with trailing stuff later
		for (i = 0, length = uint8.length - extraBytes; i < length; i += 3) {
			temp = (uint8[i] << 16) + (uint8[i + 1] << 8) + (uint8[i + 2])
			output += tripletToBase64(temp)
		}

		// pad the end with zeros, but make sure to not forget the extra bytes
		switch (extraBytes) {
			case 1:
				temp = uint8[uint8.length - 1]
				output += encode(temp >> 2)
				output += encode((temp << 4) & 0x3F)
				output += '=='
				break
			case 2:
				temp = (uint8[uint8.length - 2] << 8) + (uint8[uint8.length - 1])
				output += encode(temp >> 10)
				output += encode((temp >> 4) & 0x3F)
				output += encode((temp << 2) & 0x3F)
				output += '='
				break
		}

		return output
	}

	exports.toByteArray = b64ToByteArray
	exports.fromByteArray = uint8ToBase64
}(typeof exports === 'undefined' ? (this.base64js = {}) : exports))

},{}],25:[function(require,module,exports){
exports.read = function (buffer, offset, isLE, mLen, nBytes) {
  var e, m
  var eLen = nBytes * 8 - mLen - 1
  var eMax = (1 << eLen) - 1
  var eBias = eMax >> 1
  var nBits = -7
  var i = isLE ? (nBytes - 1) : 0
  var d = isLE ? -1 : 1
  var s = buffer[offset + i]

  i += d

  e = s & ((1 << (-nBits)) - 1)
  s >>= (-nBits)
  nBits += eLen
  for (; nBits > 0; e = e * 256 + buffer[offset + i], i += d, nBits -= 8) {}

  m = e & ((1 << (-nBits)) - 1)
  e >>= (-nBits)
  nBits += mLen
  for (; nBits > 0; m = m * 256 + buffer[offset + i], i += d, nBits -= 8) {}

  if (e === 0) {
    e = 1 - eBias
  } else if (e === eMax) {
    return m ? NaN : ((s ? -1 : 1) * Infinity)
  } else {
    m = m + Math.pow(2, mLen)
    e = e - eBias
  }
  return (s ? -1 : 1) * m * Math.pow(2, e - mLen)
}

exports.write = function (buffer, value, offset, isLE, mLen, nBytes) {
  var e, m, c
  var eLen = nBytes * 8 - mLen - 1
  var eMax = (1 << eLen) - 1
  var eBias = eMax >> 1
  var rt = (mLen === 23 ? Math.pow(2, -24) - Math.pow(2, -77) : 0)
  var i = isLE ? 0 : (nBytes - 1)
  var d = isLE ? 1 : -1
  var s = value < 0 || (value === 0 && 1 / value < 0) ? 1 : 0

  value = Math.abs(value)

  if (isNaN(value) || value === Infinity) {
    m = isNaN(value) ? 1 : 0
    e = eMax
  } else {
    e = Math.floor(Math.log(value) / Math.LN2)
    if (value * (c = Math.pow(2, -e)) < 1) {
      e--
      c *= 2
    }
    if (e + eBias >= 1) {
      value += rt / c
    } else {
      value += rt * Math.pow(2, 1 - eBias)
    }
    if (value * c >= 2) {
      e++
      c /= 2
    }

    if (e + eBias >= eMax) {
      m = 0
      e = eMax
    } else if (e + eBias >= 1) {
      m = (value * c - 1) * Math.pow(2, mLen)
      e = e + eBias
    } else {
      m = value * Math.pow(2, eBias - 1) * Math.pow(2, mLen)
      e = 0
    }
  }

  for (; mLen >= 8; buffer[offset + i] = m & 0xff, i += d, m /= 256, mLen -= 8) {}

  e = (e << mLen) | m
  eLen += mLen
  for (; eLen > 0; buffer[offset + i] = e & 0xff, i += d, e /= 256, eLen -= 8) {}

  buffer[offset + i - d] |= s * 128
}

},{}],26:[function(require,module,exports){

/**
 * isArray
 */

var isArray = Array.isArray;

/**
 * toString
 */

var str = Object.prototype.toString;

/**
 * Whether or not the given `val`
 * is an array.
 *
 * example:
 *
 *        isArray([]);
 *        // > true
 *        isArray(arguments);
 *        // > false
 *        isArray('');
 *        // > false
 *
 * @param {mixed} val
 * @return {bool}
 */

module.exports = isArray || function (val) {
  return !! val && '[object Array]' == str.call(val);
};

},{}],27:[function(require,module,exports){
// Copyright Joyent, Inc. and other Node contributors.
//
// Permission is hereby granted, free of charge, to any person obtaining a
// copy of this software and associated documentation files (the
// "Software"), to deal in the Software without restriction, including
// without limitation the rights to use, copy, modify, merge, publish,
// distribute, sublicense, and/or sell copies of the Software, and to permit
// persons to whom the Software is furnished to do so, subject to the
// following conditions:
//
// The above copyright notice and this permission notice shall be included
// in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
// OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN
// NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
// DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
// OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE
// USE OR OTHER DEALINGS IN THE SOFTWARE.

function EventEmitter() {
  this._events = this._events || {};
  this._maxListeners = this._maxListeners || undefined;
}
module.exports = EventEmitter;

// Backwards-compat with node 0.10.x
EventEmitter.EventEmitter = EventEmitter;

EventEmitter.prototype._events = undefined;
EventEmitter.prototype._maxListeners = undefined;

// By default EventEmitters will print a warning if more than 10 listeners are
// added to it. This is a useful default which helps finding memory leaks.
EventEmitter.defaultMaxListeners = 10;

// Obviously not all Emitters should be limited to 10. This function allows
// that to be increased. Set to zero for unlimited.
EventEmitter.prototype.setMaxListeners = function(n) {
  if (!isNumber(n) || n < 0 || isNaN(n))
    throw TypeError('n must be a positive number');
  this._maxListeners = n;
  return this;
};

EventEmitter.prototype.emit = function(type) {
  var er, handler, len, args, i, listeners;

  if (!this._events)
    this._events = {};

  // If there is no 'error' event listener then throw.
  if (type === 'error') {
    if (!this._events.error ||
        (isObject(this._events.error) && !this._events.error.length)) {
      er = arguments[1];
      if (er instanceof Error) {
        throw er; // Unhandled 'error' event
      }
      throw TypeError('Uncaught, unspecified "error" event.');
    }
  }

  handler = this._events[type];

  if (isUndefined(handler))
    return false;

  if (isFunction(handler)) {
    switch (arguments.length) {
      // fast cases
      case 1:
        handler.call(this);
        break;
      case 2:
        handler.call(this, arguments[1]);
        break;
      case 3:
        handler.call(this, arguments[1], arguments[2]);
        break;
      // slower
      default:
        len = arguments.length;
        args = new Array(len - 1);
        for (i = 1; i < len; i++)
          args[i - 1] = arguments[i];
        handler.apply(this, args);
    }
  } else if (isObject(handler)) {
    len = arguments.length;
    args = new Array(len - 1);
    for (i = 1; i < len; i++)
      args[i - 1] = arguments[i];

    listeners = handler.slice();
    len = listeners.length;
    for (i = 0; i < len; i++)
      listeners[i].apply(this, args);
  }

  return true;
};

EventEmitter.prototype.addListener = function(type, listener) {
  var m;

  if (!isFunction(listener))
    throw TypeError('listener must be a function');

  if (!this._events)
    this._events = {};

  // To avoid recursion in the case that type === "newListener"! Before
  // adding it to the listeners, first emit "newListener".
  if (this._events.newListener)
    this.emit('newListener', type,
              isFunction(listener.listener) ?
              listener.listener : listener);

  if (!this._events[type])
    // Optimize the case of one listener. Don't need the extra array object.
    this._events[type] = listener;
  else if (isObject(this._events[type]))
    // If we've already got an array, just append.
    this._events[type].push(listener);
  else
    // Adding the second element, need to change to array.
    this._events[type] = [this._events[type], listener];

  // Check for listener leak
  if (isObject(this._events[type]) && !this._events[type].warned) {
    var m;
    if (!isUndefined(this._maxListeners)) {
      m = this._maxListeners;
    } else {
      m = EventEmitter.defaultMaxListeners;
    }

    if (m && m > 0 && this._events[type].length > m) {
      this._events[type].warned = true;
      console.error('(node) warning: possible EventEmitter memory ' +
                    'leak detected. %d listeners added. ' +
                    'Use emitter.setMaxListeners() to increase limit.',
                    this._events[type].length);
      if (typeof console.trace === 'function') {
        // not supported in IE 10
        console.trace();
      }
    }
  }

  return this;
};

EventEmitter.prototype.on = EventEmitter.prototype.addListener;

EventEmitter.prototype.once = function(type, listener) {
  if (!isFunction(listener))
    throw TypeError('listener must be a function');

  var fired = false;

  function g() {
    this.removeListener(type, g);

    if (!fired) {
      fired = true;
      listener.apply(this, arguments);
    }
  }

  g.listener = listener;
  this.on(type, g);

  return this;
};

// emits a 'removeListener' event iff the listener was removed
EventEmitter.prototype.removeListener = function(type, listener) {
  var list, position, length, i;

  if (!isFunction(listener))
    throw TypeError('listener must be a function');

  if (!this._events || !this._events[type])
    return this;

  list = this._events[type];
  length = list.length;
  position = -1;

  if (list === listener ||
      (isFunction(list.listener) && list.listener === listener)) {
    delete this._events[type];
    if (this._events.removeListener)
      this.emit('removeListener', type, listener);

  } else if (isObject(list)) {
    for (i = length; i-- > 0;) {
      if (list[i] === listener ||
          (list[i].listener && list[i].listener === listener)) {
        position = i;
        break;
      }
    }

    if (position < 0)
      return this;

    if (list.length === 1) {
      list.length = 0;
      delete this._events[type];
    } else {
      list.splice(position, 1);
    }

    if (this._events.removeListener)
      this.emit('removeListener', type, listener);
  }

  return this;
};

EventEmitter.prototype.removeAllListeners = function(type) {
  var key, listeners;

  if (!this._events)
    return this;

  // not listening for removeListener, no need to emit
  if (!this._events.removeListener) {
    if (arguments.length === 0)
      this._events = {};
    else if (this._events[type])
      delete this._events[type];
    return this;
  }

  // emit removeListener for all listeners on all events
  if (arguments.length === 0) {
    for (key in this._events) {
      if (key === 'removeListener') continue;
      this.removeAllListeners(key);
    }
    this.removeAllListeners('removeListener');
    this._events = {};
    return this;
  }

  listeners = this._events[type];

  if (isFunction(listeners)) {
    this.removeListener(type, listeners);
  } else {
    // LIFO order
    while (listeners.length)
      this.removeListener(type, listeners[listeners.length - 1]);
  }
  delete this._events[type];

  return this;
};

EventEmitter.prototype.listeners = function(type) {
  var ret;
  if (!this._events || !this._events[type])
    ret = [];
  else if (isFunction(this._events[type]))
    ret = [this._events[type]];
  else
    ret = this._events[type].slice();
  return ret;
};

EventEmitter.listenerCount = function(emitter, type) {
  var ret;
  if (!emitter._events || !emitter._events[type])
    ret = 0;
  else if (isFunction(emitter._events[type]))
    ret = 1;
  else
    ret = emitter._events[type].length;
  return ret;
};

function isFunction(arg) {
  return typeof arg === 'function';
}

function isNumber(arg) {
  return typeof arg === 'number';
}

function isObject(arg) {
  return typeof arg === 'object' && arg !== null;
}

function isUndefined(arg) {
  return arg === void 0;
}

},{}],28:[function(require,module,exports){
if (typeof Object.create === 'function') {
  // implementation from standard node.js 'util' module
  module.exports = function inherits(ctor, superCtor) {
    ctor.super_ = superCtor
    ctor.prototype = Object.create(superCtor.prototype, {
      constructor: {
        value: ctor,
        enumerable: false,
        writable: true,
        configurable: true
      }
    });
  };
} else {
  // old school shim for old browsers
  module.exports = function inherits(ctor, superCtor) {
    ctor.super_ = superCtor
    var TempCtor = function () {}
    TempCtor.prototype = superCtor.prototype
    ctor.prototype = new TempCtor()
    ctor.prototype.constructor = ctor
  }
}

},{}],29:[function(require,module,exports){
// shim for using process in browser

var process = module.exports = {};

process.nextTick = (function () {
    var canSetImmediate = typeof window !== 'undefined'
    && window.setImmediate;
    var canPost = typeof window !== 'undefined'
    && window.postMessage && window.addEventListener
    ;

    if (canSetImmediate) {
        return function (f) { return window.setImmediate(f) };
    }

    if (canPost) {
        var queue = [];
        window.addEventListener('message', function (ev) {
            var source = ev.source;
            if ((source === window || source === null) && ev.data === 'process-tick') {
                ev.stopPropagation();
                if (queue.length > 0) {
                    var fn = queue.shift();
                    fn();
                }
            }
        }, true);

        return function nextTick(fn) {
            queue.push(fn);
            window.postMessage('process-tick', '*');
        };
    }

    return function nextTick(fn) {
        setTimeout(fn, 0);
    };
})();

process.title = 'browser';
process.browser = true;
process.env = {};
process.argv = [];

function noop() {}

process.on = noop;
process.addListener = noop;
process.once = noop;
process.off = noop;
process.removeListener = noop;
process.removeAllListeners = noop;
process.emit = noop;

process.binding = function (name) {
    throw new Error('process.binding is not supported');
}

// TODO(shtylman)
process.cwd = function () { return '/' };
process.chdir = function (dir) {
    throw new Error('process.chdir is not supported');
};

},{}],30:[function(require,module,exports){
module.exports = function isBuffer(arg) {
  return arg && typeof arg === 'object'
    && typeof arg.copy === 'function'
    && typeof arg.fill === 'function'
    && typeof arg.readUInt8 === 'function';
}
},{}],31:[function(require,module,exports){
(function (process,global){
// Copyright Joyent, Inc. and other Node contributors.
//
// Permission is hereby granted, free of charge, to any person obtaining a
// copy of this software and associated documentation files (the
// "Software"), to deal in the Software without restriction, including
// without limitation the rights to use, copy, modify, merge, publish,
// distribute, sublicense, and/or sell copies of the Software, and to permit
// persons to whom the Software is furnished to do so, subject to the
// following conditions:
//
// The above copyright notice and this permission notice shall be included
// in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
// OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN
// NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
// DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
// OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE
// USE OR OTHER DEALINGS IN THE SOFTWARE.

var formatRegExp = /%[sdj%]/g;
exports.format = function(f) {
  if (!isString(f)) {
    var objects = [];
    for (var i = 0; i < arguments.length; i++) {
      objects.push(inspect(arguments[i]));
    }
    return objects.join(' ');
  }

  var i = 1;
  var args = arguments;
  var len = args.length;
  var str = String(f).replace(formatRegExp, function(x) {
    if (x === '%%') return '%';
    if (i >= len) return x;
    switch (x) {
      case '%s': return String(args[i++]);
      case '%d': return Number(args[i++]);
      case '%j':
        try {
          return JSON.stringify(args[i++]);
        } catch (_) {
          return '[Circular]';
        }
      default:
        return x;
    }
  });
  for (var x = args[i]; i < len; x = args[++i]) {
    if (isNull(x) || !isObject(x)) {
      str += ' ' + x;
    } else {
      str += ' ' + inspect(x);
    }
  }
  return str;
};


// Mark that a method should not be used.
// Returns a modified function which warns once by default.
// If --no-deprecation is set, then it is a no-op.
exports.deprecate = function(fn, msg) {
  // Allow for deprecating things in the process of starting up.
  if (isUndefined(global.process)) {
    return function() {
      return exports.deprecate(fn, msg).apply(this, arguments);
    };
  }

  if (process.noDeprecation === true) {
    return fn;
  }

  var warned = false;
  function deprecated() {
    if (!warned) {
      if (process.throwDeprecation) {
        throw new Error(msg);
      } else if (process.traceDeprecation) {
        console.trace(msg);
      } else {
        console.error(msg);
      }
      warned = true;
    }
    return fn.apply(this, arguments);
  }

  return deprecated;
};


var debugs = {};
var debugEnviron;
exports.debuglog = function(set) {
  if (isUndefined(debugEnviron))
    debugEnviron = process.env.NODE_DEBUG || '';
  set = set.toUpperCase();
  if (!debugs[set]) {
    if (new RegExp('\\b' + set + '\\b', 'i').test(debugEnviron)) {
      var pid = process.pid;
      debugs[set] = function() {
        var msg = exports.format.apply(exports, arguments);
        console.error('%s %d: %s', set, pid, msg);
      };
    } else {
      debugs[set] = function() {};
    }
  }
  return debugs[set];
};


/**
 * Echos the value of a value. Trys to print the value out
 * in the best way possible given the different types.
 *
 * @param {Object} obj The object to print out.
 * @param {Object} opts Optional options object that alters the output.
 */
/* legacy: obj, showHidden, depth, colors*/
function inspect(obj, opts) {
  // default options
  var ctx = {
    seen: [],
    stylize: stylizeNoColor
  };
  // legacy...
  if (arguments.length >= 3) ctx.depth = arguments[2];
  if (arguments.length >= 4) ctx.colors = arguments[3];
  if (isBoolean(opts)) {
    // legacy...
    ctx.showHidden = opts;
  } else if (opts) {
    // got an "options" object
    exports._extend(ctx, opts);
  }
  // set default options
  if (isUndefined(ctx.showHidden)) ctx.showHidden = false;
  if (isUndefined(ctx.depth)) ctx.depth = 2;
  if (isUndefined(ctx.colors)) ctx.colors = false;
  if (isUndefined(ctx.customInspect)) ctx.customInspect = true;
  if (ctx.colors) ctx.stylize = stylizeWithColor;
  return formatValue(ctx, obj, ctx.depth);
}
exports.inspect = inspect;


// http://en.wikipedia.org/wiki/ANSI_escape_code#graphics
inspect.colors = {
  'bold' : [1, 22],
  'italic' : [3, 23],
  'underline' : [4, 24],
  'inverse' : [7, 27],
  'white' : [37, 39],
  'grey' : [90, 39],
  'black' : [30, 39],
  'blue' : [34, 39],
  'cyan' : [36, 39],
  'green' : [32, 39],
  'magenta' : [35, 39],
  'red' : [31, 39],
  'yellow' : [33, 39]
};

// Don't use 'blue' not visible on cmd.exe
inspect.styles = {
  'special': 'cyan',
  'number': 'yellow',
  'boolean': 'yellow',
  'undefined': 'grey',
  'null': 'bold',
  'string': 'green',
  'date': 'magenta',
  // "name": intentionally not styling
  'regexp': 'red'
};


function stylizeWithColor(str, styleType) {
  var style = inspect.styles[styleType];

  if (style) {
    return '\u001b[' + inspect.colors[style][0] + 'm' + str +
           '\u001b[' + inspect.colors[style][1] + 'm';
  } else {
    return str;
  }
}


function stylizeNoColor(str, styleType) {
  return str;
}


function arrayToHash(array) {
  var hash = {};

  array.forEach(function(val, idx) {
    hash[val] = true;
  });

  return hash;
}


function formatValue(ctx, value, recurseTimes) {
  // Provide a hook for user-specified inspect functions.
  // Check that value is an object with an inspect function on it
  if (ctx.customInspect &&
      value &&
      isFunction(value.inspect) &&
      // Filter out the util module, it's inspect function is special
      value.inspect !== exports.inspect &&
      // Also filter out any prototype objects using the circular check.
      !(value.constructor && value.constructor.prototype === value)) {
    var ret = value.inspect(recurseTimes, ctx);
    if (!isString(ret)) {
      ret = formatValue(ctx, ret, recurseTimes);
    }
    return ret;
  }

  // Primitive types cannot have properties
  var primitive = formatPrimitive(ctx, value);
  if (primitive) {
    return primitive;
  }

  // Look up the keys of the object.
  var keys = Object.keys(value);
  var visibleKeys = arrayToHash(keys);

  if (ctx.showHidden) {
    keys = Object.getOwnPropertyNames(value);
  }

  // IE doesn't make error fields non-enumerable
  // http://msdn.microsoft.com/en-us/library/ie/dww52sbt(v=vs.94).aspx
  if (isError(value)
      && (keys.indexOf('message') >= 0 || keys.indexOf('description') >= 0)) {
    return formatError(value);
  }

  // Some type of object without properties can be shortcutted.
  if (keys.length === 0) {
    if (isFunction(value)) {
      var name = value.name ? ': ' + value.name : '';
      return ctx.stylize('[Function' + name + ']', 'special');
    }
    if (isRegExp(value)) {
      return ctx.stylize(RegExp.prototype.toString.call(value), 'regexp');
    }
    if (isDate(value)) {
      return ctx.stylize(Date.prototype.toString.call(value), 'date');
    }
    if (isError(value)) {
      return formatError(value);
    }
  }

  var base = '', array = false, braces = ['{', '}'];

  // Make Array say that they are Array
  if (isArray(value)) {
    array = true;
    braces = ['[', ']'];
  }

  // Make functions say that they are functions
  if (isFunction(value)) {
    var n = value.name ? ': ' + value.name : '';
    base = ' [Function' + n + ']';
  }

  // Make RegExps say that they are RegExps
  if (isRegExp(value)) {
    base = ' ' + RegExp.prototype.toString.call(value);
  }

  // Make dates with properties first say the date
  if (isDate(value)) {
    base = ' ' + Date.prototype.toUTCString.call(value);
  }

  // Make error with message first say the error
  if (isError(value)) {
    base = ' ' + formatError(value);
  }

  if (keys.length === 0 && (!array || value.length == 0)) {
    return braces[0] + base + braces[1];
  }

  if (recurseTimes < 0) {
    if (isRegExp(value)) {
      return ctx.stylize(RegExp.prototype.toString.call(value), 'regexp');
    } else {
      return ctx.stylize('[Object]', 'special');
    }
  }

  ctx.seen.push(value);

  var output;
  if (array) {
    output = formatArray(ctx, value, recurseTimes, visibleKeys, keys);
  } else {
    output = keys.map(function(key) {
      return formatProperty(ctx, value, recurseTimes, visibleKeys, key, array);
    });
  }

  ctx.seen.pop();

  return reduceToSingleString(output, base, braces);
}


function formatPrimitive(ctx, value) {
  if (isUndefined(value))
    return ctx.stylize('undefined', 'undefined');
  if (isString(value)) {
    var simple = '\'' + JSON.stringify(value).replace(/^"|"$/g, '')
                                             .replace(/'/g, "\\'")
                                             .replace(/\\"/g, '"') + '\'';
    return ctx.stylize(simple, 'string');
  }
  if (isNumber(value))
    return ctx.stylize('' + value, 'number');
  if (isBoolean(value))
    return ctx.stylize('' + value, 'boolean');
  // For some reason typeof null is "object", so special case here.
  if (isNull(value))
    return ctx.stylize('null', 'null');
}


function formatError(value) {
  return '[' + Error.prototype.toString.call(value) + ']';
}


function formatArray(ctx, value, recurseTimes, visibleKeys, keys) {
  var output = [];
  for (var i = 0, l = value.length; i < l; ++i) {
    if (hasOwnProperty(value, String(i))) {
      output.push(formatProperty(ctx, value, recurseTimes, visibleKeys,
          String(i), true));
    } else {
      output.push('');
    }
  }
  keys.forEach(function(key) {
    if (!key.match(/^\d+$/)) {
      output.push(formatProperty(ctx, value, recurseTimes, visibleKeys,
          key, true));
    }
  });
  return output;
}


function formatProperty(ctx, value, recurseTimes, visibleKeys, key, array) {
  var name, str, desc;
  desc = Object.getOwnPropertyDescriptor(value, key) || { value: value[key] };
  if (desc.get) {
    if (desc.set) {
      str = ctx.stylize('[Getter/Setter]', 'special');
    } else {
      str = ctx.stylize('[Getter]', 'special');
    }
  } else {
    if (desc.set) {
      str = ctx.stylize('[Setter]', 'special');
    }
  }
  if (!hasOwnProperty(visibleKeys, key)) {
    name = '[' + key + ']';
  }
  if (!str) {
    if (ctx.seen.indexOf(desc.value) < 0) {
      if (isNull(recurseTimes)) {
        str = formatValue(ctx, desc.value, null);
      } else {
        str = formatValue(ctx, desc.value, recurseTimes - 1);
      }
      if (str.indexOf('\n') > -1) {
        if (array) {
          str = str.split('\n').map(function(line) {
            return '  ' + line;
          }).join('\n').substr(2);
        } else {
          str = '\n' + str.split('\n').map(function(line) {
            return '   ' + line;
          }).join('\n');
        }
      }
    } else {
      str = ctx.stylize('[Circular]', 'special');
    }
  }
  if (isUndefined(name)) {
    if (array && key.match(/^\d+$/)) {
      return str;
    }
    name = JSON.stringify('' + key);
    if (name.match(/^"([a-zA-Z_][a-zA-Z_0-9]*)"$/)) {
      name = name.substr(1, name.length - 2);
      name = ctx.stylize(name, 'name');
    } else {
      name = name.replace(/'/g, "\\'")
                 .replace(/\\"/g, '"')
                 .replace(/(^"|"$)/g, "'");
      name = ctx.stylize(name, 'string');
    }
  }

  return name + ': ' + str;
}


function reduceToSingleString(output, base, braces) {
  var numLinesEst = 0;
  var length = output.reduce(function(prev, cur) {
    numLinesEst++;
    if (cur.indexOf('\n') >= 0) numLinesEst++;
    return prev + cur.replace(/\u001b\[\d\d?m/g, '').length + 1;
  }, 0);

  if (length > 60) {
    return braces[0] +
           (base === '' ? '' : base + '\n ') +
           ' ' +
           output.join(',\n  ') +
           ' ' +
           braces[1];
  }

  return braces[0] + base + ' ' + output.join(', ') + ' ' + braces[1];
}


// NOTE: These type checking functions intentionally don't use `instanceof`
// because it is fragile and can be easily faked with `Object.create()`.
function isArray(ar) {
  return Array.isArray(ar);
}
exports.isArray = isArray;

function isBoolean(arg) {
  return typeof arg === 'boolean';
}
exports.isBoolean = isBoolean;

function isNull(arg) {
  return arg === null;
}
exports.isNull = isNull;

function isNullOrUndefined(arg) {
  return arg == null;
}
exports.isNullOrUndefined = isNullOrUndefined;

function isNumber(arg) {
  return typeof arg === 'number';
}
exports.isNumber = isNumber;

function isString(arg) {
  return typeof arg === 'string';
}
exports.isString = isString;

function isSymbol(arg) {
  return typeof arg === 'symbol';
}
exports.isSymbol = isSymbol;

function isUndefined(arg) {
  return arg === void 0;
}
exports.isUndefined = isUndefined;

function isRegExp(re) {
  return isObject(re) && objectToString(re) === '[object RegExp]';
}
exports.isRegExp = isRegExp;

function isObject(arg) {
  return typeof arg === 'object' && arg !== null;
}
exports.isObject = isObject;

function isDate(d) {
  return isObject(d) && objectToString(d) === '[object Date]';
}
exports.isDate = isDate;

function isError(e) {
  return isObject(e) &&
      (objectToString(e) === '[object Error]' || e instanceof Error);
}
exports.isError = isError;

function isFunction(arg) {
  return typeof arg === 'function';
}
exports.isFunction = isFunction;

function isPrimitive(arg) {
  return arg === null ||
         typeof arg === 'boolean' ||
         typeof arg === 'number' ||
         typeof arg === 'string' ||
         typeof arg === 'symbol' ||  // ES6 symbol
         typeof arg === 'undefined';
}
exports.isPrimitive = isPrimitive;

exports.isBuffer = require('./support/isBuffer');

function objectToString(o) {
  return Object.prototype.toString.call(o);
}


function pad(n) {
  return n < 10 ? '0' + n.toString(10) : n.toString(10);
}


var months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep',
              'Oct', 'Nov', 'Dec'];

// 26 Feb 16:19:34
function timestamp() {
  var d = new Date();
  var time = [pad(d.getHours()),
              pad(d.getMinutes()),
              pad(d.getSeconds())].join(':');
  return [d.getDate(), months[d.getMonth()], time].join(' ');
}


// log is just a thin wrapper to console.log that prepends a timestamp
exports.log = function() {
  console.log('%s - %s', timestamp(), exports.format.apply(exports, arguments));
};


/**
 * Inherit the prototype methods from one constructor into another.
 *
 * The Function.prototype.inherits from lang.js rewritten as a standalone
 * function (not on Function.prototype). NOTE: If this file is to be loaded
 * during bootstrapping this function needs to be rewritten using some native
 * functions as prototype setup using normal JavaScript does not work as
 * expected during bootstrapping (see mirror.js in r114903).
 *
 * @param {function} ctor Constructor function which needs to inherit the
 *     prototype.
 * @param {function} superCtor Constructor function to inherit prototype from.
 */
exports.inherits = require('inherits');

exports._extend = function(origin, add) {
  // Don't do anything if add isn't an object
  if (!add || !isObject(add)) return origin;

  var keys = Object.keys(add);
  var i = keys.length;
  while (i--) {
    origin[keys[i]] = add[keys[i]];
  }
  return origin;
};

function hasOwnProperty(obj, prop) {
  return Object.prototype.hasOwnProperty.call(obj, prop);
}

}).call(this,require('_process'),typeof global !== "undefined" ? global : typeof self !== "undefined" ? self : typeof window !== "undefined" ? window : {})
},{"./support/isBuffer":30,"_process":29,"inherits":28}],32:[function(require,module,exports){
// Domain Public by Eric Wendelin http://www.eriwen.com/ (2008)
//                  Luke Smith http://lucassmith.name/ (2008)
//                  Loic Dachary <loic@dachary.org> (2008)
//                  Johan Euphrosine <proppy@aminche.com> (2008)
//                  Oyvind Sean Kinsey http://kinsey.no/blog (2010)
//                  Victor Homyakov <victor-homyakov@users.sourceforge.net> (2010)
/*global module, exports, define, ActiveXObject*/
(function(global, factory) {
    if (typeof exports === 'object') {
        // Node
        module.exports = factory();
    } else if (typeof define === 'function' && define.amd) {
        // AMD
        define(factory);
    } else {
        // Browser globals
        global.printStackTrace = factory();
    }
}(this, function() {
    /**
     * Main function giving a function stack trace with a forced or passed in Error
     *
     * @cfg {Error} e The error to create a stacktrace from (optional)
     * @cfg {Boolean} guess If we should try to resolve the names of anonymous functions
     * @return {Array} of Strings with functions, lines, files, and arguments where possible
     */
    function printStackTrace(options) {
        options = options || {guess: true};
        var ex = options.e || null, guess = !!options.guess, mode = options.mode || null;
        var p = new printStackTrace.implementation(), result = p.run(ex, mode);
        return (guess) ? p.guessAnonymousFunctions(result) : result;
    }

    printStackTrace.implementation = function() {
    };

    printStackTrace.implementation.prototype = {
        /**
         * @param {Error} [ex] The error to create a stacktrace from (optional)
         * @param {String} [mode] Forced mode (optional, mostly for unit tests)
         */
        run: function(ex, mode) {
            ex = ex || this.createException();
            mode = mode || this.mode(ex);
            if (mode === 'other') {
                return this.other(arguments.callee);
            } else {
                return this[mode](ex);
            }
        },

        createException: function() {
            try {
                this.undef();
            } catch (e) {
                return e;
            }
        },

        /**
         * Mode could differ for different exception, e.g.
         * exceptions in Chrome may or may not have arguments or stack.
         *
         * @return {String} mode of operation for the exception
         */
        mode: function(e) {
            if (typeof window !== 'undefined' && window.navigator.userAgent.indexOf('PhantomJS') > -1) {
                return 'phantomjs';
            }

            if (e['arguments'] && e.stack) {
                return 'chrome';
            }

            if (e.stack && e.sourceURL) {
                return 'safari';
            }

            if (e.stack && e.number) {
                return 'ie';
            }

            if (e.stack && e.fileName) {
                return 'firefox';
            }

            if (e.message && e['opera#sourceloc']) {
                // e.message.indexOf("Backtrace:") > -1 -> opera9
                // 'opera#sourceloc' in e -> opera9, opera10a
                // !e.stacktrace -> opera9
                if (!e.stacktrace) {
                    return 'opera9'; // use e.message
                }
                if (e.message.indexOf('\n') > -1 && e.message.split('\n').length > e.stacktrace.split('\n').length) {
                    // e.message may have more stack entries than e.stacktrace
                    return 'opera9'; // use e.message
                }
                return 'opera10a'; // use e.stacktrace
            }

            if (e.message && e.stack && e.stacktrace) {
                // e.stacktrace && e.stack -> opera10b
                if (e.stacktrace.indexOf("called from line") < 0) {
                    return 'opera10b'; // use e.stacktrace, format differs from 'opera10a'
                }
                // e.stacktrace && e.stack -> opera11
                return 'opera11'; // use e.stacktrace, format differs from 'opera10a', 'opera10b'
            }

            if (e.stack && !e.fileName) {
                // Chrome 27 does not have e.arguments as earlier versions,
                // but still does not have e.fileName as Firefox
                return 'chrome';
            }

            return 'other';
        },

        /**
         * Given a context, function name, and callback function, overwrite it so that it calls
         * printStackTrace() first with a callback and then runs the rest of the body.
         *
         * @param {Object} context of execution (e.g. window)
         * @param {String} functionName to instrument
         * @param {Function} callback function to call with a stack trace on invocation
         */
        instrumentFunction: function(context, functionName, callback) {
            context = context || window;
            var original = context[functionName];
            context[functionName] = function instrumented() {
                callback.call(this, printStackTrace().slice(4));
                return context[functionName]._instrumented.apply(this, arguments);
            };
            context[functionName]._instrumented = original;
        },

        /**
         * Given a context and function name of a function that has been
         * instrumented, revert the function to it's original (non-instrumented)
         * state.
         *
         * @param {Object} context of execution (e.g. window)
         * @param {String} functionName to de-instrument
         */
        deinstrumentFunction: function(context, functionName) {
            if (context[functionName].constructor === Function &&
                context[functionName]._instrumented &&
                context[functionName]._instrumented.constructor === Function) {
                context[functionName] = context[functionName]._instrumented;
            }
        },

        /**
         * Given an Error object, return a formatted Array based on Chrome's stack string.
         *
         * @param e - Error object to inspect
         * @return Array<String> of function calls, files and line numbers
         */
        chrome: function(e) {
            return (e.stack + '\n')
                .replace(/^[\s\S]+?\s+at\s+/, ' at ') // remove message
                .replace(/^\s+(at eval )?at\s+/gm, '') // remove 'at' and indentation
                .replace(/^([^\(]+?)([\n$])/gm, '{anonymous}() ($1)$2')
                .replace(/^Object.<anonymous>\s*\(([^\)]+)\)/gm, '{anonymous}() ($1)')
                .replace(/^(.+) \((.+)\)$/gm, '$1@$2')
                .split('\n')
                .slice(0, -1);
        },

        /**
         * Given an Error object, return a formatted Array based on Safari's stack string.
         *
         * @param e - Error object to inspect
         * @return Array<String> of function calls, files and line numbers
         */
        safari: function(e) {
            return e.stack.replace(/\[native code\]\n/m, '')
                .replace(/^(?=\w+Error\:).*$\n/m, '')
                .replace(/^@/gm, '{anonymous}()@')
                .split('\n');
        },

        /**
         * Given an Error object, return a formatted Array based on IE's stack string.
         *
         * @param e - Error object to inspect
         * @return Array<String> of function calls, files and line numbers
         */
        ie: function(e) {
            return e.stack
                .replace(/^\s*at\s+(.*)$/gm, '$1')
                .replace(/^Anonymous function\s+/gm, '{anonymous}() ')
                .replace(/^(.+)\s+\((.+)\)$/gm, '$1@$2')
                .split('\n')
                .slice(1);
        },

        /**
         * Given an Error object, return a formatted Array based on Firefox's stack string.
         *
         * @param e - Error object to inspect
         * @return Array<String> of function calls, files and line numbers
         */
        firefox: function(e) {
            return e.stack.replace(/(?:\n@:0)?\s+$/m, '')
                .replace(/^(?:\((\S*)\))?@/gm, '{anonymous}($1)@')
                .split('\n');
        },

        opera11: function(e) {
            var ANON = '{anonymous}', lineRE = /^.*line (\d+), column (\d+)(?: in (.+))? in (\S+):$/;
            var lines = e.stacktrace.split('\n'), result = [];

            for (var i = 0, len = lines.length; i < len; i += 2) {
                var match = lineRE.exec(lines[i]);
                if (match) {
                    var location = match[4] + ':' + match[1] + ':' + match[2];
                    var fnName = match[3] || "global code";
                    fnName = fnName.replace(/<anonymous function: (\S+)>/, "$1").replace(/<anonymous function>/, ANON);
                    result.push(fnName + '@' + location + ' -- ' + lines[i + 1].replace(/^\s+/, ''));
                }
            }

            return result;
        },

        opera10b: function(e) {
            // "<anonymous function: run>([arguments not available])@file://localhost/G:/js/stacktrace.js:27\n" +
            // "printStackTrace([arguments not available])@file://localhost/G:/js/stacktrace.js:18\n" +
            // "@file://localhost/G:/js/test/functional/testcase1.html:15"
            var lineRE = /^(.*)@(.+):(\d+)$/;
            var lines = e.stacktrace.split('\n'), result = [];

            for (var i = 0, len = lines.length; i < len; i++) {
                var match = lineRE.exec(lines[i]);
                if (match) {
                    var fnName = match[1] ? (match[1] + '()') : "global code";
                    result.push(fnName + '@' + match[2] + ':' + match[3]);
                }
            }

            return result;
        },

        /**
         * Given an Error object, return a formatted Array based on Opera 10's stacktrace string.
         *
         * @param e - Error object to inspect
         * @return Array<String> of function calls, files and line numbers
         */
        opera10a: function(e) {
            // "  Line 27 of linked script file://localhost/G:/js/stacktrace.js\n"
            // "  Line 11 of inline#1 script in file://localhost/G:/js/test/functional/testcase1.html: In function foo\n"
            var ANON = '{anonymous}', lineRE = /Line (\d+).*script (?:in )?(\S+)(?:: In function (\S+))?$/i;
            var lines = e.stacktrace.split('\n'), result = [];

            for (var i = 0, len = lines.length; i < len; i += 2) {
                var match = lineRE.exec(lines[i]);
                if (match) {
                    var fnName = match[3] || ANON;
                    result.push(fnName + '()@' + match[2] + ':' + match[1] + ' -- ' + lines[i + 1].replace(/^\s+/, ''));
                }
            }

            return result;
        },

        // Opera 7.x-9.2x only!
        opera9: function(e) {
            // "  Line 43 of linked script file://localhost/G:/js/stacktrace.js\n"
            // "  Line 7 of inline#1 script in file://localhost/G:/js/test/functional/testcase1.html\n"
            var ANON = '{anonymous}', lineRE = /Line (\d+).*script (?:in )?(\S+)/i;
            var lines = e.message.split('\n'), result = [];

            for (var i = 2, len = lines.length; i < len; i += 2) {
                var match = lineRE.exec(lines[i]);
                if (match) {
                    result.push(ANON + '()@' + match[2] + ':' + match[1] + ' -- ' + lines[i + 1].replace(/^\s+/, ''));
                }
            }

            return result;
        },

        phantomjs: function(e) {
            var ANON = '{anonymous}', lineRE = /(\S+) \((\S+)\)/i;
            var lines = e.stack.split('\n'), result = [];

            for (var i = 1, len = lines.length; i < len; i++) {
                lines[i] = lines[i].replace(/^\s+at\s+/gm, '');
                var match = lineRE.exec(lines[i]);
                if (match) {
                    result.push(match[1] + '()@' + match[2]);
                }
                else {
                    result.push(ANON + '()@' + lines[i]);
                }
            }

            return result;
        },

        // Safari 5-, IE 9-, and others
        other: function(curr) {
            var ANON = '{anonymous}', fnRE = /function(?:\s+([\w$]+))?\s*\(/, stack = [], fn, args, maxStackSize = 10;
            var slice = Array.prototype.slice;
            while (curr && stack.length < maxStackSize) {
                fn = fnRE.test(curr.toString()) ? RegExp.$1 || ANON : ANON;
                try {
                    args = slice.call(curr['arguments'] || []);
                } catch (e) {
                    args = ['Cannot access arguments: ' + e];
                }
                stack[stack.length] = fn + '(' + this.stringifyArguments(args) + ')';
                try {
                    curr = curr.caller;
                } catch (e) {
                    stack[stack.length] = 'Cannot access caller: ' + e;
                    break;
                }
            }
            return stack;
        },

        /**
         * Given arguments array as a String, substituting type names for non-string types.
         *
         * @param {Arguments,Array} args
         * @return {String} stringified arguments
         */
        stringifyArguments: function(args) {
            var result = [];
            var slice = Array.prototype.slice;
            for (var i = 0; i < args.length; ++i) {
                var arg = args[i];
                if (arg === undefined) {
                    result[i] = 'undefined';
                } else if (arg === null) {
                    result[i] = 'null';
                } else if (arg.constructor) {
                    // TODO constructor comparison does not work for iframes
                    if (arg.constructor === Array) {
                        if (arg.length < 3) {
                            result[i] = '[' + this.stringifyArguments(arg) + ']';
                        } else {
                            result[i] = '[' + this.stringifyArguments(slice.call(arg, 0, 1)) + '...' + this.stringifyArguments(slice.call(arg, -1)) + ']';
                        }
                    } else if (arg.constructor === Object) {
                        result[i] = '#object';
                    } else if (arg.constructor === Function) {
                        result[i] = '#function';
                    } else if (arg.constructor === String) {
                        result[i] = '"' + arg + '"';
                    } else if (arg.constructor === Number) {
                        result[i] = arg;
                    } else {
                        result[i] = '?';
                    }
                }
            }
            return result.join(',');
        },

        sourceCache: {},

        /**
         * @return {String} the text from a given URL
         */
        ajax: function(url) {
            var req = this.createXMLHTTPObject();
            if (req) {
                try {
                    req.open('GET', url, false);
                    //req.overrideMimeType('text/plain');
                    //req.overrideMimeType('text/javascript');
                    req.send(null);
                    //return req.status == 200 ? req.responseText : '';
                    return req.responseText;
                } catch (e) {
                }
            }
            return '';
        },

        /**
         * Try XHR methods in order and store XHR factory.
         *
         * @return {XMLHttpRequest} XHR function or equivalent
         */
        createXMLHTTPObject: function() {
            var xmlhttp, XMLHttpFactories = [
                function() {
                    return new XMLHttpRequest();
                }, function() {
                    return new ActiveXObject('Msxml2.XMLHTTP');
                }, function() {
                    return new ActiveXObject('Msxml3.XMLHTTP');
                }, function() {
                    return new ActiveXObject('Microsoft.XMLHTTP');
                }
            ];
            for (var i = 0; i < XMLHttpFactories.length; i++) {
                try {
                    xmlhttp = XMLHttpFactories[i]();
                    // Use memoization to cache the factory
                    this.createXMLHTTPObject = XMLHttpFactories[i];
                    return xmlhttp;
                } catch (e) {
                }
            }
        },

        /**
         * Given a URL, check if it is in the same domain (so we can get the source
         * via Ajax).
         *
         * @param url {String} source url
         * @return {Boolean} False if we need a cross-domain request
         */
        isSameDomain: function(url) {
            return typeof location !== "undefined" && url.indexOf(location.hostname) !== -1; // location may not be defined, e.g. when running from nodejs.
        },

        /**
         * Get source code from given URL if in the same domain.
         *
         * @param url {String} JS source URL
         * @return {Array} Array of source code lines
         */
        getSource: function(url) {
            // TODO reuse source from script tags?
            if (!(url in this.sourceCache)) {
                this.sourceCache[url] = this.ajax(url).split('\n');
            }
            return this.sourceCache[url];
        },

        guessAnonymousFunctions: function(stack) {
            for (var i = 0; i < stack.length; ++i) {
                var reStack = /\{anonymous\}\(.*\)@(.*)/,
                    reRef = /^(.*?)(?::(\d+))(?::(\d+))?(?: -- .+)?$/,
                    frame = stack[i], ref = reStack.exec(frame);

                if (ref) {
                    var m = reRef.exec(ref[1]);
                    if (m) { // If falsey, we did not get any file/line information
                        var file = m[1], lineno = m[2], charno = m[3] || 0;
                        if (file && this.isSameDomain(file) && lineno) {
                            var functionName = this.guessAnonymousFunction(file, lineno, charno);
                            stack[i] = frame.replace('{anonymous}', functionName);
                        }
                    }
                }
            }
            return stack;
        },

        guessAnonymousFunction: function(url, lineNo, charNo) {
            var ret;
            try {
                ret = this.findFunctionName(this.getSource(url), lineNo);
            } catch (e) {
                ret = 'getSource failed with url: ' + url + ', exception: ' + e.toString();
            }
            return ret;
        },

        findFunctionName: function(source, lineNo) {
            // FIXME findFunctionName fails for compressed source
            // (more than one function on the same line)
            // function {name}({args}) m[1]=name m[2]=args
            var reFunctionDeclaration = /function\s+([^(]*?)\s*\(([^)]*)\)/;
            // {name} = function ({args}) TODO args capture
            // /['"]?([0-9A-Za-z_]+)['"]?\s*[:=]\s*function(?:[^(]*)/
            var reFunctionExpression = /['"]?([$_A-Za-z][$_A-Za-z0-9]*)['"]?\s*[:=]\s*function\b/;
            // {name} = eval()
            var reFunctionEvaluation = /['"]?([$_A-Za-z][$_A-Za-z0-9]*)['"]?\s*[:=]\s*(?:eval|new Function)\b/;
            // Walk backwards in the source lines until we find
            // the line which matches one of the patterns above
            var code = "", line, maxLines = Math.min(lineNo, 20), m, commentPos;
            for (var i = 0; i < maxLines; ++i) {
                // lineNo is 1-based, source[] is 0-based
                line = source[lineNo - i - 1];
                commentPos = line.indexOf('//');
                if (commentPos >= 0) {
                    line = line.substr(0, commentPos);
                }
                // TODO check other types of comments? Commented code may lead to false positive
                if (line) {
                    code = line + code;
                    m = reFunctionExpression.exec(code);
                    if (m && m[1]) {
                        return m[1];
                    }
                    m = reFunctionDeclaration.exec(code);
                    if (m && m[1]) {
                        //return m[1] + "(" + (m[2] || "") + ")";
                        return m[1];
                    }
                    m = reFunctionEvaluation.exec(code);
                    if (m && m[1]) {
                        return m[1];
                    }
                }
            }
            return '(?)';
        }
    };

    return printStackTrace;
}));

},{}],33:[function(require,module,exports){
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

exports.decode = base64_decode;
exports.encode = base64_encode;

},{}],34:[function(require,module,exports){
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
module.exports = this.JSON || JSON;

},{}],35:[function(require,module,exports){
var util = require('../../lib/twilio/util');
var swfobject = require('../swfobject').swfobject;

// TODO(mroberts): This file is still a little weird in the way it defines
// things. Let's see if we can get rid of `NS_MEDIASTREAM` at some point.
var NS_MEDIASTREAM = 'Twilio';

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
    if (!(this instanceof MediaStream))
        return new MediaStream(encrypt, host);
   
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

    this.onconnected = noop;

    this._uri = (encrypt ? "rtmps" : "rtmp") + "://" + host + "/chunder";

    this.micAttached = false;

    MediaStream.__instances[this.__id] = this;

    return this;
}

MediaStream.prototype = {
    openHelper: function(next, simplePermissionDialog, noMicLevel, dialogFn, showSettings) {
        var self = this;
        MediaStream.__queue(function() {
            var noMics = MediaStream.getMicrophones().length == noMicLevel;
            if (noMics) {
                next("No microphone is available");
                return;
            } else if (simplePermissionDialog) {
                if (MediaStream.isMicMuted()) {
                    MediaStream.__queueResponseCB( function(accessGranted) {
                        dialogFn.closeDialog(accessGranted);
                        if (accessGranted) {
                            self.exec("startCall");
                            self.onopen(self);
                        }
                    });
                    dialogFn.showDialog();
                } else {
                    self.onconnected = function() {
                        self.exec("startCall");
                        self.onopen(self);
                    }
                }
                next();
            } else {
                self.onconnected = function() {
                    self.exec("startCall");
                    self.onopen(self);
                }
                if (!MediaStream.isMicMuted()) next();
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
     * @param {function} callback for after the audio is attached
     * @param {int} index The index of a Microphone, or null.
     */
    attachAudio: function(callback, index) {
        var self = this;
        MediaStream.__queue(function() {
            MediaStream.__flash.attachAudio(self.__id, index);
            self.micAttached = true;
            if (callback && typeof callback == "function") {
                callback();
            }
        });
    },
    /**
     * Detach Microphone object from the MediaStream, effectively disabling
     * audio publishing.
     *
     * @example mediaStream.detachAudio();
     *
     * @param {function} callback for after the audio is detached
     * @param {int} index The index of a Microphone, or null.
     */
    detachAudio: function(callback) {
        var self = this;
        MediaStream.__queue(function() {
            MediaStream.__flash.detachAudio(self.__id);
            self.micAttached = false;
            if (callback && typeof callback == "function") {
                callback();
            }
        });
    },
    isAudioAttached: function() {
        return this.micAttached;
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
            case "callsid":
                if (typeof this.onCallSid == "function") {
                    this.onCallSid(event.info.callsid);
                }
                break;
            default:
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
                this.publish("input","live");
                this.attachAudio();
                this.onconnected();
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
     * Queue tasks to be called when simplePermissionDialog response is recorded
     *
     * @param {function} task The task to run.
     */
    __queueResponseCB: function(cb) {
        MediaStream.__responseCB.push(cb);
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
    },
    __onUserResponse: function(accessGranted) {
        for (var i = 0; i < MediaStream.__responseCB.length; i++) {
            MediaStream.__responseCB[i](accessGranted);
        }
        MediaStream.__responseCB = [];
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
MediaStream.__responseCB = [];
MediaStream.__debug = false;
MediaStream.initialized = false;

/** @constant */
MediaStream.AMF0 = 0;
/** @constant */
MediaStream.AMF3 = 3;

exports.MediaStream = MediaStream;

},{"../../lib/twilio/util":21,"../swfobject":37}],36:[function(require,module,exports){
var swfobject = require('../swfobject').swfobject;

// TODO(mroberts): This file is still a little weird in the way it defines
// things. Let's see if we can get rid of `NS_SOUND` at some point.
var NS_SOUND = 'Twilio';

function Sound(url) {
    if (!(this instanceof Sound))
        return new Sound(url);
    this.id = Sound.nextId++;
    Sound.items[this.id] = this;
    this.create();
    return this;
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

if (typeof window === 'undefined')
    for (var key in dummyBackend)
        Sound.prototype[key] = dummyBackend[key];

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
            log("WARNING: Audio sounds disabled. HTML5 audio support or Flash Player >= 10.0.0 is required");
        }
    }
};

exports.Sound = Sound;

},{"../swfobject":37}],37:[function(require,module,exports){
/*	SWFObject v2.2 <http://code.google.com/p/swfobject/> 
	is released under the MIT License <http://www.opensource.org/licenses/mit-license.php> 
*/
if (typeof window !== 'undefined') {
var swfobject=function(){var D="undefined",r="object",S="Shockwave Flash",W="ShockwaveFlash.ShockwaveFlash",q="application/x-shockwave-flash",R="SWFObjectExprInst",x="onreadystatechange",O=window,j=document,t=navigator,T=false,U=[h],o=[],N=[],I=[],l,Q,E,B,J=false,a=false,n,G,m=true,M=function(){var aa=typeof j.getElementById!=D&&typeof j.getElementsByTagName!=D&&typeof j.createElement!=D,ah=t.userAgent.toLowerCase(),Y=t.platform.toLowerCase(),ae=Y?/win/.test(Y):/win/.test(ah),ac=Y?/mac/.test(Y):/mac/.test(ah),af=/webkit/.test(ah)?parseFloat(ah.replace(/^.*webkit\/(\d+(\.\d+)?).*$/,"$1")):false,X=!+"\v1",ag=[0,0,0],ab=null;if(typeof t.plugins!=D&&typeof t.plugins[S]==r){ab=t.plugins[S].description;if(ab&&!(typeof t.mimeTypes!=D&&t.mimeTypes[q]&&!t.mimeTypes[q].enabledPlugin)){T=true;X=false;ab=ab.replace(/^.*\s+(\S+\s+\S+$)/,"$1");ag[0]=parseInt(ab.replace(/^(.*)\..*$/,"$1"),10);ag[1]=parseInt(ab.replace(/^.*\.(.*)\s.*$/,"$1"),10);ag[2]=/[a-zA-Z]/.test(ab)?parseInt(ab.replace(/^.*[a-zA-Z]+(.*)$/,"$1"),10):0}}else{if(typeof O.ActiveXObject!=D){try{var ad=new ActiveXObject(W);if(ad){ab=ad.GetVariable("$version");if(ab){X=true;ab=ab.split(" ")[1].split(",");ag=[parseInt(ab[0],10),parseInt(ab[1],10),parseInt(ab[2],10)]}}}catch(Z){}}}return{w3:aa,pv:ag,wk:af,ie:X,win:ae,mac:ac}}(),k=function(){if(!M.w3){return}if((typeof j.readyState!=D&&j.readyState=="complete")||(typeof j.readyState==D&&(j.getElementsByTagName("body")[0]||j.body))){f()}if(!J){if(typeof j.addEventListener!=D){j.addEventListener("DOMContentLoaded",f,false)}if(M.ie&&M.win){j.attachEvent(x,function(){if(j.readyState=="complete"){j.detachEvent(x,arguments.callee);f()}});if(O==top){(function(){if(J){return}try{j.documentElement.doScroll("left")}catch(X){setTimeout(arguments.callee,0);return}f()})()}}if(M.wk){(function(){if(J){return}if(!/loaded|complete/.test(j.readyState)){setTimeout(arguments.callee,0);return}f()})()}s(f)}}();function f(){if(J){return}try{var Z=j.getElementsByTagName("body")[0].appendChild(C("span"));Z.parentNode.removeChild(Z)}catch(aa){return}J=true;var X=U.length;for(var Y=0;Y<X;Y++){U[Y]()}}function K(X){if(J){X()}else{U[U.length]=X}}function s(Y){if(typeof O.addEventListener!=D){O.addEventListener("load",Y,false)}else{if(typeof j.addEventListener!=D){j.addEventListener("load",Y,false)}else{if(typeof O.attachEvent!=D){i(O,"onload",Y)}else{if(typeof O.onload=="function"){var X=O.onload;O.onload=function(){X();Y()}}else{O.onload=Y}}}}}function h(){if(T){V()}else{H()}}function V(){var X=j.getElementsByTagName("body")[0];var aa=C(r);aa.setAttribute("type",q);var Z=X.appendChild(aa);if(Z){var Y=0;(function(){if(typeof Z.GetVariable!=D){var ab=Z.GetVariable("$version");if(ab){ab=ab.split(" ")[1].split(",");M.pv=[parseInt(ab[0],10),parseInt(ab[1],10),parseInt(ab[2],10)]}}else{if(Y<10){Y++;setTimeout(arguments.callee,10);return}}X.removeChild(aa);Z=null;H()})()}else{H()}}function H(){var ag=o.length;if(ag>0){for(var af=0;af<ag;af++){var Y=o[af].id;var ab=o[af].callbackFn;var aa={success:false,id:Y};if(M.pv[0]>0){var ae=c(Y);if(ae){if(F(o[af].swfVersion)&&!(M.wk&&M.wk<312)){w(Y,true);if(ab){aa.success=true;aa.ref=z(Y);ab(aa)}}else{if(o[af].expressInstall&&A()){var ai={};ai.data=o[af].expressInstall;ai.width=ae.getAttribute("width")||"0";ai.height=ae.getAttribute("height")||"0";if(ae.getAttribute("class")){ai.styleclass=ae.getAttribute("class")}if(ae.getAttribute("align")){ai.align=ae.getAttribute("align")}var ah={};var X=ae.getElementsByTagName("param");var ac=X.length;for(var ad=0;ad<ac;ad++){if(X[ad].getAttribute("name").toLowerCase()!="movie"){ah[X[ad].getAttribute("name")]=X[ad].getAttribute("value")}}P(ai,ah,Y,ab)}else{p(ae);if(ab){ab(aa)}}}}}else{w(Y,true);if(ab){var Z=z(Y);if(Z&&typeof Z.SetVariable!=D){aa.success=true;aa.ref=Z}ab(aa)}}}}}function z(aa){var X=null;var Y=c(aa);if(Y&&Y.nodeName=="OBJECT"){if(typeof Y.SetVariable!=D){X=Y}else{var Z=Y.getElementsByTagName(r)[0];if(Z){X=Z}}}return X}function A(){return !a&&F("6.0.65")&&(M.win||M.mac)&&!(M.wk&&M.wk<312)}function P(aa,ab,X,Z){a=true;E=Z||null;B={success:false,id:X};var ae=c(X);if(ae){if(ae.nodeName=="OBJECT"){l=g(ae);Q=null}else{l=ae;Q=X}aa.id=R;if(typeof aa.width==D||(!/%$/.test(aa.width)&&parseInt(aa.width,10)<310)){aa.width="310"}if(typeof aa.height==D||(!/%$/.test(aa.height)&&parseInt(aa.height,10)<137)){aa.height="137"}j.title=j.title.slice(0,47)+" - Flash Player Installation";var ad=M.ie&&M.win?"ActiveX":"PlugIn",ac="MMredirectURL="+O.location.toString().replace(/&/g,"%26")+"&MMplayerType="+ad+"&MMdoctitle="+j.title;if(typeof ab.flashvars!=D){ab.flashvars+="&"+ac}else{ab.flashvars=ac}if(M.ie&&M.win&&ae.readyState!=4){var Y=C("div");X+="SWFObjectNew";Y.setAttribute("id",X);ae.parentNode.insertBefore(Y,ae);ae.style.display="none";(function(){if(ae.readyState==4){ae.parentNode.removeChild(ae)}else{setTimeout(arguments.callee,10)}})()}u(aa,ab,X)}}function p(Y){if(M.ie&&M.win&&Y.readyState!=4){var X=C("div");Y.parentNode.insertBefore(X,Y);X.parentNode.replaceChild(g(Y),X);Y.style.display="none";(function(){if(Y.readyState==4){Y.parentNode.removeChild(Y)}else{setTimeout(arguments.callee,10)}})()}else{Y.parentNode.replaceChild(g(Y),Y)}}function g(ab){var aa=C("div");if(M.win&&M.ie){aa.innerHTML=ab.innerHTML}else{var Y=ab.getElementsByTagName(r)[0];if(Y){var ad=Y.childNodes;if(ad){var X=ad.length;for(var Z=0;Z<X;Z++){if(!(ad[Z].nodeType==1&&ad[Z].nodeName=="PARAM")&&!(ad[Z].nodeType==8)){aa.appendChild(ad[Z].cloneNode(true))}}}}}return aa}function u(ai,ag,Y){var X,aa=c(Y);if(M.wk&&M.wk<312){return X}if(aa){if(typeof ai.id==D){ai.id=Y}if(M.ie&&M.win){var ah="";for(var ae in ai){if(ai[ae]!=Object.prototype[ae]){if(ae.toLowerCase()=="data"){ag.movie=ai[ae]}else{if(ae.toLowerCase()=="styleclass"){ah+=' class="'+ai[ae]+'"'}else{if(ae.toLowerCase()!="classid"){ah+=" "+ae+'="'+ai[ae]+'"'}}}}}var af="";for(var ad in ag){if(ag[ad]!=Object.prototype[ad]){af+='<param name="'+ad+'" value="'+ag[ad]+'" />'}}aa.outerHTML='<object classid="clsid:D27CDB6E-AE6D-11cf-96B8-444553540000"'+ah+">"+af+"</object>";N[N.length]=ai.id;X=c(ai.id)}else{var Z=C(r);Z.setAttribute("type",q);for(var ac in ai){if(ai[ac]!=Object.prototype[ac]){if(ac.toLowerCase()=="styleclass"){Z.setAttribute("class",ai[ac])}else{if(ac.toLowerCase()!="classid"){Z.setAttribute(ac,ai[ac])}}}}for(var ab in ag){if(ag[ab]!=Object.prototype[ab]&&ab.toLowerCase()!="movie"){e(Z,ab,ag[ab])}}aa.parentNode.replaceChild(Z,aa);X=Z}}return X}function e(Z,X,Y){var aa=C("param");aa.setAttribute("name",X);aa.setAttribute("value",Y);Z.appendChild(aa)}function y(Y){var X=c(Y);if(X&&X.nodeName=="OBJECT"){if(M.ie&&M.win){X.style.display="none";(function(){if(X.readyState==4){b(Y)}else{setTimeout(arguments.callee,10)}})()}else{X.parentNode.removeChild(X)}}}function b(Z){var Y=c(Z);if(Y){for(var X in Y){if(typeof Y[X]=="function"){Y[X]=null}}Y.parentNode.removeChild(Y)}}function c(Z){var X=null;try{X=j.getElementById(Z)}catch(Y){}return X}function C(X){return j.createElement(X)}function i(Z,X,Y){Z.attachEvent(X,Y);I[I.length]=[Z,X,Y]}function F(Z){var Y=M.pv,X=Z.split(".");X[0]=parseInt(X[0],10);X[1]=parseInt(X[1],10)||0;X[2]=parseInt(X[2],10)||0;return(Y[0]>X[0]||(Y[0]==X[0]&&Y[1]>X[1])||(Y[0]==X[0]&&Y[1]==X[1]&&Y[2]>=X[2]))?true:false}function v(ac,Y,ad,ab){if(M.ie&&M.mac){return}var aa=j.getElementsByTagName("head")[0];if(!aa){return}var X=(ad&&typeof ad=="string")?ad:"screen";if(ab){n=null;G=null}if(!n||G!=X){var Z=C("style");Z.setAttribute("type","text/css");Z.setAttribute("media",X);n=aa.appendChild(Z);if(M.ie&&M.win&&typeof j.styleSheets!=D&&j.styleSheets.length>0){n=j.styleSheets[j.styleSheets.length-1]}G=X}if(M.ie&&M.win){if(n&&typeof n.addRule==r){n.addRule(ac,Y)}}else{if(n&&typeof j.createTextNode!=D){n.appendChild(j.createTextNode(ac+" {"+Y+"}"))}}}function w(Z,X){if(!m){return}var Y=X?"visible":"hidden";if(J&&c(Z)){c(Z).style.visibility=Y}else{v("#"+Z,"visibility:"+Y)}}function L(Y){var Z=/[\\\"<>\.;]/;var X=Z.exec(Y)!=null;return X&&typeof encodeURIComponent!=D?encodeURIComponent(Y):Y}var d=function(){if(M.ie&&M.win){window.attachEvent("onunload",function(){var ac=I.length;for(var ab=0;ab<ac;ab++){I[ab][0].detachEvent(I[ab][1],I[ab][2])}var Z=N.length;for(var aa=0;aa<Z;aa++){y(N[aa])}for(var Y in M){M[Y]=null}M=null;for(var X in swfobject){swfobject[X]=null}swfobject=null})}}();return{registerObject:function(ab,X,aa,Z){if(M.w3&&ab&&X){var Y={};Y.id=ab;Y.swfVersion=X;Y.expressInstall=aa;Y.callbackFn=Z;o[o.length]=Y;w(ab,false)}else{if(Z){Z({success:false,id:ab})}}},getObjectById:function(X){if(M.w3){return z(X)}},embedSWF:function(ab,ah,ae,ag,Y,aa,Z,ad,af,ac){var X={success:false,id:ah};if(M.w3&&!(M.wk&&M.wk<312)&&ab&&ah&&ae&&ag&&Y){w(ah,false);K(function(){ae+="";ag+="";var aj={};if(af&&typeof af===r){for(var al in af){aj[al]=af[al]}}aj.data=ab;aj.width=ae;aj.height=ag;var am={};if(ad&&typeof ad===r){for(var ak in ad){am[ak]=ad[ak]}}if(Z&&typeof Z===r){for(var ai in Z){if(typeof am.flashvars!=D){am.flashvars+="&"+ai+"="+Z[ai]}else{am.flashvars=ai+"="+Z[ai]}}}if(F(Y)){var an=u(aj,am,ah);if(aj.id==ah){w(ah,true)}X.success=true;X.ref=an}else{if(aa&&A()){aj.data=aa;P(aj,am,ah,ac);return}else{w(ah,true)}}if(ac){ac(X)}})}else{if(ac){ac(X)}}},switchOffAutoHideShow:function(){m=false},ua:M,getFlashPlayerVersion:function(){return{major:M.pv[0],minor:M.pv[1],release:M.pv[2]}},hasFlashPlayerVersion:F,createSWF:function(Z,Y,X){if(M.w3){return u(Z,Y,X)}else{return undefined}},showExpressInstall:function(Z,aa,X,Y){if(M.w3&&A()){P(Z,aa,X,Y)}},removeSWF:function(X){if(M.w3){y(X)}},createCSS:function(aa,Z,Y,X){if(M.w3){v(aa,Z,Y,X)}},addDomLoadEvent:K,addLoadEvent:s,getQueryParamValue:function(aa){var Z=j.location.search||j.location.hash;if(Z){if(/\?/.test(Z)){Z=Z.split("?")[1]}if(aa==null){return L(Z)}var Y=Z.split("&");for(var X=0;X<Y.length;X++){if(Y[X].substring(0,Y[X].indexOf("="))==aa){return L(Y[X].substring((Y[X].indexOf("=")+1)))}}}return""},expressInstallCallback:function(){if(a){var X=c(R);if(X&&l){X.parentNode.replaceChild(l,X);if(Q){w(Q,true);if(M.ie&&M.win){l.style.display="block"}}if(E){E(B)}}a=false}}}}();
window.swfobject = swfobject;
} else { var swfobject = { getFlashPlayerVersion: function(){} }; }
exports.swfobject = swfobject;

},{}],38:[function(require,module,exports){
(function (process){
// Copyright: Hiroshi Ichikawa <http://gimite.net/en/>
// License: New BSD License
// Reference: http://dev.w3.org/html5/websockets/
// Reference: http://tools.ietf.org/html/draft-hixie-thewebsocketprotocol

var swfobject = require('../swfobject').swfobject;

// NOTE(mroberts): We're doing something tricky here to keep 'ws' from getting
// included by Browserify.
if (typeof process !== 'undefined' && process.title === 'node')
  var ws = eval("require('ws')");

exports.WebSocket = (function() {
  
  if (ws) return ws;
  else if (window.WebSocket) return window.WebSocket;

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

  return WebSocket;
  
})();

}).call(this,require('_process'))
},{"../swfobject":37,"_process":29}]},{},[1]);
