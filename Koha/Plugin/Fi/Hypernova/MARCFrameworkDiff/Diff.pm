package Koha::Plugin::Fi::Hypernova::MARCFrameworkDiff::Diff;

# Copyright 2025 Hypernova Oy
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# Koha is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Koha; if not, see <http://www.gnu.org/licenses>.

use Modern::Perl;
use strict;
use warnings;

use C4::Context;
use Koha::Database;

use Koha::Plugin::Fi::Hypernova::MARCFrameworkDiff::Options;
use Koha::Plugin::Fi::Hypernova::MARCFrameworkDiff::Util;

sub new {
  my ($class, $options, $plugin) = @_;
  if (! $options && $plugin) {
    $options = Koha::Plugin::Fi::Hypernova::MARCFrameworkDiff::Options->Retrieve($plugin);
  }
  else {
    $options = Koha::Plugin::Fi::Hypernova::MARCFrameworkDiff::Options->new($options);
  }
  my $self = {_opts => $options, _diff => MFWDiff->new($options)};
  return bless($self, $_[0]);
}

=head2 diff

Data structure to present all the frameworks in a easily comparable fashion.

field -> 'attr' -> attribute -> framework -> 'value' -> value
                                          -> 'diff'  -> [framework, framework, ...]
         'subs' -> subfield -> attribute -> framework -> 'value' -> value
                                                      -> 'diff'  -> [framework, framework, ...]

=cut

sub diff {
  return $_[0]->{_diff};
}

sub o {
  return $_[0]->{_opts};
}

sub verbose {
  return $_[0]->o->verbose;
}

sub _check_where_filter {
  my ($sql_where_filter) = @_;
  $sql_where_filter = "" unless $sql_where_filter;
  $sql_where_filter = "WHERE $sql_where_filter" if $sql_where_filter and $sql_where_filter !~ /WHERE/;
  return $sql_where_filter;
}

sub fetch_biblio_frameworks {
  my ($self, $noFilter) = @_;
  my $dbh = Koha::Plugin::Fi::Hypernova::MARCFrameworkDiff::Util->dbh();
  my ($sql_filters, $sql_placeholders) = (!$noFilter) ? Koha::Plugin::Fi::Hypernova::MARCFrameworkDiff::Util::sql_filter($self->o, 'fw') : ([],[]);
  my $sql = "SELECT * FROM biblio_framework ".(@$sql_filters ? "WHERE ".join(" AND ", @$sql_filters) : "")." ORDER BY frameworkcode ASC;";
  my $biblio_frameworks = $dbh->selectall_arrayref($sql, { Slice => {} }, @$sql_placeholders);

  my $include_default_framework = $self->o->frameworkcodes_include_exclude(['']);
  if ($noFilter || @$include_default_framework) {
    push(@$biblio_frameworks, {frameworkcode => '', frameworktext => 'Default'}); #The default framework is no longer in the biblio_frameworks-table
  }

  return $biblio_frameworks;
}
sub fetch_marc_tag_structure {
  my ($self) = @_;
  my $dbh = Koha::Plugin::Fi::Hypernova::MARCFrameworkDiff::Util->dbh();
  my ($sql_filters, $sql_placeholders) = Koha::Plugin::Fi::Hypernova::MARCFrameworkDiff::Util::sql_filter($self->o, 'fw', 'f');
  my $sql = "SELECT * FROM marc_tag_structure ".(@$sql_filters ? "WHERE ".join(" AND ", @$sql_filters) : "")." GROUP BY frameworkcode ASC, tagfield ASC;";
  return $dbh->selectall_arrayref($sql, { Slice => {} }, @$sql_placeholders);
}
sub fetch_marc_subfield_structure {
  my ($self) = @_;
  my $dbh = Koha::Plugin::Fi::Hypernova::MARCFrameworkDiff::Util->dbh();
  my ($sql_filters, $sql_placeholders) = Koha::Plugin::Fi::Hypernova::MARCFrameworkDiff::Util::sql_filter($self->o, 'fw', 'f', 'sf');
  my $sql = "SELECT * FROM marc_subfield_structure ".(@$sql_filters ? "WHERE ".join(" AND ", @$sql_filters) : "")." GROUP BY frameworkcode ASC, tagfield ASC, tagsubfield ASC;";
  return $dbh->selectall_arrayref($sql, { Slice => {} }, @$sql_placeholders);
}
sub fetch_distinct_fields_and_subfields {
  my ($self) = @_;
  my $dbh = Koha::Plugin::Fi::Hypernova::MARCFrameworkDiff::Util->dbh();
  my ($sql_filters, $sql_placeholders) = Koha::Plugin::Fi::Hypernova::MARCFrameworkDiff::Util::sql_filter($self->o, 'fw', 'f', 'sf');
  my $sql = "SELECT tagfield, tagsubfield FROM marc_subfield_structure ".(@$sql_filters ? "WHERE ".join(" AND ", @$sql_filters) : "")." GROUP BY tagfield, tagsubfield ORDER BY tagfield ASC, tagsubfield ASC;";
  return $dbh->selectall_arrayref($sql, { Slice => {} }, @$sql_placeholders);
}
sub fetch_data {
  my ($self) = @_;
  my $biblio_framework_codes = Koha::Plugin::Fi::Hypernova::MARCFrameworkDiff::Util::fetch_biblio_framework_codes();
  $biblio_framework_codes = $self->o->frameworkcodes_include_exclude($biblio_framework_codes);

  my $biblio_frameworks = $self->fetch_biblio_frameworks();
  if ($self->verbose > 1) {
    print "Biblio frameworks:\n";
    p($biblio_frameworks);
  }

  my $marc_field_structure = $self->fetch_marc_tag_structure();
  if ($self->verbose > 3) { # This is too massive info dump
    print "MARC field structure:\n";
    p($marc_field_structure);
  }

  my $marc_subfield_structure = $self->fetch_marc_subfield_structure();
  if ($self->verbose > 3) { # This is too massive info dump
    print "MARC subfield structure:\n";
    p($marc_subfield_structure);
  }

  my $distinct_fields_and_subfields = $self->fetch_distinct_fields_and_subfields();
  if ($self->verbose > 3) {
    print "distinct_fields_and_subfields:\n";
    p($distinct_fields_and_subfields);
  }

  return ($biblio_frameworks, $marc_field_structure, $marc_subfield_structure, $distinct_fields_and_subfields);
}

sub prepare_data_for_comparison {
  my ($self, $biblio_frameworks, $marc_field_structure, $marc_subfield_structure, $distinct_fields_and_subfields) = @_;
  my $d = $self->diff;

  for my $fw (@$biblio_frameworks) {
    $d->add_framework($fw);
  }

  for my $dfsfs (@$distinct_fields_and_subfields) {
    $d->push_comparison_slots($dfsfs->{tagfield}, $dfsfs->{tagsubfield});
  }

  for my $mfs (@$marc_field_structure) {
    $d->push_field_structure($mfs->{tagfield}, $mfs);
  }

  for my $mss (@$marc_subfield_structure) {
    $d->push_subfield_structure($mss->{tagfield}, $mss->{tagsubfield}, $mss);
  }

  return $d;
}

sub diff_comparison {
  my ($self, $d) = @_;
  my $opts = $self->o;

  for my $field_code (sort keys %{$d->{fields}}) {
    for my $attr (sort keys %{$d->{fields}->{$field_code}->{attr}}) {
      for my $fw_seek ($d->get_framework_codes()) {
        for my $fw_comp ($d->get_framework_codes()) {
          next if ($fw_seek eq $fw_comp);
          next if ($attr eq 'frameworkcode');
          next unless ($opts->attribute_include_exclude($attr));
          if ($d->field_values_diff($field_code, $attr, $fw_seek, $fw_comp)) {
            $d->add_field_diff($field_code, $attr, $fw_seek, $fw_comp);
          }
        }
      }
    }

    for my $subfield_code (sort keys %{$d->{fields}->{$field_code}->{subs}}) {
      for my $attr (sort keys %{$d->{fields}->{$field_code}->{subs}->{$subfield_code}}) {
        for my $fw_seek ($d->get_framework_codes()) {
          for my $fw_comp ($d->get_framework_codes()) {
            next if ($fw_seek eq $fw_comp);
            next if ($attr eq 'frameworkcode');
            next unless ($opts->attribute_include_exclude($attr));
            if ($d->subfield_values_diff($field_code, $subfield_code, $attr, $fw_seek, $fw_comp)) {
              $d->add_subfield_diff($field_code, $subfield_code, $attr, $fw_seek, $fw_comp);
            }
          }
        }
      }
    }
  }
  return $d;
}

sub list_frameworkcodes {
  my ($self) = @_;
  if ($self->verbose == 0) {
    my $biblio_framework_codes = Koha::Plugin::Fi::Hypernova::MARCFrameworkDiff::Util::fetch_biblio_framework_codes();
    print join(",", @$biblio_framework_codes)."\n";
  }
  else {
    my $biblio_frameworks = $self->fetch_biblio_frameworks("no-filter");
    p($biblio_frameworks);
  }
}

package MFWDiff;

=head2 MFWDiff

Data structure to present all the frameworks in a easily comparable fashion.

field -> 'attr' -> attribute -> framework -> 'value' -> value
                                          -> 'diff'  -> [framework, framework, ...]
         'subs' -> subfield -> attribute -> framework -> 'value' -> value
                                                      -> 'diff'  -> [framework, framework, ...]

=cut

sub new {
  my ($class, $options) = @_;
  my $self = {_opts => $options, _timestamp => DateTime->now(time_zone => C4::Context->tz)->iso8601};
  return bless($self, $class);
}

sub o {
  return $_[0]->{_opts};
}

sub field {
  return $_[0]->{fields}->{$_[1]};
}

sub field_value {
  my ($s, $field_code, $attribute, $frameworkcode) = @_;
  return '_mssin_' unless exists($s->{fields}->{$field_code}->{attr}->{$attribute}->{$frameworkcode}->{value});
  return '_undef_' unless defined($s->{fields}->{$field_code}->{attr}->{$attribute}->{$frameworkcode}->{value});
  return $s->{fields}->{$field_code}->{attr}->{$attribute}->{$frameworkcode}->{value};
}

sub subfield_value {
  my ($s, $field_code, $subfield_code, $attribute, $frameworkcode) = @_;
  return '_mssin_' unless exists($s->{fields}->{$field_code}->{subs}->{$subfield_code}->{$attribute}->{$frameworkcode}->{value});
  return '_undef_' unless defined($s->{fields}->{$field_code}->{subs}->{$subfield_code}->{$attribute}->{$frameworkcode}->{value});
  return $s->{fields}->{$field_code}->{subs}->{$subfield_code}->{$attribute}->{$frameworkcode}->{value};
}

sub add_field_diff {
  my ($s, $field_code, $attribute, $frameworkcode_seeker, $frameworkcode_comparator) = @_;
  $s->{fields}->{$field_code}->{attr}->{$attribute}->{$frameworkcode_seeker}->{diff} = [] unless $s->{fields}->{$field_code}->{attr}->{$attribute}->{$frameworkcode_seeker}->{diff};
  push(@{$s->{fields}->{$field_code}->{attr}->{$attribute}->{$frameworkcode_seeker}->{diff}}, $frameworkcode_comparator);
  print("Diff: '$field_code'->'attr'->'$attribute'->'$frameworkcode_seeker' ne '$frameworkcode_comparator'\n") if $s->o->verbose > 1;
}

sub add_subfield_diff {
  my ($s, $field_code, $subfield_code, $attribute, $frameworkcode_seeker, $frameworkcode_comparator) = @_;
  $s->{fields}->{$field_code}->{subs}->{$subfield_code}->{$attribute}->{$frameworkcode_seeker}->{diff} = [] unless $s->{fields}->{$field_code}->{subs}->{$subfield_code}->{$attribute}->{$frameworkcode_seeker}->{diff};
  push(@{$s->{fields}->{$field_code}->{subs}->{$subfield_code}->{$attribute}->{$frameworkcode_seeker}->{diff}}, $frameworkcode_comparator);
  print("Diff: '$field_code\$$subfield_code'->'attr'->'$attribute'->'$frameworkcode_seeker' ne '$frameworkcode_comparator'\n") if $s->o->verbose > 1;
}

sub field_values_diff {
  my ($s, $field_code, $attr, $fw_seek, $fw_comp) = @_;

  if ($s->o->perlyFalse) {
    return 0 if (not($s->{fields}->{$field_code}->{attr}->{$attr}->{$fw_seek}->{value}) && not($s->{fields}->{$field_code}->{attr}->{$attr}->{$fw_comp}->{value}));
  }

  return $s->field_value($field_code, $attr, $fw_seek) ne $s->field_value($field_code, $attr, $fw_comp);
}

sub subfield_values_diff {
  my ($s, $field_code, $subfield_code, $attr, $fw_seek, $fw_comp) = @_;

  if ($s->o->perlyFalse) {
    return 0 if (not($s->{fields}->{$field_code}->{subs}->{$subfield_code}->{$attr}->{$fw_seek}->{value}) && not($s->{fields}->{$field_code}->{subs}->{$subfield_code}->{$attr}->{$fw_comp}->{value}));
  }

  return $s->subfield_value($field_code, $subfield_code, $attr, $fw_seek) ne $s->subfield_value($field_code, $subfield_code, $attr, $fw_comp);
}

sub push_comparison_slots {
  my ($s, $field_code, $subfield_code) = @_;
  $s->{fields}->{$field_code} = {} unless $s->{fields}->{$field_code};
  $s->{fields}->{$field_code}->{attr} = {} unless $s->{fields}->{$field_code}->{attr};
  $s->{fields}->{$field_code}->{subs} = {} unless $s->{fields}->{$field_code}->{subs};
  $s->{fields}->{$field_code}->{subs}->{$subfield_code} = {};
}

sub push_field_structure {
  my ($s, $field_code, $mfs) = @_;
  unless ($s->{fields}->{$field_code}) {
    warn "push_field_structure($field_code fw='".$mfs->{frameworkcode}."'):> Missing field_code?";
  }

  while (my ($k, $v) = each(%$mfs)) {
    $s->{fields}->{$field_code}->{attr}->{$k} = {} unless $s->{fields}->{$field_code}->{attr}->{$k};
    $s->{fields}->{$field_code}->{attr}->{$k}->{$mfs->{frameworkcode}} = {} unless $s->{fields}->{$field_code}->{attr}->{$k}->{$mfs->{frameworkcode}};
    if ($s->o->ignoreUndef || $s->o->perlyFalse) {
      $s->{fields}->{$field_code}->{attr}->{$k}->{$mfs->{frameworkcode}}->{value} = (defined $v) ? $v : '';
    }
    else {
      $s->{fields}->{$field_code}->{attr}->{$k}->{$mfs->{frameworkcode}}->{value} = (defined $v) ? $v : '_undef_';
    }
  }
}

sub push_subfield_structure {
  my ($s, $field_code, $subfield_code, $mss) = @_;
  unless ($s->{fields}->{$field_code}) {
    warn "push_subfield_structure($field_code\$$subfield_code fw='".$mss->{frameworkcode}."'):> Missing field_code?";
  }
  unless ($s->{fields}->{$field_code}->{subs}->{$subfield_code}) {
    warn "push_subfield_structure($field_code\$$subfield_code fw='".$mss->{frameworkcode}."'):> Missing subfield_code?";
  }
  while (my ($k, $v) = each(%$mss)) {
    $s->{fields}->{$field_code}->{subs}->{$subfield_code}->{$k} = {} unless $s->{fields}->{$field_code}->{subs}->{$subfield_code}->{$k};
    $s->{fields}->{$field_code}->{subs}->{$subfield_code}->{$k}->{$mss->{frameworkcode}} = {} unless $s->{fields}->{$field_code}->{subs}->{$subfield_code}->{$k}->{$mss->{frameworkcode}};
    if ($s->o->ignoreUndef || $s->o->perlyFalse) {
      $s->{fields}->{$field_code}->{subs}->{$subfield_code}->{$k}->{$mss->{frameworkcode}}->{value} = (defined $v) ? $v : '';
    }
    else {
      $s->{fields}->{$field_code}->{subs}->{$subfield_code}->{$k}->{$mss->{frameworkcode}}->{value} = (defined $v) ? $v : '_undef_';
    }
  }
}

sub add_framework {
  my ($s, $framework) = @_;
  $s->{frameworks} = {} unless $s->{frameworks};
  $s->{frameworks}->{$framework->{frameworkcode}} = $framework;
}
# Use en external frameworks list, because not all frameworks have all fields/subfields
sub get_framework_codes {
  return sort keys %{$_[0]->{frameworks}};
}

sub prepare_diff_table {
  my ($d) = @_;

  my @table;

  my @sb = ('Fld','Sf','Attribute');
  for my $fw ($d->get_framework_codes()) {
    push(@sb, ($fw ? $fw : 'Default'));
  }
  push(@table, \@sb);

  for my $field_code (sort keys %{$d->{fields}}) {
    for my $attr (sort keys %{$d->{fields}->{$field_code}->{attr}}) {
      my $show_diff = 0;
      my @sb = ($field_code, '', $attr);
      for my $fw ($d->get_framework_codes()) {
        if ($d->{fields}->{$field_code}->{attr}->{$attr}->{$fw}->{diff}) {
          $show_diff++;
          push(@sb, $d->field_value($field_code, $attr, $fw));
          #push(@sb, scalar(@{$d->{fields}->{$field_code}->{attr}->{$attr}->{$fw}->{diff}}) . '*' . $d->field_value($field_code, $attr, $fw));
        }
        else {
          push(@sb, "");
        }
      }
      push(@table, \@sb) if $show_diff;
    }

    for my $subfield_code (sort keys %{$d->{fields}->{$field_code}->{subs}}) {
      for my $attr (sort keys %{$d->{fields}->{$field_code}->{subs}->{$subfield_code}}) {
        my $show_diff = 0;
        my @sb = ($field_code, $subfield_code, $attr);
        for my $fw ($d->get_framework_codes()) {
          if ($d->{fields}->{$field_code}->{subs}->{$subfield_code}->{$attr}->{$fw}->{diff}) {
            $show_diff++;
            push(@sb, $d->subfield_value($field_code, $subfield_code, $attr, $fw));
            #push(@sb, scalar(@{$d->{fields}->{$field_code}->{subs}->{$subfield_code}->{$attr}->{$fw}->{diff}}) . '*' . $d->subfield_value($field_code, $subfield_code, $attr, $fw));
          }
          else {
            push(@sb, "");
          }
        }
        push(@table, \@sb) if $show_diff;
      }
    }
  }
  $d->{_table} = \@table;
  return $d;
}

our $colWidths;
sub print_diff {
  my ($d, $colWidths_) = @_;
  $colWidths = $colWidths_;
  my $table = $d->{_table};

  sub col {
    my ($position, $value) = @_;
    my $width = $colWidths->[$position];
    my $offset = $width - length($value);
    return $value . (" " x $offset) if $offset > 0;
    return substr($value, 0, $width);
  }

  my $header = $table->[0];
  print "|" . join("|", map {col($_, $header->[$_])} (0..2)) . "|" .
              join("|", map {col(3, $header->[$_])} (3..($#$header)));
  print "\n+---+-+-----------+-------------------------------\n";

  for my $row ($table->[1,]) {
    print "|" . join("|", map {col($_, $row->[$_])} (0..2)) . "|" .
                join("|", map {col(3, $row->[$_])} (3..($#$row)));
  }
}

1;
