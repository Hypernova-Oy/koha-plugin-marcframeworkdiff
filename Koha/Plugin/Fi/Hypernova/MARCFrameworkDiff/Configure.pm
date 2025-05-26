package Koha::Plugin::Fi::Hypernova::MARCFrameworkDiff::Configure;

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

use Koha::Plugin::Fi::Hypernova::MARCFrameworkDiff::Diff;
use Koha::Plugin::Fi::Hypernova::MARCFrameworkDiff::Update;

sub install {
  my ($plugin) = @_;
  unless (Koha::Plugin::Fi::Hypernova::MARCFrameworkDiff::Options->Retrieve($plugin)) {
    Koha::Plugin::Fi::Hypernova::MARCFrameworkDiff::Options->new()->store($plugin);
  }
  return $plugin;
}
sub uninstall {
  my ($plugin) = @_;
  return $plugin;
}

#Controller
sub configure {
  my ($plugin, $args) = @_;
  eval {
    my $cgi = $plugin->{'cgi'};
    if ($cgi->request_method() eq 'POST') { $cgi->param('op' => 'mfwd_ignore_undef'); } #Somewhere deep inside Koha missing this causes a "Use of unitialized value" warning
    my $template = $plugin->get_template( { file => _absPath($plugin, 'configure.tt') } );

    my ($diff, $d, $options, $update);
    $options = Koha::Plugin::Fi::Hypernova::MARCFrameworkDiff::Options->newFromCGI($cgi);
    unless ($options->anyAttributeDefined()) {
      $options = Koha::Plugin::Fi::Hypernova::MARCFrameworkDiff::Options->Retrieve($plugin);
    }

    if ($cgi->param('mfwd_diff') || $cgi->param('mfwd_update')) {
      $options->store($plugin);
      ($diff, $d) = runDiff($plugin, $options);

      if ($cgi->param('mfwd_update')) {
        $update = Koha::Plugin::Fi::Hypernova::MARCFrameworkDiff::Update->new()->update($options, $diff);
      }
    }
    else {
      $diff = Koha::Plugin::Fi::Hypernova::MARCFrameworkDiff::Diff->new($options, $plugin);
    }

    my $biblio_frameworks = $diff->fetch_biblio_frameworks('no filtering');
    if ($options->frameworksInclude) {
      for my $fw (@$biblio_frameworks) {
        $fw->{included} = 1 if $options->frameworksInclude->{$fw->{frameworkcode}};
      }
    }
    if ($options->frameworksExclude) {
      for my $fw (@$biblio_frameworks) {
        $fw->{excluded} = 1 if $options->frameworksExclude->{$fw->{frameworkcode}};
      }
    }

    my $marc_subfield_structure_colNames_hash = Get_marc_subfield_structure_columnNames_hash();
    if ($options->attributesExclude) {
      for my $exclude (keys %{$options->attributesExclude}) {
        $marc_subfield_structure_colNames_hash->{$exclude}->{excluded} = 1 if $marc_subfield_structure_colNames_hash->{$exclude};
      }
    }
    if ($options->attributesInclude) {
      for my $include (keys %{$options->attributesInclude}) {
        $marc_subfield_structure_colNames_hash->{$include}->{included} = 1 if $marc_subfield_structure_colNames_hash->{$include};
      }
    }
    if ($options->attribute) {
      $marc_subfield_structure_colNames_hash->{$options->attribute}->{attributed} = 1 if $marc_subfield_structure_colNames_hash->{$options->attribute};
    }

    $template->param(
      pluginMeta => $plugin->{metadata},
      marcframeworks_available => $biblio_frameworks,
      options => $options,
      diffTable => ($d ? $d->{_table} : undef),
      marc_subfield_structure_colNames => $marc_subfield_structure_colNames_hash,
      update => $update,
      action_logs_report_id => $plugin->retrieve_data('action_logs_report_id'),
    );

    $plugin->output_html( $template->output(), 200 );
  };
  if ($@) {
    warn 'Koha::Plugin::Fi::Hypernova::MARCFrameworkDiff:> '.$@;
    $plugin->output_html( $@, 500 );
  }
  return 1;
}

sub runDiff {
  my ($plugin, $options) = @_;
  my $diff = Koha::Plugin::Fi::Hypernova::MARCFrameworkDiff::Diff->new($options, $plugin);
  my $d = $diff->diff_comparison($diff->prepare_data_for_comparison($diff->fetch_data()));
  $d->prepare_diff_table();
  return ($diff, $d);
}

sub GetMARCFrameworkSubfields {
  my ($fieldcode, $subfieldcode) = @_;
  my $dbh = Koha::Plugin::Fi::Hypernova::MARCFrameworkDiff::Util->dbh();

  my $sth = $dbh->prepare("SELECT * FROM marc_subfield_structure WHERE frameworkcode = ? AND tagfield = ?");
  $sth->execute($fieldcode, $subfieldcode);
  return $sth->fetchall_arrayref({});
}

sub Get_marc_subfield_structure_columnNames {
  my $dbh = Koha::Plugin::Fi::Hypernova::MARCFrameworkDiff::Util->dbh();

  my $sth = $dbh->prepare("SELECT * FROM marc_subfield_structure WHERE 1=0");
  $sth->execute();
  return $sth->{NAME};
}

sub Get_marc_subfield_structure_columnNames_hash {
  my %colNames = map {$_ => {}} @{Get_marc_subfield_structure_columnNames()};
  return \%colNames;
}

sub _absPath {
  my ($plugin, $file) = @_;

  return Cwd::abs_path($plugin->mbf_path($file));
}

1;
