package copan::Controller::Main;
use Mojo::Base 'Mojolicious::Controller', -signatures;

sub login($self) {
	
	my $DB_CONF  = $self->app->config->{DB};
	
	&copan::Controller::common::debug($self, $DB_CONF->{DSN});
	&copan::Controller::common::debug($self, $DB_CONF->{USER});
	&copan::Controller::common::debug($self, $DB_CONF->{PASS});
	
	my $dbh = &copan::Model::db::connectDB($DB_CONF->{DSN}, $DB_CONF->{USER}, $DB_CONF->{PASS}); # DB接続
	
	&copan::Controller::common::debug($self, "login()");
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
	my $my_user_id = "";
	my $password_hash = "";
	
	# ユーザー名とパスワードを取得出来た時だけ処理
	if ($self->param('user_name') && $self->param('password')) {
		# 取得したパスワードのハッシュ化
		($my_user_id, $password_hash) = &copan::Model::db::fetchPasswordHash($dbh, $self, $self->param('user_name'));
		
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
		
		my $is_success = &copan::Model::db::saveSessionId($dbh, $self, $id, $my_user_id);
		
		if ($is_success) {
			$self->session(id => $id);
			$self->session(user_id => $my_user_id);
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
	
	my $my_user_id = 0;
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
		($my_user_id, $user_name, $group_id) = &copan::Model::db::fetchUserData($dbh, $self, $self->session('id'));
		$self->stash(user_name => $user_name);
	}
	
	&copan::Controller::common::debug($self, "current group id : " . $group_id);
	
	# 表示する年月を取得
	my ($target_year, $target_month) = &getTargetYearAndMonth($self->param('target_year'), $self->param('target_month'));
	
	# 指定した年月の費目を取得(共有に計上されたものを取得する)
	my @receipt_array = &copan::Model::db::fetchCurrentMonthReceiptList($dbh, $self, $target_year, $target_month, $group_id);
	$self->stash(receipt_array => \@receipt_array);
	
	&copan::Controller::common::debug($self, "Current month receipt");
	
	my $pay_everyone_total = 0;
	
	# グループ全員分のオブジェクトを作成
	my @all_member_payment_array = ();
	# ユーザーid->ユーザー名のハッシュを取得
	my $group_member_hashref = &copan::Model::db::fetchGroupUserIdAndName($dbh, $self, $my_user_id, $group_id);
	# グループに存在するユーザー数を取得
	my $group_member_count = keys(%{$group_member_hashref});
	
	&copan::Controller::common::debug($self, "check receipt");
	
	foreach my $receipt (@receipt_array)	# 今月分の領収書を1つずつ仕分け
	{
		&copan::Controller::common::debug($self, %{$receipt});
		&copan::Controller::common::debug($self, 'price : ' . $receipt->{'price'});
		&copan::Controller::common::debug($self, 'user_id : ' . $receipt->{'user_id'});
		&copan::Controller::common::debug($self, 'group_id : ' . $receipt->{'group_id'});
		&copan::Controller::common::debug($self, 'payer_id : ' . $receipt->{'payer_id'});
		
		# みんなが払うを指定している場合は、全員に配分
		# 1.支払いを行った人にマイナス計上
		# 2.支払いを行わなかった人に計上
		if ($receipt->{'payer_id'} == 0) {
			
			# 領収書の金額 / グループ人数で余りの金額が発生した場合、それぞれの負担金を1円ずつ増やす形で多めに徴収する
			# 多めに徴収した端数は立替えを行った人が受け取り、立替えをした人が得をするように計算する
			if (($receipt->{'price'} % $group_member_count) > 0) {
				
				my $fraction += $group_member_count - ($receipt->{'price'} % $group_member_count);
				$receipt->{'price'} += $fraction;
			}
			
			my $each_burden = int($receipt->{'price'} / $group_member_count); # グループに所属する人数で割った金額を算出
			
			&copan::Controller::common::debug($self, 'each_burden : ' . $each_burden);
			
			foreach my $user_id (keys(%{$group_member_hashref})) {
				# 支払いを行った本人の場合は、計上した金額 - (一人分の負担金)の分マイナスする
				if ($user_id == $receipt->{'user_id'}) {
					
					$group_member_hashref->{$user_id}->{'burden'} -= $receipt->{'price'} - $each_burden;
					
				# それ以外は一人分の負担金を加算する
				} else {
					$group_member_hashref->{$user_id}->{'burden'} += $each_burden;
				}
			}
			
		# 各々が自分が計上して自分が支払うものは何もしない
		} elsif ($receipt->{'payer_id'} == $receipt->{'user_id'}) {
			
			# Do Nothing
			
		# 計上した人と、支払いを行う人が違う場合は、支払いを指定された人が全額負担し、立て替えた人に全額返す
		} elsif ($receipt->{'payer_id'} != $receipt->{'user_id'}) {
			
			$group_member_hashref->{$receipt->{'user_id'}}->{'burden'} -= $receipt->{'price'}; # 立て替えた人から全額差し引く
			$group_member_hashref->{$receipt->{'payer_id'}}->{'burden'} += $receipt->{'price'}; # 支払いを指定された人が全額負担
		}
	}
	
	foreach my $user_id (keys(%{$group_member_hashref})) {
		&copan::Controller::common::debug($self, 'user_id' . $user_id . ' burden : ' . $group_member_hashref->{$user_id}->{'burden'});
	}
	
	# 自身の立替金の計算結果をスタッシュに保存
	$self->stash(my_burden => $group_member_hashref->{$my_user_id}->{'burden'});
	
	# パラメーターの設定
	setStash($self, $dbh, $group_id);

	# レンダーメソッドで描画(第一引数にテキストで文字列の描画)
	$self->render('expensesList');
	
	$dbh->disconnect; #DB切断
}

sub add($self) {
	
	my $DB_CONF  = $self->app->config->{DB};
	my $dbh = &copan::Model::db::connectDB($DB_CONF->{DSN}, $DB_CONF->{USER}, $DB_CONF->{PASS}); # DB接続
	
	my $my_user_id = 0;
	my $user_name = 0;
	my $group_id = 0;
	
	if (!$self->session('id')) {
		$self->redirect_to('/?sessionExpired=1');
	}
	else
	{
		($my_user_id, $user_name, $group_id) = &copan::Model::db::fetchUserData($dbh, $self, $self->session('id'));
		$self->stash(user_name => $user_name);
	}
	
	# 払う人を決めるのユーザー名一覧を取得する
	my @group_user_name_array = &copan::Model::db::fetchGroupUserName($dbh, $self, $my_user_id, $group_id);
	$self->stash(payer_arrayref => \@group_user_name_array);
	
	# 表示する年月を取得
	my ($target_year, $target_month) = &getTargetYearAndMonth($self->param('target_year'), $self->param('target_month'));
	
	# 削除可能な費目一覧を取得(自分が計上したものかつ今月の費目)
	my @receipt_array = &copan::Model::db::fetchEnabledDeleteReceiptList($dbh, $self, $target_year, $target_month, $my_user_id);
	$self->stash(receipt_array => \@receipt_array);
	
	# パラメーターの設定
	setStash($self, $dbh, $group_id);
	
	# レンダーメソッドで描画(第一引数にテキストで文字列の描画)
	$self->render('add');
	
	$dbh->disconnect; #DB切断
}


sub update($self) {
	
	my $DB_CONF  = $self->app->config->{DB};
	my $dbh = &copan::Model::db::connectDB($DB_CONF->{DSN}, $DB_CONF->{USER}, $DB_CONF->{PASS}); # DB接続
	
	my $my_user_id = 0;
	my $user_name = 0;
	my $group_id = 0;
	
	if (!$self->session('id')) {
		$self->redirect_to('/?sessionExpired=1');
	}
	else
	{
		($my_user_id, $user_name, $group_id) = &copan::Model::db::fetchUserData($dbh, $self, $self->session('id'));
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
	setStash($self, $dbh, $group_id);
	
	if ($error_messages_length) {
		$self->flash(error_message => \@error_messages);
		$self->redirect_to('add');
	} else {
		my $payer_id = 0; 
		# 払う人を指定していた場合はそのuser_idを取得する。みんなで払う、無効値の場合はみんなで払うとして処理される
		if ($self->param('payer')) {
			$payer_id = &copan::Model::db::fetchPayerId($dbh, $self, $group_id, $self->param('payer'));
		}
		
		# 入力内容を計上
		my $result = &copan::Model::db::updateReceiptList($dbh, $self, \%input_data, $my_user_id, $group_id, $payer_id);
		
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
	
	my $DB_CONF  = $self->app->config->{DB};
	my $dbh = &copan::Model::db::connectDB($DB_CONF->{DSN}, $DB_CONF->{USER}, $DB_CONF->{PASS}); # DB接続
	
	my $my_user_id = 0;
	my $user_name = 0;
	my $group_id = 0;
	
	if (!$self->session('id')) {
		$self->redirect_to('/?sessionExpired=1');
	}
	else
	{
		($my_user_id, $user_name, $group_id) = &copan::Model::db::fetchUserData($dbh, $self, $self->session('id'));
		$self->stash(user_name => $user_name);
	}
	
	# 削除予定のidを取得
	my $delte_id = $self->param('id');
	
	if ($delte_id) {
		# 指定のidを削除
		my $result = &copan::Model::db::deleteReceiptList($delte_id, $dbh);
		
		if (!$result) {
			$self->flash(error_message => "削除に失敗しました");
		} else {
			$self->flash(success_message => "削除が完了しました");
		}
		
	} else {
		$self->flash(error_message => "選択された削除項目が存在しません");
	}
	
	# 払う人を決めるユーザー名一覧を取得する
	my @group_user_name_array = &copan::Model::db::fetchGroupUserName($dbh, $self, $my_user_id, $group_id);
	$self->stash(payer_arrayref => \@group_user_name_array);
	
	# 表示する年月を取得
	my ($target_year, $target_month) = &getTargetYearAndMonth($self->param('target_year'), $self->param('target_month'));
	
	# 削除可能な費目一覧を取得(自分が計上したものかつ今月の費目)
	my @receipt_array = &copan::Model::db::fetchEnabledDeleteReceiptList($dbh, $self, $target_year, $target_month, $my_user_id);
	$self->stash(receipt_array => \@receipt_array);
	
	# パラメーターの設定
	setStash($self, $dbh, $group_id);
	
	$self->redirect_to('/add');
	
	$dbh->disconnect; #DB切断
}

sub sharedUserList($self) {
	
	my $my_user_id = 0;
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
		($my_user_id, $user_name, $group_id) = &copan::Model::db::fetchUserData($dbh, $self, $self->session('id'));
		$self->stash(user_name => $user_name);
	}
	
	# 自分と同じグループIDのユーザー名を配列で取得する(自分以外)
	my @group_user_name_array = &copan::Model::db::fetchGroupUserNameExceptMyself($dbh, $self, $my_user_id, $group_id);
	$self->stash(group_user_name_arrayref => \@group_user_name_array);
	
	# パラメーターの設定
	setStash($self, $dbh, $group_id);

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
	
	my ($self, $dbh, $group_id) = @_;
	
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
	my %expenses_hash = &copan::Model::db::fetchAllExpenses($dbh, $self, $target_year, $target_month, $group_id);
	
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