# Area K, the Raku route: `use experimental :smallnatives` declares uint4 and
# friends; `my uint4 @a` composes an array of a kind without storage.
# The brief's program, each statement in its own try. The declaration is
# compiled through EVAL inside its try, so that a compile-time throw (the
# array type may be composed when the declaration is compiled) is caught too.
# Before: "declared, elems 0", push dies "MVMArray: Unhandled slot type", [].
# Fixed: the declaration dies with the compose message.
use experimental :smallnatives;
use MONKEY-SEE-NO-EVAL;
my $a;
my $declared = False;
try { $a := EVAL 'my uint4 @a; @a'; $declared = True; say "declared, elems {$a.elems}"; CATCH { default { say "declare: DIED {.message}" } } }
if $declared {
    try { $a.push(3); say "push 3: returned"; CATCH { default { say "push 3: DIED {.message}" } } }
    try { say $a; CATCH { default { say "say: DIED {.message}" } } }
}
else { say "push 3 and say: skipped, no array" }
