package copan::Controller::common;

use Mojo::Base -base;
use Mojo::Headers;
use Crypt::Eksblowfish::Bcrypt;
use Digest::SHA;
use Data::UUID;

my $IS_DEBUG = 1;


## -------------------------------------------------------------------
## 文字列をハッシュ化する
## -------------------------------------------------------------------
sub createHashedString {
	
	my ($password) = @_;
	
	# bcrypt_hashのソルト作成
	
	# ランダム + 時刻 + プロセスIDをSHA256にして先頭16桁を取る
	my $salt = substr(Digest::SHA::sha256(rand(1000000000) . time . $$), 0, 16);
	
	my $round = 8;
	
	# bcryptでハッシュ化されたパスワードを生成
	my $digest = Crypt::Eksblowfish::Bcrypt::bcrypt_hash({
		key_nul => 1,
		cost => $round,
		salt => $salt,
	}, $password);
	
	my $password_hash = sprintf(
		"\$2a\$%02d\$%s%s",
		$round,
		Crypt::Eksblowfish::Bcrypt::en_base64($salt),
		Crypt::Eksblowfish::Bcrypt::en_base64($digest)
	);
	
	return $password_hash;
}

## -------------------------------------------------------------------
## パスワードを照合する。成功したら1、失敗したら0を返す
## -------------------------------------------------------------------
sub checkPassword {
	
	my ($password, $password_hash) = @_;
	
	my $password_hash_ret = Crypt::Eksblowfish::Bcrypt::bcrypt($password, $password_hash);
	
	my $is_success = 0;
	if ($password_hash eq $password_hash_ret) {
		$is_success = 1;
	}
	
	return $is_success;
}

## -------------------------------------------------------------------
## セッションIDを生成する
## -------------------------------------------------------------------
sub createSessionId {
	
	my $ug = Data::UUID->new;
	my $uuid = $ug->create_str();
	
	return createHashedString($uuid);
}

## -------------------------------------------------------------------
## ユーザーエージェントを見て、モバイルアプリからのアクセスなら1, それ以外は0を返す
## -------------------------------------------------------------------
sub isMobileAccess {
	
	my ($self) = @_;
	my $user_agent = $self->req->headers->user_agent;
	my $is_mobile_access = 0;
	
	&copan::Controller::common::debug($self, "user_agent : " . $user_agent);
	
	if (($user_agent =~ /WebView Copan-Android/) || ($user_agent =~ /WebView Copan-iOS/)) {
		&copan::Controller::common::debug($self, "Access from mobile");
		$is_mobile_access = 1;
	}
	else
	{
		&copan::Controller::common::debug($self, "Access from browser");
	}
	
	return $is_mobile_access;
}

## -------------------------------------------------------------------
## デバッグ
## -------------------------------------------------------------------
sub debug {
	
	my ($obj, $debug_str) = @_;
	
	if ( $IS_DEBUG )
	{
		$obj->app->log->debug("$debug_str");
	}
}
1;