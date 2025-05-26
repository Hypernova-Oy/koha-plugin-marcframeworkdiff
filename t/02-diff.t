#!/usr/bin/env perl

# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

BEGIN {
  $ENV{LOG4PERL_VERBOSITY_CHANGE} = 6;
  $ENV{MOJO_OPENAPI_DEBUG} = 1;
  $ENV{MOJO_LOG_LEVEL} = 'debug';
  $ENV{VERBOSE} = 1;
  $ENV{KOHA_PLUGIN_DEV_MODE} = 1;
}

use Modern::Perl;
use utf8;

use Test::More tests => 1;
use Test::Deep;
use Test::Mojo;

use Koha::Plugin::Fi::Hypernova::MARCFrameworkDiff;

use t::Lib qw(Koha::Plugin::Fi::Hypernova::MARCFrameworkDiff);

use HTTP::Request::Common qw();
use HTTP::Headers;

my $schema = Koha::Database->schema;
$schema->storage->txn_begin;

subtest("Scenario: Diff frameworks.", sub {
  plan tests => 8;

  my $plugin = Koha::Plugin::Fi::Hypernova::MARCFrameworkDiff->new(); #This implicitly calls install()

  subtest("Given two MARC Frameworks T1 and T2", sub {
    plan tests => 3;

    my $dbh = Koha::Plugin::Fi::Hypernova::MARCFrameworkDiff::Util->dbh();
    ok($dbh->do(
      "INSERT INTO biblio_framework (frameworkcode, frameworktext) VALUES ".
      "('T1', 'Test Framework 1'), ('T2', 'Test Framework 2')"
    ), "Given two MARC Frameworks T1 and T2");
    ok($dbh->do(
      "INSERT INTO marc_tag_structure (frameworkcode, tagfield, libopac, repeatable, authorised_value) VALUES ".
      "('T1', '008', 'Best 008', '1', NULL),  ('T2', '008', 'Test 008', '0', NULL), ".
      "('T1', '044', 'Best 044', '0', 'LOC'), ('T2', '044', 'Test 044', '0', NULL), ".
      "('T1', '144', 'Best 144', '0', NULL)" # T2 is missing a field, this should be shown as missing
    ), "Given MARC Framework tags for T1 and T2");
    ok($dbh->do(
      "INSERT INTO marc_subfield_structure (frameworkcode, tagfield, tagsubfield, libopac, repeatable, authorised_value) VALUES ".
      "('T1', '008', 'a', 'Best 008a', '1', NULL),  ('T2', '008', 'a', 'Test 008a', '0', NULL), ".
      "('T1', '044', 'b', 'Best 044b', '0', 'LOC'), ('T2', '044', 'b', 'Test 044a', '0', NULL), ".
      "('T1', '144', 'c', 'Best 144c', '0', NULL)" # T2 is missing a subfield, this should be shown as missing
    ), "Given MARC Framework subfields for T1 and T2");
  });

  subtest("Diff a solo framework", sub {
    plan tests => 2;

    $plugin->{cgi} = FakeCGI->new(
      HTTP::Request::Common::POST($t::Lib::DEFAULT_URL,
        Content => [
          mfwd_frameworksInclude => "T1",
          mfwd_fields => "008",
          mfwd_subfields => "a",
        ],
      ),
    );
    my $options = Koha::Plugin::Fi::Hypernova::MARCFrameworkDiff::Options->newFromCGI($plugin->{cgi});
    my ($diff, $d) = Koha::Plugin::Fi::Hypernova::MARCFrameworkDiff::Configure::runDiff($plugin, $options);

    is_deeply($d->{_table}->[0], ["Fld", "Sf", "Attribute", "T1"], "Table header has correct framework names");
    is($d->{_table}->[1], undef, "Comparing self to nothing results with no diffs");
  });

  subtest("Diff a single field/subfield. Test 0 is correctly identified", sub {
    plan tests => 3;

    $plugin->{cgi} = FakeCGI->new(
      HTTP::Request::Common::POST($t::Lib::DEFAULT_URL,
        Content => [
          mfwd_frameworksInclude => 'T1',
          mfwd_frameworksInclude => 'T2',
          mfwd_fields => '008',
          mfwd_subfields => 'a',
        ],
      ),
    );
    my $options = Koha::Plugin::Fi::Hypernova::MARCFrameworkDiff::Options->newFromCGI($plugin->{cgi});
    my ($diff, $d) = Koha::Plugin::Fi::Hypernova::MARCFrameworkDiff::Configure::runDiff($plugin, $options);

    is_deeply($d->{_table}->[0], ["Fld", "Sf", "Attribute", "T1",  "T2"],  "Table header has correct framework names");
    is_deeply($d->{_table}->[2], ['008', '',   'repeatable','1*1', '1*0'], "Test 0 is not missing or undef for field diffs");
    is_deeply($d->{_table}->[4], ['008', 'a',  'repeatable','1*1', '1*0'], "Test 0 is not missing or undef for subfield diffs");
  });
  subtest("Diff a single field/subfield. Test NULL is correctly identified", sub {
    plan tests => 3;

    $plugin->{cgi} = FakeCGI->new(
      HTTP::Request::Common::POST($t::Lib::DEFAULT_URL,
        Content => [
          mfwd_frameworksInclude => 'T1',
          mfwd_frameworksInclude => 'T2',
          mfwd_fields => '044',
          mfwd_subfields => 'b',
        ],
      ),
    );
    my $options = Koha::Plugin::Fi::Hypernova::MARCFrameworkDiff::Options->newFromCGI($plugin->{cgi});
    my ($diff, $d) = Koha::Plugin::Fi::Hypernova::MARCFrameworkDiff::Configure::runDiff($plugin, $options);

    is_deeply($d->{_table}->[0], ["Fld", "Sf", "Attribute",       "T1",    "T2"],        "Table header has correct framework names");
    is_deeply($d->{_table}->[1], ['044', '',   'authorised_value','1*LOC', '1*_undef_'], "Test NULL is undef for field diffs");
    is_deeply($d->{_table}->[3], ['044', 'b',  'authorised_value','1*LOC', '1*_undef_'], "Test NULL is undef for subfield diffs");
  });

  subtest("Diff a single field/subfield. Test when a bunch is missing", sub {
    plan tests => 4;

    $plugin->{cgi} = FakeCGI->new(
      HTTP::Request::Common::POST($t::Lib::DEFAULT_URL,
        Content => [
          mfwd_frameworksInclude => 'T1',
          mfwd_frameworksInclude => 'T2',
          mfwd_fields => '144',
          mfwd_subfields => 'c',
        ],
      ),
    );
    my $options = Koha::Plugin::Fi::Hypernova::MARCFrameworkDiff::Options->newFromCGI($plugin->{cgi});
    my ($diff, $d) = Koha::Plugin::Fi::Hypernova::MARCFrameworkDiff::Configure::runDiff($plugin, $options);

    is_deeply($d->{_table}->[0],  ["Fld", "Sf", "Attribute",       "T1",        "T2"],        "Table header has correct framework names");
    is_deeply($d->{_table}->[1],  ['144', '',   'authorised_value','1*_undef_', '1*_mssin_'], "Test NULL is different from missing for field diffs");
    is_deeply($d->{_table}->[10], ['144', 'c',  'authorised_value','1*_undef_', '1*_mssin_'], "Test NULL is different from missing for subfield diffs");
    ok(@{$d->{_table}} > 5, "All default attributes' values from marc_*_structures are included");
  });

  subtest("Diff (144\$c:authorised_value:repeatable) a single field/subfield. Filter with attributesInclude, test missing vs undefined vs 0", sub {
    plan tests => 6;

    $plugin->{cgi} = FakeCGI->new(
      HTTP::Request::Common::POST($t::Lib::DEFAULT_URL,
        Content => [
          mfwd_frameworksInclude => 'T1',
          mfwd_frameworksInclude => 'T2',
          mfwd_fields => '144',
          mfwd_subfields => 'c',
          mfwd_attributesInclude => 'authorised_value',
          mfwd_attributesInclude => 'repeatable',
        ],
      ),
    );
    my $options = Koha::Plugin::Fi::Hypernova::MARCFrameworkDiff::Options->newFromCGI($plugin->{cgi});
    my ($diff, $d) = Koha::Plugin::Fi::Hypernova::MARCFrameworkDiff::Configure::runDiff($plugin, $options);

    is_deeply($d->{_table}->[0], ["Fld", "Sf", "Attribute",       "T1",        "T2"],  "Table header has correct framework names");
    is_deeply($d->{_table}->[1], ['144', '',   'authorised_value','1*_undef_', '1*_mssin_'], "Test NULL is different from missing for field diffs");
    is_deeply($d->{_table}->[2], ['144', '',   'repeatable',      '1*0',       '1*_mssin_'], "Test NULL is different from missing for field diffs");
    is_deeply($d->{_table}->[3], ['144', 'c',  'authorised_value','1*_undef_', '1*_mssin_'], "Test NULL is different from missing for subfield diffs");
    is_deeply($d->{_table}->[4], ['144', 'c',  'repeatable',      '1*0',       '1*_mssin_'], "Test NULL is different from missing for field diffs");
    ok(@{$d->{_table}} == 5, "Extra attributes are filtered");
  });

  subtest("Diff (144\$c:authorised_value:repeatable) test missing vs undefined vs 0 using Perly false", sub {
    plan tests => 2;

    $plugin->{cgi} = FakeCGI->new(
      HTTP::Request::Common::POST($t::Lib::DEFAULT_URL,
        Content => [
          mfwd_frameworksInclude => 'T1',
          mfwd_frameworksInclude => 'T2',
          mfwd_fields => '144',
          mfwd_subfields => 'c',
          mfwd_attributesInclude => 'authorised_value',
          mfwd_attributesInclude => 'repeatable',
          mfwd_perlyFalse => 'on',
        ],
      ),
    );
    my $options = Koha::Plugin::Fi::Hypernova::MARCFrameworkDiff::Options->newFromCGI($plugin->{cgi});
    my ($diff, $d) = Koha::Plugin::Fi::Hypernova::MARCFrameworkDiff::Configure::runDiff($plugin, $options);

    is_deeply($d->{_table}->[0], ["Fld", "Sf", "Attribute",       "T1",        "T2"],  "Table header has correct framework names");
    ok(@{$d->{_table}} == 1, "With perlyFalse, the missing and undefined and 0 are all the same");
  });

  subtest("Full diff", sub {
    plan tests => 2;

    $plugin->{cgi} = FakeCGI->new(
      HTTP::Request::Common::POST(
        $t::Lib::DEFAULT_URL,
        Content => [
          mfwd_frameworksInclude => 'T1',
          mfwd_frameworksInclude => 'T2',
        ],
      ),
    );
    my $options = Koha::Plugin::Fi::Hypernova::MARCFrameworkDiff::Options->newFromCGI($plugin->{cgi});
    my ($diff, $d) = Koha::Plugin::Fi::Hypernova::MARCFrameworkDiff::Configure::runDiff($plugin, $options);

    is_deeply($d->{_table}->[0], ["Fld", "Sf", "Attribute",       "T1",  "T2"], "Table header has correct framework names");
    ok(@{$d->{_table}} > 30, "Lots of diffs");
  });
});

$schema->storage->txn_rollback;

1;