$(function(){
	
	$(document).on('click','.button-open-sub-item', function(){
		
		/* 支出のカテゴリをクリックしたら費目の詳細の表示 / 非表示を切り替える */
		if ($(this).children('.expense-sub-item-list').css('display') == 'none') {
			$(this).children('.expense-sub-item-list').slideDown("fast");
			$(this).find('.button-open-sub-item-icon').removeClass('fa-chevron-down');
			$(this).find('.button-open-sub-item-icon').addClass('fa-chevron-up');
		} else {
			$(this).children('.expense-sub-item-list').slideUp("fast");
			$(this).find('.button-open-sub-item-icon').removeClass('fa-chevron-up');
			$(this).find('.button-open-sub-item-icon').addClass('fa-chevron-down');
		}
		
	});
});