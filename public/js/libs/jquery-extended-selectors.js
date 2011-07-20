/*
 * jQuery Extended Selectors - (c) Keith Clark freely distributable under the terms of the MIT license.
 * 
 * twitter.com/keithclarkcouk
 * www.keithclark.co.uk
 */
(function(g){function e(a,c){for(var b=a,d=0;a=a[c];)b.tagName==a.tagName&&d++;return d}function h(a,c,b){a=e(a,b);if(c=="odd"||c=="even")b=2,a-=c!="odd";else{var d=c.indexOf("n");d>-1?(b=parseInt(c,10),a-=(parseInt(c.substring(d+1),10)||0)-1):(b=a+1,a-=parseInt(c,10)-1)}return(b<0?a<=0:a>=0)&&a%b==0}var f={"first-of-type":function(a){return e(a,"previousSibling")==0},"last-of-type":function(a){return e(a,"nextSibling")==0},"only-of-type":function(a){return f["first-of-type"](a)&&f["last-of-type"](a)},
"nth-of-type":function(a,c,b){return h(a,b[3],"previousSibling")},"nth-last-of-type":function(a,c,b){return h(a,b[3],"nextSibling")}};g.extend(g.expr[":"],f)})(jQuery);