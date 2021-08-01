package copan::Controller::Main;
use Mojo::Base 'Mojolicious::Controller', -signatures;

sub login($self) {
	
	my $DB_CONF  = $self->app->config->{DB};
	
	&copan::Controller::common::debug($self, $DB_CONF->{DSN});
	&copan::Controller::common::debug($self, $DB_CONF->{USER});
	&copan::Controller::common::debug($self, $DB_CONF->{PASS});
	
	my $dbh = &copan::Model::db::connectDB($DB_CONF->{DSN}, $DB_CONF->{USER}, $DB_CONF->{PASS}); # DB接続
	
	&copan::Controller::common::debug($self, "login()");
	
	# パラメーターの設定
	#setStash($self, $dbh);

	&copan::Controller::common::debug($self, "error_message" . $self->param('error_message'));
	&copan::Controller::common::debug($self, "error_message" . $self->param('sessionExpired'));

	$self->stash("error_message");

	# レンダーメソッドで描画(第一引数にテキストで文字列の描画)
	$self->render('login');
	
	$dbh->disconnect; #DB切断
}

sub logout($self) {
	
	my $DB_CONF  = $self->app->config->{DB};
	
	&copan::Controller::common::debug($self, $DB_CONF->{DSN});
	&copan::Controller::common::debug($self, $DB_CONF->{USER});
	&copan::Controller::common::debug($self, $DB_CONF->{PASS});
	
	my $dbh = &copan::Model::db::connectDB($DB_CONF->{DSN}, $DB_CONF->{USER}, $DB_CONF->{PASS}); # DB接続
	
	&copan::Controller::common::debug($self, "logout()");

	# セッションの破棄
	if ($self->session('id')) {
		&copan::Controller::common::debug($self, "Discard session.");
		$self->session(expires => 1);
	}

	# レンダーメソッドで描画(第一引数にテキストで文字列の描画)
	$self->redirect_to('/?sessionExpired=1');
	
	$dbh->disconnect; #DB切断
}

sub loginCheck($self) {
	
	my $DB_CONF  = $self->app->config->{DB};
	
	&copan::Controller::common::debug($self, $DB_CONF->{DSN});
	&copan::Controller::common::debug($self, $DB_CONF->{USER});
	&copan::Controller::common::debug($self, $DB_CONF->{PASS});
	
	my $dbh = &copan::Model::db::connectDB($DB_CONF->{DSN}, $DB_CONF->{USER}, $DB_CONF->{PASS}); # DB接続
	
	my $is_success = 0;
	my $error_user_name = "";
	my $error_password = "";
	my $user_id = "";
	my $password_hash = "";
	
	# ユーザー名とパスワードを取得出来た時だけ処理
	if ($self->param('user_name') && $self->param('password')) {
		# 取得したパスワードのハッシュ化
		($user_id, $password_hash) = &copan::Model::db::fetchPasswordHash($dbh, $self, $self->param('user_name'));
		
		&copan::Controller::common::debug($self, $password_hash);
		
		#　ハッシュ化されたパスワードの取得が出来た時照合する
		if ($password_hash) {
			$is_success = &copan::Controller::common::checkPassword($self->param('password'), $password_hash);
		}
	
		if (!$is_success) {
			$self->stash(error_message => 'ユーザー名 / パスワードに誤りがあります');
		}
	
	# ユーザー名、またはパスワードが入力されていない
	} else {
		$self->stash(error_message => 'ユーザー名 / パスワードに誤りがあります');
	}
	
	if ($is_success) { # ログインに成功
		&copan::Controller::common::debug($self, "Login success");
		
		my $id = &copan::Controller::common::createSessionId();
		&copan::Controller::common::debug($self, $id);
		
		my $is_success = &copan::Model::db::saveSessionId($dbh, $self, $id, $user_id);
		
		if ($is_success) {
			$self->session(id => $id);
			$self->session(user_id => $user_id);
			$self->redirect_to('/expensesList');
		} else { # session_idの保存に失敗
			&copan::Controller::common::debug($self, "Failed to saving session id.");
			$self->stash(error_message => 'ログイン処理に失敗しました');
			$self->render('/login');
		}
	} else { # ログインに失敗
		&copan::Controller::common::debug($self, "Login failed");
		$self->render('/login');
	}
	
	$dbh->disconnect; #DB切断
}

sub expensesList($self) {
	
	my $user_id = 0;
	my $user_name = 0;
	my $group_id = 0;
	
	my $DB_CONF  = $self->app->config->{DB};
	my $dbh = &copan::Model::db::connectDB($DB_CONF->{DSN}, $DB_CONF->{USER}, $DB_CONF->{PASS}); # DB接続
	
	&copan::Controller::common::debug($self, $self->session('id'));
	
	if (!$self->session('id')) {
		$self->redirect_to('/?sessionExpired=1');
	}
	else
	{
		($user_id, $user_name, $group_id) = &copan::Model::db::fetchUserData($dbh, $self, $self->session('id'));
		$self->stash(user_name => $user_name);
	}
	
	# 表示する年月を取得
	my ($target_year, $target_month) = &getTargetYearAndMonth($self->param('target_year'), $self->param('target_month'));
	
	# 指定した年月の費目を取得(共有に計上されたものを取得する)
	my @receipt_array = &copan::Model::db::fetchCurrentMonthReceiptList($dbh, $self, $target_year, $target_month, $group_id);
	$self->stash(receipt_array => \@receipt_array);
	
	# パラメーターの設定
	setStash($self, $dbh);

	# レンダーメソッドで描画(第一引数にテキストで文字列の描画)
	$self->render('expensesList');
	
	$dbh->disconnect; #DB切断
}

sub add($self) {
	
	my $DB_CONF  = $self->app->config->{DB};
	my $dbh = &copan::Model::db::connectDB($DB_CONF->{DSN}, $DB_CONF->{USER}, $DB_CONF->{PASS}); # DB接続
	
	my $user_id = 0;
	my $user_name = 0;
	
	if (!$self->session('id')) {
		$self->redirect_to('/?sessionExpired=1');
	}
	else
	{
		($user_id, $user_name, undef) = &copan::Model::db::fetchUserData($dbh, $self, $self->session('id'));
		$self->stash(user_name => $user_name);
	}
	
	# 表示する年月を取得
	my ($target_year, $target_month) = &getTargetYearAndMonth($self->param('target_year'), $self->param('target_month'));
	
	# 削除可能な費目一覧を取得(自分が計上したものかつ今月の費目)
	my @receipt_array = &copan::Model::db::fetchEnabledDeleteReceiptList($dbh, $self, $target_year, $target_month, $user_id);
	$self->stash(receipt_array => \@receipt_array);
	
	# パラメーターの設定
	setStash($self, $dbh);
	
	# レンダーメソッドで描画(第一引数にテキストで文字列の描画)
	$self->render('add');
	
	$dbh->disconnect; #DB切断
}


sub update($self) {
	
	my $DB_CONF  = $self->app->config->{DB};
	my $dbh = &copan::Model::db::connectDB($DB_CONF->{DSN}, $DB_CONF->{USER}, $DB_CONF->{PASS}); # DB接続
	
	my $user_id = 0;
	my $user_name = 0;
	my $group_id = 0;
	
	if (!$self->session('id')) {
		$self->redirect_to('/?sessionExpired=1');
	}
	else
	{
		($user_id, $user_name, $group_id) = &copan::Model::db::fetchUserData($dbh, $self, $self->session('id'));
		$self->stash(user_name => $user_name);
	}
	
	# 費目の追加で入力された項目を取得
	my %input_data = ();
	$input_data{'purchase_date'} = $self->param('purchase_date');
	$input_data{'category'} = $self->param('category');
	$input_data{'item'} = $self->param('item');
	$input_data{'price'} = $self->param('price');
	
	# 入力内容にエラーがあるか確認
	my @error_messages = &getErrorMessage(\%input_data);
	my $error_messages_length = @error_messages;
	
	foreach my $err (@error_messages) {
		&copan::Controller::common::debug($self, $err);
	}
	
	# パラメーターの設定
	setStash($self, $dbh);
	
	if ($error_messages_length) {
		$self->flash(error_message => \@error_messages);
		$self->redirect_to('add');
	} else {
		# 入力内容を計上
		my $result = &copan::Model::db::updateReceiptList($dbh, $self, \%input_data, $user_id, $group_id);
		
		my $error_message = "";
		my $success_message = "";
		
		if (!$result) {
			$self->flash(error_message => '計上に失敗しました');
		} else {
			$self->flash(success_message => '計上が完了しました');
		}
		$self->redirect_to('expensesList');
	}
	$dbh->disconnect; #DB切断
}

sub delete($self) {
	
	if (!$self->session('id')) {
		$self->redirect_to('/?sessionExpired=1');
	}
	
	my $DB_CONF  = $self->app->config->{DB};
	my $dbh = &copan::Model::db::connectDB($DB_CONF->{DSN}, $DB_CONF->{USER}, $DB_CONF->{PASS}); # DB接続
	
	# 削除予定のidを取得
	my $delte_id = $self->param('id');
	
	if ($delte_id) {
		# 指定のidを削除
		my $result = &copan::Model::db::deleteReceiptList($delte_id, $dbh);
		
		if (!$result) {
			$self->stash(error_message => "削除に失敗しました");
		} else {
			$self->stash(success_message => "削除が完了しました");
		}
		
	} else {
		$self->stash(error_message => "選択された削除項目が存在しません");
	}
	
	# パラメーターの設定
	setStash($self, $dbh);
	
	$self->render('/add');
	
	$dbh->disconnect; #DB切断
}

sub sharedUserList($self) {
	
	my $user_id = 0;
	my $user_name = 0;
	my $group_id = 0;
	
	my $DB_CONF  = $self->app->config->{DB};
	my $dbh = &copan::Model::db::connectDB($DB_CONF->{DSN}, $DB_CONF->{USER}, $DB_CONF->{PASS}); # DB接続
	
	&copan::Controller::common::debug($self, $self->session('id'));
	
	if (!$self->session('id')) {
		$self->redirect_to('/?sessionExpired=1');
	}
	else
	{
		($user_id, $user_name, $group_id) = &copan::Model::db::fetchUserData($dbh, $self, $self->session('id'));
		$self->stash(user_name => $user_name);
	}
	
	# 自分と同じグループIDのユーザー名を配列で取得する(自分以外)
	my @group_user_name_array = &copan::Model::db::fetchGroupUserName($dbh, $self, $user_id, $group_id);
	$self->stash(group_user_name_arrayref => \@group_user_name_array);
	
	# パラメーターの設定
	setStash($self, $dbh);

	# レンダーメソッドで描画(第一引数にテキストで文字列の描画)
	$self->render('sharedUserList');
	
	$dbh->disconnect; #DB切断
}

sub getErrorMessage {
	
	my ($input_data_hashref) = @_;
	my @error_message = ();
	
	if (!$input_data_hashref->{'purchase_date'}) {
		push(@error_message, "購入日が入力されていません");
	}
	if (!$input_data_hashref->{'category'}) {
		push(@error_message, "カテゴリが選択されていません");
	}
	if (!$input_data_hashref->{'item'}) {
		push(@error_message, "品目等を入力してください");
	}
	if (!$input_data_hashref->{'price'}) {
		push(@error_message, "金額を入力してください");
	}
	
	return @error_message;
}

sub setStash {
	
	my ($self, $dbh) = @_;
	
	# 現在のルーターを格納
	my $url = $self->url_for('current');
	
	# 現在時刻の取得
	my $current_date = DateTime->now();
	
	# 表示する年月を取得
	my ($target_year, $target_month) = &getTargetYearAndMonth($self->param('target_year'), $self->param('target_month'));
	
	# 表示する年月を格納
	$self->stash(target_year => $target_year);
	$self->stash(target_month => $target_month);
	
	my %date_previous_month = &copan::Controller::date::getPreviousMonth($target_year, $target_month);
	my %date_next_month = &copan::Controller::date::getNextMonth($target_year, $target_month);
	
	# 表示する年月の出費をカテゴリ別に取得
	my %expenses_hash = &copan::Model::db::fetchAllExpenses($dbh, $self, $target_year, $target_month);
	
	$self->stash(
		current => $url,
		current_date => $current_date,
		target_year => $target_year, 					# 表示する年月を格納
		target_month => $target_month,
		previous_year => $date_previous_month{'year'},	# 表示する年月の一月前を格納
		previous_month => $date_previous_month{'month'},
		next_year => $date_next_month{'year'}, 			# 表示する年月の一月後を格納
		next_month => $date_next_month{'month'},
		expenses_hashref => \%expenses_hash,
	);
}

sub getTargetYearAndMonth {
	
	my ($target_year, $target_month) = @_;
	
	# 現在時刻の取得
	my $current_date = DateTime->now();
	
	# 表示する年月をパラメータで受け取っていなかったら現在の年月を取得する
	if (!$target_year and !$target_month) {
		$target_year = $current_date->year;
		$target_month = $current_date->month;
	}
	
	return ($target_year, $target_month);
}


1;