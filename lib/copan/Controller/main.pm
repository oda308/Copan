package copan::Controller::Main;
use Mojo::Base 'Mojolicious::Controller', -signatures;

sub login($self) {
	
	my $DB_CONF  = $self->app->config->{DB};
	
	&copan::Controller::common::debug($self, $DB_CONF->{DSN});
	&copan::Controller::common::debug($self, $DB_CONF->{USER});
	&copan::Controller::common::debug($self, $DB_CONF->{PASS});
	
	my $dbh = &copan::Model::db::connectDB($DB_CONF->{DSN}, $DB_CONF->{USER}, $DB_CONF->{PASS}); # DB接続
	
	# 品目一覧を取得
	my @receipt_array = &copan::Model::db::fetchReceiptList($dbh);
	$self->stash(receipt_array => \@receipt_array);
	# パラメーターの設定
	
	setStash($self, $dbh);

	# レンダーメソッドで描画(第一引数にテキストで文字列の描画)
	$self->render('login');
	
	$dbh->disconnect; #DB切断
}

sub expensesList($self) {
	
	my $DB_CONF  = $self->app->config->{DB};
	
	&copan::Controller::common::debug($self, $DB_CONF->{DSN});
	&copan::Controller::common::debug($self, $DB_CONF->{USER});
	&copan::Controller::common::debug($self, $DB_CONF->{PASS});
	
	my $dbh = &copan::Model::db::connectDB($DB_CONF->{DSN}, $DB_CONF->{USER}, $DB_CONF->{PASS}); # DB接続
	
	# 品目一覧を取得
	my @receipt_array = &copan::Model::db::fetchReceiptList($dbh);
	$self->stash(receipt_array => \@receipt_array);
	# パラメーターの設定
	
	setStash($self, $dbh);

	# レンダーメソッドで描画(第一引数にテキストで文字列の描画)
	$self->render('expenses_list');
	
	$dbh->disconnect; #DB切断
}

sub add($self) {
	
	my $DB_CONF  = $self->app->config->{DB};
	my $dbh = &copan::Model::db::connectDB($DB_CONF->{DSN}, $DB_CONF->{USER}, $DB_CONF->{PASS}); # DB接続
	
	# 品目一覧を取得
	my @receipt_array = &copan::Model::db::fetchTodayReceiptList($dbh, $self);
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
		&common::debug($self, $err);
	}
	
	# 品目一覧を取得
	my @receipt_array = &copan::Model::db::fetchReceiptList($dbh);
	$self->stash(receipt_array => \@receipt_array);
	# パラメーターの設定
	setStash($self, $dbh);
	
	if ($error_messages_length) {
		$self->stash(error_message => \@error_messages);
		$self->render('/add');
	} else {
		# 入力内容を計上
		my $result = &copan::Model::db::updateReceiptList(\%input_data, $dbh);
		
		if (!$result) {
			$self->stash(error_message => "計上に失敗しました");
		} else {
			$self->stash(success_message => "計上が完了しました");
		}
		
		$self->render('index');
	}
	$dbh->disconnect; #DB切断
}

sub delete($self) {
	
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
	
	# 品目一覧を取得
	my @receipt_array = &copan::Model::db::fetchTodayReceiptList($dbh);
	$self->stash(receipt_array => \@receipt_array);
	# パラメーターの設定
	setStash($self, $dbh);
	
	$self->render('/add');
	
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
	
	# 現在時刻の取得
	my $current_date = DateTime->now();
	
	# 現在のルーターを格納
	my $url = $self->url_for('current');
	
	# 現在の年月を指定
	my $target_year = $self->param('target_year');
	my $target_month = $self->param('target_month');
	
	# 表示する年月をGETで受け取っていたら指定
	if (!$target_year and !$target_month) {
		$target_year = $current_date->year;
		$target_month = $current_date->month;
	}
	
	# 表示する年月を格納
	$self->stash(target_year => $target_year);
	$self->stash(target_month => $target_month);
	
	my %date_previous_month = &copan::Controller::date::getPreviousMonth($target_year, $target_month);
	my %date_next_month = &copan::Controller::date::getNextMonth($target_year, $target_month);
	
	# 表示する年月の出費をカテゴリ別に取得
	my %expenses_hash = &copan::Model::db::fetchAllExpenses($dbh, $self);
	
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


1;