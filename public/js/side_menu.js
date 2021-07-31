$(document).ready(function(){
    // Requires jQuery

$(document).on('click','.overray',function(e){
	console.log("overray clicked");
	
	e.preventDefault(); $('.list_load, .list_item').stop();
	$('.js-menu_toggle').removeClass('opened').addClass('closed');

	$('.side_menu').css({ 'right':'-250px' });

	var count = $('.list_item').length;
	$('.list_item').css({
		'opacity':'0',
		'margin-left':'-20px'
	});
	$('.list_load').slideUp(300);
	
	
	// スクロール禁止解除
	$("body").css('overflow','auto');
	
	setTimeout(function() {
		// サイドメニュー、オーバーレイの非表示
		$(".side_menu").css('display','none');
		$('.overray').css('display', 'none');
	}, 300);
});
	
$(document).on('click','.js-menu_toggle.closed',function(e){
	e.preventDefault(); $('.list_load, .list_item').stop();
	
	console.log("menu-button clicked");
	
	// スクロール禁止
	$("body").css('overflow','hidden');
	// サイドメニュー、オーバーレイの表示
	$(".side_menu").css('display','block');
	$('.overray').css('display', 'block');
	
	setTimeout(function() {
		$(this).removeClass('closed').addClass('opened');
		
		$('.side_menu').css({ 'right':'0px' });
		
		var count = $('.list_item').length;
		$('.list_load').slideDown( (count*.6)*100 );
		$('.list_item').each(function(i){
			var thisLI = $(this);
			timeOut = 100*i;
			setTimeout(function(){
				thisLI.css({
					'opacity':'1',
					'margin-left':'0'
				});
			},100*i);
		}, 5);
	});
});

});