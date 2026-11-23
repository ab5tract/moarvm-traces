# OB19: a hole in an object array (made by setelems growth) reads as VMNull
# through atpos but comes back as NULL from pop and shift. NULL and VMNull are
# told apart with nqp::eqaddr against nqp::null() (VMNull), applied to the
# op's result directly: a NULL bound to a variable or passed to a sub can
# crash the VM. Also a splice of a holey array: copy_elements keeps NULL
# holes into a nursery target and stores VMNull into a gen2 target (made old
# with two full collections), so pop from the two copies differs.
# Before: pop and shift give "VMNull 0" (and the young-target splice too).
# Fixed: "VMNull 1" in every line.
sub holey() { my $a := nqp::list(); nqp::setelems($a, 3); $a }
my $a := holey();
say("atpos 1: VMNull " ~ (nqp::eqaddr(nqp::atpos($a, 1), nqp::null()) ?? 1 !! 0));
say("pop: VMNull " ~ (nqp::eqaddr(nqp::pop($a), nqp::null()) ?? 1 !! 0));
say("shift: VMNull " ~ (nqp::eqaddr(nqp::shift($a), nqp::null()) ?? 1 !! 0));
say("elems left: " ~ nqp::elems($a));
my $old := nqp::list(1);
nqp::force_gc(); nqp::force_gc();
my $young := nqp::list(1);
nqp::splice($old, holey(), 1, 0);
nqp::splice($young, holey(), 1, 0);
say("splice of holes into an old (gen2) array, pop: VMNull " ~ (nqp::eqaddr(nqp::pop($old), nqp::null()) ?? 1 !! 0));
say("splice of holes into a young (nursery) array, pop: VMNull " ~ (nqp::eqaddr(nqp::pop($young), nqp::null()) ?? 1 !! 0));
say("done");
