jQuery(document).ready(function() {
	var $ = jQuery;
		
	$.fn.stopwatch = function(type) {
		var clock = $(this);
		var timer = 0;
		
		if(type == 'reset'){
			
			clearInterval(timer);
			clock.find('.hr').html(00);
			clock.find('.min').html(00);
			clock.find('.sec').html(00);
			
		}
		else{
		
			var h = clock.find('.hr');
			var m = clock.find('.min');
			var s = clock.find('.sec');

			function do_time() {
				hour = parseFloat(h.text());
				minute = parseFloat(m.text());
				second = parseFloat(s.text());

				second++;

				if(second > 59) {
					second = 0;
					minute = minute + 1;
				}
				if(minute > 59) {
					minute = 0;
					hour = hour + 1;
				}

				h.html("0".substring(hour >= 10) + hour);
				m.html("0".substring(minute >= 10) + minute);
				s.html("0".substring(second >= 10) + second);

			}
			
			timer = setInterval(do_time, 1000);
		}
	};
});




