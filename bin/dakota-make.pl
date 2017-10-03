#!/usr/bin/perl -w
# -*- mode: cperl -*-
# -*- cperl-close-paren-offset: -2 -*-
# -*- cperl-continued-statement-offset: 2 -*-
# -*- cperl-indent-level: 2 -*-
# -*- cperl-indent-parens-as-block: t -*-
# -*- cperl-tab-always-indent: t -*-

use strict;
use warnings;
use sort 'stable';
use Cwd;

my $gbl_prefix;
my $nl = "\n";

sub dk_prefix {
  my ($path) = @_;
  $path =~ s|//+|/|;
  $path =~ s|/\./+|/|;
  $path =~ s|^./||;
  if (-d "$path/bin" && -d "$path/lib") {
    return $path
  } elsif ($path =~ s|^(.+?)/+[^/]+$|$1|) {
    &dk_prefix($path);
  } else {
    die "Could not determine \$prefix from executable path $0: $!" . $nl;
  }
}

BEGIN {
  $gbl_prefix = &dk_prefix($0);
  unshift @INC, "$gbl_prefix/lib";
};
use Carp; $SIG{ __DIE__ } = sub { Carp::confess( @_ ) };

use dakota::dakota;
use dakota::parse;
use dakota::util;

use Data::Dumper;
$Data::Dumper::Terse =     1;
$Data::Dumper::Deepcopy =  1;
$Data::Dumper::Purity =    1;
$Data::Dumper::Useqq =     1;
$Data::Dumper::Sortkeys =  1;
$Data::Dumper::Indent =    1;   # default = 2

use Getopt::Long qw(GetOptionsFromArray);
$Getopt::Long::ignorecase = 0;

sub cmd_info_from_argv {
  my ($argv) = @_;
  my $root_cmd = {
    'opts' => {
    'var' => [],
    }
  };
  &GetOptionsFromArray($argv, $$root_cmd{'opts'},
                       'path-only',
                       'target=s',
                       'var=s',
                      );
  $$root_cmd{'inputs'} = $argv; # this should always be empty
  &set_env_vars($$root_cmd{'opts'}{'var'});
  delete $$root_cmd{'opts'}{'var'};
  if (! $$root_cmd{'opts'}{'path-only'}) {
    my $force;
    $$root_cmd{'parts'} = &parts(&parts_path(), $force = 1);
  }
  return $root_cmd;
}
sub target_o_path {
  my $result = &target_build_dir() . '/target.cc.o';
  return $result;
}
sub is_o_path {
  my ($path) = @_;
  return $path =~ /\.o$/;
}
sub is_target_o_path {
  my ($path) = @_;
  return $path eq &target_o_path();
}
sub o_path_from_dk_path {
  my ($dk_path) = @_;
  my $result = &build_dir() . '/' . &basename($dk_path) . '.o';
  return $result;
}
sub is_exe_path {
  my ($path) = @_;
  my $state = 1;
  $state = 0 if $path =~ /\..+$/;
  return $state;
}
sub gen_dot {
  my ($rules, $out_path) = @_;
  my $result = '';
  $result .= "digraph { graph [ label = \"$out_path\", fontcolor = red ]" . $nl;
  $result .= "  graph [ rankdir = LR, dir = back, nodesep = 0.03 ];" . $nl;
  $result .= "  node  [ shape = rect, style = rounded, height = 0, width = 0 ];" . $nl;
  $result .= $nl;
  $result .= &gen_dot_body($rules);
  $result .= "}" . $nl;
  if (1) { # hack to make the graph less noisy
    my $prefix = $ENV{'HOME'};
    $result =~ s#"$prefix/#"#g;
    $result =~ s#$prefix/#/HOME/#g;
  }
  return $result;
}
sub gen_dot_body {
  my ($rules) = @_;
  my $result = '';
  my $root = $$rules[0][0][0];
  my $target_hdr_path = &target_hdr_path();
  my $target_src_path = &target_src_path();
  my $target_o_path =   &target_o_path();
  if (1) {
  $result .=
    "  \"$root\" [ color = green ];" . $nl .
    "  \"$target_hdr_path\" [ color = magenta ];" . $nl .
    "  \"$target_src_path\" [ color = magenta ];" . $nl .
    "  \"$target_o_path\" [ color = magenta ];" . $nl .
    $nl;
  for (my $i = 0; $i < scalar @$rules; $i++) {
    for (my $j = 0; $j < scalar @{$$rules[$i]}; $j++) {
      for (my $k = 0; $k < scalar @{$$rules[$i][$j]}; $k++) {
        my $path = $$rules[$i][$j][$k];
        if (0) {
        } elsif (&is_dk_path($path)) {
          $result .= "  \"$path\" [ color = blue ];" . $nl;
        } elsif (&is_so_path($path)) {
          $result .= "  \"$path\" [ color = green ];" . $nl;
        }
      }
    }
  }
  }
  foreach my $rule (@$rules) {
    my $tgts =               $$rule[0];
    my $prereqs =            $$rule[1];
    my $order_only_prereqs = $$rule[2];
    foreach my $tgt (@$tgts) {
      foreach my $prereq (@$prereqs) {
        $result .= "  \"$tgt\" -> \"$prereq\"";
        if (&is_o_path($tgt)) {
          $result .= ' [ color = blue ]';
        } elsif ((&is_exe_path($tgt) || &is_so_path($tgt)) && (&is_exe_path($prereq) || &is_so_path($prereq))) {
          $result .= ' [ color = green ]';
        }
        $result .= ';' . $nl;
      }
      foreach my $prereq (@$order_only_prereqs) {
        $result .= "  \"$tgt\" -> \"$prereq\" [ color = gray, style = dashed ]";
        ###
        $result .= ';' . $nl;
      }
    }
  }
  return $result;
}
sub dirs {
  my ($source_dir, $root_source_dir, $root_build_dir) = @_;
  # build_dir
  my $rel_source_dir = $source_dir =~ s#^$root_source_dir/##r;
  my $build_dir = $root_build_dir . '/' . $rel_source_dir;
  # intmd_dir
  my $intmd_dir = &dirname($root_build_dir) . '/intmd/' . $rel_source_dir;
  return ($intmd_dir, $build_dir)
}
sub gen_make {
  my ($rules, $so_paths) = @_;
  my $root_source_dir = $ENV{'root_source_dir'};
  my $source_dir = &source_dir();
  my $intmd_dir =  &intmd_dir();
  my $build_dir =  &build_dir();
  my $result = '';
  my $root_tgt = $$rules[0][0][0];
  my $target_hdr_path = &target_hdr_path();
  my $phony_root_tgt = &basename($root_tgt) =~ s#\.(so|dylib)$##r;
  $result .=
    '# -*- mode: makefile -*-' . $nl .
    $nl .
    '%.ctlg :' . $nl .
    "\t" . 'dakota-catalog --output $@ $<' . $nl .
    $nl .
    '%.ctlg.ast : %.ctlg' . $nl .
    "\t" . 'dakota --action parse --output $@ $<' . $nl .
    $nl;
  my $dirs = {};
  if (&is_so_path($root_tgt)) {
    my $dir = &dirname($root_tgt);
    $$dirs{$dir} = 1;
  }
  foreach my $so_path (@$so_paths) {
    my $dir = &dirname($so_path);
    $$dirs{$dir} = 1;
  }
  foreach my $dir (keys %$dirs) {
    $result .= "\$(shell mkdir -p \$\$HOME/.dkt$dir)" . $nl;
  }
  $result .=
    "\$(shell mkdir -p $intmd_dir/z)" . $nl .
    "\$(shell mkdir -p $build_dir/z)" . $nl .
    $nl .
    "$root_tgt $target_hdr_path : prefix := /Users/robert/dakota" . $nl .
    "$root_tgt $target_hdr_path : source_dir := $source_dir" . $nl .
    "$root_tgt $target_hdr_path : intmd_dir := $intmd_dir" . $nl .
    "$root_tgt $target_hdr_path : build_dir := $build_dir" . $nl .
    $nl .
    ".PHONY : all $phony_root_tgt" . $nl .
    $nl .
    "all : $phony_root_tgt" . $nl .
    "$phony_root_tgt : $root_tgt" . $nl;
  $result .= &gen_make_body($rules);
  return $result;
}
sub gen_make_body {
  my ($rules) = @_;
  my $result = '';
  foreach my $rule (@$rules) {
    my $tgts =               $$rule[0];
    my $prereqs =            $$rule[1];
    my $order_only_prereqs = $$rule[2];
    my $recipes =            $$rule[3];
    my $d = $nl;
    foreach my $tgt (@$tgts) {
      $result .= $d . $tgt;
      $d = " \\\n";
    }
    $result .= ' :';
    foreach my $prereq (@$prereqs) {
      $result .= $d . $prereq;
    }
    if (scalar @$order_only_prereqs) {
      $result .= ' |';
      foreach my $prereq (@$order_only_prereqs) {
        $result .= $d . $prereq;
      }
    }
    $result .= $nl;
    foreach my $recipe (@$recipes) {
      if (scalar @$recipe) {
        $result .= "\t" . join(' ', @$recipe) . $nl;
      }
    }
  }
  return $result;
}
sub write_build_mk {
  my ($str) = @_;
  my $output = &build_mk_path();
  open(my $fh, '>', $output);
  print $fh $str;
  close($fh);
  #print $output . $nl;
  return $output;
}
sub write_build_dot {
  my ($str) = @_;
  my $output = &build_dot_path();
  open(my $fh, '>', $output);
  print $fh $str;
  close($fh);
  #print $output . $nl;
  return $output;
}
sub gen_rules {
  my ($root_tgt, $parts) = @_;
  my $root_source_dir = $ENV{'root_source_dir'};
  my $source_dir = &source_dir();
  my $build_dir =  &build_dir();
  my $dk_paths = [];
  my $so_paths = [];
  my $so_ctlg_ast_paths = [];
  my $dk_o_paths = [];
  my $dk_ast_paths = [];
  foreach my $path (@$parts) {
    if (&is_dk_path($path)) {
      &add_last($dk_paths, $path);
      my $dk_o_path = &o_path_from_dk_path($path);
      &add_last($dk_o_paths, $dk_o_path);
      my $dk_ast_path = &ast_path_from_dk_path($path);
      &add_last($dk_ast_paths, $dk_ast_path);
    } else {
      &add_last($so_paths, $path);
      my $so_ctlg_path =     &ctlg_path_from_so_path($path);
      my $so_ctlg_ast_path = &ast_path_from_ctlg_path($so_ctlg_path);
      &add_last($so_ctlg_ast_paths, $so_ctlg_ast_path);
    }
  }
  my $root_tgt_name = &basename($root_tgt);
  my $root_tgt_type;
  if (&is_so_path($root_tgt)) {
    $root_tgt_type = 'shared-library';
  } else {
    $root_tgt_type = 'executable';
  }
  # -dynamiclib on darwin, -shared on linux
  # -install_name <>, -soname <> AND -rpath <> on linux
  my $gbl_recipes = {
    'parse' =>               [[ 'dakota', '--action', 'parse', "--var=source_dir=\${source_dir}", "--var=build_dir=\${build_dir}", '--output', '$@', '$<' ]],
    'merge' =>               [[ 'dakota', '--action', 'merge', "--var=source_dir=\${source_dir}", "--var=build_dir=\${build_dir}", '--output', '$@', '$?' ]],
    'gen-target-hdr' =>      [[ 'dakota', '--action', 'gen-target-hdr', "--var=source_dir=\${source_dir}", "--var=build_dir=\${build_dir}", '--output', '$@', '$<' ]],
    'gen-target-src' =>      [[ 'dakota', '--action', 'gen-target-src', "--var=source_dir=\${source_dir}", "--var=build_dir=\${build_dir}", '--output', '$@', '$<' ]],
    'compile' =>             [[ 'dakota', '-c', "\@\${prefix}/lib/dakota/compiler.opts", "--var=source_dir=\${source_dir}", "--var=build_dir=\${build_dir}", '--var=cxx=clang++',
                                "-I\${source_dir}", "-I\${prefix}/include", '-o', '$@', '$<' ]],
    'link-shared-library' => [[ 'dakota', '-dynamiclib', "\@\${prefix}/lib/dakota/linker.opts", '--var=cxx=clang++', "-Wl,-rpath,\${prefix}/lib", '-install_name', '@rpath/$(notdir $@)', '-o', '$@', '$^' ]],
    'link-executable' =>     [[ 'dakota', "\@\${prefix}/lib/dakota/linker.opts", '--var=cxx=clang++', "-Wl,-rpath,\${prefix}/lib", '-o', '$@', '$^' ]],
  };
  my $target_o_path =          &target_o_path();
  my $target_src_path =        &target_src_path();
  my $target_hdr_path =        &target_hdr_path();
  my $target_inputs_ast_path = &target_inputs_ast_path();
  my $target_srcs_ast_path =   &target_srcs_ast_path();
  my $rules = [];
  if (&is_so_path($root_tgt)) {
    &add_last($rules, [[$root_tgt], [@$dk_o_paths, $target_o_path, @$so_paths], [],
                       $$gbl_recipes{'link-shared-library'}]);
  } else {
    &add_last($rules, [[$root_tgt], [@$dk_o_paths, $target_o_path, @$so_paths], [],
                       $$gbl_recipes{'link-executable'}]);
  }
  &add_last($rules, [[$target_o_path], [$target_src_path], [$target_hdr_path], # using order-only prereqs
                     $$gbl_recipes{'compile'}]);
  &add_last($rules, [$dk_o_paths, [], [$target_hdr_path], [[]]]); # using order-only prereqs
  &add_last($rules, [[$target_hdr_path], [$target_inputs_ast_path], [],
                     $$gbl_recipes{'gen-target-hdr'}]);
  &add_last($rules, [[$target_src_path], [$target_inputs_ast_path], [],
                     $$gbl_recipes{'gen-target-src'}]);
  &add_last($rules, [[$target_inputs_ast_path], [$target_srcs_ast_path, @$so_ctlg_ast_paths], [],
                     $$gbl_recipes{'merge'}]);
  &add_last($rules, [[$target_srcs_ast_path], [@$dk_ast_paths], [],
                     $$gbl_recipes{'merge'}]);
  foreach my $dk_path (@$dk_paths) {
    my $dk_o_path = &o_path_from_dk_path($dk_path);
    my $dk_ast_path = &ast_path_from_dk_path($dk_path);
    &add_last($rules, [[$dk_o_path], [$dk_path], [],
                       $$gbl_recipes{'compile'}]);
    &add_last($rules, [[$dk_ast_path], [$dk_path], [],
                       $$gbl_recipes{'parse'} ]);
  }
  foreach my $so_path (@$so_paths) {
    my $so_ctlg_path = &ctlg_path_from_so_path($so_path);
    my $so_ctlg_ast_path = &ast_path_from_ctlg_path($so_ctlg_path);
    &add_last($rules, [[$so_ctlg_ast_path], [$so_ctlg_path], [],
                       [[]]]);
    &add_last($rules, [[$so_ctlg_path], [$so_path], [],
                       [[]]]);
  }
  return ($rules, $so_paths);
}
sub start {
  my ($argv) = @_;
  my $cmd_info = &cmd_info_from_argv($argv);
  if ($$cmd_info{'opts'}{'path-only'}) {
    print &build_mk_path() . $nl;
    exit 0;
  }
  my ($intmd_dir, $build_dir) = &dirs(&source_dir(), $ENV{'root_source_dir'}, $ENV{'root_build_dir'});
  $ENV{'intmd_dir'} = $intmd_dir;
  $ENV{'build_dir'} = $build_dir;
  #print &Dumper($cmd_info);
  my ($rules, $so_paths) = &gen_rules($$cmd_info{'opts'}{'target'}, $$cmd_info{'parts'});
  my $build_mk = &gen_make($rules, $so_paths);
  my $out_path = &write_build_mk($build_mk);
  if (1) {
    my $build_dot = &gen_dot($rules, $out_path);
    &write_build_dot($build_dot);
    #print $build_dot;
  }
  #print STDERR &Dumper($rules);
  #print STDERR $build_mk;
}
unless (caller) {
  &start(\@ARGV);
}
1;
