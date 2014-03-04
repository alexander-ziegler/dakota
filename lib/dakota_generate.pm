#!/usr/bin/perl -w

# Copyright (C) 2007, 2008, 2009 Robert Nielsen <robert@dakota.org>
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

use strict;
use warnings;
use integer;
use Cwd;

package dakota;

use dakota_include;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT= qw(
		empty_klass_defns
		generate_nrt_decl
		generate_nrt_defn
		generate_rt_decl
		generate_rt_defn
		global_scratch_str_ref
		set_global_scratch_str_ref
		function::overloadsig
		write_to_file_strings
		write_to_file_converted_strings
		should_use_include
                make_ident_symbol_scalar
		);

my $objdir = 'obj';
my $rep_ext = 'rep';
my $ctlg_ext = 'ctlg';
my $hxx_ext = 'h';
my $cxx_ext = 'cc';
my $dk_ext = 'dk';
my $obj_ext = 'o';

# same code in dakota.pl and parser.pl
my $k  = qr/[_A-Za-z0-9-]/;
my $z  = qr/[_A-Za-z]$k*[_A-Za-z0-9]?/;
my $wk = qr/[_A-Za-z]$k*[A-Za-z0-9_]*/; # dakota identifier
my $ak = qr/::?$k+/;   # absolute scoped dakota identifier
my $rk = qr/$k+$ak*/;  # relative scoped dakota identifier
my $d = qr/\d+/;  # relative scoped dakota identifier

my $global_is_defn = undef; # klass decl vs defn
my $global_is_rt = undef;   # <klass>--klasses.{h,cc} vs lib/libdakota--klasses.{h,cc}

my $gbl_nrt_file = undef;
my $global_scratch_str_ref;
#my $global_nrt_cxx_str;

my $global_seq_super_t   = [ 'super-t' ];   # special (used in eq compare)
my $global_seq_ellipsis  = [ '...' ];
my $global_klass_defns = [];

my $plural_from_singular = { 'klass', => 'klasses', 'trait' => 'traits' };

# same as in dakota_rewrite.pm
my $long_suffix =
{
    '=' => '3d',
    '?' => '3f',
    '!' => '21'
};

sub make_ident_symbol_scalar
{
    my ($symbol) = @_;
    $symbol =~ s/($z)\?/$1$$long_suffix{'?'}/g;
    $symbol =~ s/($z)\=/$1$$long_suffix{'='}/g;
    $symbol =~ s/($z)\!/$1$$long_suffix{'!'}/g;
    my $has_word_char;

    if ($symbol =~ m/\w/)
    {
	$has_word_char = 1;
    }
    else
    {
	$has_word_char = 0;
    }

    my $ident_symbol = [ '_' ];

    my $chars = [split //, $symbol];

    foreach my $char (@$chars)
    {
        my $part;
	if ('-' eq $char)
	{
	    if ($has_word_char)
	    { $part = '_'; }
	    else
	    { $part = sprintf("%02x", ord($char)); }
	}
        elsif ($char =~ /$k/)
        { $part = $char; }
	else
	{ $part = sprintf("%02x", ord($char)); }
        &_add_last($ident_symbol, $part);
    }
    my $value = &path::string($ident_symbol);
    return $value;
}
sub make_ident_symbol
{
    my ($seq) = @_;
    my $ident_symbols = [map { &make_ident_symbol_scalar($_) } @$seq];
    return &path::string($ident_symbols);
}

sub empty_klass_defns
{
    $global_klass_defns = [];
}

sub global_scratch_str_ref
{
    return $global_scratch_str_ref;
}

sub set_global_scratch_str_ref
{
    my ($ref) = @_;
    $global_scratch_str_ref = $ref;
}

sub set_nrt_decl()
{
    $global_is_rt   = 0;
    $global_is_defn = 0;
}
sub set_nrt_defn()
{
    $global_is_rt   = 0;
    $global_is_defn = 1;
}
sub set_rt_decl()
{
    $global_is_rt   = 1;
    $global_is_defn = 0;
}
sub set_rt_defn()
{
    $global_is_rt   = 1;
    $global_is_defn = 1;
}
sub is_nrt_decl
{
    if (!$global_is_rt && !$global_is_defn)
    { return 1; }
    else
    { return 0; }
}
sub is_nrt_defn
{
    if (!$global_is_rt && $global_is_defn)
    { return 1; }
    else
    { return 0; }
}
sub is_rt_decl
{
    if ($global_is_rt && !$global_is_defn)
    { return 1; }
    else
    { return 0; }
}
sub is_rt_defn
{
    if ($global_is_rt && $global_is_defn)
    { return 1; }
    else
    { return 0; }
}

sub write_to_file_strings
{
    my ($path, $strings) = @_;
    my $kw_arg_generics = &kw_arg_generics();
    open PATH, ">$path" or die __FILE__, ":", __LINE__, ": error: \"$path\" $!\n";
    foreach my $string (@$strings)
    {
	print PATH $string;
    }
    close PATH;
}

sub write_to_file_converted_strings
{
    my ($path, $strings) = @_;
    my $kw_arg_generics = &kw_arg_generics();
    open PATH, ">$path" or die __FILE__, ":", __LINE__, ": error: \"$path\" $!\n";
    foreach my $string (@$strings)
    {
	my $string_ref = \$string;
	$string_ref = &convert_dk_to_cxx($string_ref, $kw_arg_generics);
	print PATH $$string_ref;
    }
    close PATH;
}

sub generate_nrt_decl
{
    my ($path, $file_basename, $file) = @_;
    &set_nrt_decl();
    return &generate_nrt($path, $file_basename, $file, undef);
}
sub generate_nrt_defn
{
    my ($path, $file_basename, $file, $defn_tbl) = @_;
    &set_nrt_defn();
    return &generate_nrt($path, $file_basename, $file, $defn_tbl);
}
sub generate_nrt
{
    my ($path, $file_basename, $file, $defn_tbl) = @_;
    $gbl_nrt_file = "$file_basename.dk";
    my $result = {};
    my $name = $file_basename;
    $name =~ s|.*/||; # strip off directory part
    $name =~ s|\.$k+$||;    

    my $scratch_str_ref = &global_scratch_str_ref();
    my $parse_tree = &generics::pre_parse($file_basename);
    my ($generics, $symbols) = &generics::parse($parse_tree);

    my $col = 0;

    #my $generics_cp = &deep_copy($generics);
    my $symbols_cp = &deep_copy($symbols);

    my $symbols_include =   "$name--symbols";
    my $klasses_include =   "$name--klasses";
    my $generics_include =  "$name--generics";
    my $signatures_include = "$name--signatures";
    my $hashes_include =  "$name--hashes";

    my $kw_arg_generics = &kw_arg_generics();

    if (&is_nrt_defn() || &is_rt_defn())
    {
	#print STDERR "$name.$cxx_ext***\n";
	my $nrt_cxx_str = "// --nrt-cxx--\n";
        $nrt_cxx_str .= &dakota_h();
        $nrt_cxx_str .= &dk::print("\n");

	{
	    $nrt_cxx_str .= &dk::print($$defn_tbl{'klasses-hxx'}[0]);
	    $nrt_cxx_str .= &dk::print($$defn_tbl{'symbols-hxx'}[0]);
	    $nrt_cxx_str .= &dk::print($$defn_tbl{'symbols-hxx'}[1]);

	    $nrt_cxx_str .= &dk::print($$defn_tbl{'signatures-hxx'}[0]);
	    $nrt_cxx_str .= &dk::print($$defn_tbl{'signatures-hxx'}[1]);
	    $nrt_cxx_str .= &dk::print($$defn_tbl{'selectors-hxx'}[0]);
	    $nrt_cxx_str .= &dk::print($$defn_tbl{'selectors-hxx'}[1]);
	    $nrt_cxx_str .= &dk::print($$defn_tbl{'generics-hxx'}[0]);
	    $nrt_cxx_str .= &dk::print($$defn_tbl{'hashes-hxx'}[0]);
	    $nrt_cxx_str .= &dk::print($$defn_tbl{'keywords-hxx'}[0]);
	    $nrt_cxx_str .= &dk::annotate($col, __FILE__, __LINE__);
	    $nrt_cxx_str .= &dakota_before_user_code_h();
	    if (exists $ENV{'DK_ABS_PATH'})
	    {
		my $cwd = getcwd;
		$nrt_cxx_str .= &dk::print("include \"$cwd/obj/$name.$cxx_ext\";\n");
	    }
	    else
	    {
		$nrt_cxx_str .= &dk::print("include \"../$name.$cxx_ext\";\n");
	    }
	    $nrt_cxx_str .= &dakota_before_rt_code_h();
	    $nrt_cxx_str .= &dk::print($$defn_tbl{'klasses-cxx'}[0]);
	}

	my $nrt_defn = "$name";

       &write_to_file_strings("$path/$nrt_defn.$dk_ext",            [ $nrt_cxx_str ]);
###
	&write_to_file_converted_strings("$path/$nrt_defn.$cxx_ext", [ $nrt_cxx_str ]);

	$$result{'nrt-cxx'} = [ $nrt_cxx_str ];
    }
    else
    {
        my $symbols_hxx_str =  "// --symbols-hxx--\n";
        my $strings_hxx_str = "// --strings-hxx--\n";
	my $hashes_hxx_str = "// --hashes-hxx--\n";
	my $keywords_hxx_str = "// --keywords-hxx--\n";
	my $selectors_hxx_str = "// --selectors-hxx--\n";
	my $selectors_seq_hxx_str = "// --selectors-seq-hxx--\n";
	my $signatures_hxx_str = "// --signatures-hxx--\n";
	my $signatures_seq_hxx_str = "// --signatures-seq-hxx--\n";
	my $klasses_hxx_str = "// --klasses-hxx--\n";
	my $generics_hxx_str = "// --generics-hxx--\n";

        &set_global_scratch_str_ref(\$klasses_hxx_str);
	#print STDERR __FILE__, ":", __LINE__, ":\n";
	#print STDERR &Dumper($$file{'klasses'}{'callback'});
        $klasses_hxx_str = &linkage_unit::generate_klasses($file, $col, []);

        &set_global_scratch_str_ref(\$generics_hxx_str);
        $generics_hxx_str = &linkage_unit::generate_generics($file, $generics);

	&set_global_scratch_str_ref(undef);

	# here

        $selectors_hxx_str .= &linkage_unit::generate_selectors($file, $generics);
        $selectors_seq_hxx_str .= &linkage_unit::generate_selectors_seq($file, $generics);
        $signatures_hxx_str .= &linkage_unit::generate_signatures($file, $generics);
        $signatures_seq_hxx_str .= &linkage_unit::generate_signatures_seq($file, $generics);
       #$strings_hxx_str .= &linkage_unit::generate_strings($file, $generics, $$file{'strings'});
        $symbols_hxx_str .=  &linkage_unit::generate_symbols($file, $generics, $symbols);
        $hashes_hxx_str .= &linkage_unit::generate_hashes($file, $generics, $symbols);
        $keywords_hxx_str .= &linkage_unit::generate_keywords($file, $generics, $symbols);

	$$result{'selectors-hxx'} = [ $selectors_hxx_str, $selectors_seq_hxx_str ];
	$$result{'signatures-hxx'} = [ $signatures_hxx_str, $signatures_seq_hxx_str ];
	$$result{'generics-hxx'} =  [ $generics_hxx_str ];
	$$result{'klasses-hxx'} =   [ $klasses_hxx_str ];
	$$result{'symbols-hxx'} =   [ $symbols_hxx_str, $strings_hxx_str ];
	$$result{'hashes-hxx'} =  [ $hashes_hxx_str ];
	$$result{'keywords-hxx'} =  [ $keywords_hxx_str ];
    }
    return $result;
} # sub generate_nrt

sub generate_rt_decl
{
    my ($path, $file_basename, $file) = @_;
    &set_rt_decl();
    return &generate_rt($path, $file_basename, $file, undef);
}
sub generate_rt_defn
{
    my ($path, $file_basename, $file, $defn_tbl) = @_;
    &set_rt_defn();
    return &generate_rt($path, $file_basename, $file, $defn_tbl);
}
sub generate_rt
{
    my ($path, $file_basename, $file, $defn_tbl) = @_;
    $gbl_nrt_file = undef;
    #print STDERR &Dumper($defn_tbl);
    my $result = {};
    my $name = $file_basename;
    $name =~ s|.*/||; # strip off directory part
    if (&is_rt_defn())
    {
	print "  generating $path/$name\n";
    }
    $name =~ s|\.$k+$||;    

    my $scratch_str_ref = &global_scratch_str_ref();

    my ($generics, $symbols) = &generics::parse($file);

    my $col = 0;

    #my $generics_cp = &deep_copy($generics);
    my $symbols_cp = &deep_copy($symbols);

    my $symbols_include =   "$name--symbols";
    my $klasses_include =   "$name--klasses";
    my $generics_include =  "$name--generics";
    my $signatures_include = "$name--signatures";
    my $hashes_include =  "$name--hashes";

    my $kw_arg_generics = &kw_arg_generics();

    if (&is_nrt_defn() || &is_rt_defn())
    {
        my $symbols_cxx_str =  "// --symbols-cxx--\n";
        my $strings_cxx_str = "// --strings-cxx--\n";
	my $hashes_cxx_str = "// --hashes-cxx--\n";
	my $keywords_cxx_str = "// --keywords-cxx--\n";
	my $selectors_cxx_str = "// --selectors-cxx--\n";
	my $selectors_seq_cxx_str = "// --selectors-seq-cxx--\n";
	my $signatures_cxx_str = "// --signatures-cxx--\n";
	my $signatures_seq_cxx_str = "// --signatures-seq-cxx--\n";
	my $klasses_cxx_str = "// --klasses-cxx--\n";
	my $generics_cxx_str = "// --generics-cxx--\n";

        &set_global_scratch_str_ref(\$klasses_cxx_str);
	#print STDERR __FILE__, ":", __LINE__, ":\n";
	#print STDERR &Dumper($$file{'klasses'}{'callback'});
        $klasses_cxx_str = &linkage_unit::generate_klasses($file, $col, []);

        &set_global_scratch_str_ref(\$generics_cxx_str);
        $generics_cxx_str = &linkage_unit::generate_generics($file, $generics);

	&set_global_scratch_str_ref(undef);

	# here

        $selectors_cxx_str .= &linkage_unit::generate_selectors($file, $generics);
        $selectors_seq_cxx_str .= &linkage_unit::generate_selectors_seq($file, $generics);
        $signatures_cxx_str .= &linkage_unit::generate_signatures($file, $generics);
        $signatures_seq_cxx_str .= &linkage_unit::generate_signatures_seq($file, $generics);
       #$strings_cxx_str .= &linkage_unit::generate_strings($file, $generics, $$file{'strings'});
	$symbols_cxx_str .=  &linkage_unit::generate_symbols($file, $generics, $symbols);
	$hashes_cxx_str .= &linkage_unit::generate_hashes($file, $generics, $symbols);
	$keywords_cxx_str .= &linkage_unit::generate_keywords($file, $generics, $symbols);

	my $symbols_cxx =   [ $symbols_cxx_str, $strings_cxx_str ];
	my $selectors_cxx = [ $selectors_cxx_str, $selectors_seq_cxx_str ];
	my $signatures_cxx = [ $signatures_cxx_str, $signatures_seq_cxx_str ];
	my $klasses_cxx = [ $klasses_cxx_str ];
	my $generics_cxx = [ $generics_cxx_str ];
	my $hashes_cxx = [ $hashes_cxx_str ];
	my $keywords_cxx = [ $keywords_cxx_str ];

	my $rt_cxx_str = "// --rt-cxx--\n";
        $rt_cxx_str .= &dakota_h();
        $rt_cxx_str .= &dk::print("\n");

	{
	    $rt_cxx_str .= &dk::print($$defn_tbl{'klasses-hxx'}[0]);
	    $rt_cxx_str .= &dakota_before_klasses_h();
	    $rt_cxx_str .= &dk::print($$symbols_cxx[0]);
	    $rt_cxx_str .= &dk::print($$symbols_cxx[1]);
	    $rt_cxx_str .= &dk::print($$defn_tbl{'hashes-hxx'}[0]);
	    $rt_cxx_str .= &dk::print($$hashes_cxx[0]);
	    $rt_cxx_str .= &dk::print($$keywords_cxx[0]);
	    $rt_cxx_str .= &dakota_before_user_code_h();
	    $rt_cxx_str .= &dakota_before_rt_code_h();
	    $rt_cxx_str .= &dk::print($$selectors_cxx[0]);
	    $rt_cxx_str .= &dk::print($$selectors_cxx[1]);
	    $rt_cxx_str .= &dk::print($$signatures_cxx[0]);
	    $rt_cxx_str .= &dk::print($$signatures_cxx[1]);
	    $rt_cxx_str .= &dk::print($$generics_cxx[0]);
	    $rt_cxx_str .= &dk::print($$klasses_cxx[0]);
	}
	$rt_cxx_str .= &dk::print("\n");

        my $stack = [];
        my $tbl = {
            'imported-klasses' => {},
            'klasses' =>          {},
        };
        &dk::generate_imported_klasses_info($file, $stack, $tbl);
        my $keys_count;
        $keys_count = keys %{$$file{'klasses'}};
	$rt_cxx_str .= &dk::annotate($col, __FILE__, __LINE__);
        if (0 == $keys_count)
        {
            $rt_cxx_str .= &dk::print_in_col_string($col, "static assoc-node-t* imported-klasses = NULL;\n");
            $rt_cxx_str .= &dk::print_in_col_string($col, "static const symbol-t* imported-klasses-names = NULL;\n");
        }
        else
        {
            $rt_cxx_str .= &dk::print_in_col_string($col, "static const symbol-t imported-klasses-names[] = //ro-data\n");
            $rt_cxx_str .= &dk::print_in_col_string($col, "{\n");
            $col++;
            my ($key, $val);
            my $num_klasses = scalar keys %{$$file{'klasses'}};
            foreach $key (sort keys %{$$file{'klasses'}})
            {
                $val = $$file{'klasses'}{$key};
                my $cxx_klass_name = $key;
                $rt_cxx_str .= &dk::print_in_col_string($col, "$key:__klass__,\n");
            }
	    $rt_cxx_str .= &dk::print_in_col_string($col, "NULL\n");
            $col--;
            $rt_cxx_str .= &dk::print_in_col_string($col, "};\n");
###
            $rt_cxx_str .= &dk::print_in_col_string($col, "static assoc-node-t imported-klasses[] = //rw-data\n");
            $rt_cxx_str .= &dk::print_in_col_string($col, "{\n");
            $col++;
	    $num_klasses = scalar keys %{$$file{'klasses'}};
            foreach $key (sort keys %{$$file{'klasses'}})
            {
                $val = $$file{'klasses'}{$key};
                my $RT = ''; # because the klass klass won't compile
                my $cxx_klass_name = $key;
                $rt_cxx_str .= &dk::print_in_col_string($col, "{ cast(uintptr-t)&$RT$cxx_klass_name:klass, NULL },\n");
            }
	    $rt_cxx_str .= &dk::print_in_col_string($col, "{ cast(uintptr-t)NULL, NULL }\n");
            $col--;
            $rt_cxx_str .= &dk::print_in_col_string($col, "};\n");
        }
	my $scratch_str = '';
	&set_global_scratch_str_ref(\$scratch_str);
        $rt_cxx_str .= &dk::generate_cxx_footer($file, $stack, $col);
        #$rt_cxx_str .= &dk::print_in_col_string($col, "extern \"C\"\n");
        #$rt_cxx_str .= &dk::print_in_col_string($col, "{\n");
        #$col++;

        my $info_tbl =
        {
            "\$signatures-va" => 'signatures-va',
            "\$signatures" => 'signatures',
            "\$selectors-va" => 'selectors-va',
            "\$selectors" => 'selectors',
            "\$imported-klasses-names" => 'imported-klasses-names',
            "\$imported-klasses" => 'imported-klasses',
            "\$klass-defns" => 'klass-defns',
            "\$interposers" => 'interposers',
            "\$date" => '__DATE__',
            "\$time" => '__TIME__',
            "\$file" => '__FILE__',
            "\$construct" => 'DK-CONSTRUCT',
            "\$name" => 'DK-NAME',
        };
	my $exports = &exports($file);
	my $num_exports = scalar keys %$exports;
	if (0 == $num_exports) {
	    $$info_tbl{"\$exports"} = 'exports'; # NULL
	}
	else {
	    $$info_tbl{"\$exports"} = '&exports';
	}
        $rt_cxx_str .= &dk::print("\n");
	my $col;
        $rt_cxx_str .= &generate_info('registration-info', $info_tbl, $col = 0);

        $rt_cxx_str .= &dk::print("\n");
	$rt_cxx_str .= &dk::annotate($col, __FILE__, __LINE__);
        $rt_cxx_str .= &dk::print_in_col_string($col, "static void __initial()\n");
        $rt_cxx_str .= &dk::print_in_col_string($col, "{\n");
        $col++;
        $rt_cxx_str .= &dk::print_in_col_string($col, "DKT-LOG-INITIAL-FINAL(\"'func'=>'%s','args'=>[],'context'=>'%s','name'=>'%s'\", __func__, \"{\", DK-NAME);\n");
        $rt_cxx_str .= &dk::print_in_col_string($col, "dk-register-info(&registration-info);\n");
        $rt_cxx_str .= &dk::print_in_col_string($col, "DKT-LOG-INITIAL-FINAL(\"'func'=>'%s','args'=>[],'context'=>'%s','name'=>'%s'\", __func__, \"}\", DK-NAME);\n");
        $rt_cxx_str .= &dk::print_in_col_string($col, "return;\n");
        $col--;
        $rt_cxx_str .= &dk::print_in_col_string($col, "}\n");
	$rt_cxx_str .= &dk::annotate($col, __FILE__, __LINE__);
        $rt_cxx_str .= &dk::print_in_col_string($col, "static void __final()\n");
        $rt_cxx_str .= &dk::print_in_col_string($col, "{\n");
        $col++;
        $rt_cxx_str .= &dk::print_in_col_string($col, "DKT-LOG-INITIAL-FINAL(\"'func'=>'%s','args'=>[],'context'=>'%s','name'=>'%s'\", __func__, \"{\", DK-NAME);\n");
        $rt_cxx_str .= &dk::print_in_col_string($col, "dk-deregister-info(&registration-info);\n");
        $rt_cxx_str .= &dk::print_in_col_string($col, "DKT-LOG-INITIAL-FINAL(\"'func'=>'%s','args'=>[],'context'=>'%s','name'=>'%s'\", __func__, \"}\", DK-NAME);\n");
        $rt_cxx_str .= &dk::print_in_col_string($col, "return;\n");
        $col--;
        $rt_cxx_str .= &dk::print_in_col_string($col, "}\n");
        #$col--;
        #$rt_cxx_str .= &dk::print_in_col_string($col, "};\n");

        $rt_cxx_str .= &dk::print_in_col_string($col, "namespace\n");
        $rt_cxx_str .= &dk::print_in_col_string($col, "{\n");
        $col++;
        $rt_cxx_str .= &dk::print_in_col_string($col, "struct noexport __ddl_t\n");
        $rt_cxx_str .= &dk::print_in_col_string($col, "{\n");
        $col++;
        $rt_cxx_str .= &dk::print_in_col_string($col, " __ddl_t() { __initial(); }\n");
        $rt_cxx_str .= &dk::print_in_col_string($col, "~__ddl_t() { __final(); }\n");
        $col--;
        $rt_cxx_str .= &dk::print_in_col_string($col, "};\n");
        $col--;
        $rt_cxx_str .= &dk::print_in_col_string3_comment($col, "}", " // namespace", "\n");

        $rt_cxx_str .= &dk::print_in_col_string($col, "static __ddl_t __ddl = __ddl_t();\n");

	my $rt_defn = "$name";

	&write_to_file_strings("$path/$rt_defn.$dk_ext",            [ $rt_cxx_str ]);
###
	&write_to_file_converted_strings("$path/$rt_defn.$cxx_ext", [ $rt_cxx_str ]);

	#$$result{'rt-cxx'} =        [ $rt_cxx_str ];
	$$result{'symbols-cxx'} =   [ $symbols_cxx_str, $strings_cxx_str ];
	$$result{'selectors-cxx'} = [ $selectors_cxx_str, $selectors_seq_cxx_str ];
	$$result{'signatures-cxx'} = [ $signatures_cxx_str, $signatures_seq_cxx_str ];
	$$result{'generics-cxx'} =  [ $generics_cxx_str ];
	$$result{'klasses-cxx'} =   [ $klasses_cxx_str ];
    }
    else
    {
        my $symbols_hxx_str =  "// --symbols-hxx--\n";
        my $strings_hxx_str = "// --strings-hxx--\n";
	my $hashes_hxx_str = "// --hashes-hxx--\n";
	my $keywords_hxx_str = "// --keywords-hxx--\n";
	my $selectors_hxx_str = "// --selectors-hxx--\n";
	my $selectors_seq_hxx_str = "// --selectors-seq-hxx--\n";
	my $signatures_hxx_str = "// --signatures-hxx--\n";
	my $signatures_seq_hxx_str = "// --signatures-seq-hxx--\n";
	my $klasses_hxx_str = "// --klasses-hxx--\n";
	my $generics_hxx_str = "// --generics-hxx--\n";

        &set_global_scratch_str_ref(\$klasses_hxx_str);
	#print STDERR __FILE__, ":", __LINE__, ":\n";
	#print STDERR &Dumper($$file{'klasses'}{'callback'});
        $klasses_hxx_str = &linkage_unit::generate_klasses($file, $col, []);

        &set_global_scratch_str_ref(\$generics_hxx_str);
        $generics_hxx_str = &linkage_unit::generate_generics($file, $generics);

	&set_global_scratch_str_ref(undef);

	# here

        $selectors_hxx_str .= &linkage_unit::generate_selectors($file, $generics);
        $selectors_seq_hxx_str .= &linkage_unit::generate_selectors_seq($file, $generics);
	$signatures_hxx_str .= &linkage_unit::generate_signatures($file, $generics);
        $signatures_seq_hxx_str .= &linkage_unit::generate_signatures_seq($file, $generics);
       #$strings_hxx_str .= &linkage_unit::generate_strings($file, $generics, $$file{'strings'});
	$symbols_hxx_str .=  &linkage_unit::generate_symbols($file, $generics, $symbols);
	$hashes_hxx_str .= &linkage_unit::generate_hashes($file, $generics, $symbols);
	$keywords_hxx_str .= &linkage_unit::generate_keywords($file, $generics, $symbols);

	$$result{'symbols-hxx'} =   [ $symbols_hxx_str, $strings_hxx_str ];
	$$result{'selectors-hxx'} = [ $selectors_hxx_str, $selectors_seq_hxx_str ];
	$$result{'signatures-hxx'} = [ $signatures_hxx_str, $signatures_seq_hxx_str ];
	$$result{'generics-hxx'} =  [ $generics_hxx_str ];
	$$result{'klasses-hxx'} =   [ $klasses_hxx_str ];
	$$result{'hashes-hxx'} =  [ $hashes_hxx_str ];
	$$result{'keywords-hxx'} =  [ $keywords_hxx_str ];
    }
    return $result;
} # sub generate_rt

sub path::add_last
{
    my ($stack, $part) = @_;

    if (0 != @$stack)
    {
        &_add_last($stack, ':');
    }
    &_add_last($stack, $part);
}

sub path::remove_last
{
    
    my ($stack) = @_;

    &_remove_last($stack); # remove $part

    if (0 != @$stack)
    {
        &_remove_last($stack); # remove ':'
    }
}

sub remove_extra_whitespace
{
    my ($str) = @_;

    $str =~ s|(\w)\s+(\w)|$1__WHITESPACE__$2|g;
    $str =~ s|\s+||g;
    $str =~ s|__WHITESPACE__| |g;

    return $str;
}

sub arg::type
{
    my ($arg) = @_;

    if (!defined $arg)
    {
        $arg = [ 'void' ];
    }
    my $delim = $";
    $" = ' ';
    $arg = &path::string($arg);
    $" = $delim;
    $arg = &remove_extra_whitespace($arg);

    return $arg;
}

sub arg_type::super
{
    my ($arg_type_ref) = @_;
    my $num_args       = @$arg_type_ref;

    my $new_arg_type_ref = &deep_copy($arg_type_ref);

    #if (object-t eq $$new_arg_type_ref[0])
    #{
    $$new_arg_type_ref[0] = $global_seq_super_t; # replace_first
    #}
    #else
    #{
    #    $$new_arg_type_ref[0] = 'UNKNOWN-T';
    #}

    return $new_arg_type_ref;
}

sub arg_type::va
{
    my ($arg_type_ref) = @_;
    my $num_args       = @$arg_type_ref;
    
    my $new_arg_type_ref = &deep_copy($arg_type_ref);
# should assert that $$new_arg_type_ref[$num_args - 1] == "va-list-t"
    $$new_arg_type_ref[$num_args - 1] = $global_seq_ellipsis;

    return $new_arg_type_ref;
}

sub arg_type::names
{
    my ($arg_type_ref) = @_;
    my $num_args       = @$arg_type_ref;
    my $arg_num        = 0;
    my $arg_names = [];

    if (&path::string($global_seq_super_t) eq  "@{$$arg_type_ref[0]}")
    {
        $$arg_names[0] = "arg0"; # replace_first
    }
    else
    {
        $$arg_names[0] = 'object'; # replace_first
    }

    for ($arg_num = 1; $arg_num < $num_args; $arg_num++)
    {
        if (&path::string($global_seq_ellipsis) eq  "@{$$arg_type_ref[$arg_num]}")
        {
            $$arg_names[$arg_num] = undef;
        }
        elsif ("va-list-t" eq "@{$$arg_type_ref[$arg_num]}")
        {
            $$arg_names[$arg_num] = "args";
        }
        else
        {
            $$arg_names[$arg_num] = "arg$arg_num";
        }
    }

    return $arg_names;
}

sub is_exported
{
    my ($method) = @_;

    if (exists $$method{'exported?'} && $$method{'exported?'})
    { return 1; }
    else
    { return 0; }
}

sub is_raw
{
    my ($method) = @_;

    if ('object-t' ne $$method{'parameter-types'}[0][0])
    { return 1; }
    else
    { return 0; }
}

sub is_box_type
{
    my ($type_seq) = @_;
    my $result;
    my $type_str = &path::string($type_seq);

    if ('slots-t*' eq $type_str ||
        'slots-t'  eq $type_str)
    {
        $result = 1;
    }
    else
    {
        $result = 0;
    }
    return $result;
}

sub arg_type::names_unboxed
{
    my ($arg_type_ref) = @_;
    my $num_args       = @$arg_type_ref;
    my $arg_num        = 0;
    my $arg_names = [];

    if ('slots-t*' eq "@{$$arg_type_ref[0]}")
    { $$arg_names[0] = 'unbox(object)'; }
    elsif ('slots-t' eq "@{$$arg_type_ref[0]}")
    { $$arg_names[0] = '*unbox(object)'; }
    else
    { $$arg_names[0] = 'object';  }

    for ($arg_num = 1; $arg_num < $num_args; $arg_num++)
    {
        if ('slots-t*' eq "@{$$arg_type_ref[$arg_num]}")
        { $$arg_names[$arg_num] = "unbox(arg$arg_num)"; }
        elsif ('slots-t' eq "@{$$arg_type_ref[$arg_num]}")
        { $$arg_names[$arg_num] = "*unbox(arg$arg_num)"; }
        else
        { $$arg_names[$arg_num] = "arg$arg_num"; }
    }
    return $arg_names;
}

sub arg_type::list_pair
{
    my ($arg_types_ref, $arg_names_ref) = @_;

    my $num_arg_types = @$arg_types_ref;
    my $num_arg_names = @$arg_names_ref;
    my $list          = '';
    my $arg_num;

    for ($arg_num = 0; $arg_num < $num_arg_types; $arg_num++)
    {
        my $type = &arg::type(${$arg_types_ref}[$arg_num]);
        $list .= "$type";
        if (defined ${$arg_names_ref}[$arg_num])
        {
            $list .= " ${$arg_names_ref}[$arg_num]";
        }

        if ($arg_num + 1 != $num_arg_types)
        {
            $list .= ', ';
        }
    }
    return \$list;
}

# very similiar to arg_type::list_types
# see below
sub arg_type::list_names
{
    my ($args_ref) = @_;

    my $num_args   = @$args_ref;
    my $list       = '';
    my $arg_num;

    for ($arg_num = 0; $arg_num < $num_args; $arg_num++)
    {
        $list .= ${$args_ref}[$arg_num];

        if ($arg_num + 1 != $num_args)
        {
            $list .= ', ';
        }
    }
    return \$list;
}

# very similiar to arg_type::list_names
# see above
sub arg_type::list_types
{
    my ($args_ref) = @_;

    my $num_args   = @$args_ref;
    my $list       = '';
    my $arg_num;

    for ($arg_num = 0; $arg_num < $num_args; $arg_num++)
    {
        $list .= &arg::type(${$args_ref}[$arg_num]);

        if ($arg_num + 1 != $num_args)
        {
            $list .= ', ';
        }
    }
    return \$list;
}

sub method::kw_list_types
{
    my ($method) = @_;
    my $result = '';
    my $delim = '';
    foreach my $arg (@{$$method{'parameter-types'}})
    {
	my $arg_type = &arg::type($arg);

	if ('va-list-t' ne $arg_type)
	{
	    $result .= "$delim$arg_type";
	    $delim = ',';
	}
    }
    foreach my $kw_arg (@{$$method{'keyword-types'}})
    {
	my $kw_arg_name = $$kw_arg{'name'};
	my $kw_arg_type = &arg::type($$kw_arg{'type'});
	
	if (defined $$kw_arg{'default'})
	{
	    $result .= ",$kw_arg_type $kw_arg_name=>{0}";
	}
	else
	{
	    $result .= ",$kw_arg_type $kw_arg_name=>{}";
	}
    }
    return $result;
}

sub method::list_types
{
    my ($method) = @_;
    my $result = '';
    my $delim = '';
    foreach my $arg (@{$$method{'parameter-types'}})
    {
	my $arg_type = &arg::type($arg);

	if ('va-list-t' ne $arg_type)
	{
	    $result .= "$delim$arg_type";
	    $delim = ',';
	}
    }
    return $result;
}

sub kw_arg_type::list_types
{
    my ($args_ref, $kw_args_ref) = @_;

    my $num_args    = @$args_ref;
    my $num_kw_args = @$kw_args_ref;
    my $list        = '';
    my $arg_num;

    for ($arg_num = 0; $arg_num < $num_args - 1; $arg_num++)
    {
        $list .= &arg::type(${$args_ref}[$arg_num]);
        $list .= ', ';
    }

    for ($arg_num = 0; $arg_num < $num_kw_args; $arg_num++)
    {
        $list .= &arg::type(${$kw_args_ref}[$arg_num]{type});

        if ($arg_num + 1 != $num_kw_args)
        {
            $list .= ', ';
        }
    }
    return \$list;
}

sub klass::va_list_methods
{
    my ($klass_scope) = @_;
    my $method;
    my $va_methods_seq = [];
    
   #foreach $method (sort method::compare values %{$$klass_scope{'methods'}})
    foreach $method (sort method::compare values %{$$klass_scope{'methods'}}, values %{$$klass_scope{'raw-methods'}})
    {
        if (&is_va($method))
        {
            &_add_last($va_methods_seq, $method);
        }
    }

    return $va_methods_seq;
}

sub klass::ka_methods
{
    my ($klass_scope) = @_;
    my $method;
    my $ka_methods_seq = [];
    
    foreach $method (sort method::compare values %{$$klass_scope{'methods'}})
    {
        if ($$method{'keyword-types'})
        {
            &_add_last($ka_methods_seq, $method);
        }
    }

    return $ka_methods_seq;
}

sub klass::method_aliases
{
    my ($klass_scope) = @_;
    my $method;
    my $method_aliases_seq = [];
    
   #foreach $method (sort method::compare values %{$$klass_scope{'methods'}})
    foreach $method (sort method::compare values %{$$klass_scope{'methods'}}, values %{$$klass_scope{'raw-methods'}})
    {
        if ($$method{'alias'})
        {
            &_add_last($method_aliases_seq, $method);
        }
    }

    return $method_aliases_seq;
}

# should make seq of tokens and hand off to a output
# routine that knows what can/can-not be immediatly adjacent.
sub function::decl
{
    my ($function, $scope) = @_;
    my $function_decl = '';

    if (&is_exported($function))
    {
        $function_decl .= "export method";
    }
    else
    {
        $function_decl .= "noexport method"; # gratuitous
    }
    if ($$function{'is-inline'})
    { $function_decl .= " INLINE"; } # 'inline' || ''

    my $return_type = &arg::type($$function{'return-type'});
    $function_decl .= " $return_type";
    my $function_overloadsig = &function::overloadsig($function, $scope);
    $function_decl .= " $function_overloadsig";

    if ($$function{'exception-types'})
    {
        my $throw_arg_type = &arg_type::list_types($$function{'exception-types'});
        $function_decl .= " throw($$throw_arg_type)";
    }
    $function_decl .= ";";

    return \$function_decl;
}

sub function::overloadsig
{
    my ($function, $scope) = @_;
    my $last_type = &arg::type($$function{'parameter-types'}[-1]);
    my $name = "@{$$function{'name'}}";
    my $parameter_types = &arg_type::list_types($$function{'parameter-types'});
    my $function_overloadsig = "$name($$parameter_types)";
    return $function_overloadsig;
}

# should test for 'va', ':' AND va-list-t
sub is_va
{
    my ($method) = @_;
    my $num_args = @{$$method{'parameter-types'}};
    
    if ($$method{'is-va'})
    {
        return 1;
    }
    elsif ("va-list-t" eq "@{$$method{'parameter-types'}[$num_args - 1]}")
    {
        return 1;
    }
    else
    {
        return 0;
    }
}

sub method::varargs_from_qual_va_list
{
    my ($method) = @_;
    my $new_method = &deep_copy($method);

    if (3 == @{$$new_method{'name'}})
    {
        my $va  = &_remove_first($$new_method{'name'});
        my $cln = &_remove_first($$new_method{'name'});
    }
    if (exists $$new_method{'parameter-types'})
    {
        &_replace_last($$new_method{'parameter-types'}, ['...']);
    }
    delete $$new_method{'is-va'};
    return $new_method;
}

sub method::generate_va_method_defn
{
    #my ($scope, $va_method) = @_;
    my ($va_method, $scope, $col, $klass_type) = @_;


    my $is_inline  = $$va_method{'is-inline'};

    my $new_arg_types_ref      = $$va_method{'parameter-types'};
    my $new_arg_types_va_ref   = &arg_type::va($new_arg_types_ref);
    my $new_arg_names_ref      = &arg_type::names($new_arg_types_ref);
    my $new_arg_names_va_ref   = &arg_type::names($new_arg_types_va_ref);
    my $new_arg_list_va_ref    = &arg_type::list_pair($new_arg_types_va_ref, $new_arg_names_va_ref);
    my $new_arg_names_list_ref = &arg_type::list_names($new_arg_names_ref);
    
    my $num_args = @$new_arg_names_va_ref;
    my $return_type = &arg::type($$va_method{'return-type'});
    my $va_method_name;

    #if ($$va_method{'alias'})
    #{
    #$va_method_name = "@{$$va_method{'alias'}}";
    #}
    #else
    #{
    $va_method_name = "@{$$va_method{'name'}}";
    #}
    
    my $scratch_str_ref = &global_scratch_str_ref();
    $$scratch_str_ref .= &dk::annotate($col, __FILE__, __LINE__);

    $$scratch_str_ref .= &dk::print_in_col_string($col,  "namespace @$scope { ");
    my $kw_arg_generics = &kw_arg_generics();
    if (exists $$kw_arg_generics{$va_method_name})
    {
        $$scratch_str_ref .= &dk::print("sentinel ");
    }
    if (&is_exported($va_method))
    {
        $$scratch_str_ref .= &dk::print("export ");
    }
    else
    {
        $$scratch_str_ref .= &dk::print("noexport ");
    }
    if ($is_inline)
    {
        $$scratch_str_ref .= &dk::print("INLINE ");
    }
    $$scratch_str_ref .= &dk::print("$return_type ");
    my $scope_va = &deep_copy($scope);
    &_add_last($scope_va, ':');
    &_add_last($scope_va, 'va');
    $$scratch_str_ref .= &dk::print("$va_method_name($$new_arg_list_va_ref)");

    if ($$va_method{'exception-types'})
    {
        my $throw_arg_type = &arg_type::list_types($$va_method{'exception-types'});
        $$scratch_str_ref .= &dk::print(" throw($$throw_arg_type)");
    }

    if (!$$va_method{'defined?'} || &is_nrt_decl() || &is_nrt_defn() || &is_rt_decl())
    {
        $$scratch_str_ref .= &dk::print("; }\n");
    }
    elsif ($$va_method{'defined?'} && (&is_rt_decl() || &is_rt_defn()))
    {
        my $var_name = 'result';
        $$scratch_str_ref .= &dk::print("\n");
        my $name = &_last($$va_method{'name'});
        my $va_name = "_func_";
        &_replace_last($$va_method{'name'}, $va_name);
        my $method_type_decl = &method::type_decl($va_method);
        &_replace_last($$va_method{'name'}, $name);
        my $cxx_scope = &path::string($scope);
        $$scratch_str_ref .= &dk::print_in_col_string($col, "{\n");
        $col++;
        $$scratch_str_ref .= &dk::print_in_col_string($col, "static $method_type_decl = $cxx_scope:va:$va_method_name;\n");
        $$scratch_str_ref .= &dk::print_in_col_string($col, "va-list-t args;\n");
        $$scratch_str_ref .= &dk::print_in_col_string($col, "va-start(args, $$new_arg_names_ref[$num_args - 2]);\n");
        $$scratch_str_ref .= &dk::print_in_col_string($col, "");
        
        if (defined $$va_method{'return-type'})
        {
            my $return_type = &arg::type($$va_method{'return-type'});
            my $return_type_pair = "$return_type $var_name";
            $$scratch_str_ref .= &dk::print("$return_type_pair = ");
        }
        
        $$scratch_str_ref .= &dk::print("$va_name($$new_arg_names_list_ref);\n");
        $$scratch_str_ref .= &dk::print_in_col_string($col, "va-end(args);\n");
        
        if (defined $$va_method{'return-type'})
        {
            $$scratch_str_ref .= &dk::print_in_col_string($col, "return $var_name;\n");
        }
        else
        {
            $$scratch_str_ref .= &dk::print_in_col_string($col, "return;\n");
        }
        $col--;
        $$scratch_str_ref .= &dk::print_in_col_string($col, "} }\n");
    }
}

sub method::compare
{
    my $scope;
    my $a_string = &function::overloadsig($a, $scope = []);
    my $b_string = &function::overloadsig($b, $scope = []);

    $a_string =~ s/(.*?va-list-t.*?)/ $1/;
    $b_string =~ s/(.*?va-list-t.*?)/ $1/;

    $a_string cmp $b_string;
}

sub symbol::compare
{
    $a cmp $b;
}

sub string::compare
{
    $a cmp $b;
}

sub property::compare
{
    my ($a_key, $a_val) = %$a;
    my ($b_key, $b_val) = %$b;
    $a_key cmp $b_key;
}

sub type_trans
{
    my ($arg_type_ref) = @_;
    if (defined $arg_type_ref)
    {
        my $arg_type = &path::string($arg_type_ref);
    }
    return $arg_type_ref;
}

sub common::print_signature
{
    my ($generic, $col, $path) = @_;

    my $new_arg_type = $$generic{'parameter-types'};
    my $new_arg_type_list = &arg_type::list_types($new_arg_type);
    $$new_arg_type_list = &remove_extra_whitespace($$new_arg_type_list);

    my $scratch_str = "";
    if (&is_va($generic)) {
	$scratch_str .= &dk::print_in_col_string($col, "namespace __signature { namespace va { ");
    }
    else {
	$scratch_str .= &dk::print_in_col_string($col, "namespace __signature { ");
    }
    if (&is_exported($generic))
    {
        $scratch_str .= &dk::print("export ");
    }
    else
    {
        $scratch_str .= &dk::print("noexport ");
    }
    my $generic_name = "@{$$generic{'name'}}";
    $scratch_str .= &dk::print("const signature-t* $generic_name($$new_arg_type_list)");
    if (&is_nrt_decl() || &is_nrt_defn() || &is_rt_decl())
    {
	if (&is_va($generic)) {
	    $scratch_str .= &dk::print("; } }\n");
	}
	else {
	    $scratch_str .= &dk::print("; }\n");
	}
    }
    elsif (&is_rt_decl() || &is_rt_defn())
    {
        my $var_name = 'result';
        $scratch_str .= &dk::print("\n");
        $scratch_str .= &dk::print_in_col_string($col, "{\n");
        $col++;
        
        my $return_type_str = &arg::type($$generic{'return-type'});
        my $name_str;
        my $cln = ':';
        if (&is_va($generic))
        {
            $name_str = "va:$generic_name";
        }
        else
        {
            $name_str = "$generic_name";
        }
        my $parameter_types_str = $$new_arg_type_list;

        $scratch_str .= &dk::print_in_col_string($col, "static const signature-t $var_name = { \"$return_type_str\", \"$name_str\", \"$parameter_types_str\", NULL };\n");
        $scratch_str .= &dk::print_in_col_string($col, "return &$var_name;\n");
        $col--;

	if (&is_va($generic)) {
	    $scratch_str .= &dk::print("} } }\n");
	}
	else {
	    $scratch_str .= &dk::print("} }\n");
	}
    }
    return $scratch_str;
}

sub common::generate_signature_defns
{
    my ($generics, $col) = @_;
    my $scratch_str = "";
    #$scratch_str .= &dk::print_in_col_string($col, "// generate_signature_defns()\n");

    $scratch_str .= &dk::annotate($col, __FILE__, __LINE__);
    foreach my $generic (@$generics)
    {
        if (&is_va($generic))
        {
            my $keyword_types = $$generic{'keyword-types'} ||= undef;
	    if (!&is_raw($generic)) {
		$scratch_str .= &common::print_signature($generic, $col, ['signature', ':', 'va']);
	    }
            $$generic{'keyword-types'} = $keyword_types;
        }
    }

    if (1)
    {
	$scratch_str .= &dk::print("#if 0\n");
	foreach my $generic (@$generics)
	{
	    if (&is_va($generic))
	    {
		my $varargs_generic = &method::varargs_from_qual_va_list($generic);
                my $keyword_types = $$varargs_generic{'keyword-types'} ||= undef;
		#if (!&is_raw($varargs_generic)) {
		    $scratch_str .= &common::print_signature($varargs_generic, $col, ['signature']);
		#}
                $$varargs_generic{'keyword-types'} = $keyword_types;
	    }
	}
	$scratch_str .= &dk::print("#endif\n");
    } # if ()
    foreach my $generic (@$generics)
    {
        if (!&is_va($generic))
        {
            my $keyword_types = $$generic{'keyword-types'} ||= undef;
	    if (!&is_raw($generic)) {
		$scratch_str .= &common::print_signature($generic, $col, ['signature']);
	    }
            $$generic{'keyword-types'} = $keyword_types;
        }
    }
    return $scratch_str;
}

sub common::print_selector
{
    my ($generic, $col, $path) = @_;

    my $new_arg_type = $$generic{'parameter-types'};
    my $new_arg_type_list = &arg_type::list_types($new_arg_type);
    $$new_arg_type_list = &remove_extra_whitespace($$new_arg_type_list);

    my $scratch_str = "";
    if (&is_va($generic)) {
	$scratch_str .= &dk::print_in_col_string($col, "namespace __selector { namespace va { ");
    }
    else {
	$scratch_str .= &dk::print_in_col_string($col, "namespace __selector { ");
    }
    if (&is_exported($generic))
    {
        $scratch_str .= &dk::print("export ");
    }
    else
    {
        $scratch_str .= &dk::print("noexport ");
    }
    my $generic_name = "@{$$generic{'name'}}";
    $scratch_str .= &dk::print("selector-t* $generic_name($$new_arg_type_list)");
    if (&is_nrt_decl() || &is_nrt_defn() || &is_rt_decl())
    {
	if (&is_va($generic)) {
	    $scratch_str .= &dk::print("; } }\n");
	}
	else {
	    $scratch_str .= &dk::print("; }\n");
	}
    }
    elsif (&is_rt_decl() || &is_rt_defn())
    {
        my $var_name = 'result';
        $scratch_str .= &dk::print("\n");
        $scratch_str .= &dk::print_in_col_string($col, "{\n");
        $col++;
        
        my $return_type_str = &arg::type($$generic{'return-type'});
        my $name_str;
        my $cln = ':';
        if (&is_va($generic))
        {
            $name_str = "va:$generic_name";
        }
        else
        {
            $name_str = "$generic_name";
        }
        my $parameter_types_str = $$new_arg_type_list;
        
        $scratch_str .= &dk::print_in_col_string($col, "static selector-t $var_name = {0};\n");
        $scratch_str .= &dk::print_in_col_string($col, "return &$var_name;\n");
        $col--;
	if (&is_va($generic)) {
	    $scratch_str .= &dk::print_in_col_string($col, "} } }\n");
	}
	else {
	    $scratch_str .= &dk::print_in_col_string($col, "} }\n");
	}
    }
    return $scratch_str;
}

sub common::generate_selector_defns
{
    my ($generics, $col) = @_;
    my $scratch_str = "";
    #$scratch_str .= &dk::print_in_col_string($col, "// generate_selector_defns()\n");

    $scratch_str .= &dk::annotate($col, __FILE__, __LINE__);
    foreach my $generic (@$generics)
    {
        if (&is_va($generic))
        {
            my $keyword_types = $$generic{'keyword-types'} ||= undef;
	    if (!&is_raw($generic)) {
		$scratch_str .= &common::print_selector($generic, $col, ['selector', ':', 'va']);
	    }
            $$generic{'keyword-types'} = $keyword_types;
        }
    }

    if (1)
    {
	$scratch_str .= &dk::print("#if 0\n");
	foreach my $generic (@$generics)
	{
	    if (&is_va($generic))
	    {
		my $varargs_generic = &method::varargs_from_qual_va_list($generic);
                my $keyword_types = $$varargs_generic{'keyword-types'} ||= undef;
		if (!&is_raw($generic)) {
		    $scratch_str .= &common::print_selector($varargs_generic, $col, ['selector']);
		}
                $$varargs_generic{'keyword-types'} = $keyword_types;
	    }
	}
	$scratch_str .= &dk::print("#endif\n");
    } # if ()
    foreach my $generic (@$generics)
    {
        if (!&is_va($generic))
        {
            my $keyword_types = $$generic{'keyword-types'} ||= undef;
	    if (!&is_raw($generic)) {
		$scratch_str .= &common::print_selector($generic, $col, ['selector']);
	    }
            $$generic{'keyword-types'} = $keyword_types;
        }
    }
    return $scratch_str;
}

my $global_prev_io;

sub va_generics
{
    my ($generics, $name) = @_;
    my $va_generics = [];
    my $fa_generics = [];
    foreach my $generic (@$generics)
    {
	if (!$name || $name eq "@{$$generic{'name'}}")
	{
        if (&is_va($generic))
        {
            &_add_last($va_generics, $generic);
        }
        else
        {
            &_add_last($fa_generics, $generic);         
        }
        }
    }
    return ($va_generics, $fa_generics);
}

sub generics::generate_signature_seq
{
    my ($generics, $is_inline, $col) = @_;
    my ($va_generics, $fa_generics) = &va_generics($generics, undef);
    my $scratch_str = "";
    #$scratch_str .= &dk::print_in_col_string($col, "// generate_signature_seq()\n");
    my $generic;
    my $i;
    my $return_type = 'const signature-t*';
    $scratch_str .= &dk::annotate($col, __FILE__, __LINE__);

    if (0 == @$va_generics)
    {
        $scratch_str .= "static const signature-t* const* signatures-va = NULL;\n";
    }
    else
    {
        $scratch_str .= "static const signature-t* const signatures-va[] = //ro-data\n";
        $scratch_str .= "{\n";
        my $max_width = 0;
	foreach $generic (@$va_generics)
        {
	    my $method_type = &method::type($generic, [ $return_type ]);
	    my $width = length($method_type);
	    if ($width > $max_width)
	    { $max_width = $width; }
        }
	foreach $generic (@$va_generics)
        {
	    my $method_type = &method::type($generic, [ $return_type ]);
	    my $width = length($method_type);
	    my $pad = ' ' x ($max_width - $width);
            my $name = "@{$$generic{'name'}}";
	    $scratch_str .= &dk::print_in_col_string3($col + 1,
						      "(cast(dkt-signature-function-t)cast($method_type) ", $pad, "__signature:va:$name)(),\n");
        }
	$scratch_str .= "  NULL,\n";
        $scratch_str .= "};\n";
    }
    $scratch_str .= &dk::annotate($col, __FILE__, __LINE__);
    if (0 == @$fa_generics)
    {
        $scratch_str .= "static const signature-t* const* signatures = NULL;\n";
    }
    else
    {
        $scratch_str .= "static const signature-t* const signatures[] = //ro-data\n";
        $scratch_str .= "{\n";
        my $max_width = 0;
	foreach $generic (@$va_generics)
        {
	    my $method_type = &method::type($generic, [ $return_type ]);
	    my $width = length($method_type);
	    if ($width > $max_width)
	    { $max_width = $width; }
        }
	foreach $generic (@$fa_generics)
        {
	    if (!&is_raw($generic)) {
		my $method_type = &method::type($generic, [ $return_type ]);
		my $width = length($method_type);
		my $pad = ' ' x ($max_width - $width);
		my $name = "@{$$generic{'name'}}";
		$scratch_str .= &dk::print_in_col_string3($col + 1,
							  "(cast(dkt-signature-function-t)cast($method_type) ", $pad, "__signature:$name)(),\n");
	    }
        }
	$scratch_str .= "  NULL,\n";
        $scratch_str .= "};\n";
    }
    return $scratch_str;
}

sub generics::generate_selector_seq
{
    my ($generics, $is_inline, $col) = @_;
    my ($va_generics, $fa_generics) = &va_generics($generics, undef);
    my $scratch_str = "";
    #$scratch_str .= &dk::print_in_col_string($col, "// generate_selector_seq()\n");
    my $generic;
    my $i;
    my $return_type = "selector-t*";
    $scratch_str .= &dk::annotate($col, __FILE__, __LINE__);

    if (0 == @$va_generics)
    {
        $scratch_str .= "static selector-node-t* selectors-va = NULL;\n";
    }
    else
    {
        $scratch_str .= "static selector-node-t selectors-va[] = //rw-data\n";
        $scratch_str .= "{\n";
        my $max_width = 0;
	my $max_name_width = 0;
	foreach $generic (@$va_generics)
        {
	    my $method_type = &method::type($generic, [ $return_type ]);
	    my $width = length($method_type);
	    if ($width > $max_width)
	    { $max_width = $width; }

            my $name = "@{$$generic{'name'}}";
	    my $name_width = length($name);
	    if ($name_width > $max_name_width)
	    { $max_name_width = $name_width; }
        }
	foreach $generic (@$va_generics)
        {
	    my $method_type = &method::type($generic, [ $return_type ]);
	    my $width = length($method_type);
	    my $pad = ' ' x ($max_width - $width);
            my $name = "@{$$generic{'name'}}";
	    my $name_width = length($name);
	    my $name_pad = ' ' x ($max_name_width - $name_width);
	    $scratch_str .= &dk::print_in_col_string3($col + 1, "{ (cast(dkt-selector-function-t)(cast($method_type) ", $pad, "__selector:va:$name");
	    $scratch_str .= $name_pad;
	    $scratch_str .= "))(), NULL },\n";
        }
	$scratch_str .= "  { NULL, NULL },\n";
        $scratch_str .= "};\n";
    }
    $scratch_str .= &dk::annotate($col, __FILE__, __LINE__);
    if (0 == @$fa_generics)
    {
        $scratch_str .= "static selector-node-t* selectors = NULL;\n";
    }
    else
    {
        $scratch_str .= "static selector-node-t selectors[] = //rw-data\n";
        $scratch_str .= "{\n";
        my $max_width = 0;
	my $max_name_width = 0;
	foreach $generic (@$fa_generics)
        {
	    my $method_type = &method::type($generic, [ $return_type ]);
	    my $width = length($method_type);
	    if ($width > $max_width)
	    { $max_width = $width; }

            my $name = "@{$$generic{'name'}}";
	    my $name_width = length($name);
	    if ($name_width > $max_name_width)
	    { $max_name_width = $name_width; }
        }
	foreach $generic (@$fa_generics)
        {
	    if (!&is_raw($generic)) {
		my $method_type = &method::type($generic, [ $return_type ]);
		my $width = length($method_type);
		my $pad = ' ' x ($max_width - $width);
		my $name = "@{$$generic{'name'}}";
		my $name_width = length($name);
		my $name_pad = ' ' x ($max_name_width - $name_width);
		$scratch_str .= &dk::print_in_col_string3($col + 1, "{ (cast(dkt-selector-function-t)(cast($method_type) ", $pad, "__selector:$name");
		$scratch_str .= $name_pad;
		$scratch_str .= "))(), NULL },\n";
	    }
        }
	$scratch_str .= "  { NULL, NULL },\n";
        $scratch_str .= "};\n";
    }
    return $scratch_str;
}

sub generics::generate_va_generic_defns
{
    my ($generics, $is_inline, $col) = @_;

    foreach my $generic (@$generics)
    {
        if (&is_va($generic))
        {
            my $scope = [];
            &path::add_last($scope, 'dk');
            my $new_generic = &deep_copy($generic);
            $$new_generic{'is-inline'} = $is_inline;

            $$new_generic{'defined?'} = 1; # hackhack

	    my $klass_type;
            &method::generate_va_method_defn($new_generic, $scope, $col, $klass_type = undef); # object-t
            $$new_generic{'parameter-types'}[0] = $global_seq_super_t; # replace_first
            &method::generate_va_method_defn($new_generic, $scope, $col, $klass_type = undef); # super-t
            &path::remove_last($scope);
        }
    }
}

sub generics::generate_generic_defn
{
    my ($generic, $is_inline, $col) = @_;

    my $new_arg_type            = $$generic{'parameter-types'};
    my $new_arg_type_list   = &arg_type::list_types($new_arg_type);
    $new_arg_type            = $$generic{'parameter-types'};

    my $new_arg_names           = &arg_type::names($new_arg_type);
    my $new_arg_list            = &arg_type::list_pair($new_arg_type, $new_arg_names);
    my $return_type = &arg::type($$generic{'return-type'});
    my $scratch_str_ref = &global_scratch_str_ref();
    if (&is_va($generic)) {
	$$scratch_str_ref .= &dk::print_in_col_string($col, "namespace dk { namespace va { ");
    }
    else {
	$$scratch_str_ref .= &dk::print_in_col_string($col, "namespace dk { ");
    }
    if (&is_exported($generic))
    {
        $$scratch_str_ref .= &dk::print("export");
    }
    else
    {
        $$scratch_str_ref .= &dk::print("noexport");
    }
    if ($is_inline)
    {
        $$scratch_str_ref .= &dk::print(" INLINE");
    }
    $$scratch_str_ref .= &dk::print(" /*generic*/");
    my $generic_name = "@{$$generic{'name'}}";

    $$scratch_str_ref .= &dk::print(" $return_type $generic_name($$new_arg_list)");
    
    if ($$generic{'exception-types'})
    {
        my $throw_arg_type = &arg_type::list_types($$generic{'exception-types'});
        $$scratch_str_ref .= &dk::print(" throw($$throw_arg_type)");
    }
    
    if (&is_nrt_decl() || &is_nrt_defn() || &is_rt_decl())
    {
	if (&is_va($generic)) {
	    $$scratch_str_ref .= &dk::print("; } }\n");
	}
	else {
	    $$scratch_str_ref .= &dk::print("; }\n");
	}
    }
    elsif (&is_rt_decl() || &is_rt_defn())
    {
        $$scratch_str_ref .= &dk::print("\n");
        $$scratch_str_ref .= &dk::print_in_col_string($col, "{\n");
        $col++;
        if (&is_va($generic))
        {
	    $$scratch_str_ref .= &dk::print("#if DEBUG\n");
            $$scratch_str_ref .= &dk::print_in_col_string($col, "static const signature-t* signature = signature(va:$generic_name($$new_arg_type_list));\n");
	    $$scratch_str_ref .= &dk::print("#endif\n");
            $$scratch_str_ref .= &dk::print_in_col_string($col, "static selector-t selector = selector(va:$generic_name($$new_arg_type_list));\n");
            $$scratch_str_ref .= &dk::print_in_col_string($col, "object-t klass = object->klass;\n");
            $$scratch_str_ref .= &dk::print_in_col_string($col, "method-t _func_ = klass:unbox(klass)->methods.addrs[selector];\n");
        }
        else
        {
	    $$scratch_str_ref .= &dk::print("#if DEBUG\n");
            $$scratch_str_ref .= &dk::print_in_col_string($col, "static const signature-t* signature = signature($generic_name($$new_arg_type_list));\n");
	    $$scratch_str_ref .= &dk::print("#endif\n");
            $$scratch_str_ref .= &dk::print_in_col_string($col, "static selector-t selector = selector($generic_name($$new_arg_type_list));\n");
            $$scratch_str_ref .= &dk::print_in_col_string($col, "object-t klass = object->klass;\n");
            $$scratch_str_ref .= &dk::print_in_col_string($col, "method-t _func_ = klass:unbox(klass)->methods.addrs[selector];\n");
        }
	$$scratch_str_ref .= &dk::print("#if DEBUG\n");
        $$scratch_str_ref .= &dk::print_in_col_string($col, "if (cast(method-t)DKT-NULL-METHOD == _func_)\n");
        $$scratch_str_ref .= &dk::print_in_col_string($col + 1, "throw make(no-such-method-exception:klass, object => object, kls => dkt-klass(object), signature => signature);\n");
	$$scratch_str_ref .= &dk::print("#endif\n");
        my $arg_names = &deep_copy(&arg_type::names(&deep_copy($$generic{'parameter-types'})));
        my $arg_names_list = &arg_type::list_names($arg_names);
        
	if ($ENV{'DK_TRACE_MACROS'}) {
        $$scratch_str_ref .= &dk::print_in_col_string($col, "DK-TRACE-BEFORE(signature, _func_, $$arg_names_list);\n");
	}
        
        my $var_name = 'result';
        
        if (defined $$generic{'return-type'})
        {
            $$scratch_str_ref .= &dk::print_in_col_string($col, "$return_type $var_name = ");
        }
        else
        {
            $$scratch_str_ref .= &dk::print_in_col_string($col, "");
        }


        $new_arg_names = &arg_type::names($new_arg_type);

        my $new_arg_names_list = &arg_type::list_names($new_arg_names);
        
        $$scratch_str_ref .= &dk::print("(cast($return_type (*)($$new_arg_type_list))_func_)($$new_arg_names_list);\n");
	if ($ENV{'DK_TRACE_MACROS'}) {
        $$scratch_str_ref .= &dk::print_in_col_string($col, "DK-TRACE-AFTER(signature, _func_, $$arg_names_list, $var_name);\n");
	}

        if (defined $$generic{'return-type'})
        {
            $$scratch_str_ref .= &dk::print_in_col_string($col, "return $var_name;\n");
        }
        else
        {
            $$scratch_str_ref .= &dk::print_in_col_string($col, "return;\n");
        }
        $col--;
	if (&is_va($generic)) {
	    $$scratch_str_ref .= &dk::print_in_col_string($col, "} } }\n");
	}
	else {
	    $$scratch_str_ref .= &dk::print_in_col_string($col, "} }\n");
	}
    }
}

sub generics::generate_super_generic_defn
{
    my ($generic, $is_inline, $col) = @_;

    my $new_arg_type            = $$generic{'parameter-types'};
    my $new_arg_type_list   = &arg_type::list_types($new_arg_type);
    $new_arg_type            = $$generic{'parameter-types'};
    $new_arg_type            = &arg_type::super($new_arg_type);
    my $new_arg_names           = &arg_type::names($new_arg_type);
    my $new_arg_list            = &arg_type::list_pair($new_arg_type, $new_arg_names);
    my $return_type = &arg::type($$generic{'return-type'});
    my $scratch_str_ref = &global_scratch_str_ref();    
    if (&is_va($generic)) {
	$$scratch_str_ref .= &dk::print_in_col_string($col, "namespace dk { namespace va { ");
    }
    else {
	$$scratch_str_ref .= &dk::print_in_col_string($col, "namespace dk { ");
    }
    if (&is_exported($generic))
    {
        $$scratch_str_ref .= &dk::print("export");
    }
    else
    {
        $$scratch_str_ref .= &dk::print("noexport");
    }
    if ($is_inline)
    {
	$$scratch_str_ref .= &dk::print(" INLINE");
    }
    $$scratch_str_ref .= &dk::print(" /*generic*/");
    my $generic_name = "@{$$generic{'name'}}";

    $$scratch_str_ref .= &dk::print(" $return_type $generic_name($$new_arg_list)");
    
    if ($$generic{'exception-types'})
    {
        my $throw_arg_type = &arg_type::list_types($$generic{'exception-types'});
        $$scratch_str_ref .= &dk::print(" throw($$throw_arg_type)");
    }
    
    if (&is_nrt_decl() || &is_nrt_defn() || &is_rt_decl())
    {
	if (&is_va($generic)) {
	    $$scratch_str_ref .= &dk::print("; } }\n");
	}
	else {
	    $$scratch_str_ref .= &dk::print("; }\n");
	}
    }
    elsif (&is_rt_decl() || &is_rt_defn())
    {
        $$scratch_str_ref .= &dk::print("\n");
        $$scratch_str_ref .= &dk::print_in_col_string($col, "{\n");
        $col++;
        if (&is_va($generic))
        {
	    $$scratch_str_ref .= &dk::print("#if DEBUG\n");
            $$scratch_str_ref .= &dk::print_in_col_string($col, "static const signature-t* signature = signature(va:$generic_name($$new_arg_type_list));\n");
	    $$scratch_str_ref .= &dk::print("#endif\n");
            $$scratch_str_ref .= &dk::print_in_col_string($col, "static selector-t selector = selector(va:$generic_name($$new_arg_type_list));\n");
            $$scratch_str_ref .= &dk::print_in_col_string($col, "object-t klass = klass:unbox(arg0.klass)->superklass;\n");
            $$scratch_str_ref .= &dk::print_in_col_string($col, "method-t _func_ = klass:unbox(klass)->methods.addrs[selector];\n");
        }
        else
        {
	    $$scratch_str_ref .= &dk::print("#if DEBUG\n");
            $$scratch_str_ref .= &dk::print_in_col_string($col, "static const signature-t* signature = signature($generic_name($$new_arg_type_list));\n");
	    $$scratch_str_ref .= &dk::print("#endif\n");
            $$scratch_str_ref .= &dk::print_in_col_string($col, "static selector-t selector = selector($generic_name($$new_arg_type_list));\n");
            $$scratch_str_ref .= &dk::print_in_col_string($col, "object-t klass = klass:unbox(arg0.klass)->superklass;\n");
            $$scratch_str_ref .= &dk::print_in_col_string($col, "method-t _func_ = klass:unbox(klass)->methods.addrs[selector];\n");
        }
	$$scratch_str_ref .= &dk::print("#if DEBUG\n");
        $$scratch_str_ref .= &dk::print_in_col_string($col, "if (cast(method-t)DKT-NULL-METHOD == _func_)\n");
        $$scratch_str_ref .= &dk::print_in_col_string($col + 1, "throw make(no-such-method-exception:klass, object => arg0.self, superkls => dkt-superklass(arg0.klass), signature => signature);\n");
	$$scratch_str_ref .= &dk::print("#endif\n");
        my $arg_names = &deep_copy(&arg_type::names(&arg_type::super($$generic{'parameter-types'})));
        my $arg_names_list = &arg_type::list_names($arg_names);
        
	if ($ENV{'DK_TRACE_MACROS'}) {
        $$scratch_str_ref .= &dk::print_in_col_string($col, "DK-TRACE-BEFORE(signature, _func_, $$arg_names_list);\n");
	}
        
        my $var_name = 'result';
        
        if (defined $$generic{'return-type'})
        {
            $$scratch_str_ref .= &dk::print_in_col_string($col, "$return_type $var_name = ");
        }
        else
        {
            $$scratch_str_ref .= &dk::print_in_col_string($col, "");
        }
        
        $new_arg_type = &arg_type::super($new_arg_type);
        $new_arg_names = &arg_type::names($new_arg_type);
        &_replace_first($new_arg_names, "arg0.self");
        my $new_arg_names_list = &arg_type::list_names($new_arg_names);
        
        $$scratch_str_ref .= &dk::print("(cast($return_type (*)($$new_arg_type_list))_func_)($$new_arg_names_list);\n");
	if ($ENV{'DK_TRACE_MACROS'}) {
        $$scratch_str_ref .= &dk::print_in_col_string($col, "DK-TRACE-AFTER(signature, _func_, $$arg_names_list, $var_name);\n");
	}
        
        if (defined $$generic{'return-type'})
        {
            $$scratch_str_ref .= &dk::print_in_col_string($col, "return $var_name;\n");
        }
        else
        {
            $$scratch_str_ref .= &dk::print_in_col_string($col, "return;\n");
        }
        $col--;
	if (&is_va($generic)) {
	    $$scratch_str_ref .= &dk::print_in_col_string($col, "} } }\n");
	}
	else {
	    $$scratch_str_ref .= &dk::print_in_col_string($col, "} }\n");
	}
    }
}

sub generics::generate_generic_defns
{
    my ($generics, $is_inline, $col) = @_;
    my $scratch_str_ref = &global_scratch_str_ref();
    #$$scratch_str_ref .= &dk::print_in_col_string($col, "// generate_generic_defns()\n");
    my $generic;
    #$$scratch_str_ref .= &dk::print("#if defined DK-VA-GENERICS\n");
    $$scratch_str_ref .= &dk::annotate($col, __FILE__, __LINE__);
    $$scratch_str_ref .= &dk::print_in_col_string($col, "// VA OBJECT-T\n");
    foreach $generic (@$generics)
    {
        if (&is_va($generic))
        {
	    if (!&is_raw($generic)) {
		&generics::generate_generic_defn($generic, $is_inline, $col);
	    }
        }
    }
    $$scratch_str_ref .= &dk::print_in_col_string($col, "// VA SUPER-T\n");
    foreach $generic (@$generics)
    {
        if (&is_va($generic))
        {
	    if (!&is_raw($generic)) {
		&generics::generate_super_generic_defn($generic, $is_inline, $col);
	    }
        }
    }
    #$$scratch_str_ref .= &dk::print("#endif // defined DK-VA-GENERICS\n");
    #if (!&is_raw($generic)) {
	&generics::generate_va_generic_defns($generics, $is_inline = 0, $col);
    #}
    $$scratch_str_ref .= &dk::print_in_col_string($col, "// OBJECT-T\n");
    foreach $generic (@$generics)
    {
        if (!&is_va($generic))
        {
	    if (!&is_raw($generic)) {
		&generics::generate_generic_defn($generic, $is_inline, $col);
	    }
        }
    }
    $$scratch_str_ref .= &dk::print_in_col_string($col, "// SUPER-T\n");
    foreach $generic (@$generics)
    {
        if (!&is_va($generic))
        {
	    if (!&is_raw($generic)) {
		&generics::generate_super_generic_defn($generic, $is_inline, $col);
	    }
        }
    }
}

sub linkage_unit::generate_signatures
{
    my ($scope, $generics) = @_;
    my $col = 0;
    my $scratch_str = "";
    $scratch_str .= &dk::annotate($col, __FILE__, __LINE__);
    $scratch_str .= &common::generate_signature_defns($generics, $col); # __signature:foobar(...)
    return $scratch_str;
}

sub linkage_unit::generate_signatures_seq
{
    my ($scope, $generics) = @_;
    my $col = 0;
    my $scratch_str = "";
    $scratch_str .= &dk::annotate($col, __FILE__, __LINE__);
    if (&is_nrt_defn() || &is_rt_defn())
    {
	my $is_inline;
        $scratch_str .= &generics::generate_signature_seq($generics, $is_inline = 0, $col);
    }
    return $scratch_str;
}

sub linkage_unit::generate_selectors
{
    my ($scope, $generics) = @_;
    my $col = 0;
    my $scratch_str = "";
    $scratch_str .= &dk::annotate($col, __FILE__, __LINE__);
    $scratch_str .= &common::generate_selector_defns($generics, $col); # __selector:foobar(...)
    return $scratch_str;
}

sub linkage_unit::generate_selectors_seq
{
    my ($scope, $generics) = @_;
    my $col = 0;
    my $scratch_str = "";
    $scratch_str .= &dk::annotate($col, __FILE__, __LINE__);
    if (&is_nrt_defn() || &is_rt_defn())
    {
	my $is_inline;
        $scratch_str .= &generics::generate_selector_seq($generics, $is_inline = 0, $col);
    }
    return $scratch_str;
}

sub linkage_unit::generate_generics
{
    my ($file, $scope) = @_;
    my $col = 0;
    my $scratch_str_ref = &global_scratch_str_ref();
    $$scratch_str_ref .= &dk::annotate($col, __FILE__, __LINE__);
    my $is_inline;
    
    if ($$file{'should-generate-make'})
    {
        $$scratch_str_ref .= &dk::print("\n");
	$$scratch_str_ref .= &dk::print_in_col_string($col, "namespace dk { namespace va { noexport /*generic*/ object-t init(object-t, va-list-t); } }\n");
	$$scratch_str_ref .= &dk::print_in_col_string($col, "namespace dk { noexport /*generic*/ object-t alloc(object-t); }\n");
        $$scratch_str_ref .= &dk::print("\n");
	$$scratch_str_ref .= &dk::print_in_col_string($col, "#if !defined DK-USE-MAKE-MACRO\n");
        &generics::generate_va_make_defn($scope, $is_inline = 1, $col);
	$$scratch_str_ref .= &dk::print_in_col_string($col, "#endif\n");
    }
    &generics::generate_generic_defns($scope, $is_inline = 0, $col);
    return $$scratch_str_ref;
}

sub generics::generate_va_make_defn
{
    my ($generics, $is_inline, $col) = @_;
    my $scratch_str_ref = &global_scratch_str_ref();
    $$scratch_str_ref .= &dk::annotate($col, __FILE__, __LINE__);
    #$$scratch_str_ref .= &dk::print_in_col_string($col, "// generate_va_make_defn()\n");
    $$scratch_str_ref .= &dk::print_in_col_string($col, "sentinel noexport object-t make(object-t klass, ...)");
    if (&is_nrt_decl() || &is_nrt_defn() || &is_rt_decl())
    {
        $$scratch_str_ref .= &dk::print(";\n");
    }
    elsif (&is_rt_decl() || &is_rt_defn())
    {
        my $var_name = 'result';
        $$scratch_str_ref .= &dk::print("\n");
        $$scratch_str_ref .= &dk::print_in_col_string($col, "{\n");
        $col++;
        my $method_type_decl;

        $method_type_decl = "object-t (*_func_)(object-t, va-list-t)";### should use method::type_decl
        $$scratch_str_ref .= &dk::print_in_col_string($col, "static $method_type_decl = dk:va:init;\n");

        $method_type_decl = "object-t (*alloc)(object-t)";### should use method::type_decl
        $$scratch_str_ref .= &dk::print_in_col_string($col, "static $method_type_decl = dk:alloc;\n");

        $$scratch_str_ref .= &dk::print_in_col_string($col, "object-t object = alloc(klass);\n");
        $$scratch_str_ref .= &dk::print_in_col_string($col, "va-list-t args;\n");
        $$scratch_str_ref .= &dk::print_in_col_string($col, "va-start(args, klass);\n");
	if ($ENV{'DK_TRACE_MACROS'}) {
        $$scratch_str_ref .= &dk::print_in_col_string($col, "DK-VA-TRACE-BEFORE-INIT(klass, args);\n");
	}
        $$scratch_str_ref .= &dk::print_in_col_string($col, "object = _func_(object, args);\n");
	if ($ENV{'DK_TRACE_MACROS'}) {
        $$scratch_str_ref .= &dk::print_in_col_string($col, "DK-VA-TRACE-AFTER-INIT(klass, args);\n");
	}
        $$scratch_str_ref .= &dk::print_in_col_string($col, "va-end(args);\n");
        $$scratch_str_ref .= &dk::print_in_col_string($col, "return object;\n");
        $col--;
        $$scratch_str_ref .= &dk::print_in_col_string($col, "}\n");
    }
}

sub path::string
{
    my ($seq) = @_;
    my $string = "@$seq";
    return $string;
}

## exists()  (does this key exist)
## defined() (is the value (for this key) non-undef)

sub dk::parse
{
    my ($dkfile) = @_; # string.dk
    my $plfile = &rep_path_from_dk_path($dkfile);
    my $file = &scalar_from_file($plfile);
    $file = &ka_translate($file);
    return $file;
}

sub generate_struct_or_union_defn
{
    my ($col, $slots_scope, $is_exported, $is_slots) = @_;
    my $scratch_str_ref = &global_scratch_str_ref();
    my $slots_info = $$slots_scope{'info'};

    if ('struct' eq $$slots_scope{'cat'} ||
	'union'  eq $$slots_scope{'cat'}) {
	$$scratch_str_ref .= &dk::print("$$slots_scope{'cat'} slots-t\n");
    }
    else
    { die __FILE__, ":", __LINE__, ": error:\n"; }

    $$scratch_str_ref .= &dk::print_in_col_string($col, "{\n");
    my $max_width = 0;
    foreach my $slot_info (@$slots_info) {
        my ($slot_name, $slot_type) = %$slot_info;
        my $width = length($slot_type);
	if ($width > $max_width)
	{ $max_width = $width; }
    }
    foreach my $slot_info (@$slots_info) {
        my ($slot_name, $slot_type) = %$slot_info;
        my $width = length($slot_type);
	my $pad = ' ' x ($max_width - $width);
        $$scratch_str_ref .= &dk::print_in_col_string3($col + 1, "$slot_type ", $pad, "$slot_name;\n");
    }
    $$scratch_str_ref .= &dk::print_in_col_string($col, "}; ");
}

sub generate_enum_defn
{
    my ($col, $enum, $is_exported, $is_slots) = @_;
    #die if $$enum{'type'} && $is_slots;
    my $info = $$enum{'info'};
    my $scratch_str_ref = &global_scratch_str_ref();

    if ($is_slots)
    {
	$$scratch_str_ref .= &dk::print("enum slots-t");
    }
    else
    {
	$$scratch_str_ref .= &dk::print("enum");
	if ($$enum{'type'})
	{
	    $$scratch_str_ref .= &dk::print_in_col_string($col, " @{$$enum{'type'}}");
	}
    }
    $$scratch_str_ref .= &dk::print_in_col_string($col, "\n");

    $$scratch_str_ref .= &dk::print_in_col_string($col, "{\n");
    my $max_width = 0;
    foreach my $pair (@$info)
    {
	my ($name, $value) = %$pair;
        my $width = length($name);
	if ($width > $max_width)
	{ $max_width = $width; }
    }
    foreach my $pair (@$info)
    {
	my ($name, $value) = %$pair;
        my $width = length($name);
	my $pad = ' ' x ($max_width - $width);
        $$scratch_str_ref .= &dk::print_in_col_string3($col + 1, "$name = ", $pad, "$value,\n");
    }
    $$scratch_str_ref .= &dk::print_in_col_string($col, "}; ");
}

sub parameter_list_from_slots_info
{
    my ($slots_info) = @_;
    my $names = '';
    my $pairs = '';
    my $sep = '';
    
    foreach my $slot_info (@$slots_info)
    {
        my $keys = [keys %$slot_info];
        my $name = $$keys[0];
        my $type = $$slot_info{$name};
	if ('klass' eq $name) {
	    $name = 'kls';
	}
        $names .= "$sep$name";
        $pairs .= "$sep$type $name";
        
        $sep = ', ';
    }
    return ($pairs, $names);
}

sub has_object_method_defn
{
    my ($klass_scope, $raw_method_info) = @_;
    my $result = 0;

    my $object_method_info = &convert_to_object_method($raw_method_info);
    my $object_method_sig = &function::overloadsig($object_method_info, undef);
    
    if ($$klass_scope{'methods'}{$object_method_sig} &&
	$$klass_scope{'methods'}{$object_method_sig}{'defined?'})
    {
	$result = 1;
    }
    return $result;
}

sub linkage_unit::generate_klasses_body
{
    my ($klass_scope, $col, $klass_type, $klass_path, $klass_name) = @_;
    my $is_klass_defn = scalar keys %$klass_scope;
    my $va_list_methods = &klass::va_list_methods($klass_scope);
    my $ka_methods = &klass::ka_methods($klass_scope);
    my $method;

    my $scratch_str_ref = &global_scratch_str_ref();
    $$scratch_str_ref .= &dk::annotate($col, __FILE__, __LINE__);
    
    if (&is_nrt_decl() || &is_nrt_defn() || &is_rt_decl())
    {
	#$$scratch_str_ref .= &dk::print_in_col_string($col, "extern noexport const symbol-t __type__;\n");
	$$scratch_str_ref .= &dk::print_in_col_string($col, "$klass_type $klass_name { extern noexport const symbol-t __klass__; }\n");
    }
    elsif (&is_rt_decl() || &is_rt_defn())
    {
	#$$scratch_str_ref .= &dk::print_in_col_string($col, "noexport const symbol-t __type__ = \$$klass_type;\n");
	$$scratch_str_ref .= &dk::print_in_col_string($col, "$klass_type $klass_name { /*noexport*/ const symbol-t __klass__ = dk-intern(\"@$klass_path\"); }\n");
    }

    if ('trait' eq $klass_type)
    {
	#my $is_exported;
	#if (exists $$klass_scope{'enum'})
	#{
        #    $$scratch_str_ref .= &dk::print_in_col_string($col, "//if\n");
	#    &generate_enum_defn($col, $$klass_scope{'enum'}{'info'}, $is_exported = 1);
	#}
    }
    elsif ('klass' eq $klass_type)
    {
        if (&is_nrt_decl() || &is_nrt_defn() || &is_rt_decl())
        {
            $$scratch_str_ref .= &dk::print_in_col_string($col, "$klass_type $klass_name { extern noexport object-t klass; }\n");
        }
        elsif (&is_rt_decl() || &is_rt_defn())
        {
            $$scratch_str_ref .= &dk::print_in_col_string($col, "$klass_type $klass_name { noexport object-t klass = NULL; }\n");
        }
	if (!&is_rt_defn())
	{
	    my $is_exported;
	    if (exists $$klass_scope{'const'})
	    {
		foreach my $const (@{$$klass_scope{'const'}})
		{
		    $$scratch_str_ref .= &dk::print_in_col_string($col, "$klass_type $klass_name { extern const $$const{'type'} $$const{'name'}; }\n");
		}
	    }
	}
        #$$scratch_str_ref .= &dk::annotate($col, __FILE__, __LINE__);
	my $object_method_defns = {};
        foreach $method (sort method::compare values %{$$klass_scope{'raw-methods'}})
        {
            if (&is_nrt_defn() || &is_rt_defn() || &is_exported($method))
            {
                if (!&is_va($method))
                {
                    if (&is_box_type($$method{'parameter-types'}[0]))
                    {
			my $method_decl_ref = &function::decl($method, $klass_path);
			$$scratch_str_ref .= &dk::annotate($col, __FILE__, __LINE__);
			$$scratch_str_ref .= &dk::print_in_col_string($col, "$klass_type $klass_name { $$method_decl_ref }\n");
			if (!&has_object_method_defn($klass_scope, $method))
			{
			    my $object_method = &convert_to_object_method($method);
			    my $sig = &function::overloadsig($object_method, []);
			    if (!$$object_method_defns{$sig}) {
				&generate_object_method_defn($method, $klass_path, $col, $klass_type);
			    }
			    $$object_method_defns{$sig} = 1;
		        }
                    }
                }
            }
            else
            {
                if (!&is_va($method))
                {
		    my $method_decl_ref = &function::decl($method, $klass_path);
		    $$scratch_str_ref .= &dk::annotate($col, __FILE__, __LINE__);
		    $$scratch_str_ref .= &dk::print_in_col_string($col, "$klass_type $klass_name { $$method_decl_ref }\n");
		    my $object_method = &convert_to_object_method($method);
		    my $sig = &function::overloadsig($object_method, []);
		    if (!$$object_method_defns{$sig}) {
			&generate_object_method_decl($method, $klass_path, $col, $klass_type);                    
		    }
		    $$object_method_defns{$sig} = 1;
                }
            }
        }
	my $exported_raw_methods = &exported_raw_methods($klass_scope);
        foreach $method (sort method::compare values %$exported_raw_methods)
        {
            die if !&is_exported($method);
            if (&is_nrt_defn() || &is_rt_defn())
            {
                if (!&is_va($method))
                {
                    if (&is_box_type($$method{'parameter-types'}[0]))
                    {
			my $method_decl_ref = &function::decl($method, $klass_path);
			$$scratch_str_ref .= &dk::print_in_col_string($col, "$klass_type $klass_name { $$method_decl_ref }\n");
			if (!&has_object_method_defn($klass_scope, $method))
			{
			    my $object_method = &convert_to_object_method($method);
			    my $sig = &function::overloadsig($object_method, []);
			    if (!$$object_method_defns{$sig}) {
				&generate_object_method_defn($method, $klass_path, $col, $klass_type);
			    }
			    $$object_method_defns{$sig} = 1;
			}
                    }
                }
            }
            else
            {
                if (!&is_va($method))
                {
		    #my $object_method = &convert_to_object_method($method);
		    #my $sig = &function::overloadsig($object_method, []);
		    #if (!$$object_method_defns{$sig}) {
			#&generate_object_method_decl($method, $klass_path, $col);                    
		    #}
		    #$$object_method_defns{$sig} = 1;
                }
            }
        }
	if (0 < keys %$object_method_defns) {
	    #print STDERR &Dumper($object_method_defns);
	}
        if (&has_slots($klass_scope))
        {
            ### unbox()

            if ('object' eq &path::string($klass_path))
            {
                $$scratch_str_ref .= &dk::print_in_col_string($col, "// special-case: no generated unbox() for klass 'object' due to Koenig lookup\n");
            }
            elsif ('klass' eq &path::string($klass_path))
            {
                $$scratch_str_ref .= &dk::print_in_col_string($col, "$klass_type $klass_name { noexport pure slots-t* unbox(object-t object)");

                if (&is_nrt_decl() || &is_nrt_defn() || &is_rt_decl())
                {
                    $$scratch_str_ref .= &dk::print("; } // special-case\n");
                }
                elsif (&is_rt_decl() || &is_rt_defn())
                {
                    $$scratch_str_ref .= &dk::print(" // special-case\n");
                    $$scratch_str_ref .= &dk::print_in_col_string($col, "{\n");
                    $$scratch_str_ref .= &dk::print_in_col_string($col + 1, "slots-t* s = NULL;\n");
                    $$scratch_str_ref .= &dk::print_in_col_string($col + 1, "if (NULL != object) // needed for interator implementation\n");
                    $$scratch_str_ref .= &dk::print_in_col_string($col + 1, "{\n");
                    $$scratch_str_ref .= &dk::print_in_col_string($col + 1 + 1, "s = (slots-t*)((uint8-t*)object + sizeof(object::slots-t));\n");
                    $$scratch_str_ref .= &dk::print_in_col_string($col + 1, "}\n");
                    $$scratch_str_ref .= &dk::print_in_col_string($col + 1, "return s;\n");
                    $$scratch_str_ref .= &dk::print_in_col_string($col, "} }\n");
                }
            }
            else
            {
                ### unbox() same for all types
                if ($is_klass_defn || (&has_exported_slots() && &has_slots_info()))
                {
                    $$scratch_str_ref .= &dk::print_in_col_string($col, "$klass_type $klass_name { noexport pure slots-t* unbox(object-t object)");
                    if (&is_nrt_decl() || &is_nrt_defn() || &is_rt_decl())
                    {
                        $$scratch_str_ref .= &dk::print("; }\n");
                    }
                    elsif (&is_rt_decl() || &is_rt_defn())
                    {
                        $$scratch_str_ref .= &dk::print("\n");
                        $$scratch_str_ref .= &dk::print_in_col_string($col, "{\n");
                        $$scratch_str_ref .= &dk::print_in_col_string($col + 1, "slots-t* s = NULL;\n");
                        $$scratch_str_ref .= &dk::print_in_col_string($col + 1, "if (NULL != object) // needed for interator implementation\n");
                        $$scratch_str_ref .= &dk::print_in_col_string($col + 1, "{\n");
                        $$scratch_str_ref .= &dk::print_in_col_string($col + 1 + 1, "dk-unbox-check(object, klass); // optional\n");
                        $$scratch_str_ref .= &dk::print_in_col_string($col + 1 + 1, "s = cast(slots-t*)(cast(uint8-t*)object + klass:unbox(klass)->offset);\n");
                        $$scratch_str_ref .= &dk::print_in_col_string($col + 1, "}\n");
                        $$scratch_str_ref .= &dk::print_in_col_string($col + 1, "return s;\n");
                        $$scratch_str_ref .= &dk::print_in_col_string($col, "} }\n");
                    }
                }
            }
        } # if (&has_slots()
        if ('object' eq &path::string($klass_path))
        {
                    ### box() non-array-type
                    $$scratch_str_ref .= &dk::print_in_col_string($col, "$klass_type $klass_name { noexport object-t box(slots-t* arg)");
                
                    if (&is_nrt_decl() || &is_nrt_defn() || &is_rt_decl())
                    {
                        $$scratch_str_ref .= &dk::print("; }\n");
                    }
                    elsif (&is_rt_decl() || &is_rt_defn())
                    {
                        $$scratch_str_ref .= &dk::print("\n");
                        $$scratch_str_ref .= &dk::print_in_col_string($col, "{\n");
                        $col++;
                        $$scratch_str_ref .= &dk::print_in_col_string($col, "return arg;\n");
                        $col--;
                        $$scratch_str_ref .= &dk::print_in_col_string($col, "} }\n");
                    }
	}
	else
	{
            if (&has_exported_slots($klass_scope))
            {
                ### box()
                if (&is_array_type($$klass_scope{'slots'}{'type'}))
                {
                    ### box() array-type
                    $$scratch_str_ref .= &dk::print_in_col_string($col, "$klass_type $klass_name { noexport object-t box(slots-t arg)");
                
                    if (&is_nrt_decl() || &is_nrt_defn() || &is_rt_decl())
                    {
                        $$scratch_str_ref .= &dk::print("; }\n");
                    }
                    elsif (&is_rt_decl() || &is_rt_defn())
                    {
                        $$scratch_str_ref .= &dk::print("\n");
                        $$scratch_str_ref .= &dk::print_in_col_string($col, "{\n");
                        $col++;
                        $$scratch_str_ref .= &dk::print_in_col_string($col, "object-t object = make(klass);\n");
                        $$scratch_str_ref .= &dk::print_in_col_string($col, "slots-t* s = unbox(object);\n");

                        $$scratch_str_ref .= &dk::print_in_col_string($col, "memcpy(*s, arg, sizeof(slots-t)); // unfortunate\n");

                        $$scratch_str_ref .= &dk::print_in_col_string($col, "return object;\n");
                        $col--;
                        $$scratch_str_ref .= &dk::print_in_col_string($col, "} }\n");
                    }
                    $$scratch_str_ref .= &dk::print_in_col_string($col, "$klass_type $klass_name { noexport object-t box(slots-t* arg)");
                        
                    if (&is_nrt_decl() || &is_nrt_defn() || &is_rt_decl())
                    {
                        $$scratch_str_ref .= &dk::print("; }\n");
                    }
                    elsif (&is_rt_decl() || &is_rt_defn())
                    {
                        $$scratch_str_ref .= &dk::print("\n");
                        $$scratch_str_ref .= &dk::print_in_col_string($col, "{\n");
                        $col++;
                        $$scratch_str_ref .= &dk::print_in_col_string($col, "object-t object = box(*arg);\n");
                        $$scratch_str_ref .= &dk::print_in_col_string($col, "return object;\n");
                        $col--;
                        $$scratch_str_ref .= &dk::print_in_col_string($col, "} }\n");
                    }
                }
                else # !&is_array_type()
                {
                    ### box() non-array-type
                    $$scratch_str_ref .= &dk::print_in_col_string($col, "$klass_type $klass_name { noexport object-t box(slots-t* arg)");
                
                    if (&is_nrt_decl() || &is_nrt_defn() || &is_rt_decl())
                    {
                        $$scratch_str_ref .= &dk::print("; }\n");
                    }
                    elsif (&is_rt_decl() || &is_rt_defn())
                    {
                        $$scratch_str_ref .= &dk::print("\n");
                        $$scratch_str_ref .= &dk::print_in_col_string($col, "{\n");
                        $col++;
                        $$scratch_str_ref .= &dk::print_in_col_string($col, "object-t object = make(klass);\n");
                        $$scratch_str_ref .= &dk::print_in_col_string($col, "slots-t* s = unbox(object);\n");

                        $$scratch_str_ref .= &dk::print_in_col_string($col, "*s = *arg;\n");

                        $$scratch_str_ref .= &dk::print_in_col_string($col, "return object;\n");
                        $col--;
                        $$scratch_str_ref .= &dk::print_in_col_string($col, "} }\n");
                    }
                    $$scratch_str_ref .= &dk::print_in_col_string($col, "$klass_type $klass_name { noexport object-t box(slots-t arg)");
                        
                    if (&is_nrt_decl() || &is_nrt_defn() || &is_rt_decl())
                    {
                        $$scratch_str_ref .= &dk::print("; }\n");
                    }
                    elsif (&is_rt_decl() || &is_rt_defn())
                    {
                        $$scratch_str_ref .= &dk::print("\n");
                        $$scratch_str_ref .= &dk::print_in_col_string($col, "{\n");
                        $col++;
                        $$scratch_str_ref .= &dk::print_in_col_string($col, "object-t object = box(&arg);\n");
                        $$scratch_str_ref .= &dk::print_in_col_string($col, "return object;\n");
                        $col--;
                        $$scratch_str_ref .= &dk::print_in_col_string($col, "} }\n");
                    }
                }

                ### construct
                if ($$klass_scope{'slots'}{'cat'} &&
		    'struct' eq $$klass_scope{'slots'}{'cat'}) {
                if (!$ENV{'DK_USE_COMPOUND_LITERALS'}) {
                if (&has_slots_info($klass_scope))
                {
                    my ($pairs, $names) = &parameter_list_from_slots_info($$klass_scope{'slots'}{'info'});

		    if ($pairs =~ m/\[/g)
		    {}
		    else
		    {
                    $$scratch_str_ref .= &dk::print_in_col_string($col, "$klass_type $klass_name { noexport slots-t construct($pairs)");

                    if (&is_nrt_decl() || &is_nrt_defn() || &is_rt_decl())
                    {
                        $$scratch_str_ref .= &dk::print("; }\n");
                    }
                    elsif (&is_rt_decl() || &is_rt_defn())
                    {
                        my $var_name = 'result';
                        $$scratch_str_ref .= &dk::print("\n");
                        $$scratch_str_ref .= &dk::print_in_col_string($col, "{\n");
                        $col++;
                        $$scratch_str_ref .= &dk::print_in_col_string($col, "slots-t $var_name = { $names };\n");
                        $$scratch_str_ref .= &dk::print_in_col_string($col, "return $var_name;\n");
                        $col--;
                        $$scratch_str_ref .= &dk::print_in_col_string($col, "} }\n");
                    }
                    }
                }
                }
                }
                ### create()
                if (0) {
                $$scratch_str_ref .= &dk::print_in_col_string($col, "noexport slots-t* create(slots-t* arg)");
                if (&is_nrt_decl() || &is_nrt_defn() || &is_rt_decl())
                {
                    $$scratch_str_ref .= &dk::print(";\n");
                }
                elsif (&is_rt_decl() || &is_rt_defn())
                {
                    $$scratch_str_ref .= &dk::print("\n");
                    $$scratch_str_ref .= &dk::print_in_col_string($col, "{\n");
                    $col++;
                    $$scratch_str_ref .= &dk::print_in_col_string($col, "slots-t* s = cast(slots-t*)malloc(sizeof(slots-t));\n");
                    $$scratch_str_ref .= &dk::print_in_col_string($col, "memset(s, 0, sizeof(slots-t));\n");

                    if (&is_array_type($$klass_scope{'slots'}{'type'}))
                    {
                        $$scratch_str_ref .= &dk::print_in_col_string($col, "memcpy(s, arg, sizeof(slots-t)); // unfortunate\n");
                    }
                    else
                    {
                        $$scratch_str_ref .= &dk::print_in_col_string($col, "*s = *arg;\n");
                    }
                    $$scratch_str_ref .= &dk::print_in_col_string($col, "return s;\n");
                    $col--;
                    $$scratch_str_ref .= &dk::print_in_col_string($col, "}\n");
                }
                if (!&is_array_type($$klass_scope{'slots'}{'type'}))
                {
                    $$scratch_str_ref .= &dk::print_in_col_string($col, "noexport slots-t* create(slots-t arg)");
                    if (&is_nrt_decl() || &is_nrt_defn() || &is_rt_decl())
                    {
                        $$scratch_str_ref .= &dk::print(";\n");
                    }
                    elsif (&is_rt_decl() || &is_rt_defn())
                    {
                        $$scratch_str_ref .= &dk::print("\n");
                        $$scratch_str_ref .= &dk::print_in_col_string($col, "{\n");
                        $col++;
                        $$scratch_str_ref .= &dk::print_in_col_string($col, "slots-t* s = create(&arg);\n");
                        $$scratch_str_ref .= &dk::print_in_col_string($col, "return s;\n");
                        $col--;
                        $$scratch_str_ref .= &dk::print_in_col_string($col, "}\n");
                    }
                }
            }
            }
        }
    } # if ('klass' eq $klass_type)
    if ($$klass_scope{'has-initialize'})
    {
        $$scratch_str_ref .= &dk::print_in_col_string($col, "$klass_type $klass_name { noexport object-t initialize(object-t kls); }\n");
    }
    if ($$klass_scope{'has-finalize'})
    {
        $$scratch_str_ref .= &dk::print_in_col_string($col, "$klass_type $klass_name { noexport object-t finalize(object-t kls); }\n");
    }
    if (1 || @$ka_methods)
    {
	#print STDERR Dumper($va_list_methods);
        &path::add_last($klass_path, 'va');
        $$scratch_str_ref .= &dk::annotate($col, __FILE__, __LINE__);
	&generate_ka_method_signature_decls($$klass_scope{'methods'}, [ $klass_name ], $col, $klass_type);
        &path::remove_last($klass_path);
    }
    if (1 || @$ka_methods)
    {
	#print STDERR Dumper($va_list_methods);
        &path::add_last($klass_path, 'va');
        $$scratch_str_ref .= &dk::annotate($col, __FILE__, __LINE__);
	&generate_raw_method_signature_decls($$klass_scope{'raw-methods'}, [ $klass_name ], $col, $klass_type);
        &path::remove_last($klass_path);
    }
    if (@$va_list_methods)
    {
	#print STDERR Dumper($va_list_methods);
        &path::add_last($klass_path, 'va');
        $$scratch_str_ref .= &dk::annotate($col, __FILE__, __LINE__);
        foreach $method (@$va_list_methods)
        {
            my $method_decl_ref = &function::decl($method, $klass_path);
            $$scratch_str_ref .= &dk::print_in_col_string($col, "$klass_type $klass_name { namespace va { $$method_decl_ref } }\n");
        }
        &path::remove_last($klass_path);
    }
    if (@$va_list_methods)
    {
        foreach $method (@$va_list_methods)
        {
            if (&is_nrt_defn() || &is_rt_defn() || &is_exported($method))
            {
                my $va_method = &deep_copy($method);
                #$$va_method{'is-inline'} = 1;
                if (&is_nrt_decl() || &is_rt_decl())
                {
                    if (defined $$method{'keyword-types'})
                    {
                        if (0 < @{$$va_method{'keyword-types'}})
                        {
                            &method::generate_va_method_defn($va_method, $klass_path, $col, $klass_type);
                        }
                        else
                        {
                            my $last = &_remove_last($$va_method{'parameter-types'}); # bugbug: should make sure its va-list-t
                            my $method_decl_ref = &function::decl($va_method, $klass_path);
                            $$scratch_str_ref .= &dk::print_in_col_string($col, "$klass_type $klass_name { $$method_decl_ref }\n");
                            &_add_last($$va_method{'parameter-types'}, $last);
                        }
                    }
                }
                else
                {
                    &method::generate_va_method_defn($va_method, $klass_path, $col, $klass_type);
                }
                if (&is_nrt_decl() || &is_rt_decl())
                {
                    if (defined $$method{'keyword-types'})
                    {
                        if (0 != @{$$method{'keyword-types'}})
                        {
                            my $other_method_decl = &ka_method::type_decl($method);
                            
                            my $scope = &path::string($klass_path);
                            $other_method_decl =~ s/\(\*($k+)\)/\/*$scope:*\/$1/;
                            
                            if (&is_exported($method))
                            {
                                $$scratch_str_ref .= &dk::print_in_col_string($col, "export method");
                            }
                            else
                            {
                                $$scratch_str_ref .= &dk::print_in_col_string($col, "noexport method"); # gratuitous
                            }
                            if ($$method{'is-inline'})
                            {
                                #$$scratch_str_ref .= &dk::print(" INLINE");
                            }
                            $$scratch_str_ref .= &dk::print(" $other_method_decl;\n");
                        }
                    }
                }
            }
        }
    }
    $$scratch_str_ref .= &dk::annotate($col, __FILE__, __LINE__);
   #foreach $method (sort method::compare values %{$$klass_scope{'methods'}})
    foreach $method (sort method::compare values %{$$klass_scope{'methods'}}, values %{$$klass_scope{'raw-methods'}})
    {
        if (&is_nrt_defn() || &is_rt_defn() || &is_exported($method))
        {
            if (!&is_va($method))
            {
                my $method_decl_ref = &function::decl($method, $klass_path);
                $$scratch_str_ref .= &dk::print_in_col_string($col, "$klass_type $klass_name { $$method_decl_ref }\n");
            }
        }
    }
}

sub generate_object_method_decl
{
    my ($non_object_method, $klass_path, $col, $klass_type) = @_;
    my $scratch_str_ref = &global_scratch_str_ref();
    my $object_method = &convert_to_object_method($non_object_method);
    my $method_decl_ref = &function::decl($object_method, $klass_path);
    $$scratch_str_ref .= &dk::print_in_col_string($col, "$klass_type @$klass_path { $$method_decl_ref }\n");
}

sub generate_object_method_defn
{
    my ($non_object_method, $klass_path, $col, $klass_type) = @_;

    my $method = &convert_to_object_method($non_object_method);
    my $new_arg_type = $$method{'parameter-types'};
    my $new_arg_type_list = &arg_type::list_types($new_arg_type);
    $new_arg_type = $$method{'parameter-types'};
    my $new_arg_names = &arg_type::names($new_arg_type);
    my $new_arg_list  = &arg_type::list_pair($new_arg_type, $new_arg_names);
    
    my $non_object_return_type = &arg::type($$non_object_method{'return-type'});
    my $return_type = &arg::type($$method{'return-type'});
    my $scratch_str_ref = &global_scratch_str_ref();    
    if (&is_exported($method))
    {
        $$scratch_str_ref .= &dk::print_in_col_string($col, "$klass_type @$klass_path { export method");
    }
    else
    {
        $$scratch_str_ref .= &dk::print_in_col_string($col, "$klass_type @$klass_path { noexport method"); # gratuitous
    }
    my $method_name = "@{$$method{'name'}}";
    $$scratch_str_ref .= &dk::print(" $return_type $method_name($$new_arg_list)");
    
    my $new_unboxed_arg_names = &arg_type::names_unboxed($$non_object_method{'parameter-types'});
    my $new_unboxed_arg_names_list = &arg_type::list_names($new_unboxed_arg_names);

    if ($$method{'exception-types'})
    {
        my $throw_arg_type = &arg_type::list_types($$method{'exception-types'});
        $$scratch_str_ref .= &dk::print(" throw($$throw_arg_type)");
    }
    
    if (&is_nrt_decl() || &is_nrt_defn() || &is_rt_decl())
    {
        $$scratch_str_ref .= &dk::print("; }\n");
    }
    elsif (&is_rt_decl() || &is_rt_defn())
    {
        $$scratch_str_ref .= &dk::print("\n");
        $$scratch_str_ref .= &dk::print_in_col_string($col, "{\n");
        $col++;
        
        my $var_name = 'result';
        
        if (defined $$method{'return-type'})
        {
            if ($non_object_return_type ne $return_type)
            {
                $$scratch_str_ref .= &dk::print_in_col_string($col, "$return_type $var_name = box($method_name($$new_unboxed_arg_names_list));\n");
            }
            else
            {
                $$scratch_str_ref .= &dk::print_in_col_string($col, "$return_type $var_name = $method_name($$new_unboxed_arg_names_list);\n");
            }
        }
        
        if (defined $$method{'return-type'})
        {
            $$scratch_str_ref .= &dk::print_in_col_string($col, "return $var_name;\n");
        }
        else
        {
            $$scratch_str_ref .= &dk::print_in_col_string($col, "return;\n");
        }
        $col--;
        $$scratch_str_ref .= &dk::print_in_col_string($col, "} }\n");
    }
}

sub convert_to_object_type
{
    my ($type_seq) = @_;
    my $result = $type_seq;

    if (&is_box_type($type_seq))
    {
        $result = [ 'object-t' ];
    }
    return $result;
}

sub convert_to_object_method
{
    my ($non_object_method) = @_;
    my $method = &deep_copy($non_object_method);

    $$method{'return-type'} = &convert_to_object_type($$method{'return-type'});

    foreach my $parameter_type (@{$$method{'parameter-types'}})
    {
        $parameter_type = &convert_to_object_type($parameter_type);
    }

    return $method;
}

sub generate_slots_decls
{
    my ($scope, $col, $klass_path, $klass_name, $klass_scope) = @_;

    if (!$klass_scope)
    {
        $klass_scope = &generics::klass_scope_from_klass_name($klass_name);
    }
    my $scratch_str_ref = &global_scratch_str_ref();
    if (!&has_exported_slots($klass_scope) && &has_slots_type($klass_scope))
    {
        my $typedef_body = &typedef_body($$klass_scope{'slots'}{'type'}, 'slots-t');
        $$scratch_str_ref .= &dk::annotate($col, __FILE__, __LINE__);
        $$scratch_str_ref .= &dk::print_in_col_string($col, "klass $klass_name { typedef $$klass_scope{'slots'}{'type'} slots-t; }\n");
        $$scratch_str_ref .= &dk::print_in_col_string($col, "//typedef $klass_name:slots-t $klass_name-t;\n");
    }
    elsif (!&has_exported_slots($klass_scope) && &has_slots($klass_scope))
    {
	if ('struct' eq $$klass_scope{'slots'}{'cat'} ||
	    'union'  eq $$klass_scope{'slots'}{'cat'}) {
	    $$scratch_str_ref .= &dk::annotate($col, __FILE__, __LINE__);
	    $$scratch_str_ref .= &dk::print_in_col_string($col, "klass $klass_name { $$klass_scope{'slots'}{'cat'} slots-t; }\n");
	}
	elsif ('enum' eq $$klass_scope{'slots'}{'cat'}) {
	    $$scratch_str_ref .= &dk::annotate($col, __FILE__, __LINE__);
	    $$scratch_str_ref .= &dk::print_in_col_string($col, "klass $klass_name\n");
	    $$scratch_str_ref .= &dk::print_in_col_string($col, "{\n");
	    my $is_exported;
	    my $is_slots;
	    &generate_enum_defn($col, $$klass_scope{'slots'}, $is_exported = 0, $is_slots = 1);
	    $$scratch_str_ref .= &dk::print_in_col_string($col, "}\n");
	}
	else {
	    print STDERR &Dumper($$klass_scope{'slots'});
	    die __FILE__, ":", __LINE__, ": error:\n";
	}
        $$scratch_str_ref .= &dk::print_in_col_string($col, "//typedef $klass_name:slots-t $klass_name-t;\n");
    }
}

sub is_array_type
{
    my ($type) = @_;
    my $is_array_type = 0;

    if ($type && $type =~ m|\[.*?\]$|)
    {
        $is_array_type = 1;
    }
    return $is_array_type;
}

sub typedef_body
{
    my ($type, $name) = @_;

    my $is_array_type = &is_array_type($type);
    my $is_function_pointer_type = 0;
    if ($type =~ m|\)\s*\(|)
    { $is_function_pointer_type = 1; }
    my $typedef_body = $type;

    if ($is_function_pointer_type && $is_array_type)
    { die __FILE__, ":", __LINE__, ": error:\n"; }
    elsif ($is_function_pointer_type)
    {
        $typedef_body =~ s|\)\s*\(|$name\)\(|g;
    }
    elsif ($is_array_type)
    {
        $typedef_body =~ s|\[| $name\[|g;        
    }
    else
    {
        $typedef_body = "$type $name";
    }
    return $typedef_body
}

sub generate_exported_slots_decls
{
    my ($scope, $col, $klass_path, $klass_name, $klass_scope) = @_;

    if (!$klass_scope)
    {
        $klass_scope = &generics::klass_scope_from_klass_name($klass_name);
    }
    my $scratch_str_ref = &global_scratch_str_ref();
    if ('object' eq "$klass_name")
    {
	if ('struct' eq $$klass_scope{'slots'}{'cat'} ||
	    'union'  eq $$klass_scope{'slots'}{'cat'}) {
	    $$scratch_str_ref .= &dk::annotate($col, __FILE__, __LINE__);
	    $$scratch_str_ref .= &dk::print_in_col_string($col, "klass $klass_name { $$klass_scope{'slots'}{'cat'} slots-t; }\n");
	}
	elsif ('enum' eq $$klass_scope{'slots'}{'cat'}) {
	    $$scratch_str_ref .= &dk::annotate($col, __FILE__, __LINE__);
	    $$scratch_str_ref .= &dk::print_in_col_string($col, "//klass $klass_name { $$klass_scope{'slots'}{'cat'} slots-t; }\n");
	}
	else {
	    print STDERR &Dumper($$klass_scope{'slots'});
	    die __FILE__, ":", __LINE__, ": error:\n";
	}
        $$scratch_str_ref .= &dk::print_in_col_string($col, "typedef $klass_name:slots-t* $klass_name-t; // special-case\n");
    }
    elsif (&has_exported_slots($klass_scope) && &has_slots_type($klass_scope))
    {
        my $typedef_body = &typedef_body($$klass_scope{'slots'}{'type'}, 'slots-t');
        $$scratch_str_ref .= &dk::annotate($col, __FILE__, __LINE__);
	$$scratch_str_ref .= &dk::print_in_col_string($col, "klass $klass_name { typedef $$klass_scope{'slots'}{'type'} slots-t; }\n");
	my $excluded_types = { 'char16-t' => '__STDC_UTF_16__',
			       'char32-t' => '__STDC_UTF_32__',
	};
	if (!exists $$excluded_types{"$klass_name-t"}) {
	    $$scratch_str_ref .= &dk::print_in_col_string($col, "typedef $klass_name:slots-t $klass_name-t;\n");
	}
    }
    elsif (&has_exported_slots($klass_scope) || (&has_slots($klass_scope) && &is_same_file($klass_scope)))
    {
	if ('struct' eq $$klass_scope{'slots'}{'cat'} ||
	    'union'  eq $$klass_scope{'slots'}{'cat'}) {
	    $$scratch_str_ref .= &dk::annotate($col, __FILE__, __LINE__);
	    $$scratch_str_ref .= &dk::print_in_col_string($col, "klass $klass_name { $$klass_scope{'slots'}{'cat'} slots-t; }\n");
	}
	elsif ('enum' eq $$klass_scope{'slots'}{'cat'}) {
	    $$scratch_str_ref .= &dk::annotate($col, __FILE__, __LINE__);
	    $$scratch_str_ref .= &dk::print_in_col_string($col, "klass $klass_name { ");
	    my $is_exported;
	    my $is_slots;
	    &generate_enum_defn($col, $$klass_scope{'slots'}, $is_exported = 1, $is_slots = 1);
	    $$scratch_str_ref .= &dk::print_in_col_string($col, "}\n");
	}
	else {
	    print STDERR &Dumper($$klass_scope{'slots'});
	    die __FILE__, ":", __LINE__, ": error:\n";
	}
        $$scratch_str_ref .= &dk::print_in_col_string($col, "typedef $klass_name:slots-t $klass_name-t;\n");
    }
    else
    {
        #errdump($klass_name);
        #errdump($klass_scope);
        die __FILE__, ':', __LINE__, ": error: box klass \'$klass_name\' without slot or slots\n";
    }
}

sub linkage_unit::generate_klasses_exported_headers
{
    my ($klass_names) = @_;
    my $result = '';
    
    if (&is_rt_decl()) {
        $result .= "include <cstring>; // memcpy()\n";
        $result .= "include <cassert>; // assert()\n";
    }

    if (&is_nrt_decl() || &is_rt_decl()) {
	my $exported_headers = {};
	foreach my $klass_name (@$klass_names) {
	    my $klass_scope = &generics::klass_scope_from_klass_name($klass_name);
	    
	    while (my ($header, $klasses) = each (%{$$klass_scope{'exported-headers'}})) {
		$$exported_headers{$header}{$klass_name} = undef;
	    }
	}
	my $headers_names = [sort keys %$exported_headers];
	foreach my $header_name (@$headers_names) {
	    $result .= "include $header_name;\n";
	}
	if ('' ne $result) {
	    $result .= "\n";
	}
    }
    $result .= "include <dakota-log.h>;\n\n";
    return $result;
}

sub is_same_file
{
    my ($klass_scope) = @_;

    if ($gbl_nrt_file && $$klass_scope{'slots'} && $$klass_scope{'slots'}{'file'} && ($gbl_nrt_file eq $$klass_scope{'slots'}{'file'}))
    {
        return 1;
    }
    else
    {
        return 0;
    }
}

sub has_slots_type
{
    my ($klass_scope) = @_;

    if (&has_slots($klass_scope) && exists $$klass_scope{'slots'}{'type'} && $$klass_scope{'slots'}{'type'})
    {
        return 1;
    }
    else
    {
        return 0;
    }
}

sub has_slots_info
{
    my ($klass_scope) = @_;

    if (&has_slots($klass_scope) && exists $$klass_scope{'slots'}{'info'} && $$klass_scope{'slots'}{'info'})
    {
        return 1;
    }
    else
    {
        return 0;
    }
}

sub has_enum_info
{
    my ($klass_scope) = @_;

    if (exists $$klass_scope{'enum'} && $$klass_scope{'enum'})
    {
        return 1;
    }
    else
    {
        return 0;
    }
}

sub has_const_info
{
    my ($klass_scope) = @_;

    if (exists $$klass_scope{'const'} && $$klass_scope{'const'})
    {
        return 1;
    }
    else
    {
        return 0;
    }
}

sub has_enums
{
    my ($klass_scope) = @_;

    if (exists $$klass_scope{'enum'} && $$klass_scope{'enum'} && 0 < scalar(@{$$klass_scope{'enum'}}))
    {
        return 1;
    }
    else
    {
        return 0;
    }
}

sub has_slots
{
    my ($klass_scope) = @_;

    if (exists $$klass_scope{'slots'} && $$klass_scope{'slots'})
    {
        return 1;
    }
    else
    {
        return 0;
    }
}

sub has_exported_slots
{
    my ($klass_scope) = @_;

    if (&has_slots($klass_scope) && &is_exported($$klass_scope{'slots'}))
    {
        return 1;
    }
    else
    {
        return 0;
    }
}

sub has_exported_methods
{
    my ($klass_scope) = @_;

    if (exists $$klass_scope{'behavior-exported?'}  && $$klass_scope{'behavior-exported?'})
    {
        return 1;
    }
    else
    {
        return 0;
    }
}

sub order_klasses
{
    my ($scope) = @_;
    my $type_aliases = {};
    my $depends = {};
    my $verbose = 0;
    my ($klass_name, $klass_scope);
    
    foreach my $klass_type_plural ('traits', 'klasses') {
	while (($klass_name, $klass_scope) = each (%{$$scope{$klass_type_plural}})) {
	    if (!$klass_scope)
	    { $klass_scope = &generics::klass_scope_from_klass_name($klass_name); }
	    if ($klass_scope) {
		if (&has_slots($klass_scope)) {
		    # even if not exported
		    $$type_aliases{"${klass_name}-t"} = "${klass_name}:slots-t";
		    # hackhack
		    if ($$klass_scope{'slots'}{'info'}) {
			foreach my $slots_info (@{$$klass_scope{'slots'}{'info'}}) {
			    my $types = [values %$slots_info];
			    foreach my $type (@$types) {
				my $parts = {};
				&klass_part($type_aliases, $type, $parts);
				foreach my $type_klass_name (keys %$parts) {
				    if ($verbose) { print STDERR "    $type\n      $type_klass_name\n"; }
				    if (!exists $$scope{'klasses'}{$type_klass_name}) {
					#$$scope{'klasses'}{$type_klass_name} = undef;
				    }
				}
			    }
			}
		    }
		}
	    }
	    $$depends{$klass_name} = {};
	}
    }
    if ($verbose) { print STDERR &Dumper($type_aliases); }
    foreach my $klass_type_plural ('traits', 'klasses') {
	while (($klass_name, $klass_scope) = each (%{$$scope{$klass_type_plural}})) {
	    if (!$klass_scope)
	    { $klass_scope = &generics::klass_scope_from_klass_name($klass_name); }
	    if ($klass_scope) {
		if ($verbose) { print STDERR "klass-name: $klass_name\n"; }
		if (&has_slots($klass_scope)) {
		    if ($$klass_scope{'slots'}{'type'}) {
			if ($verbose) { print STDERR "  type:\n"; }
			my $type = $$klass_scope{'slots'}{'type'};
			my $type_klass_name;
			my $parts = {};
			&klass_part($type_aliases, $type, $parts);
			foreach $type_klass_name (keys %$parts) {
			    if ($verbose) { print STDERR "    $type\n      $type_klass_name\n"; }
			    if ($klass_name ne $type_klass_name)
			    { $$depends{$klass_name}{$type_klass_name} = 1; }
			}
		    }
		    elsif ($$klass_scope{'slots'}{'info'}) {
			if ($verbose) { print STDERR "  info:\n"; }
			foreach my $slots_info (@{$$klass_scope{'slots'}{'info'}}) {
			    my $types = [values %$slots_info];
			    foreach my $type (@$types) {
				my $type_klass_name;
				my $parts = {};
				&klass_part($type_aliases, $type, $parts);
				foreach $type_klass_name (keys %$parts) {
				    if ($verbose) { print STDERR "    $type\n      $type_klass_name\n"; }
				    if ($klass_name ne $type_klass_name)
				    { $$depends{$klass_name}{$type_klass_name} = 1; }
				}
			    }
			}
		    }
		}
	    }
	}
    }
    if ($verbose) { print STDERR &Dumper($depends); }
    my $result = &order_depends($depends);
    if ($verbose) { print STDERR &Dumper($result); }
    return $$result{'seq'};
}

sub add_last
{
    my ($seq, $str) = @_;
    push @$seq, $str;
}

sub order_depends
{
    my ($depends) = @_;
    my $ordered_klasses = { 'seq' => [], 'set' => {} };
    while (my ($klass_name, $dummy) = each %$depends) {
	&order_depends_recursive($depends, $klass_name, $ordered_klasses);
    }
    return $ordered_klasses;
}

sub order_depends_recursive
{
    my ($depends, $klass_name, $ordered_klasses) = @_;
    while (my ($lhs, $dummy) = each %{$$depends{$klass_name}}) {
	&order_depends_recursive($depends, $lhs, $ordered_klasses);
    }
    &add_ordered($ordered_klasses, $klass_name);
}

sub add_ordered
{
    my ($ordered_klasses, $str) = @_;
    if (!$$ordered_klasses{'set'}{$str}) {
	$$ordered_klasses{'set'}{$str} = 1;
	push @{$$ordered_klasses{'seq'}}, $str;
    }
    else {
	$$ordered_klasses{'set'}{$str}++;
    }
}

sub klass_part
{
    my ($type_aliases, $str, $result) = @_;
    
    while ($str =~ m/($rk)/g) {
	my $ident = $1;
	if ($ident =~ m/-t$/) {
	    my $klass_name = $ident;
	    $klass_name =~ s/-t$//;
	    if ($klass_name =~ m/^($rk):slots$/) {
		$$result{$1} = undef;
	    }
	    else {
		if ($$type_aliases{$ident}) {
		    &klass_part($type_aliases, $$type_aliases{$ident}, $result);
		}
	    }
	}
    }
}

sub linkage_unit::generate_klasses
{
    my ($scope, $col, $klass_path) = @_;

    my $klass_names = &order_klasses($scope);
    my $scratch_str_ref = &global_scratch_str_ref();
    $$scratch_str_ref .= &linkage_unit::generate_klasses_exported_headers($klass_names);
    &linkage_unit::generate_klasses_types($scope, $col, $klass_path);
    
    foreach my $klass_name (@$klass_names) {
        &linkage_unit::generate_klasses_klass($scope, $col, $klass_path, $klass_name);
    }
    return $$scratch_str_ref;
}

sub linkage_unit::generate_klasses_types
{
    my ($scope, $col, $klass_path) = @_;

    my $klass_names = &order_klasses($scope);
    my $scratch_str_ref = &global_scratch_str_ref();
    foreach my $klass_name (@$klass_names) {
	if (&is_nrt_decl() || &is_rt_decl()) {
	    my $klass_scope = &generics::klass_scope_from_klass_name($klass_name);

	    if (&has_exported_slots($klass_scope) || (&has_slots($klass_scope) && &is_same_file($klass_scope))) {
		&generate_exported_slots_decls($scope, $col, $klass_path, $klass_name, $klass_scope);
	    }
	    else {
                &generate_slots_decls($scope, $col, $klass_path, $klass_name, $klass_scope);
            }
        }
    }
    $$scratch_str_ref .= &dakota_before_klasses_h();
    foreach my $klass_name (@$klass_names) {
        my $klass_scope = &generics::klass_scope_from_klass_name($klass_name);
	my $is_exported;
	my $is_slots;

	if (&is_nrt_decl() || &is_rt_decl()) {
	    if (&has_enums($klass_scope)) {
		foreach my $enum (@{$$klass_scope{'enum'} ||= []}) {
		    if (&is_exported($enum)) {
			$$scratch_str_ref .= &dk::annotate($col, __FILE__, __LINE__);
			$$scratch_str_ref .= &dk::print_in_col_string($col, "klass $klass_name { ");
			&generate_enum_defn($col, $enum, $is_exported = 1, $is_slots = 0);
			$$scratch_str_ref .= &dk::print_in_col_string3_comment($col, "}", " // klass $klass_name", "\n");
		    }
		}
	    }
	}
        if (&has_slots_info($klass_scope)) {
            if (&is_nrt_decl() || &is_rt_decl()) {
                if (&has_exported_slots($klass_scope) || (&has_slots($klass_scope) && &is_same_file($klass_scope))) {
		    $$scratch_str_ref .= &dk::annotate($col, __FILE__, __LINE__);
                    $$scratch_str_ref .= &dk::print_in_col_string($col, "klass $klass_name { ");
		    if ('struct' eq $$klass_scope{'slots'}{'cat'} ||
			'union'  eq $$klass_scope{'slots'}{'cat'}) {
			&generate_struct_or_union_defn($col, $$klass_scope{'slots'}, $is_exported = 1, $is_slots = 1);
		    }
		    elsif ('enum' eq $$klass_scope{'slots'}{'cat'}) {
			$$scratch_str_ref .= &dk::print_in_col_string($col + 1, "// enum slots-t { ... }\n");
		    }
		    else {
			print STDERR &Dumper($$klass_scope{'slots'});
			die __FILE__, ":", __LINE__, ": error:\n";
		    }
                    $$scratch_str_ref .= &dk::print_in_col_string3_comment($col, "}", " // klass $klass_name", "\n");
                }
            }
            elsif (&is_nrt_defn() || &is_rt_defn()) {
                if (!&has_exported_slots($klass_scope)) {
		    if (&is_exported($klass_scope)) {
			$$scratch_str_ref .= &dk::annotate($col, __FILE__, __LINE__);
			$$scratch_str_ref .= &dk::print_in_col_string($col, "klass $klass_name { ");
			if ('struct' eq $$klass_scope{'slots'}{'cat'} ||
			    'union'  eq $$klass_scope{'slots'}{'cat'}) {
			    &generate_struct_or_union_defn($col, $$klass_scope{'slots'}, $is_exported = 0, $is_slots = 1);
			}
			elsif ('enum' eq $$klass_scope{'slots'}{'cat'}) {
			    &generate_enum_defn($col, $$klass_scope{'slots'}, $is_exported = 0, $is_slots = 1);
			}
			else {
			    print STDERR &Dumper($$klass_scope{'slots'});
			    die __FILE__, ":", __LINE__, ": error:\n";
			}
			$$scratch_str_ref .= &dk::print_in_col_string3_comment($col, "}", " // klass $klass_name", "\n");
		    }
		    else {
			$$scratch_str_ref .= &dk::annotate($col, __FILE__, __LINE__);
			$$scratch_str_ref .= &dk::print_in_col_string($col, "klass $klass_name { ");
			if ('struct' eq $$klass_scope{'slots'}{'cat'} ||
			    'union'  eq $$klass_scope{'slots'}{'cat'}) {
			    &generate_struct_or_union_defn($col, $$klass_scope{'slots'}, $is_exported = 0, $is_slots = 1);
			}
			elsif ('enum' eq $$klass_scope{'slots'}{'cat'}) {
			    $$scratch_str_ref .= &dk::print_in_col_string($col + 1, "// enum slots-t { ... }\n");
			}
			else {
			    print STDERR &Dumper($$klass_scope{'slots'});
			    die __FILE__, ":", __LINE__, ": error:\n";
			}
			$$scratch_str_ref .= &dk::print_in_col_string3_comment($col, "}", " // klass $klass_name", "\n");
		    }
		}
            }
        }
    }
    $$scratch_str_ref .= &dk::print("\n");
}

sub linkage_unit::generate_klasses_klass
{
    my ($scope, $col, $klass_path, $klass_name) = @_;

    my $klass_type = &generics::klass_type_from_klass_name($klass_name); # hackhack: name could be both a trait & a klass
    my $cxx_klass_name = $klass_name;
    my $klass_scope = &generics::klass_scope_from_klass_name($klass_name);
    &path::add_last($klass_path, $klass_name);
    my $scratch_str_ref = &global_scratch_str_ref();    
    if (&is_exported($klass_scope) || &has_exported_slots($klass_scope) || &has_exported_methods($klass_scope))
    {
        $$scratch_str_ref .= &dk::annotate($col, __FILE__, __LINE__);
        &linkage_unit::generate_klasses_body($klass_scope, $col, $klass_type, $klass_path, $klass_name);
	if (&has_exported_slots($klass_scope) && &has_slots_type($klass_scope))
	{
	    $$scratch_str_ref .= &dk::print_in_col_string($col, "using $cxx_klass_name:box;\n");
	}
    }
    else
    #elsif (!&has_exported_slots($klass_scope) && !&is_exported($klass_scope))
    {
        $$scratch_str_ref .= &dk::annotate($col, __FILE__, __LINE__);
        &linkage_unit::generate_klasses_body($klass_scope, $col, $klass_type, $klass_path, $klass_name);
    }
    &path::remove_last($klass_path);
}

sub method::type
{
    my ($method, $return_type) = @_;
    my $return_type_str;
    if (!$return_type)
    {
	$return_type_str = &arg::type($$method{'return-type'});
    }
    else
    {
	$return_type_str = &arg::type($return_type);
    }
    my $arg_type_list = &arg_type::list_types($$method{'parameter-types'});
    return "$return_type_str(*)($$arg_type_list)";
}
sub method::type_decl
{
    my ($method) = @_;
    my $return_type = &arg::type($$method{'return-type'});
    my $arg_type_list = &arg_type::list_types($$method{'parameter-types'});
    my $name = &_last($$method{'name'});
    return "$return_type(*$name)($$arg_type_list)";
}
sub ka_method::type
{
    my ($method) = @_;
    my $return_type = &arg::type($$method{'return-type'});
    my $arg_type_list = &kw_arg_type::list_types($$method{'parameter-types'}, $$method{'keyword-types'});
    return "$return_type(*)($$arg_type_list)";
}
sub ka_method::type_decl
{
    my ($method) = @_;
    my $return_type = &arg::type($$method{'return-type'});
    my $arg_type_list = &kw_arg_type::list_types($$method{'parameter-types'}, $$method{'keyword-types'});
    my $name = &_last($$method{'name'});
    return "$return_type(*$name)($$arg_type_list)";
}

sub raw_signature_body
{
    my ($klass_name, $methods, $col) = @_;
    my $sorted_methods = [sort method::compare values %$methods];
    my $scratch_str_ref = &global_scratch_str_ref();
    my $method_num  = 0;
    my $max_width = 0;
    my $return_type = 'const signature-t*';
    foreach my $method (@$sorted_methods)
    {
	my $method_type = &method::type($method, [ $return_type ]);
	my $width = length($method_type);
	if ($width > $max_width)
	{ $max_width = $width; }
    }
    foreach my $method (@$sorted_methods) {
	my $method_type = &method::type($method, [ $return_type ]);
	my $width = length($method_type);
	my $pad = ' ' x ($max_width - $width);

	if (!$$method{'alias'}) {
	    my $new_arg_type_list = &arg_type::list_types($$method{'parameter-types'});
	    my $generic_name = "@{$$method{'name'}}";
	    if (&is_va($method)) {
		$$scratch_str_ref .= &dk::print_in_col_string3($col, "(cast(dkt-signature-function-t)cast($method_type)", $pad, "__raw-signature:va:$generic_name)(),\n");
	    }
	    else {
		$$scratch_str_ref .= &dk::print_in_col_string3($col, "(cast(dkt-signature-function-t)cast($method_type)", $pad, "__raw-signature:$generic_name)(),\n");
	    }
	    my $method_name;
	    
	    if ($$method{'alias'}) {
		$method_name = "@{$$method{'alias'}}";
	    }
	    else {
		$method_name = "@{$$method{'name'}}";
	    }
	}
	$method_num++;
    }
    $$scratch_str_ref .= &dk::print_in_col_string($col, "NULL\n");
}
sub signature_body
{
    my ($klass_name, $methods, $col) = @_;
    my $sorted_methods = [sort method::compare values %$methods];
    my $scratch_str_ref = &global_scratch_str_ref();
    my $method_num  = 0;
    my $max_width = 0;
    my $return_type = 'const signature-t*';
    foreach my $method (@$sorted_methods) {
	my $method_type = &method::type($method, [ $return_type ]);
	my $width = length($method_type);
	if ($width > $max_width)
	{ $max_width = $width; }
    }
    foreach my $method (@$sorted_methods) {
	my $method_type = &method::type($method, [ $return_type ]);
	my $width = length($method_type);
	my $pad = ' ' x ($max_width - $width);

	if (!$$method{'alias'}) {
	    my $new_arg_type_list = &arg_type::list_types($$method{'parameter-types'});
	    my $generic_name = "@{$$method{'name'}}";
	    if (&is_va($method)) {
		$$scratch_str_ref .= &dk::print_in_col_string3($col, "(cast(dkt-signature-function-t)cast($method_type)", $pad, "__signature:va:$generic_name)(),\n");
	    }
	    else {
		$$scratch_str_ref .= &dk::print_in_col_string3($col, "(cast(dkt-signature-function-t)cast($method_type)", $pad, "__signature:$generic_name)(),\n");
	    }
	    my $method_name;
	    
	    if ($$method{'alias'}) {
		$method_name = "@{$$method{'alias'}}";
	    }
	    else {
		$method_name = "@{$$method{'name'}}";
	    }
	}
	$method_num++;
    }
    $$scratch_str_ref .= &dk::print_in_col_string($col, "NULL\n");
}
sub address_body
{
    my ($klass_name, $methods, $col) = @_;
    my $sorted_methods = [sort method::compare values %$methods];
    my $scratch_str_ref = &global_scratch_str_ref();
        my $method_num  = 0;
        my $max_width = 0;
        foreach my $method (@$sorted_methods)
	{
            my $method_type = &method::type($method);
	    my $width = length($method_type);
	    if ($width > $max_width)
	    { $max_width = $width; }
	}
        foreach my $method (@$sorted_methods)
        {
            my $method_type = &method::type($method);
	    my $width = length($method_type);
	    my $pad = ' ' x ($max_width - $width);

            if (!$$method{'alias'})
            {
            my $new_arg_type_list = &arg_type::list_types($$method{'parameter-types'});
            my $generic_name = "@{$$method{'name'}}";
            my $method_name;
            
            if ($$method{'alias'})
            {
                $method_name = "@{$$method{'alias'}}";
            }
            else
            {
                $method_name = "@{$$method{'name'}}";
            }
            #my $method_name = "@{$$method{'name'}}";
            
            if (!$$method{'defined?'} && !$$method{'alias'} && !$$method{'is-generated'})
            {
                $$scratch_str_ref .= &dk::print_in_col_string($col, "NULL,\n");
            }
            else
            {
                if (&is_va($method))
                {
                    $$scratch_str_ref .= &dk::print_in_col_string3($col, "cast(method-t)cast($method_type)", $pad, "va:$method_name,\n");
                }
                else
                {
                    $$scratch_str_ref .= &dk::print_in_col_string3($col, "cast(method-t)cast($method_type)", $pad, "$method_name,\n");
                }
            }
            }
            $method_num++;
        }
        $$scratch_str_ref .= &dk::print_in_col_string($col, "NULL\n");
}
sub alias_body
{
    my ($klass_name, $methods, $col) = @_;
    my $sorted_methods = [sort method::compare values %$methods];
    my $scratch_str_ref = &global_scratch_str_ref();

    my $method_num  = 0;
    foreach my $method (@$sorted_methods)
    {
	if ($$method{'alias'})
	{
	    my $new_arg_type_list = &arg_type::list_types($$method{'parameter-types'});
	    my $generic_name = "@{$$method{'name'}}";
	    my $alias_name = "@{$$method{'alias'}}";
	    if (&is_va($method))
	    {
		$$scratch_str_ref .= &dk::print_in_col_string($col, "{ signature(va:$alias_name($$new_arg_type_list)), signature(va:$generic_name($$new_arg_type_list)) },\n");
	    }
	    else
	    {
		$$scratch_str_ref .= &dk::print_in_col_string($col, "{ signature($alias_name($$new_arg_type_list)), signature($generic_name($$new_arg_type_list)) },\n");
	    }
	}
	$method_num++;
    }
    $$scratch_str_ref .= &dk::print_in_col_string($col, "{ NULL, NULL }\n");
}

sub export_pair
{
    my ($symbol, $element) = @_;

    my $name = "@{$$element{'name'}}";
    my $type0 = "@{$$element{'parameter-types'}[0]}";
    $type0 = ''; # hackhack
    my $lhs = "\"$symbol:$name($type0)\"";
    my $rhs = 1;
    return ($lhs, $rhs);
}

sub exported_methods
{
    my ($klass_scope) = @_;

    my $exported_methods = {};
    {
	while (my ($key, $val) = each (%{$$klass_scope{'methods'}})) {
	    if (&is_exported($val))
	    { $$exported_methods{$key} = $val; }
	}
    }
    return $exported_methods;
}

sub exported_raw_methods
{
    my ($klass_scope) = @_;

    my $exported_raw_methods = {};
    {
	while (my ($key, $val) = each (%{$$klass_scope{'raw-methods'}})) {
	    if (&is_exported($val))
	    { $$exported_raw_methods{$key} = $val; }
	}
    }
    return $exported_raw_methods;
}

sub exports
{
    my ($scope) = @_;
    my $exports = {};

    foreach my $klass_type ('klass', 'trait') {
    while (my ($klass_name, $klass_scope) = each(%{$$scope{$$plural_from_singular{$klass_type}}})) {
    my $exported_methods = &exported_methods($klass_scope);
    my $exported_raw_methods = &exported_raw_methods($klass_scope);

    while (my ($key, $element) = each (%$exported_methods))
    {
	my ($lhs, $rhs) = &export_pair($klass_name, $element);
	$$exports{"\"$$klass_scope{'module'}\""}{$lhs} = $rhs;
    }
    while (my ($key, $element) = each (%$exported_raw_methods))
    {
	my ($lhs, $rhs) = &export_pair($klass_name, $element);
	$$exports{"\"$$klass_scope{'module'}\""}{$lhs} = $rhs;
    }

    if (&is_exported($klass_scope))
    {
	my $lhs = "\"$klass_name\"";
	my $rhs = 1;
	$$exports{"\"$$klass_scope{'module'}\""}{$lhs} = $rhs;
    }

    if (&has_exported_slots($klass_scope))
    {
	my $lhs = "\"$klass_name:slots-t\"";
	my $rhs = 1;
	$$exports{"\"$$klass_scope{'module'}\""}{$lhs} = $rhs;
    }
    }
    }
    return $exports;
}

sub dk::generate_cxx_footer_klass
{
    my ($klass_scope, $klass_name, $col, $klass_type) = @_;
    my $scratch_str_ref = &global_scratch_str_ref();
    #$$scratch_str_ref .= &dk::print_in_col_string($col, "// generate_cxx_footer_klass()\n");

    my $token_registry = {};

    my $slot_type;
    my $slot_name;


    my $method_aliases = &klass::method_aliases($klass_scope);
    my $va_list_methods = &klass::va_list_methods($klass_scope);
    my $ka_methods = &klass::ka_methods($klass_scope);
    
    my $va_method_num = 0;
    #my $num_va_methods = @$va_list_methods;

    #if (@$va_list_methods)
    #{
    #$$scratch_str_ref .= &dk::print_in_col_string($col, "namespace va\n");
    #$$scratch_str_ref .= &dk::print_in_col_string($col, "{\n");
    #$col++;
###        
    if (@$va_list_methods)
    {
        $$scratch_str_ref .= &dk::print_in_col_string($col, "$klass_type @$klass_name { static const signature-t* const __va-method-signatures[] = // redundant\n");
        $$scratch_str_ref .= &dk::print_in_col_string($col, "{\n");
        $col++;
        
        my $sorted_va_methods = [sort method::compare @$va_list_methods];

        $va_method_num = 0;
	my $max_width = 0;
	my $return_type = 'const signature-t*';
	foreach my $va_method (@$sorted_va_methods)
	{
	    my $va_method_type = &method::type($va_method, [ $return_type ]);
	    my $width = length($va_method_type);
	    if ($width > $max_width)
	    { $max_width = $width; }
	}
        foreach my $va_method (@$sorted_va_methods)
        {
	    my $va_method_type = &method::type($va_method, [ $return_type ]);
	    my $width = length($va_method_type);
	    my $pad = ' ' x ($max_width - $width);

            if ($$va_method{'defined?'} || $$va_method{'alias'})
            {
                my $new_arg_names_list = &arg_type::list_types($$va_method{'parameter-types'});
                
                my $generic_name = "@{$$va_method{'name'}}";
                
		$$scratch_str_ref .= &dk::print_in_col_string3($col, "(cast(dkt-signature-function-t)cast($va_method_type)", $pad, "__signature:va:$generic_name)(),\n");
                my $method_name;

                if ($$va_method{'alias'})
                {
                    $method_name = "@{$$va_method{'alias'}}";
                }
                else
                {
                    $method_name = "@{$$va_method{'name'}}";
                }
                
                my $old_parameter_types = $$va_method{'parameter-types'};
                $$va_method{'parameter-types'} = &arg_type::va($$va_method{'parameter-types'});
                my $method_type = &method::type($va_method);
                $$va_method{'parameter-types'} = $old_parameter_types;
                
                my $return_type = &arg::type($$va_method{'return-type'});
                my $va_method_name = $method_name;
                #$$scratch_str_ref .= &dk::print_in_col_string($col, "(va-method-t)(($method_type)$va_method_name),\n");
            }
            $va_method_num++;
        }
        $$scratch_str_ref .= &dk::print_in_col_string($col, "NULL,\n");
        $col--;
        $$scratch_str_ref .= &dk::print_in_col_string($col, "}; }\n");
    }
###        
###        
    if (@$va_list_methods)
    {
	$$scratch_str_ref .= &dk::annotate($col, __FILE__, __LINE__);
        $$scratch_str_ref .= &dk::print_in_col_string($col, "$klass_type @$klass_name { static va-method-t __va-method-addresses[] = //ro-data\n");
        $$scratch_str_ref .= &dk::print_in_col_string($col, "{\n");
        $col++;
        
        my $sorted_va_methods = [sort method::compare @$va_list_methods];

        $va_method_num = 0;
	my $max_width = 0;
	foreach my $va_method (@$sorted_va_methods)
	{
	    $va_method = &deep_copy($va_method);
	    my $va_method_type = &method::type($va_method);
	    my $width = length($va_method_type);
	    if ($width > $max_width)
	    { $max_width = $width; }
	}
        foreach my $va_method (@$sorted_va_methods)
        {
	    $va_method = &deep_copy($va_method);
	    my $va_method_type = &method::type($va_method);
	    my $width = length($va_method_type);
	    my $pad = ' ' x ($max_width - $width);

            if ($$va_method{'defined?'} || $$va_method{'alias'})
            {
                my $new_arg_names_list = &arg_type::list_types($$va_method{'parameter-types'});
                
                my $generic_name = "@{$$va_method{'name'}}";
                my $method_name;

                if ($$va_method{'alias'})
                {
                    $method_name = "@{$$va_method{'alias'}}";
                }
                else
                {
                    $method_name = "@{$$va_method{'name'}}";
                }
                
                my $old_parameter_types = $$va_method{'parameter-types'};
                $$va_method{'parameter-types'} = &arg_type::va($$va_method{'parameter-types'});
                my $method_type = &method::type($va_method);
                $$va_method{'parameter-types'} = $old_parameter_types;
                
                my $return_type = &arg::type($$va_method{'return-type'});
                my $va_method_name = $method_name;
                $$scratch_str_ref .= &dk::print_in_col_string3($col, "cast(va-method-t)cast($method_type)", $pad, "$va_method_name,\n");
            }
            $va_method_num++;
        }
        $$scratch_str_ref .= &dk::print_in_col_string($col, "NULL,\n");
        $col--;
        $$scratch_str_ref .= &dk::print_in_col_string($col, "}; }\n");
    }
###
    #$col--;
    #$$scratch_str_ref .= &dk::print_in_col_string($col, "}\n");
    #}
###
    if (@$ka_methods)
    {
	$$scratch_str_ref .= &dk::annotate($col, __FILE__, __LINE__);
        $$scratch_str_ref .= &dk::print_in_col_string($col, "$klass_type @$klass_name { static const signature-t* const __ka-method-signatures[] = //ro-data\n");
        $$scratch_str_ref .= &dk::print_in_col_string($col, "{\n");
        $col++;
        
	#$$scratch_str_ref .= &dk::print_in_col_string($col, "\#if 0\n");
	my $max_width = 0;
        foreach my $ka_method (@$ka_methods)
	{
	    $ka_method = &deep_copy($ka_method);
	    my $ka_method_type = &ka_method::type($ka_method);
	    my $width = length($ka_method_type);
	    if ($width > $max_width)
	    { $max_width = $width; }
	}
        foreach my $ka_method (@$ka_methods)
        {
	    $ka_method = &deep_copy($ka_method);
	    my $ka_method_type = &ka_method::type($ka_method);
	    my $width = length($ka_method_type);
	    my $pad = ' ' x ($max_width - $width);

	    my $method_name = "@{$$ka_method{'name'}}";
	    my $list_types = &arg_type::list_types($$ka_method{'parameter-types'});
	    my $kw_list_types = &method::kw_list_types($ka_method);
	    $$scratch_str_ref .= &dk::print_in_col_string3($col, "(cast(dkt-signature-function-t)cast(const signature-t*(*)($$list_types))", $pad, "__ka-signature:va:$method_name)(),\n");
        }
	#$$scratch_str_ref .= &dk::print_in_col_string($col, "\#endif\n");

        $$scratch_str_ref .= &dk::print_in_col_string($col, "NULL\n");
        $col--;
        $$scratch_str_ref .= &dk::print_in_col_string($col, "}; }\n");
    }
    if (values %{$$klass_scope{'methods'} ||= []})
    {
        $$scratch_str_ref .= &dk::print("\n");
	$$scratch_str_ref .= &dk::annotate($col, __FILE__, __LINE__);
        $$scratch_str_ref .= &dk::print_in_col_string($col, "$klass_type @$klass_name { static const signature-t* const __method-signatures[] = //ro-data\n");
        $$scratch_str_ref .= &dk::print_in_col_string($col, "{\n");
        &signature_body($klass_name, $$klass_scope{'methods'}, $col + 1);
        $$scratch_str_ref .= &dk::print_in_col_string($col, "}; }\n");
    }
    if (values %{$$klass_scope{'methods'} ||= []})
    {
        $$scratch_str_ref .= &dk::print("\n");
	$$scratch_str_ref .= &dk::annotate($col, __FILE__, __LINE__);
        $$scratch_str_ref .= &dk::print_in_col_string($col, "$klass_type @$klass_name { static method-t __method-addresses[] = //ro-data\n");
        $$scratch_str_ref .= &dk::print_in_col_string($col, "{\n");
        &address_body($klass_name, $$klass_scope{'methods'}, $col + 1);
        $$scratch_str_ref .= &dk::print_in_col_string($col, "}; }\n");
    }

    my $num_method_aliases = scalar(@$method_aliases);
    if ($num_method_aliases)
    {
        $$scratch_str_ref .= &dk::print("\n");
	$$scratch_str_ref .= &dk::annotate($col, __FILE__, __LINE__);
        $$scratch_str_ref .= &dk::print_in_col_string($col, "$klass_type @$klass_name { static method-alias-t __method-aliases[] = //ro-data\n");
        $$scratch_str_ref .= &dk::print_in_col_string($col, "{\n");
        &alias_body($klass_name, $$klass_scope{'methods'}, $col + 1);
        $$scratch_str_ref .= &dk::print_in_col_string($col, "}; }\n");
    }

    my $exported_methods =     &exported_methods($klass_scope);
    my $exported_raw_methods = &exported_raw_methods($klass_scope);

    if (values %{$exported_methods ||= []})
    {
        $$scratch_str_ref .= &dk::print("\n");
	$$scratch_str_ref .= &dk::annotate($col, __FILE__, __LINE__);
        $$scratch_str_ref .= &dk::print_in_col_string($col, "$klass_type @$klass_name { static const signature-t* const __exported-method-signatures[] = //ro-data\n");
        $$scratch_str_ref .= &dk::print_in_col_string($col, "{\n");
        &signature_body($klass_name, $exported_methods, $col + 1);
        $$scratch_str_ref .= &dk::print_in_col_string($col, "}; }\n");

	$$scratch_str_ref .= &dk::annotate($col, __FILE__, __LINE__);
        $$scratch_str_ref .= &dk::print_in_col_string($col, "$klass_type @$klass_name { static method-t __exported-method-addresses[] = //ro-data\n");
        $$scratch_str_ref .= &dk::print_in_col_string($col, "{\n");
        &address_body($klass_name, $exported_methods, $col + 1);
        $$scratch_str_ref .= &dk::print_in_col_string($col, "}; }\n");
    }
    if (values %{$exported_raw_methods ||= []})
    {
        $$scratch_str_ref .= &dk::print("\n");
	$$scratch_str_ref .= &dk::annotate($col, __FILE__, __LINE__);
        $$scratch_str_ref .= &dk::print_in_col_string($col, "$klass_type @$klass_name { static const signature-t* const __exported-raw-method-signatures[] = //ro-data\n");
        $$scratch_str_ref .= &dk::print_in_col_string($col, "{\n");
        &raw_signature_body($klass_name, $exported_raw_methods, $col + 1);
        $$scratch_str_ref .= &dk::print_in_col_string($col, "}; }\n");

	$$scratch_str_ref .= &dk::annotate($col, __FILE__, __LINE__);
        $$scratch_str_ref .= &dk::print_in_col_string($col, "$klass_type @$klass_name { static method-t __exported-raw-method-addresses[] = //ro-data\n");
        $$scratch_str_ref .= &dk::print_in_col_string($col, "{\n");
        &address_body($klass_name, $exported_raw_methods, $col + 1);
        $$scratch_str_ref .= &dk::print_in_col_string($col, "}; }\n");
    }
###
###
###
    #$$scratch_str_ref .= &dk::print("\n");
    
    my $num_traits = @{( $$klass_scope{'traits'} ||= [] )}; # how to get around 'strict'
    if ($num_traits > 0)
    {
        $$scratch_str_ref .= &dk::print("\n");
	$$scratch_str_ref .= &dk::annotate($col, __FILE__, __LINE__);
        $$scratch_str_ref .= &dk::print_in_col_string($col, "$klass_type @$klass_name { static symbol-t __traits[] = //ro-data\n");
        $$scratch_str_ref .= &dk::print_in_col_string($col, "{\n");
        
        my $trait_num = 0;
        for ($trait_num = 0; $trait_num < $num_traits; $trait_num++)
        {
            my $path = "$$klass_scope{'traits'}[$trait_num]";
            $$scratch_str_ref .= &dk::print_in_col_string($col + 1, "$path:__klass__,\n");
        }
        $$scratch_str_ref .= &dk::print_in_col_string($col + 1, "NULL\n");
        $$scratch_str_ref .= &dk::print_in_col_string($col, "}; }\n");
    }
    my $num_requires = @{( $$klass_scope{'requires'} ||= [] )}; # how to get around 'strict'
    if ($num_requires > 0)
    {
        $$scratch_str_ref .= &dk::print("\n");
	$$scratch_str_ref .= &dk::annotate($col, __FILE__, __LINE__);
        $$scratch_str_ref .= &dk::print_in_col_string($col, "$klass_type @$klass_name { static symbol-t __requires[] = //ro-data\n");
        $$scratch_str_ref .= &dk::print_in_col_string($col, "{\n");
        
        my $require_num = 0;
        for ($require_num = 0; $require_num < $num_requires; $require_num++)
        {
            my $path = "$$klass_scope{'requires'}[$require_num]";
            $$scratch_str_ref .= &dk::print_in_col_string($col + 1, "$path:__klass__,\n");
        }
        $$scratch_str_ref .= &dk::print_in_col_string($col + 1, "NULL\n");
        $$scratch_str_ref .= &dk::print_in_col_string($col, "}; }\n");
    }
    my $num_provides = @{( $$klass_scope{'provides'} ||= [] )}; # how to get around 'strict'
    if ($num_provides > 0)
    {
        $$scratch_str_ref .= &dk::print("\n");
	$$scratch_str_ref .= &dk::annotate($col, __FILE__, __LINE__);
        $$scratch_str_ref .= &dk::print_in_col_string($col, "$klass_type @$klass_name { static symbol-t __provides[] = //ro-data\n");
        $$scratch_str_ref .= &dk::print_in_col_string($col, "{\n");
        
        my $provide_num = 0;
        for ($provide_num = 0; $provide_num < $num_provides; $provide_num++)
        {
            my $path = "$$klass_scope{'provides'}[$provide_num]";
            $$scratch_str_ref .= &dk::print_in_col_string($col + 1, "$path:__klass__,\n");
        }
        $$scratch_str_ref .= &dk::print_in_col_string($col + 1, "NULL\n");
        $$scratch_str_ref .= &dk::print_in_col_string($col, "}; }\n");
    }
    while (my ($key, $val) = each(%{$$klass_scope{'imported-klasses'}}))
    {
        my $token;
        my $token_seq = $key;
        if (0 != length $token_seq)
        {
            my $path = $key;
            
            if (!$$token_registry{$path})
            {
                $$token_registry{$path} = 1;
            }
        }
    }
    
    my $num_bound = keys %{$$klass_scope{'imported-klasses'}};
    if ($num_bound)
    {
	$$scratch_str_ref .= &dk::annotate($col, __FILE__, __LINE__);
        $$scratch_str_ref .= &dk::print_in_col_string($col, "$klass_type @$klass_name { static symbol-t const __imported-klasses[] = //ro-data\n");
        $$scratch_str_ref .= &dk::print_in_col_string($col, "{\n");
        $col++;
        while (my ($key, $val) = each(%{$$klass_scope{'imported-klasses'}}))
        {
            $$scratch_str_ref .= &dk::print_in_col_string($col, "$key:__klass__,\n");
        }
        $$scratch_str_ref .= &dk::print_in_col_string($col, "NULL\n");
        $col--;
        $$scratch_str_ref .= &dk::print_in_col_string($col, "}; }\n");
    }
    my $lines = [];
    my $tbbl = {};
    my $token;
    my $token_seq;
    
    $token_seq = $klass_name;
    if (0 != @$token_seq)
    {
        my $path = $klass_name;
        
        if (!$$token_registry{$path})
        {
            $$token_registry{$path} = 1;
            
            foreach $token (@$klass_name)
            {
#               $$scratch_str_ref .= &dk::print("\"$gbl_token\", ");
            }
#           $$scratch_str_ref .= &dk::print("NULL }; ");
        }
    }

    if (&has_slots_info($klass_scope))
    {
	my $root_name = '__slots-info';
	if ('enum' eq $$klass_scope{'slots'}{'cat'}) {
	    my $seq = [];
	    my $prop_num = 0;
	    foreach my $slot_info (@{$$klass_scope{'slots'}{'info'}})
	    {
		my ($slot_name, $slot_value) = %$slot_info;
		my $tbl = {};
		$$tbl{'$name'} = "\$$slot_name";
		if (defined $slot_value) {
		    $$tbl{'$value'} = "\"$slot_value\"";
		}
		my $prop_name = sprintf("%s-%s", $root_name, $slot_name);
		$$scratch_str_ref .= &dk::print_in_col_string($col, "$klass_type @$klass_name { ");
    		$$scratch_str_ref .= &generate_property_tbl($prop_name, $tbl, $col + 1, $klass_scope);
		$$scratch_str_ref .= &dk::print_in_col_string($col, "} // $klass_type @$klass_name\n");
		&_add_last($seq, "$prop_name");
		$prop_num++;
	    }
	    $$scratch_str_ref .= &dk::print_in_col_string($col, "$klass_type @$klass_name { ");
	    $$scratch_str_ref .= &generate_info_seq($root_name, $seq, $col + 1);
	    $$scratch_str_ref .= &dk::print_in_col_string($col, "} // $klass_type @$klass_name\n");
	}
	else {
	    my $seq = [];
	    my $prop_num = 0;
	    foreach my $slot_info (@{$$klass_scope{'slots'}{'info'}})
	    {
		my ($slot_name, $slot_type) = %$slot_info;
		my $tbl = {};
		$$tbl{'$name'} = "\$$slot_name";
		
		if ('struct' eq $$klass_scope{'slots'}{'cat'}) {
		    $$tbl{'$offset'} = "offsetof(slots-t, $slot_name)";
		}
		$$tbl{'$size'} = "sizeof((cast(slots-t*)NULL)->$slot_name)";
		$$tbl{'$type'} = "\"$slot_type\"";
		
		my $prop_name = sprintf("%s-%s", $root_name, $slot_name);
		$$scratch_str_ref .= &dk::print_in_col_string($col, "$klass_type @$klass_name { ");
		$$scratch_str_ref .= &generate_property_tbl($prop_name, $tbl, $col + 1);
		$$scratch_str_ref .= &dk::print_in_col_string($col, "} // $klass_type @$klass_name\n");
		&_add_last($seq, "$prop_name");
		$prop_num++;
	    }
	    $$scratch_str_ref .= &dk::print_in_col_string($col, "$klass_type @$klass_name { ");
	    $$scratch_str_ref .= &generate_info_seq($root_name, $seq, $col + 1);
	    $$scratch_str_ref .= &dk::print_in_col_string($col, "} // $klass_type @$klass_name\n");
        }
    }
    
    if (&has_enum_info($klass_scope))
    {
	my $num = 0;
        foreach my $enum (@{$$klass_scope{'enum'}})
        {
	    $$scratch_str_ref .= &dk::annotate($col, __FILE__, __LINE__);
	    $$scratch_str_ref .= &dk::print_in_col_string($col, "$klass_type @$klass_name { static enum-info-t __enum-info-$num\[] = //ro-data\n");
	    $$scratch_str_ref .= &dk::print_in_col_string($col, "{\n");
	    $col++;
        
	    my $info = $$enum{'info'};
	    foreach my $pair (@$info)
	    {
		my ($name, $value) = %$pair;
		$$scratch_str_ref .= &dk::print_in_col_string($col, "{ \$$name, \"$value\" },\n");
	    }
	    $$scratch_str_ref .= &dk::print_in_col_string($col, "{ NULL, NULL }\n");
	    $col--;
	    $$scratch_str_ref .= &dk::print_in_col_string($col, "}; }\n");

	    $num++;
        }
	$$scratch_str_ref .= &dk::annotate($col, __FILE__, __LINE__);
	$$scratch_str_ref .= &dk::print_in_col_string($col, "$klass_type @$klass_name { static named-enum-info-t __enum-info[] = //ro-data\n");
	$$scratch_str_ref .= &dk::print_in_col_string($col, "{\n");
	$col++;
	$num = 0;
        foreach my $enum (@{$$klass_scope{'enum'}})
        {
	    if ($$enum{'type'})
	    {
		my $type = "@{$$enum{'type'}}";
		$$scratch_str_ref .= &dk::print_in_col_string($col, "{ \"$type\", __enum-info-$num },\n");
	    }
	    else
	    {
		$$scratch_str_ref .= &dk::print_in_col_string($col, "{ NULL, __enum-info-$num },\n");
	    }
	    $num++;
	}
	$$scratch_str_ref .= &dk::print_in_col_string($col, "{ NULL, NULL }\n");
	$col--;
	$$scratch_str_ref .= &dk::print_in_col_string($col, "}; }\n");
    }
    
    if (&has_const_info($klass_scope))
    {
	$$scratch_str_ref .= &dk::annotate($col, __FILE__, __LINE__);
	$$scratch_str_ref .= &dk::print_in_col_string($col, "$klass_type @$klass_name { static const-info-t __const-info\[] = //ro-data\n");
	$$scratch_str_ref .= &dk::print_in_col_string($col, "{\n");
	$col++;
        
        foreach my $const (@{$$klass_scope{'const'}})
        {
	    my $delim = $";
	    $" = ' ';
	    my $value = "@{$$const{'rhs'}}";
	    $" = $delim;
	    $value =~ s/"/\\"/g;
	    $$scratch_str_ref .= &dk::print_in_col_string($col, "{ \$$$const{'name'}, \"$$const{'type'}\", \"$value\" },\n");
        }
	$$scratch_str_ref .= &dk::print_in_col_string($col, "{ NULL, NULL, NULL }\n");
	$col--;
	$$scratch_str_ref .= &dk::print_in_col_string($col, "}; }\n");
    }
    
    my $symbol = &path::string($klass_name);
    $$tbbl{'$name'} = '__klass__';
    
    $$tbbl{'$construct'} = "\$$klass_type";

    if (&has_slots_type($klass_scope))
    {
        my $slots_type_ident = &make_ident_symbol_scalar($$klass_scope{'slots'}{'type'});
	my $type_symbol = $$klass_scope{'slots'}{'type'};
        $$tbbl{'$slots-type'} = "\"$type_symbol\"";
    }
    elsif (&has_slots_info($klass_scope))
    {
	my $cat = $$klass_scope{'slots'}{'cat'};
	$$tbbl{'$cat'} = "\$$cat";
	$$tbbl{'$slots-info'} = '__slots-info';
    }
    if (&has_slots_type($klass_scope) || &has_slots_info($klass_scope))
    {
        $$tbbl{'$size'} = 'sizeof(slots-t)';
    }

    if (&has_enum_info($klass_scope))
    {
        $$tbbl{'$enum-info'} = '__enum-info';
    }
    if (&has_const_info($klass_scope))
    {
        $$tbbl{'$const-info'} = '__const-info';
    }
    
    if (@$ka_methods)
    {
        $$tbbl{'$ka-method-signatures'} = '__ka-method-signatures';
    }
    if (values %{$$klass_scope{'methods'}})
    {
        $$tbbl{'$method-signatures'} = '__method-signatures';
	$$tbbl{'$method-addresses'}  = '__method-addresses';
    }
    
    if ($num_method_aliases)
    {
	$$tbbl{'$method-aliases'} = '&__method-aliases';
    }

    if (values %{$exported_methods ||= []})
    {
        $$tbbl{'$exported-method-signatures'} = '__exported-method-signatures';
        $$tbbl{'$exported-method-addresses'}  = '__exported-method-addresses';
    }
    
    if (values %{$exported_raw_methods ||= []})
    {
        $$tbbl{'$exported-raw-method-signatures'} = '__exported-raw-method-signatures';
        $$tbbl{'$exported-raw-method-addresses'}  = '__exported-raw-method-addresses';
    }
    
    if (@$va_list_methods)
    {
        $$tbbl{'$va-method-signatures'} = '__va-method-signatures';
	$$tbbl{'$va-method-addresses'}  = '__va-method-addresses';
    }
    $token_seq = $$klass_scope{'interpose'};

    if ($token_seq)
    {
	my $path = $$klass_scope{'interpose'};
        $$tbbl{'$interpose-name'} = "$path:__klass__";
    }

    $token_seq = $$klass_scope{'superklass'};

    if ($token_seq)
    {
	my $path = $$klass_scope{'superklass'};
        $$tbbl{'$superklass-name'} = "$path:__klass__";
    }

    $token_seq = $$klass_scope{'klass'};
    if ($token_seq)
    {
	my $path = $$klass_scope{'klass'};
        $$tbbl{'$klass-name'} = "$path:__klass__";
    }
    
    if ($num_traits > 0)
    {
        $$tbbl{'$traits'} = '__traits';
    }

    if ($num_requires > 0)
    {
        $$tbbl{'$requires'} = '__requires';
    }
    
    if ($num_provides > 0)
    {
        $$tbbl{'$provides'} = '__provides';
    }
    
    if (&is_exported($klass_scope))
    {
        $$tbbl{'$exported?'} = '1';
    }

    if (&has_exported_slots($klass_scope))
    {
        $$tbbl{'$state-exported?'} = '1';
    }

    if (&has_exported_methods($klass_scope))
    {
        $$tbbl{'$behavior-exported?'} = '1';
    }

    if ($$klass_scope{'has-initialize'})
    {
        $$tbbl{'$initialize'} = '(method-t)initialize';
    }
    if ($$klass_scope{'has-finalize'})
    {
        $$tbbl{'$finalize'} = '(method-t)finalize';
    }
    if ($$klass_scope{'module'})
    {
	$$tbbl{'$module'} = "\"$$klass_scope{'module'}\"";
    }
    $$tbbl{'$file'} = '__FILE__';

    $$scratch_str_ref .= &dk::print_in_col_string($col, "$klass_type @$klass_name { ");
    $$scratch_str_ref .= &generate_property_tbl('__klass-props', $tbbl, $col + 1);
    $$scratch_str_ref .= &dk::print_in_col_string($col, "} // $klass_type @$klass_name\n");
    my $RT = ''; # because the klass klass won't compile
    &_add_last($global_klass_defns, "$RT$symbol:__klass-props");
    return $$scratch_str_ref;
}

sub generate_ka_method_signature_decls
{
    my ($methods, $klass_name, $col, $klass_type) = @_;

    foreach my $method (sort method::compare values %$methods)
    {
        if ($$method{'keyword-types'})
        {
	    &generate_ka_method_signature_decl($method, $klass_name, $col, $klass_type);
        }
    }
}
sub generate_ka_method_signature_defns
{
    my ($methods, $klass_name, $col, $klass_type) = @_;

    foreach my $method (sort method::compare values %$methods)
    {
        if ($$method{'keyword-types'})
        {
	    &generate_ka_method_signature_defn($method, $klass_name, $col, $klass_type);
        }
    }
}

sub generate_raw_method_signature_decls
{
    my ($methods, $klass_name, $col, $klass_type) = @_;

    foreach my $method (sort method::compare values %$methods)
    {
	&generate_raw_method_signature_decl($method, $klass_name, $col, $klass_type);
    }
}

sub generate_raw_method_signature_defns
{
    my ($methods, $klass_name, $col, $klass_type) = @_;

    foreach my $method (sort method::compare values %$methods)
    {
	&generate_raw_method_signature_defn($method, $klass_name, $col, $klass_type);
    }
}

sub generate_ka_method_signature_decl
{
    my ($method, $klass_name, $col, $klass_type) = @_;
    my $scratch_str_ref = &global_scratch_str_ref();
    my $return_type = &arg::type($$method{'return-type'});
    my $method_name = "@{$$method{'name'}}";
    my $list_types = &arg_type::list_types($$method{'parameter-types'});
    my $kw_list_types = &method::kw_list_types($method);
    $$scratch_str_ref .= &dk::annotate($col, __FILE__, __LINE__);
    $$scratch_str_ref .= &dk::print_in_col_string($col, "$klass_type @$klass_name { namespace __ka-signature { namespace va { noexport const signature-t* $method_name($$list_types); } } }\n");
}
sub generate_ka_method_signature_defn
{
    my ($method, $klass_name, $col, $klass_type) = @_;

    my $scratch_str_ref = &global_scratch_str_ref();
    my $method_name = "@{$$method{'name'}}";
    my $return_type = &arg::type($$method{'return-type'});
    my $list_types = &arg_type::list_types($$method{'parameter-types'});
    $$scratch_str_ref .= &dk::annotate($col, __FILE__, __LINE__);
    $$scratch_str_ref .= &dk::print_in_col_string($col, "$klass_type @$klass_name { namespace __ka-signature { namespace va { noexport const signature-t* $method_name($$list_types)\n");
    $$scratch_str_ref .= &dk::print_in_col_string($col, "{\n");
    $col++;

    my $kw_arg_list = "static const signature-t result = { \"$return_type\", \"$method_name\", \"";
    $kw_arg_list .= &method::kw_list_types($method);
    $kw_arg_list .= "\", NULL };";
    $$scratch_str_ref .= &dk::print_in_col_string($col, "$kw_arg_list\n");
    $$scratch_str_ref .= &dk::print_in_col_string($col, "return &result;\n");
    $col--;
    $$scratch_str_ref .= &dk::print_in_col_string($col, "} } } }\n");
}
sub generate_raw_method_signature_decl
{
    my ($method, $klass_name, $col, $klass_type) = @_;

    my $scratch_str_ref = &global_scratch_str_ref();
    my $method_name = "@{$$method{'name'}}";
    my $return_type = &arg::type($$method{'return-type'});
    my $list_types = &arg_type::list_types($$method{'parameter-types'});
    $$scratch_str_ref .= &dk::print_in_col_string($col, "$klass_type @$klass_name { namespace __raw-signature { noexport const signature-t* $method_name($$list_types); } }\n");
}

sub generate_raw_method_signature_defn
{
    my ($method, $klass_name, $col, $klass_type) = @_;

    my $scratch_str_ref = &global_scratch_str_ref();
    my $method_name = "@{$$method{'name'}}";
    my $return_type = &arg::type($$method{'return-type'});
    my $list_types = &arg_type::list_types($$method{'parameter-types'});
    $$scratch_str_ref .= &dk::print_in_col_string($col, "$klass_type @$klass_name { namespace __raw-signature { noexport const signature-t* $method_name($$list_types)\n");
    $$scratch_str_ref .= &dk::print_in_col_string($col, "{\n");
    $col++;

    my $arg_list = "static const signature-t result = { \"$return_type\", \"$method_name\", \"";
    $arg_list .= &method::list_types($method);
    $arg_list .= "\", NULL };";
    $$scratch_str_ref .= &dk::print_in_col_string($col, "$arg_list\n");
    $$scratch_str_ref .= &dk::print_in_col_string($col, "return &result;\n");
    $col--;
    $$scratch_str_ref .= &dk::print_in_col_string($col, "} } }\n");
}

sub generate_ka_method_defns
{
    my ($methods, $klass_name, $col, $klass_type) = @_;

    foreach my $method (sort method::compare values %$methods)
    {
        if ($$method{'keyword-types'})
        {
	    &generate_ka_method_defn($method, $klass_name, $col, $klass_type);
        }
    }
}

sub generate_ka_method_defn
{
    my ($method, $klass_name, $col, $klass_type) = @_;
    my $scratch_str_ref = &global_scratch_str_ref();
    #$$scratch_str_ref .= &dk::print_in_col_string($col, "// generate_ka_method_defn()\n");

    my $qualified_klass_name = &path::string($klass_name);
    $$scratch_str_ref .= &dk::annotate($col, __FILE__, __LINE__);

#    &path::add_last($klass_name, 'va');
    my $new_arg_type = $$method{'parameter-types'};
    my $new_arg_type_list = &arg_type::list_types($new_arg_type);
    $new_arg_type = $$method{'parameter-types'};
    my $new_arg_names = &arg_type::names($new_arg_type);
    &_replace_first($new_arg_names, 'self');
    &_replace_last($new_arg_names, '_args_');
    my $new_arg_list  = &arg_type::list_pair($new_arg_type, $new_arg_names);

    my $return_type = &arg::type($$method{'return-type'});
    $$scratch_str_ref .= &dk::annotate($col, __FILE__, __LINE__);
    $$scratch_str_ref .= &dk::print_in_col_string($col, "$klass_type @$klass_name { namespace va { ");

    if (&is_exported($method))
    {
        $$scratch_str_ref .= &dk::print("export ");
    }
    else
    {
        $$scratch_str_ref .= &dk::print("DK-VISIBILITY ");
    }
    #if ($$method{'is-inline'})
    #{
    #    $$scratch_str_ref .= &dk::print("INLINE ");
    #}
    my $method_name = "@{$$method{'name'}}";
    $$scratch_str_ref .= &dk::print("$return_type $method_name($$new_arg_list)");

    if ($$method{'exception-types'})
    {
        my $throw_arg_type = &arg_type::list_types($$method{'exception-types'});
        $$scratch_str_ref .= &dk::print(" throw($$throw_arg_type)");
    }
    $$scratch_str_ref .= &dk::print("\n");
    $$scratch_str_ref .= &dk::print_in_col_string($col, "{\n");
    $col++;
    my $method_type_decl;
    $$method{'name'} = [ '_func_' ];
    my $func_name = "@{$$method{'name'}}";
    my $list_types = &arg_type::list_types($$method{'parameter-types'});
    my $list_names = &arg_type::list_names($$method{'parameter-types'});

    my $arg_names = &deep_copy(&arg_type::names(&deep_copy($$method{'parameter-types'})));
    my $arg_names_list = &arg_type::list_names($arg_names);

    if (0 < @{$$method{'keyword-types'}})
    {
        #my $param = &_remove_last($$method{'parameter-types'}); # remove uintptr-t type
        $method_type_decl = &ka_method::type_decl($method);
        #&_add_last($$method{'parameter-types'}, $param);
    }
    else
    {
        my $param1 = &_remove_last($$method{'parameter-types'}); # remove va-list-t type
        # should test $param1
        #my $param2 = &_remove_last($$method{'parameter-types'}); # remove uintptr-t type
        ## should test $param2
        $method_type_decl = &method::type_decl($method);
        #&_add_last($$method{'parameter-types'}, $param2);
        &_add_last($$method{'parameter-types'}, $param1);
    }
    $$scratch_str_ref .= &dk::print_in_col_string($col, "static $method_type_decl = $qualified_klass_name:$method_name; /*qualqual*/\n");
    $$scratch_str_ref .= &dk::print_in_col_string($col, "static const signature-t* __ka-signature__ = ka-signature(va:$method_name($$list_types));\n");

    foreach my $kw_arg (@{$$method{'keyword-types'}})
    {
        my $kw_arg_name = $$kw_arg{'name'};
        my $kw_arg_type = &arg::type($$kw_arg{'type'});
        my $statment = "$kw_arg_type $kw_arg_name = {0};";
        $$scratch_str_ref .= &dk::print_in_col_string($col, "$statment\n");
    }
    foreach my $kw_arg (@{$$method{'keyword-types'}})
    {
        my $kw_arg_name = $$kw_arg{'name'};
        $$scratch_str_ref .= &dk::print_in_col_string($col, "boole-t state-$kw_arg_name = false;\n");
    }
    #$$scratch_str_ref .= &dk::print_in_col_string($col, "if (NULL != $$new_arg_names[-1])\n");
    #$$scratch_str_ref .= &dk::print_in_col_string($col, "{\n");
    #$col++;
    my $is_first;

	$$scratch_str_ref .= &dk::print_in_col_string($col, "keyword-t* _keyword_;\n");
        $$scratch_str_ref .= &dk::print_in_col_string($col, "while (NULL != (_keyword_ = va-arg(_args_, keyword-t*)))\n");
        $$scratch_str_ref .= &dk::print_in_col_string($col, "{\n");
        $col++;
        $$scratch_str_ref .= &dk::print_in_col_string($col, "switch (_keyword_->hash)\n");
        $$scratch_str_ref .= &dk::print_in_col_string($col, "{\n");
        $col++;
        my $kw_arg_name;

        foreach my $kw_arg (@{$$method{'keyword-types'}})
        {
            $kw_arg_name = $$kw_arg{'name'};
            $$scratch_str_ref .= &dk::print_in_col_string($col, "case \$'$kw_arg_name':\n");
#            $$scratch_str_ref .= &dk::print_in_col_string($col, "{\n");
            $col++;
            my $kw_type = &arg::type($$kw_arg{'type'});

            if ('boole-t' eq $kw_type)
            {
                $kw_type = 'DK-VA-ARG-BOOLE-T'; # bools are promoted to ints
            }
            # should do this for other types (char=>int, float=>double, ... ???

            $$scratch_str_ref .= &dk::print_in_col_string($col, "$kw_arg_name = va-arg($$new_arg_names[-1], $kw_type);\n");
            $$scratch_str_ref .= &dk::print_in_col_string($col, "state-$kw_arg_name = true;\n");
            $$scratch_str_ref .= &dk::print_in_col_string($col, "break;\n");
            $col--;
#            $$scratch_str_ref .= &dk::print_in_col_string($col, "}\n");
            $is_first = 0;
        }
        $$scratch_str_ref .= &dk::print_in_col_string($col, "default:\n");
#        $$scratch_str_ref .= &dk::print_in_col_string($col, "{\n");
        $col++;

        $$scratch_str_ref .= &dk::print_in_col_string($col, "throw make(no-such-keyword-exception:klass,\n");
	$$scratch_str_ref .= &dk::print_in_col_string($col, "           object =>    self,\n");
	$$scratch_str_ref .= &dk::print_in_col_string($col, "           signature => __ka-signature__,\n");
	$$scratch_str_ref .= &dk::print_in_col_string($col, "           symbol =>    _keyword_->symbol);\n");
        $col--;
#        $$scratch_str_ref .= &dk::print_in_col_string($col, "}\n");
        $col--;
        $$scratch_str_ref .= &dk::print_in_col_string($col, "}\n");
        $col--;
        $$scratch_str_ref .= &dk::print_in_col_string($col, "}\n");

    foreach my $kw_arg (@{$$method{'keyword-types'}})
    {
        my $kw_arg_name    = $$kw_arg{'name'};
        $$scratch_str_ref .= &dk::print_in_col_string($col, "unless (state-$kw_arg_name)\n");
        $col++;
        if (defined $$kw_arg{'default'})
        {
            my $kw_arg_default = $$kw_arg{'default'};
            $$scratch_str_ref .= &dk::print_in_col_string($col,"$kw_arg_name = $kw_arg_default;\n");
        }
        else
        {
            $$scratch_str_ref .= &dk::print_in_col_string($col,"throw \"missing required keyword argument\";\n");
        }
        $col--;
    }

    $$scratch_str_ref .= &dk::print_in_col_string($col, "");
    my $var_name = '_result_';
    if ($$method{'return-type'})
    {
        $$scratch_str_ref .= &dk::print("$return_type $var_name = ");
    }
    $$scratch_str_ref .= &dk::print("$func_name(");
    $is_first = 1;
    #my $last_arg_name = &_remove_last($new_arg_names); # remove name associated with uintptr-t type

    for (my $i = 0; $i < @$new_arg_names - 1; $i++)
    {
        if ($is_first)
        {
            $$scratch_str_ref .= &dk::print("$$new_arg_names[$i]");
        }
        else
        {
            $$scratch_str_ref .= &dk::print(", $$new_arg_names[$i]");
        }
        $is_first = 0;
    }
    #&_add_last($new_arg_names, $last_arg_name); # add name associated with uintptr-t type
    foreach my $kw_arg (@{$$method{'keyword-types'}})
    {
        my $kw_arg_name = $$kw_arg{'name'};
        $$scratch_str_ref .= &dk::print(", $kw_arg_name");
    }
    $$scratch_str_ref .= &dk::print(");\n");
    if ($$method{'return-type'})
    {
        $$scratch_str_ref .= &dk::print_in_col_string($col, "return $var_name;\n");
    }
    else
    {
        $$scratch_str_ref .= &dk::print_in_col_string($col, "return;\n");
    }

    $col--;
    $$scratch_str_ref .= &dk::print_in_col_string($col, "} } }\n");
    $col--;
    #&path::remove_last($klass_name);
} 

sub dk::generate_cxx_footer
{
    my ($scope, $stack, $col) = @_;

    my $scratch_str_ref = &global_scratch_str_ref();
    &dk::generate_ka_method_defns($scope, $stack, 'trait', $col);
    &dk::generate_ka_method_defns($scope, $stack, 'klass', $col);

    if (&is_rt_decl() || &is_rt_defn())
    {
        my $num_klasses = scalar @$global_klass_defns;
        if (0 == $num_klasses)
        {
            $$scratch_str_ref .= &dk::print_in_col_string($col, "static named-info-node-t* klass-defns = NULL;\n");
        }
        else
        {
	    $$scratch_str_ref .= &generate_info_seq('klass-defns', [sort @$global_klass_defns], $col);
        }
	my $exports = &exports($scope);
        my $num_exports = scalar keys %$exports;
        if (0 == $num_exports)
        {
            $$scratch_str_ref .= &dk::print_in_col_string($col, "static named-info-node-t* exports = NULL;\n");
        }
        else
        {
	    $$scratch_str_ref .= &generate_info('exports', $exports, $col);
        }
        if (0 == keys %{$$scope{'interposers'}})
        {
            $$scratch_str_ref .= &dk::print_in_col_string($col, "static property-t* interposers = NULL;\n");
        }
        else
        {
	    #print STDERR Dumper $$scope{'interposers'};
	    my $interposers = &many_1_to_1_from_1_to_many($$scope{'interposers'});
	    #print STDERR Dumper $interposers;

            $$scratch_str_ref .= &dk::print_in_col_string($col, "static property-t interposers[] = //ro-data\n");
            $$scratch_str_ref .= &dk::print_in_col_string($col, "{\n");
            $col++;
            my ($key, $val);
            my $num_klasses = scalar keys %$interposers;
            foreach $key (sort keys %$interposers)
            {
                $val = $$interposers{$key};
                $$scratch_str_ref .= &dk::print_in_col_string($col, "{ $key:__klass__, cast(uintptr-t)$val:__klass__ },\n");
            }
	    $$scratch_str_ref .= &dk::print_in_col_string($col, "{ NULL, cast(uintptr-t)NULL }\n");
            $col--;
            $$scratch_str_ref .= &dk::print_in_col_string($col, "};\n");
        }
    }
    return $$scratch_str_ref;
}
sub dk::generate_ka_method_defns
{
    my ($scope, $stack, $klass_type, $col) = @_;
    my $scratch_str_ref = &global_scratch_str_ref();
    while (my ($klass_name, $klass_scope) = each(%{$$scope{$$plural_from_singular{$klass_type}}}))
    {
        if ($klass_scope)
        {
            my $cxx_klass_name = $klass_name;
            $$scratch_str_ref .= &dk::annotate($col, __FILE__, __LINE__);
            &path::add_last($stack, $klass_name);
            if (&is_rt_decl() || &is_rt_defn())
            {
                &dk::generate_cxx_footer_klass($klass_scope, $stack, $col, $klass_type);
            }
            else
            {
		if (1 || $$klass_scope{'raw-methods'})
		{
		    $$scratch_str_ref .= &dk::annotate($col, __FILE__, __LINE__);

		    # currently no support for va: methods

		    &generate_raw_method_signature_defns($$klass_scope{'raw-methods'}, [ $klass_name ], $col, $klass_type);
		}
               #&generate_ka_method_signature_decls($$klass_scope{'methods'}, [ $klass_name ], $col + 1);

                &generate_ka_method_signature_defns($$klass_scope{'methods'}, [ $klass_name ], $col, $klass_type);

                &generate_ka_method_defns($$klass_scope{'methods'}, [ $klass_name ], $col, $klass_type);
            }
            &path::remove_last($stack);
        }
    }
}
sub many_1_to_1_from_1_to_many
{
    my ($tbl) = @_;
    my $result = {};
    while (my ($key, $subseq) = each(%$tbl))
    {
	my $lhs = $key;
	foreach my $element (@$subseq)
	{
	    my $rhs = $element;
	    $$result{$lhs} = $rhs;
	    $lhs = $rhs;
	}
    }
    return $result;
}
sub dk::generate_imported_klasses_info
{
    my ($scope, $stack, $tbl) = @_;

    if (defined $$scope{'imported-klasses'})
    {
        while (my ($import_string, $seq) = each(%{$$scope{'imported-klasses'}}))
        {
            $$tbl{'imported-klasses'}{$import_string} = $seq;
        }
    }

    foreach my $construct ('traits', 'klasses')
    {
	while (my ($klass_name, $klass_scope) = each(%{$$scope{$construct}}))
	{
	    &path::add_last($stack, $klass_name);
	    my $import_string = &path::string($stack);
	    $$tbl{$construct}{$import_string} = &deep_copy($stack);

	    if ($klass_scope)
	    {
		$$tbl{'imported-klasses'}{$import_string} = &deep_copy($stack);
	    }

	    if (defined $$klass_scope{'imported-klasses'})
	    {
		while (my ($import_string, $seq) = each(%{$$klass_scope{'imported-klasses'}}))
		{
		    $$tbl{'imported-klasses'}{$import_string} = $seq;
		}
	    }
	    &path::remove_last($stack);
	}
    }
}

sub add_extra_symbols
{
    my ($file) = @_;
        $$file{'symbols'}{'construct'} = undef;
        $$file{'symbols'}{'exported-raw-method-addresses'} = undef;
        $$file{'symbols'}{'exported-raw-method-signatures'} = undef;
        $$file{'symbols'}{'exported-method-addresses'} = undef;
        $$file{'symbols'}{'exported-method-signatures'} = undef;
        $$file{'symbols'}{'behavior-exported?'} = undef;
        $$file{'symbols'}{'state-exported?'} = undef;
        $$file{'symbols'}{'exported?'} = undef;
        $$file{'symbols'}{'exports'} = undef;
        $$file{'symbols'}{'file'} = undef;
        $$file{'symbols'}{'interposers'} = undef;
        $$file{'symbols'}{'interpose-name'} = undef;
        $$file{'symbols'}{'ka-method-signatures'} = undef;
        $$file{'symbols'}{'klass'} = undef;
        $$file{'symbols'}{'klass-name'} = undef;
        $$file{'symbols'}{'method'} = undef;
        $$file{'symbols'}{'method-addresses'} = undef;
        $$file{'symbols'}{'method-aliases'} = undef;
        $$file{'symbols'}{'method-signatures'} = undef;
        $$file{'symbols'}{'name'} = undef;
        $$file{'symbols'}{'offset'} = undef;
        $$file{'symbols'}{'requires'} = undef;
        $$file{'symbols'}{'size'} = undef;
        $$file{'symbols'}{'slots-info'} = undef;
        $$file{'symbols'}{'slots-type'} = undef;
        $$file{'symbols'}{'superklass-name'} = undef;
        $$file{'symbols'}{'trait'} = undef;
        $$file{'symbols'}{'traits'} = undef;
        $$file{'symbols'}{'type'} = undef;
        $$file{'symbols'}{'va-method'} = undef;
        $$file{'symbols'}{'va-method-addresses'} = undef;
        $$file{'symbols'}{'va-method-signatures'} = undef;
        $$file{'symbols'}{'klass-defns'} = undef;
        $$file{'symbols'}{'module'} = undef;
        $$file{'symbols'}{'imported-klasses-names'} = undef;
        $$file{'symbols'}{'imported-klasses'} = undef;
        $$file{'symbols'}{'signatures'} = undef;
        $$file{'symbols'}{'signatures-va'} = undef;
        $$file{'symbols'}{'selectors'} = undef;
        $$file{'symbols'}{'selectors-va'} = undef;
        $$file{'symbols'}{'library'} = undef;
        $$file{'symbols'}{'executable'} = undef;
        $$file{'symbols'}{'time'} = undef;
        $$file{'symbols'}{'date'} = undef;
}

sub linkage_unit::generate_symbols
{
    my ($file, $generics, $symbols) = @_;
    my $col = 0;

    while (my ($symbol, $symbol_seq) = each(%$symbols))
    {
        my $ident_symbol = &make_ident_symbol($symbol_seq);
        $$symbols{$symbol} = $ident_symbol;
    }
    if (&is_rt_decl() || &is_rt_defn())
    {
	&add_extra_symbols($file);
    }
    while (my ($symbol, $symbol_seq) = each(%{$$file{'symbols'}}))
    {
        my $ident_symbol = &make_ident_symbol_scalar($symbol);
        $$file{'symbols'}{$symbol} = $ident_symbol;
        $$symbols{$symbol} = $ident_symbol;
    }
    my $symbol_keys = [sort symbol::compare keys %$symbols];
    my $scratch_str = "";
    $scratch_str .= &dk::annotate($col, __FILE__, __LINE__);

    my $max_width = 0;
    foreach my $symbol (@$symbol_keys)
    {
        my $cxx_ident = $$symbols{$symbol};
        my $width = length($cxx_ident);
	if ($width > $max_width)
	{ $max_width = $width; }
    }
    foreach my $symbol (@$symbol_keys)
    {
        my $cxx_ident = $$symbols{$symbol};
        my $width = length($cxx_ident);
	my $pad = ' ' x ($max_width - $width);
        if (&is_nrt_decl() || &is_rt_decl())
        {
            $scratch_str .= &dk::print_in_col_string3($col, "namespace __symbol { extern noexport symbol-t $cxx_ident; ", $pad, "} // $symbol\n");
        }
        else
        {
            $symbol =~ s|"|\\"|g;
	    $scratch_str .= &dk::print_in_col_string3($col, "namespace __symbol { noexport symbol-t $cxx_ident = ", $pad, "dk-intern(\"$symbol\"); }\n");
        }
    }
    return $scratch_str;
}

sub hashdjb
{
    my $h = 5381;

    for (split //, shift) {
        $h = (($h << 5) + $h) + ord($_); # h * 33 + c
    }
    return $h;
}

sub linkage_unit::generate_hashes
{
    my ($file, $generics, $symbols) = @_;
    my $col = 0;

    my ($symbol, $symbol_seq);
    my $symbol_keys = [sort symbol::compare keys %{$$file{'hashes'}}];
	my $max_width = 0;
	foreach $symbol (@$symbol_keys)
	{
	    my $cxx_ident = &make_ident_symbol_scalar($symbol);
	    $$file{'hashes'}{$symbol} = $cxx_ident;
	    my $width = length($cxx_ident);
	    if ($width > $max_width)
	    { $max_width = $width; }
	}
    my $scratch_str = "";
    if (&is_nrt_decl() || &is_rt_decl())
    {
        $scratch_str .= &dk::annotate($col, __FILE__, __LINE__);

	foreach $symbol (@$symbol_keys)
        {
	    my $cxx_ident = $$file{'hashes'}{$symbol};
	    my $width = length($cxx_ident);
	    my $pad = ' ' x ($max_width - $width);
            my $value = &hashdjb($symbol);
            my $hex_value = sprintf("0x%08x", $value);
            $scratch_str .= &dk::print_in_col_string3($col, "namespace __hash { /*static*/ const uintmax-t $cxx_ident = ", $pad, "$hex_value; } // $symbol\n");
        }
    }
    return $scratch_str;
}


sub linkage_unit::generate_keywords
{
    my ($file, $generics, $symbols) = @_;
    my $col = 0;

    my ($symbol, $symbol_seq);
    my $symbol_keys = [sort symbol::compare keys %{$$file{'keywords'}}];
	my $max_width = 0;
	foreach $symbol (@$symbol_keys)
	{
	    my $cxx_ident = &make_ident_symbol_scalar($symbol);
	    $$file{'keywords'}{$symbol} = $cxx_ident;
	    my $width = length($cxx_ident);
	    if ($width > $max_width)
	    { $max_width = $width; }
	}
    my $scratch_str = "";
    $scratch_str .= &dk::annotate($col, __FILE__, __LINE__);

    foreach $symbol (@$symbol_keys)
    {
	my $cxx_ident = $$file{'keywords'}{$symbol};
        my $width = length($cxx_ident);
	my $pad = ' ' x ($max_width - $width);
	if (defined $cxx_ident)
	{
        if (&is_nrt_decl() || &is_rt_decl())
        {
            $scratch_str .= &dk::print_in_col_string3($col, "namespace __keyword { extern noexport keyword-t $cxx_ident; ", $pad, "} // $symbol\n");
        }
        else
        {
            $symbol =~ s|"|\\"|g;
	    $symbol =~ s/\?$/$$long_suffix{'?'}/;
	    $symbol =~ s/\=$/$$long_suffix{'='}/;
	   #$symbol =~ s/\!$/$$long_suffix{'!'}/;
	    my $keyword_defn = "namespace __keyword { noexport keyword-t $cxx_ident = ";
	    $keyword_defn .= $pad;
	    $keyword_defn .= "{ \$$symbol, ";
	    $keyword_defn .= $pad;
	    $keyword_defn .= "\$'$symbol' ";
	    $keyword_defn .= $pad;
	    $keyword_defn .= "}; } // $symbol\n";

	    $scratch_str .= &dk::print_in_col_string($col, $keyword_defn);
        }
        }
    }
    return $scratch_str;
}

sub linkage_unit::generate_strings
{
    my ($file, $generics, $strings) = @_;
    my $scratch_str = "";
    my $col = 0;
    $scratch_str .= &dk::annotate($col, __FILE__, __LINE__);
    $scratch_str .= &dk::print_in_col_string($col, "namespace __string\n");
    $scratch_str .= &dk::print_in_col_string($col, "{\n");
    $col++;
    while (my ($string, $dummy) = each(%{$$file{'strings'}}))
    {
        my $string_ident = &make_ident_symbol_scalar($string);
        if (&is_nrt_decl() || &is_rt_decl())
        {
            $scratch_str .= &dk::print_in_col_string($col, "//extern noexport object-t $string_ident;\n");
        }
        else
        {
            $scratch_str .= &dk::print_in_col_string($col, "//noexport object-t $string_ident = make(string:klass, bytes => \"$string\");\n");
        }
    }
    $col--;
    $scratch_str .= &dk::print_in_col_string($col, "}\n");
    return $scratch_str;
}

sub generate_property_tbl
{
    my ($name, $tbl, $col) = @_;
    my $sorted_keys = [sort keys %$tbl];
    my $num;
    my $result = '';
    my $max_key_width = 0;
    my $max_element_width = 0;
    $num = 1;
    foreach my $key (@$sorted_keys)
    {
        my $element = $$tbl{$key};

	if ('HASH' eq ref $element)
	{
	    $result .= &generate_info("$name-$num", $element, $col);
	    $element = "&$name-$num";
	    $num++;
	}
	elsif (!defined $element)
	{ $element = "NULL"; }
        my $key_width = length($key);
	if ($key_width > $max_key_width)
	{ $max_key_width = $key_width; }

	my $element_width = length($element);
	if ($element_width > $max_element_width)
	{ $max_element_width = $element_width; }
    }
    $result .= &dk::print("static property-t $name\[] = //ro-data\n");
    $result .= &dk::print_in_col_string($col, "{\n");
    $num = 1;
    foreach my $key (@$sorted_keys)
    {
        my $element = $$tbl{$key};

	if ('HASH' eq ref $element)
	{
	    $element = "&$name-$num";
	    $num++;
	}
	elsif (!defined $element)
	{ $element = "NULL"; }
        my $key_width = length($key);
	my $key_pad = ' ' x ($max_key_width - $key_width);

        my $element_width = length($element);
	my $element_pad = ' ' x ($max_element_width - $element_width);

        $result .= &dk::print_in_col_string($col + 1, "{ $key, ");
	$result .= $key_pad;
	$result .= "cast(uintptr-t)$element";
	$result .= $element_pad;
	$result .= " },\n";
    }
    $result .= &dk::print_in_col_string($col, "};\n");
    return $result;
}
sub generate_info
{
    my ($name, $tbl, $col, $scope) = @_;
    my $result = &generate_property_tbl("$name-props", $tbl, $col, $scope);
    $result .= &dk::print_in_col_string($col, "static named-info-node-t $name = { $name-props, DK-ARRAY-LENGTH($name-props), NULL };\n");
    return $result;
}

sub generate_info_seq
{
    my ($name, $seq, $col) = @_;
    my $result = '';

    $result .= &dk::print("static named-info-node-t $name\[] = //ro-data\n");
    $result .= &dk::print_in_col_string($col, "{\n");

    my $max_width = 0;
    foreach my $element (@$seq)
    {
        my $width = length($element);
	if ($width > $max_width)
	{ $max_width = $width; }
    }
    foreach my $element (@$seq)
    {
        my $width = length($element);
	my $pad = ' ' x ($max_width - $width);
	$result .= &dk::print_in_col_string($col + 1, "{ $element, ");
	$result .= $pad;
	$result .= &dk::print("DK-ARRAY-LENGTH($element), ");
	$result .= $pad;
	$result .= &dk::print("NULL },\n");
    }
    $result .= &dk::print_in_col_string($col + 1, "{ NULL, 0, NULL }\n");
    $result .= &dk::print_in_col_string($col, "};\n");
    return $result;
}

sub dk::print
{
    my ($string) = @_;
    return $string;
}

sub pad
{
    my ($col_num) = @_;
    my $result_str = '';
    $col_num *= 2;
    $result_str .= ' ' x $col_num;
    return $result_str;
}

sub dk::annotate
{
    my ($col_num, $file, $line) = @_;
    my $string = '';
    if (1)
    {
	$string = &pad($col_num);
        $string .= '//';
        $string .= $file;
        $string .= ":";
        $string .= $line;
        $string .= "\n";
    }
    return $string;
}

sub dk::print_in_col_string
{
    my ($col_num, $string) = @_;
    my $result_str = &pad($col_num);
    $result_str .= $string;
    return &dk::print("$result_str");
}

sub dk::print_in_col_string3
{
    my ($col_num, $string1, $string2, $string3) = @_;
    my $result_str = &pad($col_num);
    $result_str .= $string1;
    $result_str .= $string2;
    $result_str .= $string3;
    return &dk::print("$result_str");
}

sub dk::print_in_col_string3_comment
{
    my ($col_num, $string1, $string2, $string3) = @_;
    if (1) {
	$string2 = '';
    }
    return &dk::print_in_col_string3($col_num, $string1, $string2, $string3);
}

sub dk::generate_dk_cxx
{
    my ($file_basename, $path, $name) = @_;
    my $filestr = &filestr_from_file("$file_basename.$dk_ext");
    my $tmp_out = "$path$name.$cxx_ext";
    $tmp_out =~ s|^\./||;
    print "  generating $tmp_out\n";

    #print STDERR "$name.$dk_ext.$cxx_ext\n";
    if (exists $ENV{'DK_NO_LINE'})
    {
	&write_to_file_converted_strings("$path$name.$cxx_ext", [ $filestr ]);
    }
    else
    {
	if (exists $ENV{'DK_ABS_PATH'})
	{
	    my $cwd = getcwd;
	    &write_to_file_converted_strings("$path$name.$cxx_ext", [ "#line 1 \"$cwd/$file_basename.$dk_ext\"\n", $filestr ]);
	}
	else
	{
	    &write_to_file_converted_strings("$path$name.$cxx_ext", [ "#line 1 \"$file_basename.$dk_ext\"\n", $filestr ]);
	}
    }
}

1;
