package copan::Controller::common;

use warnings;
use strict;

my $IS_DEBUG = 1;

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