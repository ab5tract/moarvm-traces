# P1 from plain Raku: Rakudo methods whose candidates are typed by a native
# array role (`int @values`, `intarray:D`, `strarray:D`, ...) also accept a
# *shaped* native array, whose REPR is MultiDimArray, and pass it to
# nqp::splice as the source. asplice lets it in (MultiDimArray has elems),
# and copy_elements reads its REPR data as a VMArray's: NULL, a SIGSEGV.
#
# Run with one argument (each case crashes upstream, so one per run):
#   buf      Buf.new(my int @a[2] = 1, 2)       (Buf.rakumod:410, Blob.new(int @values))
#   strapp   my str @t = <x>; @t.append(my str @s[2] = <a b>)
#                                               (native_array.rakumod:385, strarray append)
#   intapp   my int @i = 1; @i.append(my int @a[2] = 1, 2)
#                                               (native_array.rakumod:1015, intarray append)
#
# A correct VM prints the REPR line, the case name and either the result or "DIED <message>",
# and then "survived". Upstream: SIGSEGV (exit 139) in copy_elements. With the
# P1 fix: DIED MVMArray: Can only splice from a VMArray, got a MultiDimArray.

sub MAIN(Str $case) {
    my int @a[2] = 1, 2;
    say "a shaped native array: {@a.^name}, REPR {@a.REPR}";
    given $case {
        when 'buf'    { try { say "buf: ", Buf.new(@a); CATCH { default { say "buf: DIED ", .message } } } }
        when 'strapp' { my str @s[2] = <a b>; my str @t = <x>;
                        try { @t.append(@s); say "strapp: ", @t; CATCH { default { say "strapp: DIED ", .message } } } }
        when 'intapp' { my int @i = 1;
                        try { @i.append(@a); say "intapp: ", @i; CATCH { default { say "intapp: DIED ", .message } } } }
        default { die "case: buf, strapp or intapp" }
    }
    say "survived";
}
