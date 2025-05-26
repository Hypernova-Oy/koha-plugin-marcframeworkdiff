package Koha::Plugin::Fi::Hypernova::MARCFrameworkDiff::Update;

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

sub new {
  my ($class) = @_;
  my $self = bless({}, $class);
  return $self;
}

sub sql {
  my ($self, $val) = @_;
  if ($val) {
    $self->{'sql'} = $val;
    return $self;
  }
  return $self->{'sql'} || 0;
}

sub rows_affected {
  my ($self, $val) = @_;
  if ($val) {
    $self->{'rows_affected'} = $val;
    return $self;
  }
  return $self->{'rows_affected'} || 0;
}

sub errors {
  my ($self, $val) = @_;
  if ($val) {
    $self->{'errors'} = $val;
    return $self;
  }
  return $self->{'errors'} || 0;
}

sub optionsUsed {
  my ($self, $val) = @_;
  if ($val) {
    $self->{'optionsUsed'} = $val;
    return $self;
  }
  return $self->{'optionsUsed'} || 0;
}

sub serialize {
  my ($self) = @_;
  return YAML::XS::Dump($self);
}
sub Deserialize {
  my ($class, $yamlString) = @_;
  return YAML::XS::Load($yamlString);
}

sub update {
  my ($self, $options, $diff) = @_;

  my (@errors);
  eval {
    $self->optionsUsed($options);
    push(@errors, "missing the 'attribute'") unless (defined($options->attribute));
    push(@errors, "missing 'fields'") unless (defined($options->fields));
    push(@errors, "missing 'value'") unless (defined($options->value));
    die 'errors' if @errors;

    my $dbh = Koha::Plugin::Fi::Hypernova::MARCFrameworkDiff::Util->dbh();

    my ($sql_filters, $sql_placeholders);
    if (defined($options->fields) && not(defined($options->subfields))) {
      ($sql_filters, $sql_placeholders) = Koha::Plugin::Fi::Hypernova::MARCFrameworkDiff::Util::sql_filter($options, 'fw', 'f');
      unshift(@$sql_placeholders, $options->value);
      $self->sql("UPDATE marc_tag_structure SET ".$dbh->quote_identifier($options->attribute)." = ? WHERE ".join(" AND ", @$sql_filters).";");
      my $rv = $dbh->do($self->sql, undef, @$sql_placeholders);
      $self->rows_affected($rv);
    }
    elsif (defined($options->fields) && defined($options->subfields)) {
      ($sql_filters, $sql_placeholders) = Koha::Plugin::Fi::Hypernova::MARCFrameworkDiff::Util::sql_filter($options, 'fw', 'f', 'sf');
      unshift(@$sql_placeholders, $options->value);
      $self->sql("UPDATE marc_subfield_structure SET ".$dbh->quote_identifier($options->attribute)." = ? WHERE ".join(" AND ", @$sql_filters).";");
      my $rv = $dbh->do($self->sql, undef, @$sql_placeholders);
      $self->rows_affected($rv);
    }
    my $i=0;
    my $sql = $self->sql;
    $sql =~ s/\?/'$sql_placeholders->[$i++]'/gsm;
    $self->sql($sql);
  };
  if ($@) {
    push(@errors, $@);
    warn "Trying to update MARC Frameworks, but having the following errors => [@errors]. Using options => {".$options->serialize()."}";
    $self->errors(\@errors);
  }
  C4::Log::logaction('MARCFrameworkDiff', 'UPDATE', undef, $self->serialize(), undef, undef);
  return $self;
}

1;
