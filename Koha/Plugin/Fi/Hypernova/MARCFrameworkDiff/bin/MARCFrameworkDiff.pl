#!/usr/bin/perl

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

use FindBin;
use lib "$FindBin::Bin/../../../../../..";

use Getopt::Long qw(:config no_ignore_case bundling);
use Data::Printer;
use Pod::Usage qw( pod2usage );

use Koha::Plugin::Fi::Hypernova::MARCFrameworkDiff::Diff;

=head1 NAME

marc_framework_diff.pl - Detect differences in MARC frameworks and reconcile them

=head1 SYNOPSIS

marc_framework_diff.pl

 Options:
  --help or -h          Brief usage message
  --verbose or -v       Integer, 0-4, Be more verbose

 Utility commands
  --list-frameworkcodes List all framework codes in Koha as a csv, with more
                        verbosity dumps object attributes.

 Diff commands
  --diff                Activate diffing output. By default selects all
                        frameworks for diffing.
  --attributes-exclude  CSV String, eg. "display_order,maxlength".
                        Exclude these marc framework keys from comparison.
  --frameworks-include  CSV String, eg. "ACQ,,FA,BKS"
                        (Empty ,, selects the default framework).
                        Include these frameworks.
  --frameworks-exclude  CSV String, eg. "ACQ,FA"
                        (Empty ,, selects the default framework).
                        Exclude these frameworks. Can be used with
                        --frameworks-include
  --ignore-undef        When comparing values, undefined and "" and 0 compare
                        as equally undefined/unset/false.
  --perly-false         When comparing values, "" and 0 compare
                        as equally undefined/unset/false.

 Update commands
  --update              Activate the update feature.
  --fields              String, eg. "245,490". MARC fields within the framework.
  --subfields           String, eg. "a,b,c". MARC subfields within the framework.
  --attribute           String, eg. "hidden". Framework attribute to update.
  --value               String, eg. "yso_finto_finaf.pl".
                        Value to set to all of the selected frameworks.

=head1 EXAMPLES

 marc_framework_diff.pl --list-frameworkcodes -v 1

 # Update marc frameworks "KI,,KA,EK" field "810$t" attribute "hidden" with "0"
 marc_framework_diff.pl --diff --attributes-exclude "display_order,maxlength" \
  --frameworks-include "KI,,KA,EK" --ignore-undef --perly-false \
  --update --field 810 --subfield t --attribute hidden --value 0

=cut

binmode( STDOUT, ":encoding(UTF-8)" );

my %a = (
  verbose => 0,
);

Getopt::Long::GetOptions(
  'verbose|v:i'          => \$a{verbose},

  #Utility commands
  'list-frameworkcodes'  => \$a{listFrameworkcodes},

  #Diff commands
  'diff'                 => \$a{diff},
  'attributes-exclude:s' => \$a{attributesExclude},
  'attributes-include:s' => \$a{attributesInclude},
  'frameworks-exclude:s' => \$a{frameworksExclude},
  'frameworks-include:s' => \$a{frameworksInclude},
  'ignore-undef'         => \$a{ignoreUndef},
  'perly-false'          => \$a{perlyFalse},

  #Update commands
  'update'               => \$a{update},
  'fields:s'             => \$a{fields},
  'subfields:s'          => \$a{subfields},
  'attribute:s'          => \$a{attribute},
  'value:s'              => \$a{value},

  'help|h' => sub {
    pod2usage(1);
  }
) or pod2usage(2);
p(%a);

my @colWidths = (3, 1, 16, 30);

my $diff = Koha::Plugin::Fi::Hypernova::MARCFrameworkDiff::Diff->new(\%a);

$diff->list_frameworkcodes() if $a{'list-frameworkcodes'};
Koha::Plugin::Fi::Hypernova::MARCFrameworkDiff::Util::update($diff) if $a{update};
my $d = $diff->diff_comparison($diff->prepare_data_for_comparison($diff->fetch_data()));
$d->prepare_diff_table()->print_diff(\@colWidths) if $a{diff};
