$(function(){

	$('#login-background img:nth-child(n+2)').css({opacity:'0'});
		setInterval(function() {
			$('#login-background img:first-child').fadeTo('300', 0);
			$('#login-background img:nth-child(2)').fadeTo('300', 1);
			$('#login-background img:first-child').appendTo('#login-background');
		}, 4000);
	
});