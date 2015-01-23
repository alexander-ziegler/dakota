#!/usr/bin/perl -w
# -*- mode: cperl -*-
# -*- cperl-close-paren-offset: -2 -*-
# -*- cperl-continued-statement-offset: 2 -*-
# -*- cperl-indent-level: 2 -*-
# -*- cperl-indent-parens-as-block: t -*-
# -*- cperl-tab-always-indent: t -*-

use strict;
use warnings;

use Data::Dumper;
$Data::Dumper::Terse     = 1;
$Data::Dumper::Purity    = 1;
$Data::Dumper::Quotekeys = 1;
$Data::Dumper::Indent    = 1;   # default = 2

my $obj = 'obj';
my $SO_EXT = 'dylib';
my $colorscheme = 'dark26';     # needs to have 5 or more colors
my $show_headers = 0;

sub path {
  my ($path) = @_;
  $path =~ s|//|/|g;
  $path =~ s|/\./|/|g;
  $path =~ s|^\./||g;
  $path =~ s|/$||g;
  return $path;
}
sub rdir_name_ext {
  my ($path) = @_;
  $path =~ m|^/?((.+)/)?(.*?)\.(.*)$|;
  my ($rdir, $name, $ext) = ($2, $3, $4);
  die "Error parsing path '$path'" if !$name || !$ext;;
  return ($rdir ||= '.', $name, $ext);
}
sub start {
  my ($opts, $repository) = @_;

  $repository = &path($repository);
  my ($rdir, $name, $ext) = &rdir_name_ext($repository);
  my $graph_name = &path("$rdir/$name");

  my $result = `../bin/dakota-project name --repository $repository --var SO_EXT=$SO_EXT`;
  chomp $result;

  my $so_files = [split("\n", `../bin/dakota-project libs --repository $repository --var SO_EXT=$SO_EXT`)];
  my $dk_files = [split("\n", `../bin/dakota-project srcs --repository $repository`)];

  my $input_files = [ @$so_files, @$dk_files ];

  sub add_edge
    {
      my ($tbl, $e1, $e2, $attr) = @_;

      if (!exists $$tbl{$e1}) {
        $$tbl{$e1} = {};
      }
      if (!exists $$tbl{$e1}{$e2}) {
        $$tbl{$e1}{$e2} = $attr;
      }
    }

  my $edges = {};

  ($rdir, $name, $ext) = &rdir_name_ext($result);
  my $rt_rep_file = &path("$obj/rt/$rdir/$name.rep");
  my $rt_hh_file =  &path("$obj/rt/$rdir/$name.hh");
  my $rt_cc_file =  &path("$obj/rt/$rdir/$name.cc");
  my $rt_o_file =   &path("$obj/rt/$rdir/$name.o");

  my $rt_files = {};

  if ($show_headers) {
    $$rt_files{$rt_hh_file} = undef;
  }
  $$rt_files{$rt_cc_file} = undef;

  foreach my $so_file (@$so_files) {
    my ($rdir, $name, $ext) = &rdir_name_ext($so_file);
    my $ctlg_file = &path("$obj/$rdir/$name.ctlg");
    my $rep_file =  &path("$obj/$rdir/$name.rep");

    &add_edge($edges, $ctlg_file,   $so_file,   1);
    &add_edge($edges, $rep_file,    $ctlg_file, 2);
    &add_edge($edges, $rt_rep_file, $rep_file,  3);
  }
  my $dk_cc_files = {};
  my $nrt_rep_files = {};
  my $nrt_src_files = {};
  my $o_files = {};

  foreach my $dk_file (@$dk_files) {
    my ($rdir, $name, $ext) = &rdir_name_ext($dk_file);
    my $nrt_rep_file = &path("$obj/$rdir/$name.rep");
    my $dk_cc_file =   &path("$obj/$rdir/$name.cc");
    my $nrt_hh_file =  &path("$obj/nrt/$rdir/$name.hh");
    my $nrt_cc_file =  &path("$obj/nrt/$rdir/$name.cc");
    my $nrt_o_file =   &path("$obj/nrt/$rdir/$name.o");

    $$dk_cc_files{$dk_cc_file} = undef;

    $$nrt_src_files{$dk_cc_file} = undef;
    if ($show_headers) {
      $$nrt_src_files{$nrt_hh_file} = undef;
    }
    $$nrt_src_files{$nrt_cc_file} = undef;

    $$nrt_rep_files{$nrt_rep_file} = undef;
    $$o_files{$nrt_o_file} = undef;

    &add_edge($edges, $nrt_rep_file, $dk_file,     1);
    &add_edge($edges, $dk_cc_file,   $dk_file,     4);
    if (1) {
      &add_edge($edges, $dk_cc_file,   $rt_rep_file, 0); # gray, dashed
      &add_edge($edges, $nrt_cc_file,  $rt_rep_file, 0); # gray, dashed
    }
    &add_edge($edges, $nrt_o_file,   $dk_cc_file,  5);

    if ($show_headers) {
      &add_edge($edges, $nrt_hh_file, $rt_rep_file,  0); # gray, dashed
      &add_edge($edges, $nrt_hh_file, $nrt_rep_file, 4);
      &add_edge($edges, $nrt_o_file,  $nrt_hh_file,  5);
    }

    &add_edge($edges, $nrt_cc_file,  $nrt_rep_file, 4);
    &add_edge($edges, $nrt_o_file,   $nrt_cc_file,  5);
  }
  foreach my $nrt_rep_file (sort keys %$nrt_rep_files) {
    &add_edge($edges, $rt_rep_file, $nrt_rep_file, 3);
  }
  if ($show_headers) {
    &add_edge($edges, $rt_hh_file, $rt_rep_file, 4);
    &add_edge($edges, $rt_o_file,  $rt_hh_file, 5);
  }

  &add_edge($edges, $rt_cc_file, $rt_rep_file, 4);
  &add_edge($edges, $rt_o_file,  $rt_cc_file, 5);

  foreach my $o_file (sort keys %$o_files) {
    &add_edge($edges, $result, $o_file, 0); # black indicates no concurrency (linking)
  }
  &add_edge($edges, $result, $rt_o_file, 0); # black indicates no concurrency (linking)

  my $filestr = '';
  $filestr .=
      "digraph \"$graph_name\" {\n" .
      "  graph [ label = \"\\G\", fontcolor = red ];\n" .
      "  graph [ page = \"8.5,11\", size = \"7.5,10\" ];\n" .
      "  graph [ rankdir = RL ];\n" .
      "  edge  [ ];\n" .
      "  node  [ shape = rect, style = rounded, height = 0.25 ];\n" .
      "\n" .
      "  \"$result\" [ style = none ];\n" .
      "\n";
if ($show_headers) {
  $filestr .= "  \"$rt_hh_file\" [ colorscheme = $colorscheme, color = 4 ];\n";
}
$filestr .= "  \"$rt_cc_file\" [ colorscheme = $colorscheme, color = 4 ];\n";
$filestr .= "\n";

foreach my $so_file (sort @$so_files) {
  $filestr .= "  \"$so_file\" [ style = none ];\n";
}
$filestr .= "\n";
foreach my $dk_cc_file (sort keys %$dk_cc_files) {
  $filestr .= "  \"$dk_cc_file\" [ style = \"rounded,bold\" ];\n";
}
$filestr .= "\n";
foreach my $e1 (sort keys %$edges) {
  my ($e2, $attr);
  while (($e2, $attr) = each %{$$edges{$e1}}) {
    $filestr .= "  \"$e1\" -> \"$e2\"";
    if (exists $$nrt_src_files{$e1} && $rt_rep_file eq $e2) {
      $filestr .= " [ style = dashed, color = gray ]";
    } elsif ($attr) {
      $filestr .= " [ colorscheme = $colorscheme, color = $attr ]";
    }
    $filestr .= ";\n"
  }
}
$filestr .=
  "\n" .
  "  subgraph {\n" .
  "    rank = same;\n" .
  "\n";
foreach my $input_file (sort @$input_files) {
  $filestr .= "    \"$input_file\";\n";
}
$filestr .= "  }\n";
$filestr .= "}\n";

if ($$opts{'output'}) {
  open OUTPUT, ">$$opts{'output'}" or die __FILE__, ":", __LINE__, ": ERROR: $$opts{'output'}: $!\n";
  print OUTPUT $filestr;
  close OUTPUT;
} else {
  print $filestr;
}

($rdir, $name, $ext) = &rdir_name_ext($repository);
my $make_targets = "$rdir/$name.mk";

open FILE, ">$make_targets" or die __FILE__, ":", __LINE__, ": ERROR: $make_targets: $!\n";
foreach my $e1 (sort keys %$edges) {
  print FILE "$e1:\\\n";
  my ($e2, $attr);
  foreach my $e2 (sort keys %{$$edges{$e1}}) {
    #my $attr = $$edges{$e1}{$e2};
    print FILE " $e2\\\n";
  }
  print FILE "#\n"
}
close FILE;
}

unless (caller) {
  use Getopt::Long;
  $Getopt::Long::ignorecase = 0;
  my $opts = {};
  &GetOptions($opts,
              'output=s');
  die "Too many args." if @ARGV > 1;
  my $repository;

  if (@ARGV == 1) {
    $repository = $ARGV[0];
  } else {
    $repository = 'dummy-project.rep';
  }
  &start($opts, $repository);
}

1;
