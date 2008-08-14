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


# Usage: ./dump.pl SYMBOL SYMBOL ...
#
# Print a dump of Finance::Quote::Hollywood quotes downloaded for the given
# symbols (or EBANA as a sample by default).

use strict;
use warnings;
use Finance::Quote;

my @symbols = @ARGV;
if (! @symbols) { @symbols = ('EBANA'); }

my $q = Finance::Quote->new ('Hollywood');
my %rates = $q->fetch ('hollywood', @symbols);

foreach my $symbol (@symbols) {
  print "Symbol: '$symbol'\n";

  # keys have the $; separator like "$symbol$;last", match and strip the
  # $symbol$; part
  foreach my $key (sort grep /^$symbol$;/, keys %rates) {
    my $showkey = $key;
    $showkey =~ s/.*?$;//;
    printf "  %-14s '%s'\n", $showkey, $rates{$key};
  }
}

exit 0;
