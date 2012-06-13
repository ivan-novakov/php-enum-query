package ENUM;

# $Id: ENUM.pm,v 1.32 2004/03/23 06:46:58 fujiwara Exp $

###########################################################################
#
# ENUM - Perl ENUM resolver module
#
# Copyright (c) 2004  Japan Registry Service Co., LTD.
# Copyright (c) 2004  Kazunori Fujiwara
# All Rights Reserved.
#
# Author: Kazunori Fujiwara <fujiwara@jprs.co.jp>
#
###########################################################################

use strict;
use vars qw($enumerror $ignore_order $rfc2916service);
use vars qw(@ISA @EXPORT @EXPORT_OK $VERSION);

use Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(EnumQuery AUScheck);
@EXPORT_OK = qw($enumerror);
$VERSION = 0.1;

# Hack commanche
my $TIMEOUT = 5;

$ignore_order = 1; # for DEBUG
$rfc2916service = 1; # for RFC2916 compat

use Net::DNS;

# &eval_regexp('!^+9433(.*)$!\1@dnslab.jp!', '+94330351');

use vars qw($eval_regexp_error);

sub AUScheck($)
{
	my ($AUS) = @_;

	$AUS =~ tr /0-9//cd;
	$AUS = '+' . $AUS if ($AUS =~ /^\d/);

	return $AUS;
}

sub eval_regexp($$) # ($regexp, $aus)
{
	my($reg,$aus) = @_;
	my(@value, $d, $pattern, $replace, $flag);

	$d = substr $reg, 0, 1;
	if (!defined($d) || $d =~ /[1-9i]/) {
		$eval_regexp_error = "bad delim-char:[$d]";
		return undef;
	}
	if ($d ne '\\') {
		unless ($reg =~ m/^$d(([^$d]|\\$d)+)$d(([^$d]|\\$d)+)$d(i?)$/) {
			$eval_regexp_error = "bad subst-expr:[$reg]";
			return undef;
		}
		$pattern = $1;
		$pattern =~ s/\\$d/$d/g;
		$replace = $3;
		$replace =~ s/\\$d/$d/g;
		$flag = $5; # ignore
	} else {
		unless ($reg =~ m/^\\(([^\\]|\\\\)+)\\(([^\\]|\\[1-9\\])+)\\(i?)$/) {
			$eval_regexp_error = "bad subst-expr:[$reg]";
			return undef;
		}
		$pattern = $1;
		$pattern =~ s/\\\\/\\/g;
		$replace = $3;
		$replace =~ s/\\\\/\\/g;
		$flag = $5; # ignore
	}

# check regular expression

# character '$' exist only last of $pattern.
# because ENUM AUS only contains digits and '+'.
	if ($pattern =~ /\$[^\$]/) {
		$eval_regexp_error = "ere contains \$:[$pattern]";
		return undef;
	}
#
# Special fix: ^+ must be ^\+
#
	$pattern =~ s/^\^\+/\^\\\+/;
#
#
#
	if ($aus =~ /$pattern/) {
		@value = $aus =~ //;
	} else {
		$eval_regexp_error = "aus doesnot match ere:aus=$aus ere=[$pattern]";
		return undef;
	}
	my $temp = '';
	while ($replace ne "") {
		last unless ($replace =~ m/^([^\\]*)\\([1-9])(.*)$/);
		if (1+$#value < $2) {
			$eval_regexp_error = "bad repl backref:\\$2";
			return undef;
		}
		$temp .= $1 . $value[$2-1];
		$replace = $3;
	}
	return $temp . $replace;
}


sub EnumQuery($$$%) #($aus, $enumdomain, $res, %enumservice)
{
	my ($aus, $enumdomain, $res, %enumservice) = @_;
	my ($dom, $ok, $es, $query,$rr,$i,$new,$uri,$order,$eval_es);
	my (@output) = (); 

	$eval_es = scalar(%enumservice);
	if (!($aus =~ /^\+(\d+)$/)) {
		$enumerror = "wrong aus";
		return ();
	}
	$dom = join('.', reverse(split(//, $1))) . $enumdomain;

	$enumerror = "";

	if (!defined($res)) {
		$res = Net::DNS::Resolver->new();
		# Hack commanche
		$res->tcp_timeout(5);
	}
	if (!defined($dom)) {
		$enumerror = "wrong AUS : $aus";
		return ();
	}
	$query = $res->query($dom, "NAPTR");
	if (!$query) { 
		$enumerror = "NAPTR:query failed: " . $res->errorstring;
		return ();
	}
	$order=65536;
	foreach $rr ($query->answer) {
		next unless $rr->type eq "NAPTR";
		next unless ($rr->flags eq "U" || $rr->flags eq "u");
		$uri = &eval_regexp($rr->regexp, $aus);
		if (!defined($uri)) {
			$enumerror .= $rr->regexp . ":" . $eval_regexp_error . "\n";
			next;
		}
		if (!$ignore_order) {
			if ($rr->order < $order) {
				# ignore previous data
				$order = $rr->order;
				@output = ();
			} elsif ($rr->order > $order) {
				# ignore bigger order
				next;
			}
		}

		$es = $rr->service;
		$es =~ y/A-Z/a-z/;
		if ($es =~ /^e2u\+(.+)$/) {
			$es = $1;
		} elsif ($rfc2916service && $es =~ /^(.+)\+e2u$/) {
			$es = $1;
		} else {
			next;
		}
		$ok = 0;
		foreach $i (split(/\+/, $es)) {
			if ($eval_es == 0 || $enumservice{$i} != 0) {
				my %entry;
				$entry{order} = $rr->order;
				$entry{pref} = $rr->preference;
				$entry{service} = $rr->service;
				$entry{servicefound} = $i;
				$entry{uri} = $uri;
				push @output, \%entry;
			}
		}
	}
	if ($ignore_order) {
		return sort { my $tmp;
				($tmp = $a->{order} <=> $b->{order}) == 0 ?
				$a->{pref} <=> $b->{pref} : $tmp }
				@output;
	}
	return sort { $a->{pref} <=> $b->{pref} } @output;
}

1;
__END__

=head1 NAME

ENUM - Perl ENUM resolver

=head1 DESCRIPTION

 ENUM.pm is a ENUM resolver.
 It allows the programmer to perform ENUM DNS queries and DDDS evaluation.
 it resolve ENUM with assigned enumservices and returns URIs.

 See RFC 3401,3402,3403,3404 and rfc2916bis.

=head1 SYMPOSIS

 use ENUM.pm;
 use Net::DNS;

 @ret = &EnumQuery($aus, $enumdomain, $resolver, %enumservice);

 $AUS		ENUM Application Unique String    '+81352972571'
 $enumdomain	ENUM domainname 'e164.arpa' 'e164.jp'
 $resolver	Net::DNS::Resolver->new($nameserver) or undef
 %enumservice	ENUM services	$enumservice{'sip'}=1; or undef
				enumservice must be written in small case.
				non zero required

=head1 RETURN VALUES

  The ENUM_Query() function returns array of structure of query data.
  otherwise the value () is retuened and the global variable $ENUM::enumerror
  is set to indicate the error.

	ret[]->{order}           is order value
	ret[]->{pref}            is preference value
	ret[]->{service}         is service field
	ret[]->{servicefound}    is matched servicename.
	ret[]->{uri}             is URI

=head1 EXAMPLES

 The following examples show how to use the "ENUM" modules.

 Lookup number '+81301234567''s ENUM entry.
 enumservice is 'sip' and 'email:mailto'.
 ENUM domain is '.e164.arpa'
 use default resolver.

	use ENUM;

	my %enumservice = ( 'sip' => 1, 'email:mailto' => 1 );
	my @u = &EnumQuery('+81301234567', '.e164.arpa', undef, %enumservice);
	if (scalar(@u) == 0) {
		print "error: ", $ENUM::enumerror, "\n";
	} else {
		foreach my $r (@u) {
			print "uri is ", $r->{uri}, "\n";
		}
	}

 Lookup number '+81301234567''s ENUM entry. 
 enumservice is 'h323' and 'web:http'.
 ENUM domain is '.e164.jp'
 use another resolver (hostname is my.resolver).

	use ENUM;
	use Net::DNS;

	my %enumservice = ( 'h323' => 1, 'web:http' => 1 );
	my $res = Net::DNS::Resolver->new('my.resolver');
	my @u = &EnumQuery('+81301234567', '.e164.jp', $res, %enumservice);
	foreach my $r (@u) {
		print "uri is ", $r->{uri}, "\n";
	}

=head1 BUGS

 incompatible with DDDS and rfc2916bis
 - not support non-terminal NAPTRs.
 - this library accepts multiple enumservices.
 - this library may return multiple candidates.
 this function interface will be changed soon.

=head1 Changes

 Feb. 15, 2004:  IETF59 enum-wg presentation version.
 March 10, 2004: apply IETF59 meeting agreement.
	- ORDER field MUST be processed first.

=head1 COPYRIGHT

 Copyright (c) 2004  Japan Registry Service Co., LTD.
 Copyright (c) 2004  Kazunori Fujiwara
 All Rights Reserved.

 Author: Kazunori Fujiwara <fujiwara@jprs.co.jp>

=cut
