#!perl -w

##############################################################################
# Script : remove_all_test_points.pl
#
# Objetivo:
#   Eliminar el atributo .test_point
#   de todos los pads del STEP activo.
#
# Validado:
#   Valor NPI 25.1
#
# Resultado esperado:
#   Ningún pad conserva el atributo .test_point.
#
##############################################################################

use strict;
use warnings;

use lib "V:/vNPI_DIR/sys/scripts/jabil/perl/lib";

use Valor;
use Valor_util;

my $F = new Valor;
my $v = new Valor_util();

my $job  = $ENV{JOB}  || "";
my $step = $ENV{STEP} || "";

#################################################
# OBTENER TODAS LAS LAYERS
#################################################

$F->DO_INFO(
    "-t step -e $job/$step -d LAYERS_LIST"
);

my @layers =
grep {
    defined($_) && $_ ne ""
}
@{$F->{doinfo}{gLAYERS_LIST}};

my $layers_scanned = 0;
my $pads_reviewed  = 0;

#################################################
# RECORRER TODAS LAS LAYERS
#################################################

foreach my $layer (@layers)
{
    $layers_scanned++;

    $v->setWorkLayer($layer);

    $v->resetFilter();

    $F->COM("sel_clear_feat");

    #################################################
    # SELECCIONAR TODOS LOS PADS
    #################################################

    $F->COM(
        "sel_multi_feat",
        operation  => "select",
        feat_types => "pad",
        resize_by  => 0
    );

    my $count =
    $v->getSelectedCount();

    $count = 0 unless defined $count;

    $pads_reviewed += $count;

    next if($count < 1);

    #################################################
    # ELIMINAR ATRIBUTO
    #################################################

    $F->COM(
        "sel_delete_atr",
        attributes => ".test_point;",
        pkg_attr   => "no"
    );

    $F->COM("sel_clear_feat");
}

#################################################
# LIMPIEZA FINAL
#################################################

$F->COM("sel_clear_feat");

#################################################
# REPORTE
#################################################

print "\n";
print "========================================\n";
print "REMOVE ALL TEST POINTS\n";
print "========================================\n";
print "JOB=$job\n";
print "STEP=$step\n";
print "\n";
print "LAYERS_REVISADAS=$layers_scanned\n";
print "PADS_REVISADOS=$pads_reviewed\n";
print "\n";
print "ATRIBUTO_ELIMINADO=.test_point\n";
print "RESULTADO=SUCCESS\n";
print "========================================\n";

$F->PAUSE(

    "TEST POINT CLEANUP\n\n" .

    "SUCCESS\n\n" .

    "Todos los atributos\n" .

    ".test_point fueron eliminados."

);

exit 0;
