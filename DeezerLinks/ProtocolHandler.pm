package Plugins::DeezerLinks::ProtocolHandler;

# Turns a link shared from the Deezer app into deezer:// items of the Deezer plugin.
#
# The app shares https://link.deezer.com/s/<code>. Its first redirect carries the
# real URL in the "dest" parameter (https://www.deezer.com/track/<id>?...); following
# the chain to the end is pointless, where Deezer is not open it ends at www.deezer.com/soon.
#
# Tracks become deezer://<id>.<format> directly: Plugins::Deezer::ProtocolHandler's
# explodePlaylist has no branch for tracks. Albums, playlists and artists are expanded
# by the Deezer plugin itself.

use strict;
use base qw(Slim::Player::Protocols::HTTPS);

use HTTP::Request;
use URI;
use URI::Escape qw(uri_unescape);

use Slim::Networking::Async::HTTP;
use Slim::Player::Protocols::HTTPS;
use Slim::Utils::Log;

my $log = logger('plugin.deezerlinks');

# what the app shares
my $SHORT_REGEX  = qr{^https?://(?:link\.deezer\.com|deezer\.page\.link)/}i;
# www.deezer.com/tr/track/123 - without the language segment the Deezer plugin takes it
my $LOCALE_REGEX = qr{^https?://(?:www\.)?deezer\.com/[a-z]{2}(?:-[a-z]{2})?/(?:track|album|playlist|artist)/\d+}i;
# the item anywhere in a URL, after unescaping
my $ITEM_REGEX   = qr{deezer\.com/(?:[a-z]{2}(?:-[a-z]{2})?/)?(track|album|playlist|artist)/(\d+)}i;

use constant MAX_HOPS => 3;
use constant TIMEOUT  => 15;

sub register {
	Slim::Player::ProtocolHandlers->registerURLHandler($SHORT_REGEX, __PACKAGE__);
	Slim::Player::ProtocolHandlers->registerURLHandler($LOCALE_REGEX, __PACKAGE__);
}

sub explodePlaylist {
	my ( $class, $client, $url, $cb ) = @_;

	if ( !Plugins::Deezer::ProtocolHandler->can('explodePlaylist') ) {
		$log->error("Deezer plugin is not loaded, can't play $url");
		return $cb->([]);
	}

	_resolve($url, MAX_HOPS, sub {
		my ($type, $id) = @_;

		if (!$id) {
			$log->error("No Deezer item found for $url");
			return $cb->([]);
		}

		main::INFOLOG && $log->is_info && $log->info("$url -> $type $id");

		if ($type eq 'track') {
			return $cb->([ "deezer://$id." . Plugins::Deezer::API::getFormat() ]);
		}

		Plugins::Deezer::ProtocolHandler->explodePlaylist($client, "deezer://$type:$id", sub {
			my $tracks = shift;

			$tracks = [ map { $_->{play} || $_->{url} } @{$tracks->{items} || []} ] if ref $tracks eq 'HASH';

			# getPlaylist puts a sort order menu item (a code ref) before the tracks
			$tracks = [ grep { defined $_ && !ref $_ && m{^deezer://} } @{$tracks || []} ];

			main::INFOLOG && $log->is_info && $log->info("$type $id: " . scalar @$tracks . " tracks");
			$cb->($tracks);
		});
	});
}

sub _findItem {
	my $str = uri_unescape(shift // '');
	my ($type, $id) = $str =~ $ITEM_REGEX;
	return $id ? (lc $type, $id) : ();
}

sub _resolve {
	my ($url, $hops, $cb) = @_;

	if ( my ($type, $id) = _findItem($url) ) {
		return $cb->($type, $id);
	}

	return $cb->() if $hops <= 0 || $url !~ $SHORT_REGEX;

	main::DEBUGLOG && $log->is_debug && $log->debug("Resolving $url");

	# maxRedirect 0: the redirect comes back as an error, with the response kept
	Slim::Networking::Async::HTTP->new->send_request({
		request     => HTTP::Request->new( GET => $url ),
		maxRedirect => 0,
		Timeout     => TIMEOUT,
		onError     => sub {
			my ($http, $error) = @_;

			my $location = $http->response && $http->response->header('Location');

			if ($location) {
				return _resolve(URI->new_abs($location, $url)->as_string, $hops - 1, $cb);
			}

			$log->error("Can't resolve $url: $error");
			$cb->();
		},
		onBody      => sub {
			my $http = shift;

			# no redirect: the page may still name the item
			my ($ogUrl) = $http->response->content =~ m{<meta[^>]+property=["']og:url["'][^>]+content=["']([^"']+)}i;
			$cb->( _findItem($ogUrl) );
		},
	});
}

1;
