package copan;
use Mojo::Base 'Mojolicious', -signatures;
use Mojo::Base 'Mojolicious::Controller';
use DateTime;
use DBI;
use lib qw(lib);
use copan::Model::db;
use copan::Controller::date;
use copan::Controller::common;
use Path::Class;

my $IS_DEBUG = 1; 

# This method will run once at server start
sub startup {
	my $self = shift;

	# configを読み込む
	$self->_load_config();

	# Router
	my $r = $self->routes;

	# コントローラーmainのログインサブルーチンを呼び出す
	$r->get('/')->to('Main#login');
	
	$r->post('/')->to('Main#loginCheck');
	
	$r->get('/callbackMobile')->to('Main#callbackMobile');
	
	$r->get('/logout')->to('Main#logout');
	
	$r->get('/expensesList')->to('Main#expensesList');
	
	$r->get('/add')->to('Main#add');
	
	$r->get('/update')->to('Main#update');
	
	$r->get('/delete')->to('Main#delete');
	
	$r->get('/sharedUserList')->to('Main#sharedUserList');
}

sub _load_config {
	my $self = shift;
	
	my $suffix = $self->mode eq 'production' ? '_product' : '';

	my $file_name = 'etc/db' . $suffix . '.conf';

	# Mojolicious::Plugin::Configを使ってconfigを読み込んでいる場所
	$self->plugin( 'Config', { 'file' => $file_name } );
}
1;
