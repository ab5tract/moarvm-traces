my $b = buf16.new(1..8);
say (try $b.read-uint32(2**63 - 1)) // "died: {$!.message}";
say (try { $b.write-uint32(2**63 - 1, 0x22221111); 'ok' }) // "died: {$!.message}";
say $b.list;
