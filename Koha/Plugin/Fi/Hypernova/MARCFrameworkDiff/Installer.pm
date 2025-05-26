package Koha::Plugin::Fi::Hypernova::MARCFrameworkDiff::Installer;

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

use C4::Reports::Guided;

sub install {
  my ($plugin) = @_;
  my $id = C4::Reports::Guided::save_report({
    borrowernumber => C4::Context->userenv ? C4::Context->userenv->{'borrowernumber'} : undef,
    sql => "SELECT * FROM action_logs WHERE module = 'MARCFrameworkDiff' ORDER BY action_id ASC LIMIT 20",
    name => 'MARCFrameworkDiff - Action Logs',
    notes => 'Action logs for MARCFrameworkDiff plugin',
    area => undef,
    group => 'plugins',
    subgroup => undef,
    cache_expiry => undef,
    public => undef,
  });
  if ($id) {
    $plugin->store_data({action_logs_report_id => $id});
  }
  return 1;
}

sub uninstall {
  my $dbh = Koha::Plugin::Fi::Hypernova::MARCFrameworkDiff::Util->dbh();
  my $result = $dbh->selectall_arrayref("SELECT id FROM saved_sql WHERE report_name = ?", {Slice => {}}, 'MARCFrameworkDiff - Action Logs');
  if ($result && @$result) {
    C4::Reports::Guided::delete_report($result->[0]->{id});
  }
  return 1;
}

1;
