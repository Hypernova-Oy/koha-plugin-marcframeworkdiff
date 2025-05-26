package Koha::Plugin::Fi::Hypernova::MARCFrameworkDiff::Options;

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
use strict;
use warnings;

use YAML::XS;
$YAML::XS::LoadBlessed = 1;

##
## CONSTRUCTORS, SETTERS and GETTERS
##
my @multi_values = ('attributesExclude', 'attributesInclude', 'frameworksExclude', 'frameworksInclude');

sub new {
  my ($class, $options) = @_;
  $options = {} unless $options;
  my %self = %$options;
  my $self = bless(\%self, $class);

  if (defined($self->{fields}) && ref($self->{fields}) ne 'ARRAY') {
    $self->fields($self->{fields});
  }
  if (defined($self->{subfields}) && ref($self->{subfields}) ne 'ARRAY') {
    $self->subfields($self->{subfields});
  }
  for my $multi_value (@multi_values) {
    if ($self->{$multi_value}) {
      $self->$multi_value($self->{$multi_value});
    }
  }

  return $self;
}

sub newFromCGI {
  my ($class, $cgi) = @_;
  my %multi_values = map {
    if ($cgi->multi_param('mfwd_'.$_)) {
      my @multi_value = $cgi->multi_param('mfwd_'.$_);
      $_ => \@multi_value;
    }
    else {
      $_ => undef;
    }
  } @multi_values;
  return $class->new({
    fields => scalar $cgi->param('mfwd_fields'),
    subfields => scalar $cgi->param('mfwd_subfields'),
    attribute => scalar $cgi->param('mfwd_attribute'),
    value => scalar $cgi->param('mfwd_value'),
    verbose => scalar $cgi->param('mfwd_verbose'),
    perlyFalse => scalar $cgi->param('mfwd_perlyFalse'),
    ignoreUndef => scalar $cgi->param('mfwd_ignoreUndef'),
    %multi_values,
  });
}

sub fields {
  my ($self, $val) = @_;
  if (defined($val)) {
    my @fs = split(",", $val);
    $self->{fields} = \@fs;
    return $self;
  }
  return $self->{'fields'};
}

sub subfields {
  my ($self, $val) = @_;
  if (defined($val)) {
    if ($val eq '') {
      $self->{subfields} = undef;
      return $self;
    }
    my @fs = split(",", $val);
    $self->{subfields} = \@fs;
    return $self;
  }
  return $self->{'subfields'};
}

sub attribute {
  my ($self, $val) = @_;
  if ($val) {
    $self->{'attribute'} = $val;
    return $self;
  }
  return $self->{'attribute'};
}

sub value {
  my ($self, $val) = @_;
  if ($val) {
    $self->{'value'} = $val;
    return $self;
  }
  return $self->{'value'};
}

sub verbose {
  my ($self, $val) = @_;
  if ($val) {
    $self->{'verbose'} = $val;
    return $self;
  }
  return $self->{'verbose'} || 0;
}

sub perlyFalse {
  my ($self, $val) = @_;
  if ($val) {
    $self->{'perlyFalse'} = $val;
    return $self;
  }
  return $self->{'perlyFalse'} || 0;
}

sub ignoreUndef {
  my ($self, $val) = @_;
  if ($val) {
    $self->{'ignoreUndef'} = $val;
    return $self;
  }
  return $self->{'ignoreUndef'} || 0;
}

sub frameworksExclude {
  my ($self, $val) = @_;
  if ($val) {
    $self->{'frameworksExclude'} = $self->_multivalueToHash($val);
    return $self;
  }
  return $self->{'frameworksExclude'};
}

sub frameworksInclude {
  my ($self, $val) = @_;
  if ($val) {
    $self->{'frameworksInclude'} = $self->_multivalueToHash($val);
    return $self;
  }
  return $self->{'frameworksInclude'};
}

sub attributesExclude {
  my ($self, $val) = @_;
  if ($val) {
    $self->{'attributesExclude'} = $self->_multivalueToHash($val, 'disallowEmpty');
    return $self;
  }
  return $self->{'attributesExclude'};
}

sub attributesInclude {
  my ($self, $val) = @_;
  if ($val) {
    $self->{'attributesInclude'} = $self->_multivalueToHash($val, 'disallowEmpty');
    return $self;
  }
  return $self->{'attributesInclude'};
}

sub _multivalueToHash {
  my ($self, $val, $disallowEmpty) = @_;
  if ($val) {
    my $hash;
    if (ref($val) eq 'ARRAY') {
      $hash = { map { $_ => 1 } grep {$disallowEmpty && $_ eq '' ? 0 : 1 } @$val };
    }
    elsif (ref($val) eq 'HASH') {
      $hash = $val;
    }
    else {
      my @fs = split(",", $val);
      $hash = $self->_multivalueToHash(\@fs);
    }
    return undef unless ($hash && %$hash);
    return $hash;
  }
  return undef;
}

sub store {
  my ($self, $plugin) = @_;

  $plugin->store_data({'options' => $self->serialize()});

  return $self;
}
sub Retrieve {
  my ($class, $plugin) = @_;

  my $serialized = $plugin->retrieve_data('options');
  return $class->new() unless $serialized;
  return $class->Deserialize($serialized);
}

sub serialize {
  my ($self) = @_;
  return YAML::XS::Dump($self);
}
sub Deserialize {
  my ($class, $yamlString) = @_;
  return YAML::XS::Load($yamlString);
}

##
## METHODS
##

sub anyAttributeDefined {
  my ($self) = @_;
  return $self->{fields} || $self->{subfields} || $self->{attribute} || $self->{value} || $self->{verbose} || $self->{perlyFalse} || $self->{ignoreUndef} || $self->{frameworksInclude};
}

sub frameworkcodes_include_exclude {
  my ($self, $frameworkCodes) = @_;
  my $frameworksInclude = $self->frameworksInclude();
  my $frameworksExclude = $self->frameworksExclude();

  if ($frameworksInclude) {
    $frameworkCodes = [ grep { $frameworksInclude->{$_} } @$frameworkCodes ];
  }
  if ($frameworksExclude) {
    $frameworkCodes = [ grep { !$frameworksExclude->{$_} } @$frameworkCodes ];
  }
  return $frameworkCodes;
}

sub attribute_include_exclude {
  my ($self, $attribute) = @_;
  my $attributesInclude = $self->attributesInclude();
  my $attributesExclude = $self->attributesExclude();

  if ($attributesInclude) {
    if ($attributesInclude->{$attribute}) {
      return 1;
    }
    return 0;
  }
  if ($attributesExclude) {
    if ($attributesExclude->{$attribute}) {
      return 0;
    }
    return 1;
  }
  return 1;
}

1;
