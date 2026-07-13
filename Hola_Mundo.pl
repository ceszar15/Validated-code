#!perl -w

use strict;
use warnings;

use lib "V:/vNPI_DIR/sys/scripts/jabil/perl/lib";

use Valor_util;

my $v = Valor_util->new(
    'rcom' => 1
);

$v->{F}->PAUSE("Hola Mundo desde Valor_util");

