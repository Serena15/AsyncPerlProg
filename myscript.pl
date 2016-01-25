use strict;
use warnings;
use AnyEvent;
use AnyEvent::HTTP;
use DDP;
use 5.18.2;

$AnyEvent::HTTP::MAX_PER_HOST = 100;
my $cv = AnyEvent->condvar;
my $url = "http://www.math.msu.su/";
my $host = 'www.math.msu.su';
my %links = ();
my $summ = 0;
my $size_hash = 1;
my $max_size = 0;

	#$cv->begin;
	http_get $url, sub {
	my ($body, $hr) = @_;
	my $size_page = length $body;
	$max_size = $size_page;
	my %htmlhash = ();
	$summ += $size_page;	
	$links{$url} = $size_page;
	$body =~s/\n//g;
	while( $body =~/<a.*?href\s*=\s*['"](http:\/\/$host.+?)['"]/g )
	{
		$htmlhash{$1}=1;
	}
	warn $size_page;
	foreach my $j (keys(%htmlhash)) {
		if (defined $links{$j}) {
			my $num = delete $htmlhash{$j};				 
			unless ($num) {
				print "Error delete hash!\n";
				return;
			}
		}
	}
	async(%htmlhash);
	say "# referenses $size_hash"; 
	#$cv->end;
	return;	
	};



sub async {
	my %htmlhash = @_;
	my $count = 0;
	$cv->begin;
	foreach my $i (keys(%htmlhash)) {
		$cv->begin;
		#print "New event: GET => $i\n";
		http_get $i, sub {
			my ($page_body, $header) = @_;
			my $size_page_this = length $page_body;
			$max_size = $size_page_this if $max_size < $size_page_this;
			my %htmlhash1 = ();
			$summ += $size_page_this;	
			if (!(defined $links{$i})) {
				$links{$i} = $size_page_this;
				$page_body =~s/\n//g;
				while( $page_body =~/<a.*?href\s*=\s*['"](http:\/\/$host.+?)['"]/g )
				{
					$htmlhash1{$1}=1;
				}
				foreach my $j (keys(%htmlhash1)) {
					if (defined $links{$j}) {
						my $num = delete $htmlhash1{$j};				 
						unless ($num) {
							print "Error delete hash!\n";
							return;
						}
					}
				}
				warn $size_page_this;			
				my $size_hash1 = $size_hash + 1;
				say "##### referenses $size_hash"; 
				if ($size_hash1 < 10000) {
					$size_hash = $size_hash1;
					async(%htmlhash1);
				}
				else {
					say "STOP";
					$cv->end;
					return;
				}				
			}
			#print "Content of $i: $size_page_this\n";
            		$count++;
			#say $count;
			# если количество успешных запросов равно размеру списка URLов, отправляем данные, на уровень выше.
            		if ($count == scalar keys(%htmlhash)) {
				          say "WOHOOOOOO";
				          $cv->end;
			          }
	 	};
		$cv->end;
	};
}

$cv->recv;
say "Нашли такие уникальные ссылки: ";
#my $c = 0;
for my $key (sort { $links{$a} <=> $links{$b} } keys %links) { };
for my $value (values %links) {	
	if ($c <= 10){
		print" URL: $links{$value} size: $value \n";
	}
	else {
		last;
	}	
  $c++;
}
say "Maxsize $max_size";
say "Всего найдено ссылок: $size_hash";
say "Суммарный размер всех страниц $summ";
