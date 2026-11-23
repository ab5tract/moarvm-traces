# OB8, the Raku route: buf16.write-uint64 into a buf16 of 3 grows it to
# offset + 8 elements. Before: 9. Fixed: 5.
my $b = buf16.new(1, 2, 3);
try {
    $b.write-uint64(1, 1);
    say "buf16.new(1,2,3).write-uint64(1, 1): elems {$b.elems}: {$b.list}";
    CATCH { default { say "DIED {.message}" } }
}
my $c = buf32.new(1);
try {
    $c.write-uint16(1, 0x0102);
    say "buf32.new(1).write-uint16(1, 0x0102): elems {$c.elems}: {$c.list}";
    CATCH { default { say "DIED {.message}" } }
}
