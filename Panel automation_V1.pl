#!perl -w

use strict;
use warnings;

use lib "V:/vNPI_DIR/sys/scripts/jabil/perl/lib";

use Valor;

my $F = new Valor;

#################################################
# Datos del entorno
#################################################

my $job         = $ENV{JOB}  || "";
my $source_step = $ENV{STEP} || "";
my $panel_step  = "panel_auto";

if ($job eq "") {
    $F->PAUSE("ERROR: No se encontró la variable JOB");
    exit 1;
}

if ($source_step eq "") {
    $F->PAUSE("ERROR: No se encontró la variable STEP");
    exit 1;
}

if ($source_step eq $panel_step) {
    $F->PAUSE(
        "ERROR: El step de origen y el step de panel son iguales.\n\n" .
        "STEP=$source_step"
    );
    exit 1;
}

print "JOB=$job\n";
print "SOURCE_STEP=$source_step\n";
print "PANEL_STEP=$panel_step\n";

#################################################
# Crear step de panel
#################################################

$F->COM(
    "create_entity",
    job  => $job,
    type => "step",
    name => $panel_step
);

#################################################
# Abrir step de panel
#################################################

$F->COM(
    "open_entity",
    job    => $job,
    type   => "step",
    name   => $panel_step,
    iconic => "no"
);

#################################################
# Primera fila
#################################################

$F->COM(
    "sr_tab_add",
    line  => 1,
    step  => $source_step,
    x     => 0,
    y     => 0,
    nx    => 2,
    ny    => 1,
    dx    => 3.6382,
    dy    => 0,
    angle => 0,
    flip  => "no"
);

#################################################
# Segunda fila rotada
#################################################

$F->COM(
    "sr_tab_add",
    line  => 2,
    step  => $source_step,
    x     => 3.154240551,
    y     => 1.512167322,
    nx    => 2,
    ny    => 1,
    dx    => 3.6382,
    dy    => 0,
    angle => 180,
    flip  => "no"
);

#################################################
# Final
#################################################

$F->PAUSE(
    "Prueba de step dinámico terminada.\n\n" .
    "JOB: $job\n" .
    "Step origen: $source_step\n" .
    "Step panel: $panel_step\n\n" .
    "IMPORTANTE:\n" .
    "Las posiciones todavía corresponden al PCB anterior."
);

exit 0;
