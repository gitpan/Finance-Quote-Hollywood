#!/usr/bin/perl

# Copyright 2008 Kevin Ryde

# This file is part of Finance-Quote-Hollywood.
#
# Finance-Quote-Hollywood is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as published
# by the Free Software Foundation; either version 3, or (at your option) any
# later version.
#
# Finance-Quote-Hollywood is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General
# Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Finance-Quote-Hollywood.  If not, see <http://www.gnu.org/licenses/>.

use strict;
use warnings;
use FindBin;
use File::Spec;

# use LWP::Debug '+';

{
  require HTTP::Response;
  require Perl6::Slurp;
  require Finance::Quote::Hollywood;
  my $symbol = 'EBANA';

  my $resp = HTTP::Response->new;
  my $topdir = File::Spec->catdir ($FindBin::Bin, File::Spec->updir);
  my $content = Perl6::Slurp::slurp
    (File::Spec->catfile ($topdir, 'samples', 'hollywood', 'ebana.html'));
  $resp->content($content);
  $resp->{'_rc'} = 200;

  my %quotes;
  Finance::Quote::Hollywood::resp_to_quotes ($symbol, $resp, \%quotes);

  require Data::Dumper;
  { no warnings; $Data::Dumper::Sortkeys = 1; }
  print Data::Dumper::Dumper(\%quotes);
  exit 0;
}

{
  require Finance::Quote;
  my $q = Finance::Quote->new ('-defaults', 'Hollywood');
  my %rates = $q->fetch ('hollywood','EBANA','ZORRO');

  require Data::Dumper;
  { no warnings; $Data::Dumper::Sortkeys = 1; }
  print Data::Dumper::Dumper(\%rates);

  exit 0;
}

    # 'http://localhost:8080/',

