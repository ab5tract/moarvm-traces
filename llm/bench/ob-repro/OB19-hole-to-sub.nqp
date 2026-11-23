# OB19, the consequence Task 1 saw: a hole popped (or shifted) from an
# object array into a variable and passed to an nqp sub. Before the fix pop
# and shift return the raw NULL slot, and the VM crashes on the sub call
# (seen as a segfault in Task 1's first draft of OB19-holes.nqp). Fixed: the
# hole is VMNull and the sub sees a null: "isnull 1" on both lines.
sub describe($value) { nqp::isnull($value) ?? 'isnull 1' !! 'isnull 0' }
my $popped_from := nqp::list(); nqp::setelems($popped_from, 3);
my $popped := nqp::pop($popped_from);
say("pop into a variable, passed to a sub: " ~ describe($popped));
my $shifted_from := nqp::list(); nqp::setelems($shifted_from, 3);
my $shifted := nqp::shift($shifted_from);
say("shift into a variable, passed to a sub: " ~ describe($shifted));
say("done");
