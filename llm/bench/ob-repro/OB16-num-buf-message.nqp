# OB16: write_buf and read_buf accept the num kinds, but their message says
# "requires an integer type". Program from cfix-open-bugs.md OB16.
# Before: "MVMArray: write_buf requires an integer type" (and read_buf).
# Fixed: "... requires an integer or num type"; the num array still accepts.
my $n := nqp::list_n(1.5);
my $r := 'returned';
try { nqp::writeint($n, 0, 4607182418800017408, 13); $r := 'returned, atpos_n ' ~ nqp::atpos_n($n, 0) ~ ', readint ' ~ nqp::readint($n, 0, 13); CATCH { $r := 'DIED ' ~ nqp::getmessage($!) } }
say("num array, writeint then readint: $r");
for <obj str> -> $kind {
    my $o := $kind eq 'obj' ?? nqp::list(1) !! nqp::list_s('a');
    $r := 'returned';
    try { nqp::writeint($o, 0, 1, 13); CATCH { $r := 'DIED ' ~ nqp::getmessage($!) } }
    say("$kind array, writeint: $r");
    $r := 'returned';
    try { nqp::readint($o, 0, 13); CATCH { $r := 'DIED ' ~ nqp::getmessage($!) } }
    say("$kind array, readint: $r");
}
