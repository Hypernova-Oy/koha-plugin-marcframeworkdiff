package t::Lib;

use strict;
use warnings;

use Exporter;
use HTTP::Request;
use HTTP::Response;

our $DEFAULT_PLUGIN_CLASS;
our $DEFAULT_METHOD = 'configure';
our $DEFAULT_URL_GET;
our $DEFAULT_URL;

our $LAST_HTTP_RESPONSE; # = HTTP::Response->new();

sub import {
  my @LIST = @_;
  die "importing ".__PACKAGE__." without the plugin name! Eg. use ".__PACKAGE__." qw(Koha::Plugin::Fi::Hypernova::ValueBuilder)" unless @LIST;
  $DEFAULT_PLUGIN_CLASS = $LIST[1] if @LIST;
  $DEFAULT_METHOD = $LIST[2] if @LIST > 2;
  $DEFAULT_URL_GET = "/cgi-bin/koha/plugins/run.pl?class=$DEFAULT_PLUGIN_CLASS&method=$DEFAULT_METHOD";
  $DEFAULT_URL = "/cgi-bin/koha/plugins/run.pl";
}

sub htmlContains {
  my ($regexp) = @_;
  warn "HTML Response not set!" unless $LAST_HTTP_RESPONSE;
  return $LAST_HTTP_RESPONSE->content =~ m!$regexp!gsm ? 1 : 0;
}

sub htmlStatus {
  warn "HTML Response not set!" unless $LAST_HTTP_RESPONSE;
  return $LAST_HTTP_RESPONSE->code;
}

package Koha::Plugin::Fi::Hypernova::MARCFrameworkDiff;

#Silence the HTML generation from the test case
sub output_html {
  my ( $self, $data, $status, $extra_options ) = @_;
  $t::Lib::LAST_HTTP_RESPONSE = HTTP::Response->new($status, undef, undef, $data);
  return "OK";
}

package FakeCGI;

our %DEFAULTS = (
  'QUERY_STRING' => 'class=Koha%3A%3APlugin%3A%3AFi%3A%3AHypernova%3A%3AValueBuilder&method=configure',
  'SCRIPT_NAME' => '/intranet/plugins/run.pl',
  'GATEWAY_INTERFACE' => 'CGI/1.1',
  'SERVER_SOFTWARE' => 'CGI-Emulate-PSGI',
  'HTTP_ACCEPT_LANGUAGE' => 'en-US,en;q=0.5',
  'HTTP_ACCEPT_CHARSET' => 'utf-8;q=0.7,*;q=0.7',
  'HTTP_USER_AGENT' => 'Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:136.0) Gecko/20100101 Firefox/136.0',
  'SERVER_PORT' => '80',
  'HTTP_PRAGMA' => 'no-cache',
  'HTTPS' => 'OFF',
  'SERVER_PROTOCOL' => 'HTTP/1.1',
  'REMOTE_HOST' => undef,
  'HTTP_ACCEPT_ENCODING' => 'gzip, deflate, br, zstd',
  'HTTP_REFERER' => '/cgi-bin/koha/plugins/plugins-home.pl',
  'HTTP_PRIORITY' => 'u=0, i',
  'HTTP_CACHE_CONTROL' => 'no-cache',
  'SERVER_NAME' => '127.0.0.1',
  'HTTP_SEC_FETCH_SITE' => 'same-origin',
  'REMOTE_PORT' => '0',
  'HTTP_ACCEPT' => '*/*',
  'HTTP_X_FORWARDED_HOST' => 'koha.example.com',
  'REQUEST_URI' => '/intranet/plugins/run.pl?class=Koha%3A%3APlugin%3A%3AFi%3A%3AHypernova%3A%3AValueBuilder&method=configure',
  'REMOTE_ADDR' => '127.0.0.1',
  'REQUEST_METHOD' => 'GET',
);

use base 'CGI';

sub new {
  my ($class, $httpRequest, $credentials) =  @_;

  CGI::initialize_globals(); #Reset CGI internal state, as it caches parts of the previous request.

  unless ($httpRequest) {
    $httpRequest = HTTP::Request->new(GET => $t::Lib::DEFAULT_URL_GET);
  }

  # Parse the HTTP request string
  my ($method, $path, $protocol, $headers, $body) = _parse_http_request($httpRequest);

  # Extract query string from the path
  my ($script_name, $query_string) = split(/\?/, $path, 2);

  # Populate %ENV with CGI environment variables
  $ENV{'REQUEST_METHOD'} = $method;
  $ENV{'SCRIPT_NAME'}    = $script_name;
  $ENV{'QUERY_STRING'}   = $query_string // '';
  $ENV{'SERVER_PROTOCOL'} = $protocol // 'HTTP/1.1';
  $ENV{'CONTENT_LENGTH'} = length($body // '');
  $ENV{'CONTENT_TYPE'}   = $headers->{'Content-Type'} // '';
  $ENV{'HTTP_COOKIE'}    = $headers->{'Cookie'} // '';

  # Populate HTTP headers in %ENV
  for my $header_name (keys %$headers) {
      my $env_name = 'HTTP_' . uc($header_name);
      $env_name =~ s/-/_/g; # Replace dashes with underscores
      $ENV{$env_name} = $headers->{$header_name};
  }

  #Set defaults if not set
  for my $default (sort keys %DEFAULTS) {
    $ENV{$default} = $DEFAULTS{$default} unless exists $ENV{$default};
  }

  # Simulate STDIN for POST data
  my $OLDSTDIN = *STDIN;
  if ($body) {
      open my $stdin, '<', \$body or die "Can't open in-memory file: $!";
      *STDIN = $stdin;
  }

  my $self = $class->SUPER::new();

  if ($body) {
    *STDIN = $OLDSTDIN;
  }

  # Set credentials
  if ($credentials) {
    my ($user, $password) = split(/:/, $credentials);
    $ENV{'HTTP_AUTHORIZATION'} = "Basic " . encode_base64("$user:$password");
  }

  return bless($self, $class);
}

sub _parse_http_request {
  my ($httpRequest) = @_;

  my ($headers, $body) = split(/\n\n/, $httpRequest->as_string(), 2);
  chomp($body);
  my @lines = split(/\n/, $headers);

  # Parse the request line
  my ($method, $path, $protocol) = split(' ', shift @lines);

  # Parse headers
  my %headers;
  for my $line (@lines) {
    my ($key, $value) = split(/:\s*/, $line, 2);
    $headers{$key} = $value;
  }

  return ($method, $path, $protocol, \%headers, $body);
}

sub redirect {
  my ($self, @args) = @_;
  my $redirect = $self->SUPER::redirect(@args);
  $t::Lib::LAST_HTTP_RESPONSE = HTTP::Response->new(302, '', $redirect);
  return $redirect;
}

1;
