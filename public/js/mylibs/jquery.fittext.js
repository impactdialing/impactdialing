/*global jQuery */
/*!	
* FitText.js 1.0
*
* Copyright 2011, Dave Rupert http://daverupert.com
* Released under the WTFPL license 
* http://sam.zoy.org/wtfpl/
*
* Date: Thu May 05 14:23:00 2011 -0600
*/
(function(a){a.fn.fitText=function(e){return this.each(function(){var c=a(this),b=origFontSize=c.css("font-size"),f=e||1,d=function(a){b=a.width()/(f*10);b=b>=origFontSize?origFontSize:b;a.css("font-size",b)};d(c);a(window).resize(function(){d(c)})})}})(jQuery);