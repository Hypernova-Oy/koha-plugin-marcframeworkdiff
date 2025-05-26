package Koha::Plugin::Fi::Hypernova::MARCFrameworkDiff;

# Copyright 2025 Hypernova Oy
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# This program comes with ABSOLUTELY NO WARRANTY;

use Modern::Perl;

use base qw(Koha::Plugins::Base);

use Cwd;
use Mojo::JSON qw(decode_json);
use YAML;
use Try::Tiny;

use Koha::Plugin::Fi::Hypernova::MARCFrameworkDiff::Configure;
use Koha::Plugin::Fi::Hypernova::MARCFrameworkDiff::Installer;

our $VERSION = '0.0.1'; #PLACEHOLDER
our $DATE_UPDATED = '2025-05-26'; #PLACEHOLDER

our $metadata = {
  name            => 'MARCFrameworkDiff',
  author          => 'Olli-Antti Kivilahti',
  date_authored   => '2025-05-26',
  date_updated    => $DATE_UPDATED,
  minimum_version => '24.11.01.000',
  maximum_version => undef,
  version         => $VERSION,
  description     => 'Diff and update MARC frameworks.',
};

sub new {
  my ( $class, $args ) = @_;

  ## We need to add our metadata here so our base class can access it
  $args->{'metadata'} = $metadata;
  $args->{'metadata'}->{'class'} = $class;

  ## Here, we call the 'new' method for our base class
  ## This runs some additional magic and checking
  ## and returns our actual $self
  my $self = $class->SUPER::new($args);
  $self->{cgi} = CGI->new() unless $self->{cgi};

  return $self;
}

sub configure { return Koha::Plugin::Fi::Hypernova::MARCFrameworkDiff::Configure::configure(@_); }
sub install { return Koha::Plugin::Fi::Hypernova::MARCFrameworkDiff::Installer::install(@_); }
sub uninstall { return Koha::Plugin::Fi::Hypernova::MARCFrameworkDiff::Installer::uninstall(@_); }
1;
