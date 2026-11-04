package HarnessTimer;
use TAP::Harness;
no warnings 'redefine';
my $orig = TAP::Harness->can('new');
*TAP::Harness::new = sub { my ($c,$a)=@_; $a ||= {}; $a->{timer}=1; $orig->($c,$a) };
1;
