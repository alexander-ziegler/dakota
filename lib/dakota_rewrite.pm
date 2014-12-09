#!/usr/bin/perl -w
# -*- mode: cperl -*-
# -*- cperl-close-paren-offset: -2 -*-
# -*- cperl-continued-statement-offset: 2 -*-
# -*- cperl-indent-level: 2 -*-
# -*- cperl-indent-parens-as-block: t -*-
# -*- cperl-tab-always-indent: t -*-

# Copyright (C) 2007-2015 Robert Nielsen <robert@dakota.org>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

my $prefix;

BEGIN {
  $prefix = '/usr/local';
  if ($ENV{'DK_PREFIX'}) {
    $prefix = $ENV{'DK_PREFIX'};
  }
  unshift @INC, "$prefix/lib";
};

package dakota;

use strict;
use warnings;

use dakota;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT= qw(
                 convert_dash_syntax
                 convert_dk_to_cxx
                 decode
                 encode
              );

my $ENCODED_COMMENT_BEGIN = '__ENCODED_COMMENT_BEGIN__';
my $ENCODED_COMMENT_END =   '__ENCODED_COMMENT_END__';

my $ENCODED_STRING_BEGIN = '__ENCODED_STRING_BEGIN__';
my $ENCODED_STRING_END =   '__ENCODED_STRING_END__';

$main::block = qr{
                   \{
                   (?:
                     (?> [^{}]+ )         # Non-braces without backtracking
                   |
                     (??{ $main::block }) # Group with matching braces
                   )*
                   \}
               }x;

$main::block_in = qr{
                      (?:
                        (?> [^{}]+ )         # Non-braces without backtracking
                      |
                        (??{ $main::block }) # Group with matching braces
                      )*
                  }x;

$main::list = qr{
                  \(
                  (?:
                    (?> [^()]+ )         # Non-parens without backtracking
                  |
                    (??{ $main::list }) # Group with matching parens
                  )*
                  \)
              }x;

$main::list_in = qr{
                     (?:
                       (?> [^()]+ )         # Non-parens without backtracking
                     |
                       (??{ $main::list }) # Group with matching parens
                     )*
                 }x;

$main::seq = qr{
                 \[
                 (?:
                   (?> [^\[\]]+ )         # Non-parens without backtracking
                 |
                   (??{ $main::seq }) # Group with matching parens
                 )*
                 \]
             }x;

# same code in dakota.pl and parser.pl
my $k  = qr/[_A-Za-z0-9-]/;
my $z  = qr/[_A-Za-z]$k*[_A-Za-z0-9]?/;
my $t  = qr/[_A-Za-z0-9-\+\/\*()\[\].,: ]/;
my $wk = qr/[_A-Za-z]$k*[A-Za-z0-9_]/; # dakota identifier
my $ak = qr/::?$k+/;            # absolute scoped dakota identifier
my $rk = qr/$k+$ak*/;           # relative scoped dakota identifier
my $d = qr/\d+/;                # relative scoped dakota identifier
my $mx = qr/\!|\?/;
my $m  = qr/$z$mx?/;
my $msig_type = qr/object-t|slots-t|slots-t\s*\*/;
my $msig = qr/(va:)?$m(\($msig_type?\))?/;
my $h  = qr|[/._A-Za-z0-9-]|;

# not-escaped " .*? not-escaped "
my $dqstr = qr/(?<!\\)".*?(?<!\\)"/;

# not-escaped ' .*? not-escaped '
my $sqstr = qr/(?<!\\)'.*?(?<!\\)'/;

# same as in dakota_generate.pm
my $long_suffix = {
                   '?' => 'p',
                   '!' => 'd'
                  };

$main::list_body = qr{
                       (?:
                         (?> [^()]+ )         # Non-parens without backtracking
                       |
                         (??{ $main::list }) # Group with matching parens
                       )*
                   }x;

my $rewrite_compound_literal_names = {
                                      'super' => undef,
                                      'assoc' => undef,
                                      'sequence' => undef,
                                      'vector' => undef,
                                     };

my $use_compound_literals = $ENV{'DK_USE_COMPOUND_LITERALS'};
sub rewrite_compound_literal {
  my ($filestr_ref) = @_;
  foreach my $name (keys %$rewrite_compound_literal_names) {
    if ($use_compound_literals) {
      $$filestr_ref =~ s|(?<!$k)($name)(\s*)\(($main::list_body)\)|cast($1:slots-t)$2\{$3\}|g;
    } else {
      $$filestr_ref =~ s|(?<!$k)($name)(\s*)\(($main::list_body)\)|$1:construct$2($3)|g;
    }
  }
}
sub rewrite_compound_literal_cstring {
  my ($filestr_ref) = @_;
  my $name = 'cstring';

  if ($use_compound_literals) {
    $$filestr_ref =~ s|(?<!$k)($name)(\s*)\((\".*?\")\)|cast($1:slots-t)$2\{$3, sizeof($3) - 1\}|g;
  } else {
    $$filestr_ref =~ s|(?<!$k)($name)(\s*)\((\".*?\")\)|$1:construct$2($3, sizeof($3) - 1)|g;
  }
}
sub rewrite_compound_literal_cstring_null {
  my ($filestr_ref) = @_;
  my $name = 'cstring';

  if ($use_compound_literals) {
    $$filestr_ref =~ s|($name)-null|cast($1:slots-t)\{nullptr, 0\}|g;
  } else {
    $$filestr_ref =~ s|($name)-null|$1:construct(nullptr, 0)|g;
  }
}
sub concat1 {
  my ($result_ref, $str) = @_;
  $$result_ref .= $str;
}
sub concat3 {
  my ($result_ref, $s1, $s2, $s3) = @_;
  &concat1($result_ref, "$s1$s2$s3");
}
sub concat5 {
  my ($result_ref, $s1, $s2, $s3, $s4, $s5) = @_;
  &concat1($result_ref, "$s1$s2$s3$s4$s5");
}
sub encode_str5 {
  my ($result_ref, $s1, $s2, $s3, $s4, $s5) = @_;
  &concat5($result_ref, $s1, $s2, unpack('H*', $s3), $s4, $s5);
}
sub encode_comments3 {
  my ($result_ref, $s1, $s2, $s3) = @_;
  &concat5($result_ref, $s1, $ENCODED_COMMENT_BEGIN, unpack('H*', $s2), $ENCODED_COMMENT_END, $s3);
}
sub encode_str1 {
  my ($result_ref, $s) = @_;
  $s =~ m/^(.)(.*?)(.)$/;
  my ($s1, $s2, $s3) = ($1, $2, $3);
  &encode_str3($result_ref, $s1, $s2, $s3);
}
sub encode_strings1 {
  my ($result_ref, $s) = @_;
  $s =~ m/^(.)(.*?)(.)$/;
  my ($s1, $s2, $s3) = ($1, $2, $3);
  &encode_str5($result_ref, $s1, $ENCODED_STRING_BEGIN, $s2, $ENCODED_STRING_END, $s3);
}
sub encode {
  my ($filestr_ref) = @_;
  &encode_comments($filestr_ref);
  &encode_strings($filestr_ref);
}
sub encode_comments {
  my ($filestr_ref) = @_;
  my $result = '';
  while (1) {
    if (0) {}
    elsif ($$filestr_ref =~ m|\G(//)(.*?)(\n)|gcs)   { &encode_comments3(\$result, $1, $2, $3); }
    elsif ($$filestr_ref =~ m|\G(/\*)(.*?)(\*/)|gcs) { &encode_comments3(\$result, $1, $2, $3); }
    elsif ($$filestr_ref =~ m|\G($dqstr)|gc)         { &concat1(\$result, $1);                  }
    elsif ($$filestr_ref =~ m|\G(.)|gcs)             { &concat1(\$result, $1);                  }
    else                                             { last; }
  }
  $$filestr_ref =  $result;
}
sub encode_strings_dq {
  my ($filestr_ref) = @_;
  my $result = '';
  while (1) {
    if (0) {}
    elsif ($$filestr_ref =~ m|\G(//)(.*?)(\n)|gcs)   { &concat3(\$result, $1, $2, $3); }
    elsif ($$filestr_ref =~ m|\G(/\*)(.*?)(\*/)|gcs) { &concat3(\$result, $1, $2, $3); }
    elsif ($$filestr_ref =~ m|\G(<$h+>)|gc)          { &encode_strings1(\$result, $1); }
    elsif ($$filestr_ref =~ m|\G($dqstr)|gc)         { &encode_strings1(\$result, $1); }
    elsif ($$filestr_ref =~ m|\G(.)|gcs)             { &concat1(\$result, $1);         }
    else                                             { last; }
  }
  $$filestr_ref =  $result;
}
sub encode_strings_sq {
  my ($filestr_ref) = @_;
  my $result = '';
  while (1) {
    if (0) {}
    elsif ($$filestr_ref =~ m|\G(//)(.*?)(\n)|gcs)   { &concat3(\$result, $1, $2, $3); }
    elsif ($$filestr_ref =~ m|\G(/\*)(.*?)(\*/)|gcs) { &concat3(\$result, $1, $2, $3); }
    elsif ($$filestr_ref =~ m|\G($sqstr)|gc)         { &encode_strings1(\$result, $1); }
    elsif ($$filestr_ref =~ m|\G(.)|gcs)             { &concat1(\$result, $1);         }
    else                                             { last; }
  }
  $$filestr_ref =  $result;
}
sub encode_strings {
  my ($filestr_ref) = @_;
  &encode_strings_dq($filestr_ref);
  &encode_strings_sq($filestr_ref);
}
sub decode {
  my ($filestr_ref) = @_;
  &decode_comments($filestr_ref);
  &decode_strings($filestr_ref);
}
sub decode_comments {
  my ($filestr_ref) = @_;
  $$filestr_ref =~ s{$ENCODED_COMMENT_BEGIN([A-Za-z0-9]*)$ENCODED_COMMENT_END}{pack('H*',$1)}gseo;
}
sub decode_strings {
  my ($filestr_ref) = @_;
  $$filestr_ref =~ s{$ENCODED_STRING_BEGIN([A-Za-z0-9]*)$ENCODED_STRING_END}{pack('H*',$1)}gseo;
}
sub nest_namespaces {
  my ($filestr_ref) = @_;
  foreach my $kind ('klass', 'trait', 'namespace') {
    while ($$filestr_ref =~ s/$kind(\s+):?($k+):($rk)(\s*)($main::block)/namespace $2 { $kind$1$3$4$5 }/gs) {
    }
  }
}
sub rewrite_klass_decl {
  my ($filestr_ref) = @_;
  $$filestr_ref =~ s=(\b(klass|trait)\s+$k+\s*;)=/*$1*/=g;
}
sub rewrite_klass_initialize {
  my ($filestr_ref) = @_;
  $$filestr_ref =~ s=(object-t\s+initialize\s*\()=noexport $1=g;
}
sub rewrite_klass_finalize {
  my ($filestr_ref) = @_;
  $$filestr_ref =~ s=(object-t\s+finalize\s*\()=noexport $1=g;
}
sub rewrite_klass_defn {
  my ($filestr_ref) = @_;
  $$filestr_ref =~ s/\b(klass|trait)(\s+$k+\s*\{)/namespace$2/g;
}
sub rewrite_dk_klass {
  my ($filestr_ref) = @_;
  $$filestr_ref =~ s|dk:+klass\(|dkt-klass(|g;
}
sub rewrite_selsig_replacement {
  my ($aa, $bb) = @_;
  my $cxx_ident = $$long_suffix{$bb};
  my $result = "$aa$cxx_ident";
  return $result;
}
sub rewrite_signatures {
  my ($filestr_ref) = @_;
  $$filestr_ref =~ s/(?<!$k)(dkt-signature\s*\(.*?)(\()/$1,$2/g;
  $$filestr_ref =~ s/(?<!$k)(dkt-signature\s*\(\s*$rk)(\!|\?)/&rewrite_selsig_replacement($1, $2)/ge;
  $$filestr_ref =~ s/(?<!$k)(dkt-signature\s*\($rk)\s*,\s*,/$1,/g; # hackhack

  $$filestr_ref =~ s/(?<!$k)(dkt-ka-signature\s*\(.*?)(\()/$1,$2/g;
  $$filestr_ref =~ s/(?<!$k)(dkt-ka-signature\s*\(\s*$rk)(\!|\?)/&rewrite_selsig_replacement($1, $2)/ge;
  $$filestr_ref =~ s/(?<!$k)(dkt-ka-signature\s*\($rk)\s*,\s*,/$1,/g; # hackhack

  $$filestr_ref =~ s/(?<!$k)(dkt-raw-signature\s*\(.*?)(\()/$1,$2/g;
  $$filestr_ref =~ s/(?<!$k)(dkt-raw-signature\s*\(\s*$rk)(\!|\?)/&rewrite_selsig_replacement($1, $2)/ge;
  $$filestr_ref =~ s/(?<!$k)(dkt-raw-signature\s*\($rk)\s*,\s*,/$1,/g; # hackhack
}
sub rewrite_selectors {
  my ($filestr_ref) = @_;
  $$filestr_ref =~ s/(?<!$k)(selector\s*\(.*?)(\()/$1,$2/g;
  $$filestr_ref =~ s/(?<!$k)(selector\s*\(\s*$rk)(\!|\?)/&rewrite_selsig_replacement($1, $2)/ge;

  $$filestr_ref =~ s/(?<!$k)(selector\s*\($rk)\s*,\s*,/$1,/g; # hackhack
  ###
  $$filestr_ref =~ s/(?<!$k)(__selector\s*\(.*?)(\()/$1,$2/g;
  $$filestr_ref =~ s/(?<!$k)(__selector\s*\(\s*$rk)(\!|\?)/&rewrite_selsig_replacement($1, $2)/ge;

  $$filestr_ref =~ s/(?<!$k)(__selector\s*\($rk)\s*,\s*,/$1,/g; # hackhack
}
sub rewrite_method_names_special_replacement {
  my ($aa, $bb, $cc) = @_;
  my $cxx_ident = $$long_suffix{$bb};
  my $result = "$aa$cxx_ident$cc";
  return $result;
}
sub rewrite_method_names_special {
  my ($filestr_ref) = @_;
  $$filestr_ref =~ s/(:+$k+)(\!|\?)(\),)/&rewrite_method_names_special_replacement($1, $2, $3)/ge;
}
sub rewrite_includes {
  my ($filestr_ref) = @_;
  $$filestr_ref =~ s|(?<!\#)( *include)(\s*\".*?\"\s*);|\#include$2|g;
  $$filestr_ref =~ s|(?<!\#)( *include)(\s*<.*?>\s*);|\#include$2|g;
}
sub rewrite_declarations {
  my ($filestr_ref) = @_;
  $$filestr_ref =~ s|(?<!$k)(\s+)(interpose\s+[^%;]+\s*;)|$1/*$2*/|gs;
  $$filestr_ref =~ s|(?<!$k)(\s+)(superklass\s+$rk\s*;)|$1/*$2*/|gs;
  $$filestr_ref =~ s|(?<!$k)(\s+)(klass\s+$rk\s*;)|$1/*$2*/|gs;
  $$filestr_ref =~ s|(?<!$k)(\s+)(trait\s+$rk\s*;)|$1/*$2*/|gs;
  $$filestr_ref =~ s|(?<!$k)(\s+)(provide\s+$rk\s*;)|$1/*$2*/|gs;
  $$filestr_ref =~ s|(?<!$k)(\s+)(require\s+$rk\s*;)|$1/*$2*/|gs;
}

my $catch_block  = qr/catch\s*\(\s*$rk?:klass\s*$k*\s*\)\s*($main::block)/;
my $catch_object = qr/\}(\s*$catch_block)+/;
sub rewrite_catch_block {
  my ($cond, $str_in) = @_;
  my $str_out = '';

  while (1) {
    if ($str_in =~ m/\Gcatch\s*\(\s*($rk?:klass)\s*($k*)\s*\)(\s*)\{/gc) {
      if (0 != length $2) {
        $str_out .= "$cond(dk:instance?(_e, $1))$3\{ object-t $2 = _e;";
      } else {
        $str_out .= "$cond(dk:instance?(_e, $1))$3\{";
      }
    } elsif ($str_in =~ m/\G(.)/gc) {
      $str_out .= $1;
    } elsif ($str_in =~ m/\G(\n)/gc) {
      $str_out .= $1;
    } else {
      last;
    }
  }
  return $str_out;
}
sub rewrite_finally {
  my ($filestr_ref) = @_;
  local $_ = $$filestr_ref;
  my $filestr = ''; # should call $filestr/$filestr_ref

  while (1) {
    if (m/\G(\s*)(try.*?\s*)finally(\s*)($main::block)/gsc) {
      $filestr .= "$1\{ $2struct finally_t { ~finally_t()$3$4} unused finally; }";
    } elsif (m/\G(.)/gc) {
      $filestr .= $1;
    } elsif (m/\G(\n)/gc) {
      $filestr .= $1;
    } else {
      last;
    }
  }
  return \$filestr;
}
sub rewrite_catch_object {
  my ($str_in) = @_;
  my $str_out = '';
  my $cond = 'if';

  while (1) {
    if ($str_in =~ m/\G($catch_block)/gc) {
      $str_out .= &rewrite_catch_block($cond, $1);
      $cond = 'else if';
    } elsif ($str_in =~ m/\G(.)/gc) {
      $str_out .= $1;
    } elsif ($str_in =~ m/\G(\n)/gc) {
      $str_out .= $1;
    } else {
      last;
    }
  }
  $str_out =~ s/^\}/\} catch(object-t _e) {/;
  $str_out =~ s/\}$/\} else { throw; } }/;
  return $str_out;
}
sub rewrite_exceptions {
  my ($filestr_ref) = @_;
  local $_ = $$filestr_ref;
  my $filestr = '';             # should call $filestr/$filestr_ref

  while (1) {
    if (m/\G($catch_object)/gc) {
      $filestr .= &rewrite_catch_object($1);
    } elsif (m/\G(.)/gc) {
      $filestr .= $1;
    } elsif (m/\G(\n)/gc) {
      $filestr .= $1;
    } else {
      last;
    }
  }
  return \$filestr;
}
sub convert_dash_syntax {
  my ($str1, $str2) = @_;
  $str2 =~ s/-/_/g;
  return "$str1$str2";
}
sub rewrite_syntax {
  my ($filestr_ref) = @_;
  $$filestr_ref =~ s/($z)\?/$1$$long_suffix{'?'}/g;
  $$filestr_ref =~ s/($z)\!/$1$$long_suffix{'!'}/g;

  $$filestr_ref =~ s/([a-zA-Z0-9])(-+)(?=[a-zA-Z0-9])/&convert_dash_syntax($1, $2)/ge;
  $$filestr_ref =~ s/([^:]):(?=[_a-zA-Z])/$1::/g;
}
sub vars_from_defn {
  my ($defn, $name, $params, $ka_generics) = @_;
  my $result = '';
  $result .= $defn;

  $params =~ s|\s+| |gs;

  if (0) {
    $result .= "//";
  }

  if (!exists $$ka_generics{$name}) { # hackhack
    $result .= " unused /*static*/ const signature-t* __signature__ = dkt-signature($name,($params));";
  } else {
    # replace keyword args with va-list-t
    $params =~ s|,[^,]+?/\*=>.*?\*/||g;
    $params .= ", va-list-t";
    $result .= " unused /*static*/ const signature-t* __signature__ = dkt-ka-signature(va:$name,($params));";
  }
  $result .= " unused /*static*/ const char8-t* __method__ = __signature__->name;";
  return $result;
}
sub rewrite_functions_replacement {
  my ($aa, $bb, $cc) = @_;
  my $cxx_ident = $$long_suffix{$bb};
  my $result = "$aa$cxx_ident$cc";
  return $result;
}
sub rewrite_functions {
  my ($filestr_ref) = @_;
  $$filestr_ref =~ s/(dk:$k+)(\!|\?)/&rewrite_functions_replacement($1, $2, '')/ges;
  $$filestr_ref =~ s/($k+)(\!|\?)(\()/&rewrite_functions_replacement($1, $2, $3)/ges;
}
sub rewrite_methods {
  my ($filestr_ref, $ka_generics) = @_;
  $$filestr_ref =~ s|(method\s+)(alias\($k+\))|$1/*$2*/|gs; #hackhack

  $$filestr_ref =~ s/klass method/klass_method/gs;           #hackhack
  $$filestr_ref =~ s/namespace method/namespace_method/gs;   #hackhack

  $$filestr_ref =~ s|(method\s+[^(]*?($rk)\((object-t self.*?)\)\s*\{)|&vars_from_defn($1, $2, $3, $ka_generics)|ges;
  $$filestr_ref =~ s|(?<!export)(\s)(method)(\s+)|$1 /*$2*/$3|gm;
  $$filestr_ref =~ s|export(\s)(method)(\s+)|export$1/\*$2\*/$3|gs;

  $$filestr_ref =~ s/klass_method/klass method/gs;           #hackhack
  $$filestr_ref =~ s/namespace_method/namespace method/gs;   #hackhack
}
sub rewrite_throws {
  my ($filestr_ref) = @_;
  # throw "..."
  # throw $foo
  # throw $"..." ;
  # throw $[...] ;
  # throw ${...} ;
  # throw box(...) ;
  # throw foo:box(...) ;
  # throw make(...) ;
  # throw klass ;
  # throw self ;
  #
  # not in parens
  $$filestr_ref =~ s/\bthrow(\s*\$\")/dkt-throw$1/gs;
  $$filestr_ref =~ s/\bthrow(\s*\$\[)/dkt-throw$1/gs;
  $$filestr_ref =~ s/\bthrow(\s*\$\{)/dkt-throw$1/gs;
  $$filestr_ref =~ s/\bthrow(\s+)(box\s*\()/$1dkt-throw$2/gs;
  $$filestr_ref =~ s/\bthrow(\s+)(make\s*\()/$1dkt-throw$2/gs;
  $$filestr_ref =~ s/\bthrow(\s+)(klass\s*;)/$1dkt-throw$2/gs;
  $$filestr_ref =~ s/\bthrow(\s+)(self\s*;)/$1dkt-throw$2/gs;
  # in parens
  $$filestr_ref =~ s/\bthrow(\s*\(\s*\$\")/dkt-throw$1/gs;
  $$filestr_ref =~ s/\bthrow(\s*\(\s*\$\[)/dkt-throw$1/gs;
  $$filestr_ref =~ s/\bthrow(\s*\(\s*\$\{)/dkt-throw$1/gs;
  $$filestr_ref =~ s/\bthrow(\s*\(\s*box\s*\()/dkt-throw$1/gs;
  $$filestr_ref =~ s/\bthrow(\s*\(\s*make\s*\()/dkt-throw$1/gs;
  $$filestr_ref =~ s/\bthrow(\s*\(\s*klass\s*\)\s*;)/dkt-throw$1/gs;
  $$filestr_ref =~ s/\bthrow(\s*\(\s*self\s*\)\s*;)/dkt-throw$1/gs;

  # throw "...";
  # throw("...");
  # throw $foo-bar;
  # throw($foo-bar);
  $$filestr_ref =~ s/\bthrow(\s*)(".*?"\s*);/$1dkt-throw$2;/gs;
  $$filestr_ref =~ s/\bthrow(\s*\(\s*".*?"\s*\)\s*);/dkt-throw$1;/gs;
  $$filestr_ref =~ s/\bthrow(\s*)(\$$z\s*);/$1dkt-throw$2;/gs;
  $$filestr_ref =~ s/\bthrow(\s*\(\s*\$$z\s*\)\s*);/dkt-throw$1;/gs;
  # add parens if absent
  $$filestr_ref =~ s/\bdkt-throw(\s*)(?!\()(.+?);/dkt-throw$1($2);/gs;
}
sub rewrite_slots {
  # does not deal with comments containing '{' or '}' between the { }
  my ($filestr_ref) = @_;
  #$$filestr_ref =~ s{(import|export|noexport)(\s+)(slots\s+)}{/*$1*/$2$3}g;
  $$filestr_ref =~ s/(?<!\$)\bslots(\s+)(struct|union|enum)(\s*$main::block)/$2$1slots-t$3;/gs;
  $$filestr_ref =~ s/(?<!\$)\bslots(\s+)(struct|union|enum)(\s*;)/$2$1slots-t$3/gs;
  $$filestr_ref =~ s/(?<!\$)\bslots(\s+$t+?)(\s*;)/typedef$1 slots-t$2/gs;
}
sub rewrite_set_literal {
  my ($filestr_ref) = @_;
  $$filestr_ref =~ s/\$\{(.*?)\}/&rewrite_set_literal_both_replacement($1)/ge;
}
sub rewrite_set_literal_both_replacement {
  my ($body) = @_;
  if ($body =~ m|=>|) {
    $body =~ s|^\s*=>\s*$||s;
    return &rewrite_table_literal_replacement($body);
  } else {
    return &rewrite_list_literal_replacement($body, 'SET');
  }
}
sub trim {
  my ($str) = @_;
  $str =~ s/^\s+//;
  $str =~ s/\s+$//;
  return $str;
}
sub rewrite_table_literal_replacement {
  my ($body) = @_;
  my $result = '';
  $result .= "make(DEFAULT-TABLE-KLASS";

  my $assocs = [split /,/, $body];
  if (0 != @$assocs && '' ne $$assocs[0]) {
    $result .= ", items => (object-t[]){ ";
    foreach my $assoc (@$assocs) {
      my ($key, $element) = split /=>/, $assoc;
      $key = &trim($key);
      $element = &trim($element);

      #print STDERR "key=$key, element=$element\n";

      # key
      if ($key =~ m/^\$/ || $key =~ m/^__symbol:/) {
        $result .= "assoc:box({symbol:box($key), ";
      } elsif ($key =~ m/^\"/) {
        $result .= "assoc:box({str:box($key), ";
      } else {
        $result .= "assoc:box({box($key), ";
      }

      # element
      if ($element =~ m/^\$/ || $element =~ m/^__symbol:/) {
        $result .= "symbol:box($element)}), ";
      } elsif ($element =~ m/^\"/) {
        $result .= "str:box($element)}), ";
      } else {
        $result .= "box($element)}), ";
      }
    }
    $result .= "nullptr }";
  }
  $result .= ")";
  return $result;
}
sub rewrite_sequence_literal {
  my ($filestr_ref) = @_;
  $$filestr_ref =~ s/\$\[(.*?)\]/&rewrite_list_literal_replacement($1, 'SEQUENCE')/ge;
}
sub rewrite_list_literal_replacement {
  my ($body, $type) = @_;
  my $result = '';
  my $assocs = [split /,/, $body];
  $assocs = [map {&trim($_)} @$assocs];
  $result .= "make(DEFAULT-$type-KLASS";

  if (0 != @$assocs && '' ne $$assocs[0]) {
    $result .= ", items => (object-t[]){ ";

    foreach my $assoc (@$assocs) {
      $result .= "box($assoc), ";
    }
    $result .= "nullptr }";
  }
  $result .= ")";
  return $result;
}
sub rewrite_enums {
  # does not deal with comments containing '{' or '}' between the { }
  my ($filestr_ref) = @_;
  #$$filestr_ref =~ s{(?<!/\*)(import|export|noexport)(\s+)(enum[^\w-])}{/*$1*/$2$3}g;
  $$filestr_ref =~ s/(?<!slots)(\s+enum(\s+$k+)?\s*$main::block)/$1;/gs;
}
sub rewrite_const {
  # does not deal with comments containing '{' or '}' between the { }
  my ($filestr_ref) = @_;
  $$filestr_ref =~ s|\bexport(\s+const.*?;)|/*export*/$1|g;
}
sub rewrite_function_typedef {
  my ($filestr_ref) = @_;
  $$filestr_ref =~ s|(typedef\s*[^;]+?\s*\(\s*\*)(\s*\)\(.*?\))(\s*$k+)(\s*;)|$1$3$2$4|gs;
}
sub rewrite_array_types {
  my ($filestr_ref) = @_;
  $$filestr_ref =~ s/($k+?\-t)(\s*)($main::seq)(\s*)($k+)/$1$2$4$5$3/gm;
}
sub rewrite_symbols {
  my ($filestr_ref) = @_;
  #$$filestr_ref =~ s/\$($k+)\s*=>\s*($k+)/keyword($1), __arg($2)/g;
  &rewrite_keywords($filestr_ref);
  $$filestr_ref =~ s/(?<!\\)\$($m)/&symbol($1)/ge;
  $$filestr_ref =~ s/(?<!\\)\$($z)/&symbol($1)/ge;
}

# this leaks memory!!
sub rewrite_strings_rhs {
  my ($string) = @_;
  my $string_ident = &make_ident_symbol_scalar($string);
  #my $result = "__string:$string_ident";
  my $result = "str:box(\"$string_ident\")";
  return $result;
}
sub rewrite_strings {
  my ($filestr_ref) = @_;
  $$filestr_ref =~ s/(?<!\\)\$\"(.+?)\"/&rewrite_strings_rhs($1)/ge;
}
sub rewrite_keywords {
  my ($filestr_ref) = @_;
  $$filestr_ref =~ s/(?<!\\)\$($sqstr)/&keyword($1)/ge;
}
sub rewrite_boxes {
  my ($filestr_ref) = @_;
  if ($use_compound_literals) {
    $$filestr_ref =~ s/($k+):box\((\s*\{.*?\}\s*)\)/$1:box(cast($1:slots-t)$2)/g;
  } else {
    $$filestr_ref =~ s/($k+):box\(\s*\{(.*?)\}\s*\)/$1:box($1:construct($2))/g;
  }
  # <non-colon>box($foo)  =>  symbol:box($foo)
  $$filestr_ref =~ s/(?<!:)(box\s*\(\s*\$$k+\))/symbol:$1/g;
  $$filestr_ref =~ s/(?<!:)(box\s*\(\s*__symbol:.+?\))/symbol:$1/g;

  # <non-colon>box($'foo')  =>  uintmax:box($'foo')
  $$filestr_ref =~ s/(?<!:)(box\s*\(\s*\$\'.+?\'\s*\))/uintmax:$1/g;
  $$filestr_ref =~ s/(?<!:)(box\s*\(\s*__hash:.+?\))/uintmax:$1/g;
}
sub rewrite_unless {
  my ($filestr_ref) = @_;
  $$filestr_ref =~ s/(\Wunless)\s+\(/$1(/g;
}
sub rewrite_unboxes_replacement {
  my ($type_eq, $name, $func) = @_;
  my $result = "$type_eq$func";

  if ('object' ne $name && 'slots' ne $name) {
    $result = "$type_eq$name:$func";
  }
  return $result;
}
sub rewrite_unboxes {
  my ($filestr_ref) = @_;
  # foo:slots-t* foo = unbox(bar)
  # becomes
  # foo:slots-t* foo = foo:unbox(bar)
  $$filestr_ref =~ s/(($k+?)\:slots-t\s*\*?\s*$k+\s*=\s*\*?)(unbox)(?=\()/&rewrite_unboxes_replacement($1, $2, $3)/ge;

  # foo:slots-t& foo = *unbox(bar)
  # becomes
  # foo:slots-t& foo = *foo:unbox(bar)
  $$filestr_ref =~ s/(($k+?)\:slots-t\s*\&?\s*$k+\s*=\s*\*?)(unbox)(?=\()/&rewrite_unboxes_replacement($1, $2, $3)/ge;

  # foo-t* foo = unbox(bar)
  # becomes
  # foo-t* foo = foo:unbox(bar)
  #$$filestr_ref =~ s/(($k+?)-t\s*\*?\s*$k+\s*=\s*\*?)(unbox)(?=\()/&rewrite_unboxes_replacement($1, $2, $3)/ge;

  # foo-t& foo = *unbox(bar)
  # becomes
  # foo-t& foo = *foo:unbox(bar)
  #$$filestr_ref =~ s/(($k+?)-t\s*\&?\s*$k+\s*=\s*\*?)(unbox)(?=\()/&rewrite_unboxes_replacement($1, $2, $3)/ge;
}
sub rewrite_creates {
  my ($filestr_ref) = @_;
  $$filestr_ref =~ s/($k+):create\((\s*\{.*?\}\s*)\)/$1:create(($1:slots-t)$2)/g;
}
sub rewrite_supers {
  my ($filestr_ref) = @_;
  $$filestr_ref =~ s/(dk:$k+\s*)\(\s*super\b/$1(super(self, klass)/g;
  $$filestr_ref =~ s/(dk:va:$k+\s*)\(\s*super\b/$1(super(self, klass)/g;
}
#sub rewrite_makes
#{
#    my ($filestr_ref) = @_;
#    ## regex should be (:)?(\w+:)*\w+ ?
#    $$filestr_ref =~ s/make\(([_a-z0-9:-]+)/dk:init(dk:alloc($1)/g;
#}
sub rewrite_for_each_replacement {
  my ($type, $element, $sequence, $ws1, $open_brace, $ws2, $stmt, $ws3) = @_;
  my $first_stmt = '';
  my $result = "for (object-t _iterator_ = dk:forward-iterator($sequence);";

  if ('object-t' eq $type) {
    $result .= " object-t $element = dk:next(_iterator_);";
    $result .= " /**/)";
    if (!$open_brace) { # $ws2 will be undefined
      $first_stmt .= "$ws1$stmt$ws3";
    } else {
      $first_stmt .= "$ws1\{$ws2$stmt$ws3";
    }
  } elsif ('slots-t*' eq $type) {
    $result .= " object-t _element_ = dk:next(_iterator_);";
    $result .= " /**/)";

    if (!$open_brace) { # $ws2 will be undefined
      $first_stmt .= "$ws1\{ $type $element = unbox(_element_); $stmt \}$ws3";
    } else {
      $first_stmt .= "$ws1\{$ws2$type $element = unbox(_element_); $stmt$ws3";
    }
  } elsif ($type =~ m|($k+?)-t|) {
    $result .= " object-t _element_ = dk:next(_iterator_);";
    $result .= " /**/)";

    if (!$open_brace) { # $ws2 will be undefined
      $first_stmt .= "$ws1\{ $type $element = $1:unbox(_element_); $stmt \}$ws3";
    } else {
      $first_stmt .= "$ws1\{$ws2$type $element = $1:unbox(_element_); $stmt$ws3";
    }
  } else {
    die __FILE__, ":", __LINE__, ": error:\n";
  }
  $result .= $first_stmt;
  return $result;
}
sub rewrite_for_each {
  my ($filestr_ref) = @_;
  # for ( object-t xx : yy )
  $$filestr_ref =~ s|for\s*\(\s*($k+\*?)\s*($k+)\s+in\s+(.*?)\s*\)(\s*)(\{?)(\s*)(.*?;)(\s*)|&rewrite_for_each_replacement($1, $2, $3, $4, $5, $6, $7, $8)|gse;
}
sub rewrite_slot_access {
  my ($filestr_ref) = @_;
  $$filestr_ref =~ s/self\./unbox(self)->/g;

  #    $$filestr_ref =~ s/unbox\((.*?)\)\./unbox($1)->/g;
}
sub symbol {
  my ($symbol) = @_;
  $symbol =~ s|^\"||;   # strip leading  double-quote (if any)
  $symbol =~ s|\"$||;   # strip trailing double-quote (if any)
  $symbol =~ s/($z)\?/$1$$long_suffix{'?'}/g;
  $symbol =~ s/($z)\!/$1$$long_suffix{'!'}/g;
  my $cxx_ident = &make_ident_symbol_scalar($symbol);
  return "__symbol:${cxx_ident}";
}
sub keyword {
  my ($keyword) = @_;
  return &hash($keyword);
}
sub hash {
  my ($keyword) = @_;
  $keyword =~ s|^\'||;  # strip leading  single-quote
  $keyword =~ s|\'$||;  # strip trailing single-quote
  my $cxx_ident = &make_ident_symbol_scalar($keyword);
  return "__hash:$cxx_ident";
}
sub rewrite_case_with_string_rhs {
  my ($ws1, $str, $ws2) = @_;
  my $ident = &hash($str);
  return "case$ws1$ident$ws2:";
}
sub rewrite_case_with_string {
  my ($filestr_ref) = @_;
  $$filestr_ref =~ s|(case)(\s*)"(.*?)"(\s*)(:)|&rewrite_case_with_string_rhs($2, $3, $4)|ges;
  $$filestr_ref =~ s|(case)(\s*)\$(.*?)(\s*)(:)|&rewrite_case_with_string_rhs($2, $3, $4)|ges;
}
sub rewrite_strswitch {
  my ($filestr_ref) = @_;
  $$filestr_ref =~ s|strswitch(\s*)\((.*?)\)|switch$1(dk-hash($2))|gs;
}
sub remove_non_newlines {
  my ($str) = @_;
  my $result = $str;
  $result =~ s|[^\n]+||gs;
  return $result;
}
sub exported_slots_body {
  my ($a, $b, $c, $d, $e) = @_;
  #my $d = &remove_non_newlines($c);
  return "/*$a$b$c$d$e*/";
}
sub rewrite_module_statement {
  my ($filestr_ref) = @_;
  $$filestr_ref =~ s|\b(module\s+$z\s*.*?;)|/*$1*/|gs;
}
sub add_implied_slots_struct {
  my ($filestr_ref) = @_;
  $$filestr_ref =~ s/(\s+slots)(\s*\{)/$1 struct$2/g;
  $$filestr_ref =~ s/(\s+slots)(\s*;)/$1 struct$2/g;
}
sub remove_exported_slots {
  my ($filestr_ref) = @_;
  $$filestr_ref =~ s=(export)(\s+slots\s+)=/*$1*/$2=gs;
  $$filestr_ref =~ s=(slots)(\s+)(struct|union|enum)(\s*)(\{.*?\})=&exported_slots_body($1, $2, $3, $4, $5)=gse;
}
sub exported_enum_body {
  my ($a, $b, $c, $d) = @_;
  #my $d = &remove_non_newlines($c);

  if ($b =~ m/$k+/) {
    return "$a$b;$c/*$d*/";
  } else {
    return "/*$a$b$c$d*/";
  }
}
sub remove_exported_enum {
  my ($filestr_ref) = @_;
  $$filestr_ref =~ s/(export\s+enum)(\s*$k*)(\s*)(\{.*?\})/&exported_enum_body($1, $2, $3, $4)/gse;
}
# method init( ... , object-t $arg1, object-t $arg2 = ...) {|;
# method init( ... , object-t  arg1, object-t  arg2      ) {|;

# dk:init(...,        $arg1  =     ...,         $arg2  =     ...)
# dk:init(..., SYMBOL(_arg1) , ARG(...), SYMBOL(_arg2) , ARG(...), nullptr)
sub rewrite_keyword_syntax_list {
  my ($arg1, $arg2, $arg3) = @_;
  my $list = $arg3;

  if ($arg3 =~ m/=>/g) {
    #print STDERR "$arg1$arg2$list\n";

    # remove the leading and trailing parens
    # so we can remove balenced parens and
    # everything in between
    $list =~ s/^\(//;
    $list =~ s/\)$//;
    $list =~ s/($rk*$main::list)/&remove_non_newlines($1)/ges;
    $list = "($list)";

    $list =~ s{($m\s*)(=>\s*.*?)(\s*,|\))}{$1/*$2*/$3}g;
    $list =~ s{($z\s*)(=>\s*.*?)(\s*,|\))}{$1/*$2*/$3}g;
    #print STDERR "$arg1$arg2$list\n";
  }
  return "$arg1$arg2$list";
}
sub rewrite_keyword_syntax_use_rhs {
  my ($arg1, $arg2) = @_;
  my $arg1_ident = &make_ident_symbol_scalar($arg1);
  return "&__keyword:$arg1_ident$arg2,";
}
sub rewrite_keyword_syntax_use {
  my ($arg1, $arg2) = @_;
  my $list = $arg2;

  #print STDERR "$arg1$list\n";
  $list =~ s/($m)(\s*)=>/&rewrite_keyword_syntax_use_rhs($1, $2)/ge;
  $list =~ s/($z)(\s*)=>/&rewrite_keyword_syntax_use_rhs($1, $2)/ge;
  $list =~ s/\)$/, nullptr\)/g;
  #print STDERR "$arg1$list\n";
  return "$arg1$list";
}
sub rewrite_keyword_syntax {
  my ($filestr_ref, $ka_generics) = @_;
  foreach my $name (keys %$ka_generics) {
    $$filestr_ref =~ s/(method.*?)($name)($main::list)/&rewrite_keyword_syntax_list($1, $2, $3)/ge;
    $$filestr_ref =~ s/(dk:+$name)($main::list)/&rewrite_keyword_syntax_use($1, $2)/ge;
  }
  $$filestr_ref =~ s|make(\([^\)]+?\.\.\.\))|__MAKE__$1|gs;
  $$filestr_ref =~ s/(make)($main::list)/&rewrite_keyword_syntax_use($1, $2)/ge;
  $$filestr_ref =~ s|__MAKE__|make|gs;
}
sub wrapped_rewrite {
  my ($filestr_ref, $lhs, $rhs) = @_;
  my $sst = &sst::make($$filestr_ref, undef);

  &rewrite($sst, $lhs, $rhs);

  my $filestr = &sst::filestr($sst);
  $$filestr_ref = $filestr;
}
sub rewrite {
  my ($sst, $lhs, $rhs) = @_;
  my $sst_cursor = &sst_cursor::make($sst);
  my $size = &sst_cursor::size($sst_cursor);
  my $all_matches = [];
  for (my $i = 0; $i < $size - @$lhs; $i++) {
    my $first_index = $$sst_cursor{'first-token-index'} ||= 0;
    my $last_index = $$sst_cursor{'last-token-index'} ||= undef;
    my $new_sst_cursor = &sst_cursor::make($$sst_cursor{'sst'}, $first_index + $i, $last_index);
    my ($range, $matches) = &sst_cursor::match_pattern_seq($new_sst_cursor, $lhs);

    if ($range) {
      $$range[0] += $first_index + $i;
      $$range[1] += $first_index + $i;

      # why add_first()?  Because we want to iterate over the 
      # results in reverse order (so we don't have to adjust the range
      # after every splice
      &_add_first($all_matches, [$range, $matches]);
    }
  }
  if (0 != @$all_matches) {
    foreach my $match (@$all_matches) {
      my $result = [];
      foreach my $tkn (@$rhs) {
        if ($tkn =~ m/^\?/) {
          my $seq = $$match[1]{$tkn};
          foreach my $seq_tkn (@$seq) {
            &_add_last($result, $seq_tkn);
          }
        } else {
          &_add_last($result, $tkn);
        }
      }
      my $index = $$match[0][0];
      my $length = $$match[0][1] - $$match[0][0] + 1;
      &sst::splice($sst, $index, $length, $result);
    }
  }
}
sub export_method_rhs {
  my ($a, $b, $c, $sig_min) = @_;
  #$c =~ s/(\bnoexport\b)(\s+\bmethod\b.*?$sig_min\s*$main::list\s*;)/$1/gm;
  #$c =~ s/(\bnoexport\b)(\s+\bmethod\b.*?$sig_min\s*$main::list\s*$main::block)/$1/gm;

  $c =~ s/(\bmethod\b.*?$sig_min\s*$main::list\s*(;|$main::block))/export $1/gm;

  #print STDERR "$a$b\{ ... method ... $sig_min \( ... \) { ... } ... \}\n";
  #print STDERR "$c\n";
  return "$a$b$c";
}
sub rewrite_export_method {
  my ($filestr_ref, $exports) = @_;
  if (0 == keys %$exports) {
    #print STDERR "path=$path, exports={}\n";
  }
  #print STDERR &Dumper($exports);

  while (my ($module_name, $symbol_tbl) = each (%$exports)) {
    foreach my $symbol (sort keys %$symbol_tbl) {
      #print STDERR "$symbol\n";
      if ($symbol =~ m/($z):($msig)/) {
        my $klass_name = $1;
        my $sig = $2;
        if ($sig !~ m/-t$/) {
          my $sig_min = $sig;
          $sig_min =~ s/\(.*?\)$//;
          $$filestr_ref =~ s/(klass|trait)(\s+$klass_name\s*)($main::block)/&export_method_rhs($1, $2, $3, $sig_min)/ges;
        }
      }
    }
  }
}
sub convert_dk_to_cxx {
  my ($filestr_ref, $ka_generics, $arg) = @_;
  #&encode($filestr_ref);

  &encode_comments($filestr_ref);

  &rewrite_strswitch($filestr_ref);
  &rewrite_case_with_string($filestr_ref);

  &rewrite_keywords($filestr_ref);
  #&wrapped_rewrite($filestr_ref, [ '?literal-squoted-cstring' ], [ 'DKT-SYMBOL', '(', '?literal-squoted-cstring', ')' ]);
  &rewrite_symbols($filestr_ref);
  &rewrite_strings($filestr_ref);

  &encode_strings_dq($filestr_ref);
  &rewrite_multi_char_consts($filestr_ref);
  &decode_strings($filestr_ref);
  &encode_strings($filestr_ref);
  &decode_strings($filestr_ref);
  &encode_strings($filestr_ref);
  &rewrite_module_statement($filestr_ref);

  &rewrite_klass_decl($filestr_ref);
  &rewrite_klass_initialize($filestr_ref);
  &rewrite_klass_finalize($filestr_ref);
  &add_implied_slots_struct($filestr_ref);
  &remove_exported_slots($filestr_ref);
  #&wrapped_rewrite($filestr_ref, [ 'export', 'slots', '?block' ], [ ]);

  &remove_exported_enum($filestr_ref);
  #&wrapped_rewrite($filestr_ref, [ 'export', 'enum',           '?block' ], [ ]);
  #&wrapped_rewrite($filestr_ref, [ 'export', 'enum', '?ident', '?block' ], [ ]);

  &rewrite_set_literal($filestr_ref);
  &rewrite_sequence_literal($filestr_ref);

  &rewrite_throws($filestr_ref);
  #&wrapped_rewrite($filestr_ref, [ 'throw', 'make' ], [ 'throw', '*', 'dkt-current-exception', '(', ')', '=', 'make' ]);
  #&wrapped_rewrite($filestr_ref, [ 'throw', '?literal-cstring' ], [ 'throw', '*', 'dkt-current-exception-cstring', '(', ')', '=', '?literal-cstring' ]);

  if ($$filestr_ref =~ m/finally/g) {
    $filestr_ref = &rewrite_finally($filestr_ref);
  }
  if ($$filestr_ref =~ m/catch/g) {
    $filestr_ref = &rewrite_exceptions($filestr_ref);
  }
  &nest_namespaces($filestr_ref);
  #&nest_generics($filestr_ref);
  &rewrite_slots($filestr_ref);
  &rewrite_enums($filestr_ref);
  &rewrite_const($filestr_ref);
  &rewrite_function_typedef($filestr_ref);

  &rewrite_signatures($filestr_ref);
  &rewrite_selectors($filestr_ref);
  &rewrite_method_names_special($filestr_ref);
  &rewrite_keyword_syntax($filestr_ref, $ka_generics);
  &rewrite_array_types($filestr_ref);
  &rewrite_methods($filestr_ref, $ka_generics);
  &rewrite_functions($filestr_ref);
  &rewrite_for_each($filestr_ref);
  &rewrite_unboxes($filestr_ref);

  &rewrite_slot_access($filestr_ref);
  #&wrapped_rewrite($filestr_ref, [ 'self', '.', '?ident' ], [ 'unbox', '(', 'self', ')', '->', '?ident' ]);

  &rewrite_boxes($filestr_ref);
  &rewrite_unless($filestr_ref);
  &rewrite_creates($filestr_ref);
  &rewrite_supers($filestr_ref);
  &rewrite_compound_literal_cstring_null($filestr_ref);
  &rewrite_compound_literal_cstring($filestr_ref);
  &rewrite_compound_literal($filestr_ref);
  &rewrite_klass_defn($filestr_ref);
  &rewrite_dk_klass($filestr_ref);
  &rewrite_syntax($filestr_ref);
  &rewrite_declarations($filestr_ref);

  $$filestr_ref =~ s/else[_-]if/else if/gs;

  $$filestr_ref =~ s/,(\s*\})/$1/gs;

  &rewrite_includes($filestr_ref);
  &decode_comments($filestr_ref);
  &decode_strings($filestr_ref);
  $$filestr_ref =~ s|;;|;|g;
  return $filestr_ref;
}
sub rewrite_multi_char_consts {
  my ($filestr_ref) = @_;
  my $c = ' ';
  $$filestr_ref =~ s/'([^'\\])([^'\\])([^'\\])'/'$1$2$3$c'/g;
  $$filestr_ref =~ s/'([^'\\])([^'\\])'/'$1$2$c$c'/g;
}
sub dakota_lang_user_data_old {
  my $ka_generics;
  if ($ENV{'DKT_KA_GENERICS'}) {
    $ka_generics = do $ENV{'DKT_KA_GENERICS'} or die;
  } else {
    $ka_generics = do "$prefix/src/ka-generics.pl" or die;
  }

  my $user_data = { 'ka-generics' => $ka_generics };
  return $user_data;
}

unless (caller) {
  my $user_data = &dakota_lang_user_data_old();

  foreach my $arg (@ARGV) {
    my $filestr = &dakota::filestr_from_file($arg);

    &convert_dk_to_cxx(\$filestr, $$user_data{'ka-generics'}, $arg);
    print $filestr;
  }
}

1;
