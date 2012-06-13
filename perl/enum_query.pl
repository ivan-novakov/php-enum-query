#!/usr/bin/perl -w

use strict;
use ENUM;
use Net::DNS;

my $aus 	= $ARGV[0];
my $enumdomain 	= $ARGV[1];
my $resolver 	= $ARGV[2];
my $res;

if (!defined($aus)) {
  exit(1);
}

if (!defined($enumdomain)) {
  $enumdomain = '.e164.arpa';
}

if (defined($resolver)) {
  $res = Net::DNS::Resolver->new($resolver);
}

my @ret = &EnumQuery($aus, $enumdomain, $res);

if (scalar(@ret) == 0) {
  print $ENUM::enumerror, "\n";
  exit(2);
}
else {
  foreach my $r (@ret) {
    # order / pref / service / servicefound / uri  
    printf("%s | %s | %s | %s | %s\n", $r->{'order'}, $r->{'pref'}, $r->{'service'}, $r->{'servicefound'}, $r->{'uri'});
  }
}

