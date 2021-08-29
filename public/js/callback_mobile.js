$(function () { 
	
	const user_agent = navigator.userAgent;
	const params = (new URL(document.location)).searchParams;
	const id = params.get('id');
	
	if ((user_agent.indexOf('WebView') != -1) && (user_agent.indexOf('Copan-Android') != -1)) {
		console.log("Androidアプリ呼び出し");
		appJsInterface.startCopan(id);
	}
	else if ((user_agent.indexOf('WebView') != -1) && (user_agent.indexOf('Copan-iOS') != -1)) {
		console.log("iOSアプリ呼び出し");
		appJsInterface.startCopan(id);
	}
})