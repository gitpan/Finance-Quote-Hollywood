# Copyright 2008 Kevin Ryde

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
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

package Finance::Quote::Hollywood;
use strict;
use warnings;
use Carp;
use Regexp::Common 'whitespace';

our $VERSION = 2;

use constant DEBUG => 0;

use constant HOLLYWOOD_EXCHANGE_BASE_URL =>
  'http://movies.hsx.com/servlet/SecurityDetail?symbol=';

use constant HOLLYWOOD_EXCHANGE_COPYRIGHT_URL =>
  'http://www.hsx.com/about/terms.htm';

sub methods {
  return (hollywood => \&hollywood_quotes);
}
sub labels {
  return (hollywood => [ qw(date isodate name status
                            movie_gross star_trailing_average_gross
                            last net volume
                            week_high   week_low   week_range
                            month_high  month_low  month_range
                            season_high season_low season_range
                            year_high   year_low   year_range
                            method copyright_url) ]);
}
sub currency_fields {
  return qw(last net
            week_high   week_low   week_range
            month_high  month_low  month_range
            season_high season_low season_range
            year_high   year_low   year_range);
}

sub hollywood_quotes {
  my ($quoter, @symbol_list) = @_;
  my $ua = $quoter->user_agent;
  my %quotes;

  foreach my $symbol (@symbol_list) {
    my $url = make_url ($symbol);

    my $req = HTTP::Request->new ('GET', $url);
    $ua->prepare_request ($req);
    $req->accept_decodable; # we use decoded_content() below
    $req->user_agent ("Finance-Quote-Hollywood/$VERSION " . $req->user_agent);
    if (DEBUG) { print $req->as_string; }
    my $resp = $ua->request ($req);

    $quoter->store_date(\%quotes, $symbol, {today => 1});
    resp_to_quotes ($symbol, $resp, \%quotes);
  }
  return wantarray() ? %quotes : \%quotes;
}

sub make_url {
  my ($symbol) = @_;
  return HOLLYWOOD_EXCHANGE_BASE_URL() . URI::Escape::uri_escape($symbol);
}

# store to hashref $quotes for $symbol based on HTTP::Response in $resp
sub resp_to_quotes {
  my ($symbol, $resp, $quotes) = @_;

  $quotes->{$symbol,'method'} = 'hollywood';
  $quotes->{$symbol,'success'} = 1;

  my $content = $resp->decoded_content (raise_error => 1);
  if (! $resp->is_success) {
    $quotes->{$symbol,'success'}  = 0;
    $quotes->{$symbol,'errormsg'} = $resp->status_line;
    return;
  }
  $quotes->{$symbol,'copyright_url'} = HOLLYWOOD_EXCHANGE_COPYRIGHT_URL;

  require HTML::TableExtract;
  {
    # This is looking for the little table with Symbol: and Price: rows.
    # The first row is the name, but HTML::TableExtract drops that when we
    # match on the Symbol:.  So having found the desired table parse a
    # second time asking for it by depth+count so as to get all rows.
    #
    my $te = HTML::TableExtract->new (headers => ["Symbol: $symbol"],
                                      keep_headers => 1,
                                      slice_columns => 0);
    $te->parse ($content);
    my $ts = $te->first_table_found;
    if (! $ts) {
      $quotes->{$symbol,'success'}  = 0;
      $quotes->{$symbol,'errormsg'} = 'price table not found in HTML';
      return;
    }
    $te = HTML::TableExtract->new (depth => $ts->depth,
                                   count => $ts->count);
    $te->parse ($content);
    $ts = $te->first_table_found;
    if (! $ts) {
      $quotes->{$symbol,'success'}  = 0;
      $quotes->{$symbol,'errormsg'} = 'Oops, re-parse failed';
      return;
    }

    my ($name) = $ts->row(0);
    $name =~ s/$RE{ws}{crop}//g;      # leading and trailing whitespace
    $quotes->{$symbol,'name'} = $name;

    # price row in the table like
    #    Price: H$119.56 Change: +1/2   Volume: 291,871 ...
    #    Price: H$117.06 Change: 0   Volume: 387,675 ...
    # or change "+2 1/2" or "-2" etc
    #
    my $last;
    my $change;
    my $rows = $ts->rows;
    foreach my $row (@{$rows}[1..$#$rows]) {  # skip row [0]
      my $str = $row->[0]; # first column
      $str =~ s/,//g; # various thousands separators

      if ($str =~ /Status: *(\w+)/) {
        $quotes->{$symbol,'status'} = $1;
      }
      if ($str =~ /TAG: *\$([0-9.]+)/) {
        $quotes->{$symbol,'star_trailing_average_gross'} = $1;
      }
      if ($str =~ /Price: *H\$([0-9.]+)/) {
        $quotes->{$symbol,'last'} = $last = $1;
      }
      if ($str =~ /Volume: *([0-9,]+)/) {
        $quotes->{$symbol,'volume'} = $1;
      }
      if ($str =~ /Change: *([0-9 +-]+)/) {
        my $frac = $1;
        $quotes->{$symbol,'net'} = $change = fraction_to_decimal ($frac);
        if (! defined $change) {
          $quotes->{$symbol,'success'}  = 0;
          $quotes->{$symbol,'errormsg'} ="Oops, unrecognised fraction '$frac'";
          return;
        }
      }
      if ($str =~ /Gross: *\$([0-9.]+)/) {
        $quotes->{$symbol,'movie_gross'} = $1;
      }
    }
  }

  {
    my $te = HTML::TableExtract->new (headers => ["THIS WEEK"],
                                      keep_headers => 1,
                                      slice_columns => 0);
    $te->parse ($content);
    my $ts = $te->first_table_found;
    if (! $ts) {
      $quotes->{$symbol,'success'}  = 0;
      $quotes->{$symbol,'errormsg'} =
        'week/season/year range table not found in HTML';
      return;
    }
    foreach my $row ($ts->rows) {
      if (DEBUG) { require Data::Dumper;
                   print Data::Dumper::Dumper($row); }
      my @row = @$row;

      # "THIS WEEK", "THIS SEASON" or "THIS YEAR"
      if (! defined $row[0]) { next; }
      $row[0] =~ /THIS ([A-Za-z]+)/ or next;
      my $period = lc($1);
      shift @row;

      # high and low values in columns, with dummy separator columns
      my @hl;
      foreach my $value (@row) {
        if (defined $value && $value =~ /H\$([0-9.]+)/) {
          push @hl, $1;
        }
      }
      if (@hl != 2) {
        $quotes->{$symbol,'success'} = 0;
        $quotes->{$symbol,'errormsg'} =
          'Oops, didn\'t see high and low values';
        return;
      }

      my ($high, $low) = @hl;
      $quotes->{$symbol,"${period}_high"} = $high;
      $quotes->{$symbol,"${period}_low"} = $low;
      $quotes->{$symbol,"${period}_range"} = "$high-$low";
    }
  }
}

# $str is a fraction like like "0" "+1/2" "+2 1/2" "-2" etc
# return a decimal form like "2.50"
#
# This is a bit slack, it assumes two decimal places will be enough
#
sub fraction_to_decimal {
  my ($str) = @_;
  #          1      2                 34        5
  $str =~ m{^([+-]?)([0-9]+$|[0-9]+ )?(([0-9]+)/([0-9]+))?}
    or return;

  my $sign = $1;
  if ($sign eq '+') { $sign = ''; }
  my $integer = $2 || 0;
  my $numerator = $4 || 0;
  my $denominator = $5 || 1;

  return sprintf ('%s%d.%02d',
                  $sign, $integer, int (100 * $numerator / $denominator));
}


1;
__END__

=head1 NAME

Finance::Quote::Hollywood - download Hollywood Stock Exchange quotes

=head1 SYNOPSIS

 use Finance::Quote;
 my $quoter = Finance::Quote->new ('-defaults', 'Hollywood');
 my %quotes = $quoter->fetch('hollywood','EBANA','ZORRO');

=head1 DESCRIPTION

This module downloads stock quotes from the Hollywood Stock Exchange game

=over 4

L<http://www.hsx.com>

=back

Using pages like

=over 4

L<http://movies.hsx.com/servlet/SecurityDetail?symbol=EBANA>

=back

Both stars stock quotes and movie stock quotes can be fetched, under the
symbols shown on the pages.  The home page has a symbol search.

The HSX web site is for use under terms described

=over 4

L<http://www.hsx.com/about/terms.htm>

=back

As of May 2008 it's for personal non-commercial enjoyment only.  It's your
responsibility to ensure your use of this module complies with those terms.

=head1 USAGE

This module is not in the C<Finance::Quote> defaults, but can be loaded in
the usual ways, either an environment variable

    FQ_LOAD_QUOTELET="-defaults Hollywood"
    export FQ_LOAD_QUOTELET

or in the quoter creation in your code

    my $quoter = Finance::Quote->new ('-defaults', 'Hollywood');

The C<-defaults> can be omitted if you don't want the standard modules, just
Hollywood.

A single fetch method C<hollywood> is provided, so for example with the
sample C<chkshares.pl> script from C<Finance::Quote>

    FQ_LOAD_QUOTELET="Hollywood" ./chkshares.pl hollywood EBANA

or in your own code

    my %quotes = $quoter->fetch ('hollywood', 'EBANA');
    print "last price ", $quotes{'EBANA','last'}, "\n";

Each symbol is a separate HTTP request, so there's no particular need to
group them in a single C<fetch> call.

=head1 FIELDS

The following fields are available

    date isodate name status
    last net volume
    week_high   week_low   week_range
    month_high  month_low  month_range
    season_high season_low season_range
    year_high   year_low   year_range
    method copyright_url

C<status> is a string C<"Active">, C<"Halted"> or C<"Inactive">.

=head1 SEE ALSO

L<Finance::Quote>, L<LWP>

=head1 HOME PAGE

L<http://www.geocities.com/user42_kevin/finance-quote-hollywood/>

=head1 LICENCE

Copyright 2008 Kevin Ryde

Finance-Quote-Hollywood is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 3, or (at your option) any
later version.

Finance-Quote-Hollywood is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General
Public License for more details.

You should have received a copy of the GNU General Public License along with
Finance-Quote-Hollywood; see the file F<COPYING>.  If not, see
L<http://www.gnu.org/licenses/>.

=cut
