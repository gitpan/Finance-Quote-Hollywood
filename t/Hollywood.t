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
use Test::More tests => 14;
use Finance::Quote::Hollywood;

is (Finance::Quote::Hollywood::fraction_to_decimal('0'), '0.00');
is (Finance::Quote::Hollywood::fraction_to_decimal('1'), '1.00');
is (Finance::Quote::Hollywood::fraction_to_decimal('+1'), '1.00');
is (Finance::Quote::Hollywood::fraction_to_decimal('-1'), '-1.00');
is (Finance::Quote::Hollywood::fraction_to_decimal('1/2'), '0.50');
is (Finance::Quote::Hollywood::fraction_to_decimal('+1/2'), '0.50');
is (Finance::Quote::Hollywood::fraction_to_decimal('-1/2'), '-0.50');
is (Finance::Quote::Hollywood::fraction_to_decimal('1/4'), '0.25');
is (Finance::Quote::Hollywood::fraction_to_decimal('+1/4'), '0.25');
is (Finance::Quote::Hollywood::fraction_to_decimal('-1/4'), '-0.25');
is (Finance::Quote::Hollywood::fraction_to_decimal('1 3/4'), '1.75');
is (Finance::Quote::Hollywood::fraction_to_decimal('+1 3/4'), '1.75');
is (Finance::Quote::Hollywood::fraction_to_decimal('-1 3/4'), '-1.75');
is (Finance::Quote::Hollywood::fraction_to_decimal('10 3/4'), '10.75');

exit 0;
