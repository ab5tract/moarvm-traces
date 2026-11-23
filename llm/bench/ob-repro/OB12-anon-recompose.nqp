# OB12: #2081's recompose refusal prints "Type  is" (two spaces) for a type
# without a debug name. Program from cfix-open-bugs.md OB12.
# Before: "DIED [MVMArray: Type  is already composed with another element kind]".
# Fixed: "DIED [MVMArray: Type <anon> is already composed with another element kind]".
my $t := nqp::newtype(nqp::null(), "VMArray");
nqp::composetype($t, nqp::hash("array", nqp::hash("type", int)));
my $r := "returned";
try { nqp::composetype($t, nqp::hash("array", nqp::hash("type", str))); CATCH { $r := "DIED [" ~ nqp::getmessage($!) ~ "]" } };
say("anonymous type, int then str: $r");
my $named := nqp::newtype(nqp::null(), "VMArray");
nqp::setdebugtypename($named, "NamedArray");
nqp::composetype($named, nqp::hash("array", nqp::hash("type", int)));
$r := "returned";
try { nqp::composetype($named, nqp::hash("array", nqp::hash("type", str))); CATCH { $r := "DIED [" ~ nqp::getmessage($!) ~ "]" } };
say("named type (control), int then str: $r");
