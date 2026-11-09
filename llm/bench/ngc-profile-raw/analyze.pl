#!/usr/bin/perl
# ngc Task 2 Step 4: the numbers of ngc-profile.md from the driver's output.
# Usage: perl analyze.pl <driver out dir> <file with the C src/gc statics>
# Prints markdown sections: stat medians and f/c ratios, top-40 per side,
# the collector symbols counted, the aligned delta table, the collector share.
# Collector symbols: MVM_gc_* in libmoar, the C statics of src/gc/*.c (list in
# c-gc-statics.txt), the Zig gc.<file>.<fn> functions, and moar_c.MVM_gc_*
# (translate-c copies of src/gc header inlines compiled into the Zig object).
use strict; use warnings;
my ($O, $statics_file) = @ARGV;
sub median { my @s = sort { $a <=> $b } @_; my $n = @s; $n % 2 ? $s[$n / 2] : ($s[$n / 2 - 1] + $s[$n / 2]) / 2 }
my @ev = qw(cycles:u instructions:u branch-misses:u cache-misses:u L1-dcache-load-misses:u);
open my $sf, '<', $statics_file or die; chomp(my @statics = <$sf>); my %static = map { $_ => 1 } @statics;

# --- stat
my (%rm, %all);   # setting side event -> [round medians] / [all runs]
for my $set (qw(plain bad)) { for my $side (qw(c f)) { for my $r (1 .. 3) {
    open my $fh, '<', "$O/$set/$side-r$r/stat.tsv" or die "$set $side $r: $!";
    <$fh>;
    while (<$fh>) { chomp; my ($e, $med, $min, $max, @runs) = split /\t/;
        push @{ $rm{$set}{$side}{$e} }, $med; push @{ $all{$set}{$side}{$e} }, @runs; }
}}}
my %T;   # setting side -> median of round medians of cycles
print "## Counters\n\n";
for my $set (qw(plain bad)) {
    print "### $set\n\n| event | c median [round-median min-max] | f median [round-median min-max] | f/c | c runs min-max (15) | f runs min-max (15) |\n|---|---:|---:|---:|---:|---:|\n";
    for my $e (@ev) {
        my %m; my %rng; my %r15;
        for my $side (qw(c f)) { my @r = sort { $a <=> $b } @{ $rm{$set}{$side}{$e} };
            $m{$side} = median(@r); $rng{$side} = "$r[0]-$r[-1]";
            my @a = sort { $a <=> $b } @{ $all{$set}{$side}{$e} }; $r15{$side} = "$a[0]-$a[-1]"; }
        printf "| %s | %.0f [%s] | %.0f [%s] | %.4f | %s | %s |\n", $e, $m{c}, $rng{c}, $m{f}, $rng{f}, $m{f} / $m{c}, $r15{c}, $r15{f};
        if ($e eq 'cycles:u') { $T{$set}{$_} = $m{$_} for qw(c f) }
    }
    print "\nRound medians, cycles:u: c ", join(' ', @{ $rm{$set}{c}{'cycles:u'} }), "; f ", join(' ', @{ $rm{$set}{f}{'cycles:u'} }), "\n\n";
}

# --- reports
sub key_of { my ($sym) = @_;     # alignment key: C name; Zig gc.<file>.<camel> -> snake
    (my $k = $sym) =~ s/\.\d+$//;
    if ($k =~ /^gc\.\w+\.(\w+)$/) { (my $s = $1) =~ s/([A-Z])/_\l$1/g; return $s }
    return $k }
sub is_gc { my ($dso, $sym) = @_; return 0 unless $dso eq 'libmoar.so';
    (my $k = $sym) =~ s/\.\d+$//; return $k =~ /^(?:moar_c\.)?MVM_gc_/ || $static{$k} || $k =~ /^gc\./ }
sub read_report { my ($f) = @_; my (@rows, %agg, $total);
    open my $fh, '<', $f or die "$f: $!";
    while (<$fh>) {
        next unless /^\s+([\d.]+)%\s+(\d+)\s+(.+?)\s+\[\.\]\s+(\S+)/;
        my ($pct, $n, $dso, $sym) = ($1, $2, $3, $4);
        $dso = '[JIT]' if $dso =~ /^\[JIT\]/;
        $sym = '(unresolved)' if $sym =~ /^0x[0-9a-f]+$/;
        push @rows, [$pct, $n, $dso, $sym];
        my $k = $dso eq 'libmoar.so' ? key_of($sym) : "$dso $sym";
        $agg{$k}{pct} += $pct; $agg{$k}{gc} ||= is_gc($dso, $sym); push @{ $agg{$k}{names} }, $sym;
        $total += $pct;
    }
    return (\@rows, \%agg, $total) }

for my $set (qw(plain bad nlto)) {
    my %R; my %A; my %tot;
    for my $side (qw(c f)) { my $f = $set eq 'nlto' ? "$O/nlto/$side/report.txt" : "$O/$set/$side-r1/report.txt";
        my ($rows, $agg, $t) = read_report($f); $R{$side} = $rows; $A{$side} = $agg; $tot{$side} = $t; }
    my $label = $set eq 'nlto' ? 'non-LTO (attribution only, a different binary)' : "LTO, $set";
    print "## Samples: $label\n\n";
    for my $side (qw(c f)) {
        my %seen; my $i = 0; my %gcnames;
        print "### top 40, $side\n\n| # | share % | samples | dso | symbol |\n|---:|---:|---:|---|---|\n";
        # top 40 per side: JIT and libc unresolved addresses merged per dso
        my %m; for my $r (@{ $R{$side} }) { my $k = "$r->[2]\t$r->[3]"; $m{$k}[0] += $r->[0]; $m{$k}[1] += $r->[1] }
        for my $k (sort { $m{$b}[0] <=> $m{$a}[0] } keys %m) { last if ++$i > 40;
            my ($d, $s) = split /\t/, $k; printf "| %d | %.2f | %d | %s | %s |\n", $i, $m{$k}[0], $m{$k}[1], $d, $s }
        my $gc = 0; for my $r (@{ $R{$side} }) { if (is_gc($r->[2], $r->[3])) { $gc += $r->[0]; $gcnames{$r->[3]} += $r->[0] } }
        printf "\nCollector share of samples, %s: %.2f %% (sum over %d symbols; perf's listed total %.2f %%)\n\n", $side, $gc, scalar(keys %gcnames), $tot{$side};
        print "Collector symbols counted, $side: ", join(', ', map { sprintf '%s %.2f', $_, $gcnames{$_} } sort { $gcnames{$b} <=> $gcnames{$a} } keys %gcnames), "\n\n";
        $T{$set}{"gc_$side"} = $gc;
    }
    # aligned delta in cycles (shares scaled to median totals; nlto uses the plain totals as scale, shares only)
    my $Ts = $set eq 'nlto' ? undef : $T{$set};
    my %keys = map { $_ => 1 } (keys %{ $A{c} }, keys %{ $A{f} });
    my @d = map { my $c = $A{c}{$_}{pct} // 0; my $f = $A{f}{$_}{pct} // 0;
        [ $_, $c, $f, $Ts ? ($f / 100 * $Ts->{f} - $c / 100 * $Ts->{c}) : ($f - $c), ($A{c}{$_}{gc} || $A{f}{$_}{gc}) ? 'gc' : '' ] } keys %keys;
    @d = sort { abs($b->[3]) <=> abs($a->[3]) } @d;
    print "### aligned delta, top 40 by |delta|", ($Ts ? " (cycles = share x median total cycles of the side)" : " (share points)"), "\n\n";
    print "| key (C name) | c % | f % | f names | ", ($Ts ? "delta cycles (f - c)" : "delta points"), " | collector |\n|---|---:|---:|---|---:|---|\n";
    my $i = 0; for my $r (@d) { last if ++$i > 40; my $fn = $A{f}{$r->[0]} ? join(' ', sort { $a cmp $b } keys %{ { map { $_ => 1 } @{ $A{f}{$r->[0]}{names} } } }) : '-';
        $fn = substr($fn, 0, 60) . '...' if length $fn > 63;
        printf "| %s | %.2f | %.2f | %s | %s | %s |\n", $r->[0], $r->[1], $r->[2], $fn, $Ts ? sprintf('%.3e', $r->[3]) : sprintf('%+.2f', $r->[3]), $r->[4] }
    print "\n";
    if ($Ts) {
        my $gc_c = $T{$set}{gc_c} / 100 * $Ts->{c}; my $gc_f = $T{$set}{gc_f} / 100 * $Ts->{f};
        my $dt = $Ts->{f} - $Ts->{c};
        my @rc = sort { $a <=> $b } @{ $rm{$set}{c}{'cycles:u'} }; my @rf = sort { $a <=> $b } @{ $rm{$set}{f}{'cycles:u'} };
        my @ac = sort { $a <=> $b } @{ $all{$set}{c}{'cycles:u'} }; my @af = sort { $a <=> $b } @{ $all{$set}{f}{'cycles:u'} };
        print "### collector share, $set\n\n";
        printf "- total cycles median: c %.0f, f %.0f; difference f - c %.0f (%.2f %% of c)\n", $Ts->{c}, $Ts->{f}, $dt, 100 * $dt / $Ts->{c};
        printf "- spread of round medians: c %.0f, f %.0f; run-to-run spread over all 15 runs: c %.0f, f %.0f\n", $rc[-1] - $rc[0], $rf[-1] - $rf[0], $ac[-1] - $ac[0], $af[-1] - $af[0];
        printf "- collector cycles: c %.2f %% x %.0f = %.0f; f %.2f %% x %.0f = %.0f; difference %.0f\n", $T{$set}{gc_c}, $Ts->{c}, $gc_c, $T{$set}{gc_f}, $Ts->{f}, $gc_f, $gc_f - $gc_c;
        printf "- collector share = %.0f / %.0f = %.3f\n\n", $gc_f - $gc_c, $dt, ($gc_f - $gc_c) / $dt;
    }
}
