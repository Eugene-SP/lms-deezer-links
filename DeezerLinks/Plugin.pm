package Plugins::DeezerLinks::Plugin;

# Registers a URL handler for links that the Deezer plugin does not recognise:
# short share links and www.deezer.com URLs with a language segment.
# The handler only rewrites them; tracks are played by Plugins::Deezer.

use strict;
use base qw(Slim::Plugin::Base);

use Slim::Utils::Log;

use Plugins::DeezerLinks::ProtocolHandler;

my $log = Slim::Utils::Log->addLogCategory({
	'category'     => 'plugin.deezerlinks',
	'defaultLevel' => 'INFO',
	'description'  => 'PLUGIN_DEEZERLINKS_NAME',
});

sub initPlugin {
	my $class = shift;

	$class->SUPER::initPlugin(@_);

	Plugins::DeezerLinks::ProtocolHandler->register;
}

1;
