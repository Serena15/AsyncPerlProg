use warnings;
use strict;
use DDP;
use JSON;
use utf8;
use open ':std', ':encoding(UTF-8)';

my $data = do { # Чтение из файла
    open my $f,'<:raw',$ARGV[0] or die "open `$ARGV[0]' failed: $!";
    local $/; <$f>
};

my $data_test = $data;

my $number = "-?(0\\.\\d+([eE][+-]?\\d*)|[1-9][0-9]*|[1-9]+\\.\\d+([eE][+-]?\\d+))";
my $str = "(\"([\\w\\d\\s]|\\\"|\\\\|\\\/|(\\\\[bfnrt])|(\\\\u[0-9]{4}))*\")";
my $reg_obj = "\{\\s*(".$str."\\s*:\\s*((".$number.")|false|true|null|".$str.")\\s*,\\s*)*".$str."\\s*:\\s*((".$number.")|false|true|null|".$str.")\\s*\}";
my $array = "\\[\\s*(\\s*((".$number.")|false|true|null|(".$str."))\\s*,)*\\s*((".$number.")|false|true|null|".$str."|(\\s*))\\s*\\]";

sub function_test_valid {
	my $valid_test = @_;
	while ($valid_test =~ s/{\s*$number\s*,/{/ || $valid_test =~ s/{\s* $str \s*,/{/ || $valid_test =~ s/{\s* $reg_obj \s*,/{/ || $valid_test =~ s/{\s* $array \s*,/{/ || $valid_test =~ s/{\s*$number\s*,/{/ || $valid_test =~ s/{\s* $str \s*,/{/ || $valid_test =~ s/{\s* $reg_obj \s*,/{/ || $valid_test =~ s/{\s* $array \s*,/{/) {
		
	}
	if ($valid_test =~ s/$reg_obj//) {
		# body...
	} else
	{
		$valid_test =~ s/$array//;
	}
	return $valid_test;
}

sub keyToHash {
	my ($one_arg, $two_arg) = @_;
	if (ref($one_arg) eq "HASH") {
	my %hash = %{$one_arg};
	my %my_strings = %{$two_arg};
	while(my ($key,$value) = each %hash){
			while ($value =~ s/\s+//) {
					# body...
			}
			if (exists($my_strings{$value})) {
				$hash{$key}    = $my_strings{$value};
				my $temp = keyToHash($hash{$key}, $two_arg);
				if ($temp != 0) {
					$hash{$key} = $temp;
				}
			}
		}
		return \%hash;
	} else
	{
		return 0;
	}	
}

sub my_decode_json {

	my $data = shift;
	my $temp_data = $data;
	$temp_data = function_test_valid($temp_data);
	if (! ($temp_data =~ m/\s*/)) {
		print "data invalid\n";
		return;
	}
	while ($data =~ s/\\u([a-f\d]{4})/chr(hex($1))/e) {
		# body...
	}
	while ( $data =~ m/\G(.)/sgc ) {
		$data =~ s{(?<!\\)"(\w+)(?<!\\)"\s*:}{$1 =>}; #'"keyNumber" : str/num/obj/arr' convert 'keyNumber => str/num/obj/arr'   
	}
	pos($data) 	   = 0;
	my $count_keys = 0;
	my %strings;
	while ( $data =~ m/\G(.)/sgc ) {	
		if ( $data =~ s{"((\\.|[^\\"])*?)"}{key$count_keys}s ) {
			%strings = ( %strings, "key$count_keys" => $1 );
			$count_keys++;			
		}
	}
	pos($data) = 0;
	while ( $data =~ m/\G(.)/sgc ) {	
		if ( $data =~ s{(\-\s*\d+\.{0,1}\d*)}{key$count_keys}s ) {
			%strings = ( %strings, "key$count_keys" => $1 );
			$count_keys++;
		}		
	}
	pos($data) = 0;
	while ( $data =~ m/\G(.)/sgc ) {		
		if ( $data =~ s{(\d+\.{1}\d*)}{key$count_keys}s ) {
			%strings = ( %strings, "key$count_keys" => $1 );
			$count_keys++;
		}
	}
	pos($data) = 0;
	while ( $data =~ m/[\[\{]/ ) {
		while ( $data =~ m/\G(.)/sgc ) {	
			if ( $data =~ s{\[([(\-\s*\d+\.{0,1}\d*),\$\s]*?)\]}{key$count_keys}s ) {
				my @array_numbers = split(/,/,$1);
				for my $j (0..$#array_numbers){
					$array_numbers[$j] += 0;
				}
				%strings = ( %strings, "key$count_keys" => \@array_numbers );
				$count_keys++;
			}		
		}
		pos($data) = 0;
		while ( $data =~ m/\G(.)/sgc ) {	
			if (  $data =~ s{\[([\w\(\),\$\s]*?)\]}{key$count_keys}s ) {
				my @array = split(/,/,$1);
				for my $j (0..$#array){
					my $key_for_hash = $array[$j];
					while ($key_for_hash =~ s/\s+//) {
						# body...
					}
					if (ref($strings{$key_for_hash}) eq 'HASH' and exists($strings{$key_for_hash})) {
						$array[$j] = $strings{$key_for_hash};
						my %hash_array = %{$array[$j]};
						my $temp = keyToHash(\%hash_array, \%strings);
						if ($temp != 0) {
							$array[$j] = $temp;
						}
					}
				}
				%strings = ( %strings, "key$count_keys" => \@array );
				$count_keys++;
			}
   		}	
		pos($data) = 0;
		while ( $data =~ m/\G(.)/sgc ) {		
			if ( $data =~ s{\{([\w\(\),\$=>\s]*?)\}}{key$count_keys}s ) {
				my $hash = $1;
				my @n 	 = $hash =~ m/(\w+)\s*=>\s*(\w+),*/sg;
				my %hash = @n;
				my $temp = '111111111111';
				#p $temp;
				#p @n;
				%strings = ( %strings, "key$count_keys" => \%hash );
				$count_keys++;
			}			
		}
		pos($data) = 0;		
	}
	$count_keys--;	
		for my $j (0..$count_keys) {
			if ( ref($strings{"key$j"}) eq "HASH" ) {
				my %my_hash;
				my $xs = 0;
				my ($key, $value);
				while ( ($key, $value) = each $strings{"key$j"} ) { 
					$value   = $strings{$value} if defined $strings{$value};
					%my_hash = ( %my_hash, $key, $value); 
				}
				$strings{"key$j"} = \%my_hash;
			}
			if ( ref($strings{"key$j"}) eq "ARRAY" ) {
				my @my_array;
				my $xs = 0;
				while ( $my_array[$xs] = $strings{"key$j"}->[$xs] ) { $xs++; }
				pop @my_array;
				for my $sx (0..$#my_array) {
					$my_array[$sx] = $strings{$my_array[$sx]} if defined $strings{$my_array[$sx]};
				}
				$strings{"key$j"} = \@my_array;
			}
		}
	$data = $strings{"key$count_keys"}; 
}

my $my_struct 		= my_decode_json($data);
my $correct_struct  = decode_json($data_test);
print "My struct: \n";
p $my_struct;
print "Correct struct: \n";
p $correct_struct;
