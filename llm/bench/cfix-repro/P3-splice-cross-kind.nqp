# P3: a splice between a reference kind and a numeric kind reinterprets the
# register instead of converting it.
#
# When source and target kinds differ, copy_elements (VMArray.c:956-965)
# reads each element with at_pos in the source's register kind and binds it
# with bind_pos in the target's register kind, passing the same MVMRegister
# union through: "actually should coerce between source_kind and target_kind
# here" (VMArray.c:962). From an int array into an object array the integer
# becomes an object pointer; from an object array into an int array the
# pointer becomes an integer.
#
# Run with one argument:
#   int-into-obj  splice nqp::list_i(0x4141414141) into nqp::list(1, 2), then
#                 nqp::force_gc(): the collector follows the "pointer".
#                 Correct VM: "int-into-obj: DIED <an exception>" (or the
#                 integer boxed), then "gc: survived". Bug: SIGSEGV in the
#                 collector (or on use) after the splice "succeeds".
#   obj-into-int  splice nqp::list(nqp::hash()) into nqp::list_i(1, 2) and
#                 print element 1. Correct VM: DIED (or a defined
#                 conversion). Bug: prints the hash's address as an integer
#                 (a different number every run).
#   num-from-int  splice nqp::list_i(4607182418800017408) into
#                 nqp::list_n(): prints 1 (the int's bits read as a double)
#                 instead of 4.607182418800017e+18. Numeric to numeric: no
#                 memory hazard, a wrong value.

sub MAIN($prog, $case) {
    if $case eq 'int-into-obj' {
        my $a := nqp::list(1, 2);
        my $r;
        try { nqp::splice($a, nqp::list_i(280267669825), 1, 0); $r := 'returned, elems ' ~ nqp::elems($a); CATCH { $r := 'DIED ' ~ nqp::getmessage($!) } }
        say("int-into-obj: $r");
        nqp::force_gc();
        say("gc: survived");
        say("element 1 is null: " ~ nqp::isnull(nqp::atpos($a, 1)));
    }
    elsif $case eq 'obj-into-int' {
        my $a := nqp::list_i(1, 2);
        my $r;
        try { nqp::splice($a, nqp::list(nqp::hash()), 1, 0); $r := 'returned, element 1 = ' ~ nqp::atpos_i($a, 1); CATCH { $r := 'DIED ' ~ nqp::getmessage($!) } }
        say("obj-into-int: $r");
    }
    elsif $case eq 'num-from-int' {
        my $a := nqp::list_n();
        my $r;
        try { nqp::splice($a, nqp::list_i(4607182418800017408), 0, 0); $r := 'returned, element 0 = ' ~ nqp::atpos_n($a, 0); CATCH { $r := 'DIED ' ~ nqp::getmessage($!) } }
        say("num-from-int: $r");
    }
    else { nqp::die("case: int-into-obj, obj-into-int or num-from-int") }
}
