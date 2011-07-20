window.Modernizr=function(i,f,m){function s(a,b){return typeof a===b}function J(a,b){for(var d in a)if(h[a[d]]!==m&&(!b||b(a[d],v)))return!0}function q(a,b){var d=a.charAt(0).toUpperCase()+a.substr(1),d=(a+" "+x.join(d+" ")+d).split(" ");return!!J(d,b)}function K(){j.input=function(a){for(var b=0,d=a.length;b<d;b++)C[a[b]]=!!(a[b]in g);return C}("autocomplete autofocus list placeholder max min multiple pattern required step".split(" "));j.inputtypes=function(a){for(var b=0,d,e,n=a.length;b<n;b++){g.setAttribute("type",
e=a[b]);if(d=g.type!=="text")g.value=y,g.style.cssText="position:absolute;visibility:hidden;",/^range$/.test(e)&&g.style.WebkitAppearance!==m?(l.appendChild(g),d=f.defaultView,d=d.getComputedStyle&&d.getComputedStyle(g,null).WebkitAppearance!=="textfield"&&g.offsetHeight!==0,l.removeChild(g)):/^(search|tel)$/.test(e)||(/^(url|email)$/.test(e)?d=g.checkValidity&&g.checkValidity()===!1:/^color$/.test(e)?(l.appendChild(g),d=g.value!=y,l.removeChild(g)):d=g.value!=y);M[a[b]]=!!d}return M}("search tel url email datetime date month week time datetime-local number range color".split(" "))}
var j={},l=f.documentElement,p=f.head||f.getElementsByTagName("head")[0],v=f.createElement("modernizr"),h=v.style,g=f.createElement("input"),y=":)",r=Object.prototype.toString,o=" -webkit- -moz- -o- -ms- -khtml- ".split(" "),x="Webkit Moz O ms Khtml".split(" "),w={svg:"http://www.w3.org/2000/svg"},c={},M={},C={},N=[],z,D=f.getElementsByTagName("script")[0],E=function(){var a={},b=f.createElement("body"),d=f.createElement("div");d.id="modernizr-mqtest";b.appendChild(d);return function(e){if(a[e]==
m){if(i.matchMedia)return a[e]=matchMedia(e).matches;var n=f.createElement("style"),c="@media "+e+" { #modernizr-mqtest { position: absolute; } }";n.type="text/css";n.styleSheet?n.styleSheet.cssText=c:n.appendChild(f.createTextNode(c));D.parentNode.insertBefore(b,D);D.parentNode.insertBefore(n,D);a[e]=(i.getComputedStyle?getComputedStyle(d,null):d.currentStyle).position=="absolute";b.parentNode.removeChild(b);n.parentNode.removeChild(n)}return a[e]}}(),t=function(){var a={select:"input",change:"input",
submit:"form",reset:"form",error:"img",load:"img",abort:"img"};return function(b,d){var d=d||f.createElement(a[b]||"div"),b="on"+b,e=b in d;e||(d.setAttribute||(d=f.createElement("div")),d.setAttribute&&d.removeAttribute&&(d.setAttribute(b,""),e=s(d[b],"function"),s(d[b],m)||(d[b]=m),d.removeAttribute(b)));return e}}(),A={}.hasOwnProperty,F;F=!s(A,m)&&!s(A.call,m)?function(a,b){return A.call(a,b)}:function(a,b){return b in a&&s(a.constructor.prototype[b],m)};c.flexbox=function(){var a=f.createElement("div"),
b=f.createElement("div");(function(a,d,b,c){d+=":";a.style.cssText=(d+o.join(b+";"+d)).slice(0,-d.length)+(c||"")})(a,"display","box","width:42px;padding:0;");b.style.cssText=o.join("box-flex:1;")+"width:10px;";a.appendChild(b);l.appendChild(a);var d=b.offsetWidth===42;a.removeChild(b);l.removeChild(a);return d};c.canvas=function(){var a=f.createElement("canvas");return!(!a.getContext||!a.getContext("2d"))};c.canvastext=function(){return!(!j.canvas||!s(f.createElement("canvas").getContext("2d").fillText,
"function"))};c.webgl=function(){return!!i.WebGLRenderingContext};c.touch=function(){return"ontouchstart"in i||E("("+o.join("touch-enabled),(")+"modernizr)")};c.geolocation=function(){return!!navigator.geolocation};c.postmessage=function(){return!!i.postMessage};c.websqldatabase=function(){return!!i.openDatabase};c.indexedDB=function(){for(var a=-1,b=x.length;++a<b;)if(i[x[a].toLowerCase()+"IndexedDB"])return!0;return!!i.indexedDB};c.hashchange=function(){return t("hashchange",i)&&(f.documentMode===
m||f.documentMode>7)};c.history=function(){return!(!i.history||!history.pushState)};c.draganddrop=function(){return t("dragstart")&&t("drop")};c.websockets=function(){return"WebSocket"in i};c.rgba=function(){h.cssText="background-color:rgba(150,255,150,.5)";return!!~(""+h.backgroundColor).indexOf("rgba")};c.hsla=function(){h.cssText="background-color:hsla(120,40%,100%,.5)";return!!~(""+h.backgroundColor).indexOf("rgba")||!!~(""+h.backgroundColor).indexOf("hsla")};c.multiplebgs=function(){h.cssText=
"background:url(//:),url(//:),red url(//:)";return/(url\s*\(.*?){3}/.test(h.background)};c.backgroundsize=function(){return q("backgroundSize")};c.borderimage=function(){return q("borderImage")};c.borderradius=function(){return q("borderRadius","",function(a){return!!~(""+a).indexOf("orderRadius")})};c.boxshadow=function(){return q("boxShadow")};c.textshadow=function(){return f.createElement("div").style.textShadow===""};c.opacity=function(){var a=o.join("opacity:.55;")+"";h.cssText=a;return/^0.55$/.test(h.opacity)};
c.cssanimations=function(){return q("animationName")};c.csscolumns=function(){return q("columnCount")};c.cssgradients=function(){var a=("background-image:"+o.join("gradient(linear,left top,right bottom,from(#9f9),to(white));background-image:")+o.join("linear-gradient(left top,#9f9, white);background-image:")).slice(0,-17);h.cssText=a;return!!~(""+h.backgroundImage).indexOf("gradient")};c.cssreflections=function(){return q("boxReflect")};c.csstransforms=function(){return!!J(["transformProperty","WebkitTransform",
"MozTransform","OTransform","msTransform"])};c.csstransforms3d=function(){var a=!!J(["perspectiveProperty","WebkitPerspective","MozPerspective","OPerspective","msPerspective"]);a&&"webkitPerspective"in l.style&&(a=E("("+o.join("transform-3d),(")+"modernizr)"));return a};c.csstransitions=function(){return q("transitionProperty")};c.fontface=function(){var a,b,d=p||l,e=f.createElement("style");b=f.implementation||{hasFeature:function(){return!1}};e.type="text/css";d.insertBefore(e,d.firstChild);a=e.sheet||
e.styleSheet;b=(b.hasFeature("CSS2","")?function(d){if(!a||!d)return!1;var b=!1;try{a.insertRule(d,0),b=/src/i.test(a.cssRules[0].cssText),a.deleteRule(a.cssRules.length-1)}catch(e){}return b}:function(d){if(!a||!d)return!1;a.cssText=d;return a.cssText.length!==0&&/src/i.test(a.cssText)&&a.cssText.replace(/\r+|\n+/g,"").indexOf(d.split(" ")[0])===0})('@font-face { font-family: "font"; src: url("//:"); }');d.removeChild(e);return b};c.video=function(){var a=f.createElement("video"),b=!!a.canPlayType;
if(b)b=new Boolean(b),b.ogg=a.canPlayType('video/ogg; codecs="theora"'),b.h264=a.canPlayType('video/mp4; codecs="avc1.42E01E"')||a.canPlayType('video/mp4; codecs="avc1.42E01E, mp4a.40.2"'),b.webm=a.canPlayType('video/webm; codecs="vp8, vorbis"');return b};c.audio=function(){var a=f.createElement("audio"),b=!!a.canPlayType;if(b)b=new Boolean(b),b.ogg=a.canPlayType('audio/ogg; codecs="vorbis"'),b.mp3=a.canPlayType("audio/mpeg;"),b.wav=a.canPlayType('audio/wav; codecs="1"'),b.m4a=a.canPlayType("audio/x-m4a;")||
a.canPlayType("audio/aac;");return b};c.localstorage=function(){try{return!!localStorage.getItem}catch(a){return!1}};c.sessionstorage=function(){try{return!!sessionStorage.getItem}catch(a){return!1}};c.webWorkers=function(){return!!i.Worker};c.applicationcache=function(){return!!i.applicationCache};c.svg=function(){return!!f.createElementNS&&!!f.createElementNS(w.svg,"svg").createSVGRect};c.inlinesvg=function(){var a=f.createElement("div");a.innerHTML="<svg/>";return(a.firstChild&&a.firstChild.namespaceURI)==
w.svg};c.smil=function(){return!!f.createElementNS&&/SVG/.test(r.call(f.createElementNS(w.svg,"animate")))};c.svgclippaths=function(){return!!f.createElementNS&&/SVG/.test(r.call(f.createElementNS(w.svg,"clipPath")))};for(var G in c)F(c,G)&&(z=G.toLowerCase(),j[z]=c[G](),N.push((j[z]?"":"no-")+z));j.input||K();j.crosswindowmessaging=j.postmessage;j.historymanagement=j.history;j.addTest=function(a,b){a=a.toLowerCase();if(!j[a])return b=!!b(),l.className+=" "+(b?"":"no-")+a,j[a]=b,j};h.cssText="";v=
g=null;i.attachEvent&&function(){var a=f.createElement("div");a.innerHTML="<elem></elem>";return a.childNodes.length!==1}()&&function(a,b){function d(d){for(var a=-1;++a<g;)d.createElement(f[a])}a.iepp=a.iepp||{};var e=a.iepp,c=e.html5elements||"abbr|article|aside|audio|canvas|datalist|details|figcaption|figure|footer|header|hgroup|mark|meter|nav|output|progress|section|summary|time|video",f=c.split("|"),g=f.length,h=RegExp("(^|\\s)("+c+")","gi"),j=RegExp("<(/*)("+c+")","gi"),k=/^\s*[\{\}]\s*$/,H=
RegExp("(^|[^\\n]*?\\s)("+c+")([^\\n]*)({[\\n\\w\\W]*?})","gi"),u=b.createDocumentFragment(),i=b.documentElement,c=i.firstChild,I=b.createElement("body"),L=b.createElement("style"),l=/print|all/,B;e.getCSS=function(d,a){if(d+""===m)return"";for(var b=-1,c=d.length,f,k=[];++b<c;)f=d[b],f.disabled||(a=f.media||a,l.test(a)&&k.push(e.getCSS(f.imports,a),f.cssText),a="all");return k.join("")};e.parseCSS=function(d){for(var a=[],b;(b=H.exec(d))!=null;)a.push(((k.exec(b[1])?"\n":b[1])+b[2]+b[3]).replace(h,
"$1.iepp_$2")+b[4]);return a.join("\n")};e.writeHTML=function(){var a=-1;for(B=B||b.body;++a<g;)for(var d=b.getElementsByTagName(f[a]),e=d.length,c=-1;++c<e;)d[c].className.indexOf("iepp_")<0&&(d[c].className+=" iepp_"+f[a]);u.appendChild(B);i.appendChild(I);I.className=B.className;I.id=B.id;I.innerHTML=B.innerHTML.replace(j,"<$1font")};e._beforePrint=function(){L.styleSheet.cssText=e.parseCSS(e.getCSS(b.styleSheets,"all"));e.writeHTML()};e.restoreHTML=function(){I.innerHTML="";i.removeChild(I);i.appendChild(B)};
e._afterPrint=function(){e.restoreHTML();L.styleSheet.cssText=""};d(b);d(u);if(!e.disablePP)c.insertBefore(L,c.firstChild),L.media="print",L.className="iepp-printshim",a.attachEvent("onbeforeprint",e._beforePrint),a.attachEvent("onafterprint",e._afterPrint)}(i,f);j._enableHTML5=!0;j._version="1.8pre";j.mq=E;j.isEventSupported=t;l.className=l.className.replace(/\bno-js\b/,"")+" js "+N.join(" ");return j}(this,this.document);
(function(i,f,m){function s(){var a=b;a.loader={load:J,i:0};return a}function J(a,b,c){var f=b=="c"?D:z;o=0;b=b||"j";t(a)?q(f,a,b,this.i++,v,c):(r.splice(this.i++,0,a),r.length==1&&K());return this}function q(a,e,n,i,j,l){function m(){!H&&(!k.readyState||k.readyState=="loaded"||k.readyState=="complete")&&(u.r=H=1,!o&&p(),k.onload=k.onreadystatechange=null,h(function(){c.removeChild(k)},0))}var k=f.createElement(a),H=0,u={t:n,s:e,e:l};k.src=k.data=e;!w&&(k.style.display="none");k.width=k.height="0";
a!="object"&&(k.type=n);k.onload=k.onreadystatechange=m;a=="img"?k.onerror=m:a=="script"&&(k.onerror=function(){u.e=u.r=1;K()});r.splice(i,0,u);c.insertBefore(k,w?null:g);h(function(){H||(c.removeChild(k),u.r=u.e=H=1,p())},b.errorTimeout)}function K(){var a=r.shift();o=1;a?a.t?h(function(){a.t=="c"?j(a):l(a)},0):(a(),p()):o=0}function j(a){var e=f.createElement("link"),c;e.href=a.s;e.rel="stylesheet";e.type="text/css";!a.e&&(C||x)?function O(a){h(function(){if(!c)try{a.sheet.cssRules.length?(c=1,
p()):O(a)}catch(b){b.code==1E3||b.message=="security"||b.message=="denied"?(c=1,h(function(){p()},0)):O(a)}},0)}(e):(e.onload=function(){c||(c=1,h(function(){p()},0))},a.e&&e.onload());h(function(){c||(c=1,p())},b.errorTimeout);!a.e&&g.parentNode.insertBefore(e,g)}function l(a){var c=f.createElement("script"),i;c.src=a.s;c.onreadystatechange=c.onload=function(){!i&&(!c.readyState||c.readyState=="loaded"||c.readyState=="complete")&&(i=1,p(),c.onload=c.onreadystatechange=null)};h(function(){i||(i=1,
p())},b.errorTimeout);a.e?c.onload():g.parentNode.insertBefore(c,g)}function p(){for(var a=1,b=-1;r.length-++b;)if(r[b].s&&!(a=r[b].r))break;a&&K()}var v=f.documentElement,h=i.setTimeout,g=f.getElementsByTagName("script")[0],y={}.toString,r=[],o=0,x="MozAppearance"in v.style,w=x&&!!f.createRange().compareNode,c=w?v:g.parentNode,M=i.opera&&y.call(i.opera)=="[object Opera]",C="webkitAppearance"in v.style,N=C&&"async"in f.createElement("script"),z=x?"object":M||N?"img":"script",D=C?"img":z,E=Array.isArray||
function(a){return y.call(a)=="[object Array]"},t=function(a){return typeof a=="string"},A=function(a){return y.call(a)=="[object Function]"},F=[],G={},a,b;b=function(a){function c(a,b){function d(a){if(t(a))f(a,h,b,0,e);else if(typeof a=="object")for(g in a)a.hasOwnProperty(g)&&f(a[g],h,b,g,e)}var e=!!a.test,i=a.load||a.both,h=a.callback,g;d(e?a.yep:a.nope);d(i);a.complete&&b.load(a.complete)}function f(a,b,c,d,e){var g=i(a),h=g.autoCallback;if(!g.bypass){b&&(b=A(b)?b:b[a]||b[d]||b[a.split("/").pop().split("?")[0]]);
if(g.instead)return g.instead(a,b,c,d,e);c.load(g.url,g.forceCSS||!g.forceJS&&/css$/.test(g.url)?"c":m,g.noexec);(A(b)||A(h))&&c.load(function(){s();b&&b(g.origUrl,e,d);h&&h(g.origUrl,e,d)})}}function i(a){var a=a.split("!"),b=F.length,c=a.pop(),d=a.length,c={url:c,origUrl:c,prefixes:a},f,e;for(e=0;e<d;e++)(f=G[a[e]])&&(c=f(c));for(e=0;e<b;e++)c=F[e](c);return c}var g,h,j=this.yepnope.loader;if(t(a))f(a,0,j,0);else if(E(a))for(g=0;g<a.length;g++)h=a[g],t(h)?f(h,0,j,0):E(h)?b(h):typeof h=="object"&&
c(h,j);else typeof a=="object"&&c(a,j)};b.addPrefix=function(a,b){G[a]=b};b.addFilter=function(a){F.push(a)};b.errorTimeout=1E4;f.readyState==null&&f.addEventListener&&(f.readyState="loading",f.addEventListener("DOMContentLoaded",a=function(){f.removeEventListener("DOMContentLoaded",a,0);f.readyState="complete"},0));i.yepnope=s()})(this,this.document);