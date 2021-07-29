package copan::Model::db;

use strict;
use warnings;
use DBI;
use experimental qw(signatures);
use Mojo::Util qw(secure_compare);
use copan::Controller::date;
use copan::Controller::common;

## -------------------------------------------------------------------
## DBに接続する
## -------------------------------------------------------------------
sub connectDB {

	my ($dsn, $user, $pass) = @_;
	
	my $dbh = DBI->connect(
		$dsn,
		$user,
		$pass,
		{
			mysql_enable_utf8mb4 => 1
		}
		) or die "cannot connect to MySQL: $DBI::errstr";
		
	return $dbh;
}

## -------------------------------------------------------------------
## 費目の追加から領収書を追加する
## -------------------------------------------------------------------
sub updateReceiptList {
	
	my ($input_data_ref, $dbh) = @_;
	
	my $sql = qq{INSERT INTO receipt_list ( };
	$sql .= qq{purchase_date, };
	$sql .= qq{category, };
	$sql .= qq{item, };
	$sql .= qq{price };
	$sql .= qq{) VALUES ( };
	$sql .= qq{\"$input_data_ref->{'purchase_date'}\", };
	$sql .= qq{\"$input_data_ref->{'category'}\", };
	$sql .= qq{\"$input_data_ref->{'item'}\", };
	$sql .= qq{\"$input_data_ref->{'price'}\" };
	$sql .= qq{) };
	
	my $sth = $dbh->prepare($sql) or die $dbh->errstr;
	my $rv = $sth->execute();
	
	return $rv;
}

## -------------------------------------------------------------------
## 追加した費目を削除する
## -------------------------------------------------------------------
sub deleteReceiptList {
	
	my ($delete_id, $dbh) = @_;
	
	my $sql = qq{DELETE FROM receipt_list };
	$sql .= qq{WHERE id = $delete_id };
	
	my $sth = $dbh->prepare($sql) or die $dbh->errstr;
	my $rv = $sth->execute();
	
	return $rv;
}

## -------------------------------------------------------------------
## 過去計上した領収書全てを取得する
## -------------------------------------------------------------------
sub fetchReceiptList {
	
	my ($dbh, $mode) = @_;
	
	my $sql = qq{SELECT * FROM receipt_list };
	
	my $sth = $dbh->prepare($sql);
	$sth->execute();
	
	my @receipt_array = ();
	
	while (my $hash_ref = $sth->fetchrow_hashref) {
		
		# 購入日をMM/DD形式に書き換え
		$hash_ref->{'purchase_date'} = &copan::Controller::date::convertDateToMMDD($hash_ref->{'purchase_date'});
		
		push(@receipt_array, $hash_ref);
	}
	$sth->finish;
	
	return @receipt_array;
}

## -------------------------------------------------------------------
## 今日計上した領収書を取得する
## -------------------------------------------------------------------
sub fetchTodayReceiptList {
	
	my ($dbh, $self) = @_;
	
	my $current_date = DateTime->now();
	
	my $start_date = $current_date->year . '-' . sprintf("%02d", $current_date->month) . '-' . sprintf("%02d", $current_date->day) . ' 00:00:00';
	my $end_date = $current_date->year . '-' . sprintf("%02d", $current_date->month) . '-' . sprintf("%02d", $current_date->day + 1) . ' 00:00:00';
	
	my $sql = qq{SELECT * FROM receipt_list };
	$sql .= qq{WHERE time_stamp >= \'$start_date\' };
	$sql .= qq{AND time_stamp < \'$end_date\' };
	
	my $sth = $dbh->prepare($sql);
	$sth->execute();
	
	my @receipt_array = ();
	
	while (my $hash_ref = $sth->fetchrow_hashref) {
		
		# 購入日をMM/DD形式に書き換え
		$hash_ref->{'purchase_date'} = &copan::Controller::date::convertDateToMMDD($hash_ref->{'purchase_date'});
		
		push(@receipt_array, $hash_ref);
	}
	$sth->finish;
	
	return @receipt_array;
}

## -------------------------------------------------------------------
## 各カテゴリごとの合計金額をハッシュで取得する
## -------------------------------------------------------------------
sub fetchAllExpenses {
	
	my ($dbh, $self) = @_;
	
	my %expenses_hash = ();
	
	$expenses_hash{'total_expenses'} = fetchTotalExpenses($dbh, $self);
	$expenses_hash{'food'} = fetchFood($dbh, $self);
	$expenses_hash{'daily_necessities'} = fetchDailyNecessities($dbh, $self);
	$expenses_hash{'electricity'} = fetchElectricity($dbh, $self);
	$expenses_hash{'gas'} = fetchGas($dbh, $self);
	$expenses_hash{'water_supply'} = fetchWaterSupply($dbh, $self);
	$expenses_hash{'others'} = fetchOthers($dbh, $self);
	
	&copan::Controller::common::debug($self, "total_expenses : " . $expenses_hash{'total_expenses'});
	&copan::Controller::common::debug($self, "food : " . $expenses_hash{'food'});
	&copan::Controller::common::debug($self, "daily_necessities : " . $expenses_hash{'daily_necessities'});
	&copan::Controller::common::debug($self, "electricity : " . $expenses_hash{'electricity'});
	&copan::Controller::common::debug($self, "gas : " . $expenses_hash{'gas'});
	&copan::Controller::common::debug($self, "water_supply : " . $expenses_hash{'water_supply'});
	&copan::Controller::common::debug($self, "others : " . $expenses_hash{'others'});
	
	return %expenses_hash;
}

## -------------------------------------------------------------------
## 今月の総計を取得する
## -------------------------------------------------------------------
sub fetchTotalExpenses {
	
	my ($dbh, $self) = @_;
	
	my $current_date = DateTime->now();
	
	my $start_date = $current_date->year . '-' . sprintf("%02d", $current_date->month) . '-' . '01' . ' 00:00:00';
	my $end_date = $current_date->year . '-' . sprintf("%02d", $current_date->month) . '-' . sprintf("%02d", &copan::Controller::date::getDaysOfMonth($current_date->month, $current_date->month)) . ' 23:59:59';
	
	my $sql = qq{SELECT price FROM receipt_list };
	$sql .= qq{WHERE time_stamp >= \'$start_date\' };
	$sql .= qq{AND time_stamp <= \'$end_date\' };
	
	my $sth = $dbh->prepare($sql);
	$sth->execute();
	
	my $total_expense = 0;
	
	while (my ($price) = $sth->fetchrow_array) {
		# 総計を取得
		$total_expense += $price;
	}
	$sth->finish;
	
	return $total_expense;
}

## -------------------------------------------------------------------
## 今月の食費を取得する
## -------------------------------------------------------------------
sub fetchFood {
	
	my ($dbh, $self) = @_;
	
	my $current_date = DateTime->now();
	
	my $start_date = $current_date->year . '-' . sprintf("%02d", $current_date->month) . '-' . '01' . ' 00:00:00';
	
	my $end_date = $current_date->year . '-' . sprintf("%02d", $current_date->month) . '-' . sprintf("%02d", &copan::Controller::date::getDaysOfMonth($current_date->month, $current_date->month)) . ' 23:59:59';
	my $sql = qq{SELECT price FROM receipt_list };
	$sql .= qq{WHERE time_stamp >= \'$start_date\' };
	$sql .= qq{AND time_stamp <= \'$end_date\' };
	$sql .= qq{AND category = \'食費\' };
	
	my $sth = $dbh->prepare($sql);
	$sth->execute();
	
	my $food = 0;
	
	while (my ($price) = $sth->fetchrow_array) {
		# 食費を取得
		$food += $price;
	}
	$sth->finish;
	
	return $food;
}

## -------------------------------------------------------------------
## 今月の日用品を取得する
## -------------------------------------------------------------------
sub fetchDailyNecessities {
	
	my ($dbh, $self) = @_;
	
	my $current_date = DateTime->now();
	
	my $start_date = $current_date->year . '-' . sprintf("%02d", $current_date->month) . '-' . '01' . ' 00:00:00';
	my $end_date = $current_date->year . '-' . sprintf("%02d", $current_date->month) . '-' . sprintf("%02d", &copan::Controller::date::getDaysOfMonth($current_date->month, $current_date->month)) . ' 23:59:59';
	
	my $sql = qq{SELECT price FROM receipt_list };
	$sql .= qq{WHERE time_stamp >= \'$start_date\' };
	$sql .= qq{AND time_stamp <= \'$end_date\' };
	$sql .= qq{AND category = \'日用品\' };
	
	my $sth = $dbh->prepare($sql);
	$sth->execute();
	
	my $dairy_necessities = 0;
	
	while (my ($price) = $sth->fetchrow_array) {
		# 日用品を取得
		$dairy_necessities += $price;
	}
	$sth->finish;
	
	return $dairy_necessities;
}

## -------------------------------------------------------------------
## 今月の電気代を取得する
## -------------------------------------------------------------------
sub fetchElectricity {
	
	my ($dbh, $self) = @_;
	
	my $current_date = DateTime->now();
	
	my $start_date = $current_date->year . '-' . sprintf("%02d", $current_date->month) . '-' . '01' . ' 00:00:00';
	my $end_date = $current_date->year . '-' . sprintf("%02d", $current_date->month) . '-' . sprintf("%02d", &copan::Controller::date::getDaysOfMonth($current_date->month, $current_date->month)) . ' 23:59:59';
	
	my $sql = qq{SELECT price FROM receipt_list };
	$sql .= qq{WHERE time_stamp >= \'$start_date\' };
	$sql .= qq{AND time_stamp <= \'$end_date\' };
	$sql .= qq{AND category = \'電気代\' };
	
	my $sth = $dbh->prepare($sql);
	$sth->execute();
	
	my $electricity = 0;
	
	while (my ($price) = $sth->fetchrow_array) {
		# 電気代を取得
		$electricity += $price;
	}
	$sth->finish;
	
	return $electricity;
}

## -------------------------------------------------------------------
## 今月のガス代を取得する
## -------------------------------------------------------------------
sub fetchGas {
	
	my ($dbh, $self) = @_;
	
	my $current_date = DateTime->now();
	
	my $start_date = $current_date->year . '-' . sprintf("%02d", $current_date->month) . '-' . '01' . ' 00:00:00';
	my $end_date = $current_date->year . '-' . sprintf("%02d", $current_date->month) . '-' . sprintf("%02d", &copan::Controller::date::getDaysOfMonth($current_date->month, $current_date->month)) . ' 23:59:59';
	
	my $sql = qq{SELECT price FROM receipt_list };
	$sql .= qq{WHERE time_stamp >= \'$start_date\' };
	$sql .= qq{AND time_stamp <= \'$end_date\' };
	$sql .= qq{AND category = \'ガス代\' };
	
	my $sth = $dbh->prepare($sql);
	$sth->execute();
	
	my $gas = 0;
	
	while (my ($price) = $sth->fetchrow_array) {
		# ガス代を取得
		$gas += $price;
	}
	$sth->finish;
	
	return $gas;
}

## -------------------------------------------------------------------
## 今月の水道代を取得する
## -------------------------------------------------------------------
sub fetchWaterSupply {
	
	my ($dbh, $self) = @_;
	
	my $current_date = DateTime->now();
	
	my $start_date = $current_date->year . '-' . sprintf("%02d", $current_date->month) . '-' . '01' . ' 00:00:00';
	my $end_date = $current_date->year . '-' . sprintf("%02d", $current_date->month) . '-' . sprintf("%02d", &copan::Controller::date::getDaysOfMonth($current_date->month, $current_date->month)) . ' 23:59:59';
	
	my $sql = qq{SELECT price FROM receipt_list };
	$sql .= qq{WHERE time_stamp >= \'$start_date\' };
	$sql .= qq{AND time_stamp <= \'$end_date\' };
	$sql .= qq{AND category = \'水道代\' };
	
	my $sth = $dbh->prepare($sql);
	$sth->execute();
	
	my $water_supply = 0;
	
	while (my ($price) = $sth->fetchrow_array) {
		# 水道代を取得
		$water_supply += $price;
	}
	$sth->finish;
	
	return $water_supply;
}

## -------------------------------------------------------------------
## 今月のその他の費目を取得する
## -------------------------------------------------------------------
sub fetchOthers {
	
	my ($dbh, $self) = @_;
	
	my $current_date = DateTime->now();
	
	my $start_date = $current_date->year . '-' . sprintf("%02d", $current_date->month) . '-' . '01' . ' 00:00:00';
	my $end_date = $current_date->year . '-' . sprintf("%02d", $current_date->month) . '-' . sprintf("%02d", &copan::Controller::date::getDaysOfMonth($current_date->month, $current_date->month)) . ' 23:59:59';

	my $sql = qq{SELECT price FROM receipt_list };
	$sql .= qq{WHERE time_stamp >= \'$start_date\' };
	$sql .= qq{AND time_stamp <= \'$end_date\' };
	$sql .= qq{AND category = \'その他\' };
	
	my $sth = $dbh->prepare($sql);
	$sth->execute();
	
	my $others = 0;
	
	while (my ($price) = $sth->fetchrow_array) {
		# 水道代を取得
		$others += $price;
	}
	$sth->finish;
	
	return $others;
}

## -------------------------------------------------------------------
## ユーザー名からハッシュ化されたパスワードを取得する
## -------------------------------------------------------------------
sub fetchPasswordHash {
	
	my ($dbh, $self, $user_name) = @_;
	
	if (!$user_name) {
		return;
	}
	
	my $password = "";
	
	my $sql = qq{SELECT password FROM user };
	$sql .= qq{WHERE user_name = "$user_name" };
	
	&copan::Controller::common::debug($self, $sql);
	
	my $sth = $dbh->prepare($sql);
	$sth->execute();
	
	&copan::Controller::common::debug($self, $sth->rows);
	
	if ($sth->rows) {
		($password) = $sth->fetchrow_array;
	}
	
	$sth->finish;
	
	return $password;
}
1;