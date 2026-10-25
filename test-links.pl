# Tests link parsing in ProtocolHandler.pm without running LMS: the LMS modules are
# replaced by stubs. Needs HTTP::Request, URI and URI::Escape, e.g. from the CPAN
# directory of an LMS installation:
#   mkdir -p /tmp/dltest/Plugins && cp -r DeezerLinks /tmp/dltest/Plugins/
#   S=/usr/local/slimserver   # or /usr/share/squeezeboxserver, etc.
#   perl -I/tmp/dltest -I$S/CPAN -I$S/CPAN/arch/<perl version>/<arch> test-links.pl
use strict;
use warnings;

# stubs for the LMS modules ProtocolHandler.pm uses
BEGIN {
	$INC{$_} = 1 for qw(Slim/Player/Protocols/HTTPS.pm Slim/Networking/Async/HTTP.pm Slim/Utils/Log.pm);
	package Slim::Player::Protocols::HTTPS; our $stub = 1;
	package Slim::Utils::Log;
	sub import { no strict 'refs'; *{caller() . '::logger'} = sub { bless {}, 'StubLog' } }
	package StubLog;
	sub AUTOLOAD { 1 }
	package main;
	use constant { INFOLOG => 0, DEBUGLOG => 0 };
}

require Plugins::DeezerLinks::ProtocolHandler;

my @cases = (
	# shape of the Location returned by link.deezer.com/s/<code> (Oct 2026), host= removed
	[ 'https://link.deezer.com/?awf=https%3A%2F%2Fwww.deezer.com%2Ftrack%2F3025645421%3Futm_campaign%3Dclipboard-generic&dest=https%3A%2F%2Fwww.deezer.com%2Ftrack%2F3025645421%3Futm_source%3Duser_sharing', 'track 3025645421' ],
	[ 'https://link.deezer.com/s/AbCdEfGhIjKlMnOpQrStU', '' ],
	[ 'https://www.deezer.com/tr/album/533378332?utm_source=x', 'album 533378332' ],
	[ 'https://www.deezer.com/en-gb/playlist/1234567890', 'playlist 1234567890' ],
	[ 'https://deezer.com/artist/860', 'artist 860' ],
	[ 'https://www.deezer.com/soon', '' ],
);

my $fail = 0;
for (@cases) {
	my ($in, $want) = @$_;
	my $got = join ' ', Plugins::DeezerLinks::ProtocolHandler::_findItem($in);
	my $ok = $got eq $want;
	$fail++ unless $ok;
	printf "%s %-40s %s\n", $ok ? 'ok  ' : 'FAIL', "[$got]", substr($in, 0, 60);
}

# which URLs the handler claims (must not overlap the Deezer plugin's own regex)
my $deezer = qr{^https://(?:\w+\.)?deezer.com/(track|playlist|album|artist|podcast)/([a-z\d-]+)}i;
my @claimed;
{
	no warnings 'redefine';
	package Slim::Player::ProtocolHandlers;
	sub registerURLHandler { push @claimed, $_[1] }
}
Plugins::DeezerLinks::ProtocolHandler->register;
for my $u ('https://link.deezer.com/s/AbCdEfGhIjKlMnOpQrStU', 'https://www.deezer.com/tr/track/3025645421',
           'https://www.deezer.com/track/3025645421', 'https://deezer.page.link/abc') {
	my $ours = grep { $u =~ $_ } @claimed;
	my $theirs = $u =~ $deezer ? 1 : 0;
	printf "%-48s ours=%d deezer=%d%s\n", $u, $ours, $theirs, ($ours && $theirs) ? '  OVERLAP' : '';
	$fail++ if $ours && $theirs;
}

print $fail ? "FAILED: $fail\n" : "all ok\n";
exit($fail ? 1 : 0);
