package Koha::Plugin::Fi::Hypernova::MARCFrameworkDiff::Util;

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

sub dbh {
  my $dbh = Koha::Database->schema->storage->dbh(); # Use DBD::MySQL for minimum headache
  $dbh->{ShowErrorStatement} = 1;
  $dbh->{RaiseError} = 1;
  #$dbh->trace(1);
  return $dbh;
}

sub selectall_arrayref {
  my ($diff, $sql, @bind) = @_;
  if ($diff->options->{verbose}) {
    print "Executing SQL: $sql\n"; # Print the SQL statement
    print "Bind parameters: " . join(", ", @bind) . "\n"; # Print bind parameters
  }
  my $dbh = dbh();
  my $sth = $dbh->prepare($sql);
  $sth->execute(@bind);
  return $sth->fetchall_arrayref({});
}

sub sql_filter {
  my ($options, $frameworks, $fields, $subfields) = @_;

  my @sql;
  my @placeholders;

  if ($frameworks) {
    my $biblio_framework_codes = fetch_biblio_framework_codes();
    $biblio_framework_codes = $options->frameworkcodes_include_exclude($biblio_framework_codes);
    push(@sql, "frameworkcode IN (" . join(",", ('?') x @$biblio_framework_codes) . ")");
    push(@placeholders, @$biblio_framework_codes);
  }

  if ($fields && defined($options->fields) && @{$options->fields}) {
    push(@sql, "tagfield IN (" . join(",", ('?') x @{$options->fields}) . ")");
    push(@placeholders, @{$options->fields});
  }

  if ($subfields && defined($options->subfields) && @{$options->subfields}) {
    push(@sql, "tagsubfield IN (" . join(",", ('?') x @{$options->subfields}) . ")");
    push(@placeholders, @{$options->subfields});
  }

  unless (@sql) {
    push(@sql, "1=1");
  }

  return (\@sql, \@placeholders);
}

sub fetch_biblio_framework_codes {
  my $dbh = Koha::Plugin::Fi::Hypernova::MARCFrameworkDiff::Util->dbh();
  my $sql = "SELECT DISTINCT(frameworkcode) FROM biblio_framework WHERE frameworkcode != '' ORDER BY frameworkcode ASC;";
  my $biblio_framework_codes = $dbh->selectcol_arrayref($sql);
  push(@$biblio_framework_codes, ''); #The default framework may or may not be in the biblio_frameworks-table
  return $biblio_framework_codes;
}

1;
