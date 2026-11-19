# B2 from plain Raku (no nqp ops): buf64/buf32 read-int64 / write-int64 /
# read-int32 / write-int32 pass the offset to nqp::readint/writeint
# unchecked, and offset * elem_size wraps (see B2-buf-offset-wrap.nqp).
#
# A correct VM prints, for both lines,
#     ...: read DIED ..., write DIED ..., after 1 2 3 4
# The bug: the read returns element 1 (2), the write replaces element 1:
#     buf64: read 2, write ok, after 1 99 3 4
#     buf32: read 2, write ok, after 1 99 3 4

$*OUT.out-buffer = False;   # keep every line if the VM dies
for (buf64, 2**61 + 1), (buf32, 2**62 + 1) -> ($type, $off) {
    my $b = $type.new(1, 2, 3, 4);
    my $r = try { $type ~~ buf64 ?? $b.read-int64($off) !! $b.read-int32($off) } // "DIED {$!.message}";
    my $w = try { $type ~~ buf64 ?? $b.write-int64($off, 99) !! $b.write-int32($off, 99); 'ok' } // "DIED {$!.message}";
    say "{$type.^name}: read $r, write $w, after {$b.list}";
}
