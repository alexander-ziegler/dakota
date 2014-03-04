#!/usr/bin/perl -w

use strict;

use Data::Dumper;

undef $/;
my $ops = [];

while (<>)
{
    push @$ops, split /\s/;
}
#print Dumper $ops;

my $tree = {};

my $op;
foreach $op (@$ops)
{
    my $chars = [split //, $op];
    &add_subtbl($tree, $chars);
    #print Dumper $tree;
}
#print Dumper $tree;
#exit 0;
my $col = 1;
$" = '';
&switch_with_arg($tree, 1, $col, []);

sub add_subtbl
{
    my ($tbl, $chars) = @_;
    if (@$chars)
    {
	my $char = shift @$chars;
	if (@$chars)
	{
	    if (!exists $$tbl{$char})
	    {
		$$tbl{$char} = {};
	    }
	    &add_subtbl($$tbl{$char}, $chars);
	}
	else
	{
	    $$tbl{$char} = {};
	}
    }
}

sub colprint
{
    my ($col_num, $string) = @_;
    my $result_str = '';
    $col_num *= 2;
    $result_str .= ' ' x $col_num;
    $result_str .= $string;
    print $result_str;
}
sub colprintln
{
    my ($col_num, $string) = @_;
    my $line = $string;
    $line .= "\n";
    &colprint($col_num, $line);
}

sub switch_with_arg
{
    my ($tbl, $argnum, $col, $chars) = @_;

    my $c = "c$argnum";

    &colprintln($col, "char-t $c = get-char(self);");
    &colprintln($col, "switch ($c)");
    &colprintln($col, "{");
    $col++;
    
    my $firsts = [sort keys %$tbl]; # order lexically

    my ($first, $rest);
    #while (($first, $rest) = each (%$tbl))
    foreach $first (@$firsts)
    {
	$rest = $$tbl{$first};
	push @$chars, $first;
	&colprintln($col, "case '$first':");
	&colprintln($col, "{");
	$col++;
	if ($rest && keys %$rest)
	{
	    $argnum++;
	    &switch_with_arg($rest, $argnum, $col, $chars);
	    $argnum--;
	}
	#&colprintln($col, "// '@$chars'");
	&colprintln($col, "return make(token:klass, \$tokenid = \$'@$chars');");
	$col--;
	#&colprintln($col, "} // case '$first':");
	&colprintln($col, "}");
	pop @$chars;
    }
    $col--;
    #&colprintln($col, "} // switch ($c)");
    &colprintln($col, "}");
    &colprintln($col, "unget-char(self, $c);");
}
