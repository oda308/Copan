package copan::Controller::date;

use Mojo::Base -base;

## -------------------------------------------------------------------
## 一月後のyyyyとmmを取得
## -------------------------------------------------------------------
sub getNextMonth {
	
	my ($current_year, $current_month) = @_;
	
	my %date_next_month = ();
	
	$date_next_month{'year'} = $current_year;
	$date_next_month{'month'} = $current_month;
	
	if ($current_month == 12) {
		$date_next_month{'year'}++;
		$date_next_month{'month'} = 1;
	} else {
		$date_next_month{'month'}++;
	}
	
	return %date_next_month;
}

## -------------------------------------------------------------------
## 一月前のyyyyとmmを取得
## -------------------------------------------------------------------
sub getPreviousMonth {
	
	my ($current_year, $current_month) = @_;
	
	my %date_previous_month = ();
	
	$date_previous_month{'year'} = $current_year;
	$date_previous_month{'month'} = $current_month;
	
	if ($current_month == 1) {
		$date_previous_month{'year'}--;
		$date_previous_month{'month'} = 12;
	} else {
		$date_previous_month{'month'}--;
	}
	
	return %date_previous_month;
}

## -------------------------------------------------------------------
## 日付文字列yyyymmddをmmddに変換する
## -------------------------------------------------------------------
sub convertDateToMMDD {
	
	my ($date) = @_;
	
	if (!$date) {
		return '';
	}
	
	my @yyyymmdd = split(/-/, $date);
	
	my $month = sprintf("%02d", $yyyymmdd[1]);
	my $day = sprintf("%02d", $yyyymmdd[2]);
	
	return $month . '/' . $day;
}

## -------------------------------------------------------------------
## うるう年ならtrue、そうでなければfalseを返す
## -------------------------------------------------------------------
sub isLeapYear {
	
	my($year) = @_;
	
	if ($year % 100) {		# 西暦年号が 100 で割り切れない
		if ($year % 4) {	# 西暦年号が 4 で割り切れない
			return 0;	# 平年
		} else {
			return 1;	# うるう年
		}
	} else {					# 西暦年号が 100 で割り切れる
		if ($year % 400) {	# 西暦年号が 400 で割り切れない
			return 0;	# 平年
		} else {				# 西暦年号が 400 で割り切れる
			if ($year % 4000) {	# 西暦年号が 4000 で割り切れない
				return 1;	# うるう年
			} else {			# 西暦年号が 4000 で割り切れる
				return 0;	#平年
			}
		}
	}
}

## -------------------------------------------------------------------
## その月の日数を返す
## -------------------------------------------------------------------
sub getDaysOfMonth {
	
	my($year, $month) = @_;
	
	my @LeapYear = (0, 31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31);
	my @NormYear = (0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31);
	
	return isLeapYear($year) ? $LeapYear[$month] : $NormYear[$month];
}
1;