# OB19, serialization: what a hole (a NULL slot of an object array) reads
# back as after a serialize/deserialize round trip. serialize writes a NULL
# slot as REFVAR_NULL and an nqp::null() element as REFVAR_VM_NULL
# (serialization.c write_ref); read_ref gives NULL and VMNull back, so the
# deserialized array holds a NULL slot again. Before the fix atpos read it
# as VMNull but pop gave the raw NULL; after it every read gives VMNull.
# Expected after: "VMNull 1" on every line. The result is compared before it
# is bound anywhere (a bound NULL crashed the VM before the fix).
sub uint8_buf_type() {
    my $e := nqp::newtype(nqp::null(), 'P6int');
    nqp::composetype($e, nqp::hash('integer', nqp::hash('bits', 8, 'unsigned', 1)));
    my $t := nqp::newtype(nqp::null(), 'VMArray');
    nqp::composetype($t, nqp::hash('array', nqp::hash('type', $e)));
    $t
}
sub encode_as_base64($buf) {   # as nqp's t/serialization/01-basic.t
    my @base64 := nqp::split('', "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/");
    my @str; my int $i := 0; my int $size := nqp::elems($buf);
    while $i < $size {
        my int $c := nqp::atpos_i($buf, $i++);
        $c := $c * 256; if $i < $size { $c := $c + nqp::atpos_i($buf, $i) }; $i++;
        $c := $c * 256; if $i < $size { $c := $c + nqp::atpos_i($buf, $i) }; $i++;
        nqp::push(@str, @base64[nqp::bitshiftr_i($c +& 0x00fc0000, 18)]);
        nqp::push(@str, @base64[nqp::bitshiftr_i($c +& 0x0003f000, 12)]);
        if $i > $size + 1 { nqp::push(@str, '=') } else { nqp::push(@str, @base64[nqp::bitshiftr_i($c +& 0x00000fc0, 6)]) };
        if $i > $size { nqp::push(@str, '=') } else { nqp::push(@str, @base64[$c +& 0x0000003f]) }
    }
    nqp::join('', @str)
}
sub round_trip($name, $array) {
    my $sc := nqp::createsc($name ~ '_IN');
    my $strings := nqp::list_s();
    nqp::scsetobj($sc, 0, $array); nqp::setobjsc($array, $sc);
    my $buf := nqp::serializetobuf($sc, $strings, uint8_buf_type());
    my $read_sc := nqp::createsc($name ~ '_OUT');
    nqp::deserialize(encode_as_base64($buf), $read_sc, $strings, nqp::list(), nqp::null());
    nqp::scgetobj($read_sc, 0)
}
# [ 'first', <hole>, nqp::null() ]
my $holey := nqp::list('first'); nqp::setelems($holey, 2); nqp::push($holey, nqp::null());
my $read_back := round_trip('OB19_SERIALIZED', $holey);
say("read back: elems " ~ nqp::elems($read_back));
say("atpos 1 (the hole): VMNull " ~ (nqp::eqaddr(nqp::atpos($read_back, 1), nqp::null()) ?? 1 !! 0));
say("pop (the nqp::null() element): VMNull " ~ (nqp::eqaddr(nqp::pop($read_back), nqp::null()) ?? 1 !! 0));
say("pop (the hole): VMNull " ~ (nqp::eqaddr(nqp::pop($read_back), nqp::null()) ?? 1 !! 0));
say("shift: " ~ nqp::shift($read_back));
say("done");
