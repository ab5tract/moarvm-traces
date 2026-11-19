# Known remaining gap of the recompose refusal (from the Task 4 review), NOT a
# flip: a VMArray type that has an array (an object slot holding a hash)
# before its first compose with an element type, then composed with str.
# The refusal applies only once an element type has been composed
# (elem_type set), because the REPR cannot know whether arrays of a type
# exist; so this compose is allowed before and after the fix, and the live
# array's object slot is then read as a string: atpos_s gives an MVMHash as
# an MVMString ("chars: 0" here: a type confusion, no crash in this run).
my $t := nqp::newtype(nqp::null(), 'VMArray');
my $a := nqp::create($t);
nqp::push($a, nqp::hash('a', 1));
nqp::composetype($t, nqp::hash('array', nqp::hash('type', str)));
say("composed to str with a live object array");
my $s := nqp::atpos_s($a, 0);
say("chars: " ~ nqp::chars($s));
