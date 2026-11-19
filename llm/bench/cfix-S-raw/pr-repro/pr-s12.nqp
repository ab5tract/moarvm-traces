sub fill($a) { my int $i := 0; while $i < 10 { nqp::push($a, ~($i * 3 + 1)); $i++ } }
sub show($name, $a) { my @p; for $a { nqp::push(@p, ~$_) }; say("$name: " ~ nqp::join(' ', @p)) }
my $old := nqp::list(); fill($old);
nqp::force_gc(); nqp::force_gc();          # promote it to the second generation
nqp::splice($old, $old, 1, 0); show("obj gen2", $old);
my $new := nqp::list(); fill($new);
nqp::splice($new, $new, 1, 0); show("obj nursery", $new);
my $s := nqp::list_s(); my int $i := 0;
while $i < 10 { nqp::push_s($s, ~($i * 3 + 1)); $i++ }
nqp::splice($s, $s, 1, 0); show("str", $s);
