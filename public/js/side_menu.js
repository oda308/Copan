$(document).ready(function(){
    // Requires jQuery

	$(document).on('click','.overlay',function(e){
		console.log("overlay clicked");
		
		$('.js-menu_toggle').removeClass('opened').addClass('closed');
		$('.side-menu').css({ 'right':'-250px' });
		// スクロール禁止解除
		$("body").css('overflow','auto');
		
		setTimeout(function() {
			// サイドメニュー、オーバーレイの非表示
			$(".side-menu").css('display','none');
			$('.overlay').css('display', 'none');
		}, 300);
	});
		
	$(document).on('click','.js-menu_toggle.closed',function(e){
		
		console.log("menu-button clicked");
		
		// スクロール禁止
		$("body").css('overflow','hidden');
		// サイドメニュー、オーバーレイの表示
		$(".side-menu").css('display','block');
		$('.overlay').css('display', 'block');
		
		setTimeout(function() {
			$(this).removeClass('closed').addClass('opened');
			$('.side-menu').css({ 'right':'0px' })
		}, 5);
	});
});