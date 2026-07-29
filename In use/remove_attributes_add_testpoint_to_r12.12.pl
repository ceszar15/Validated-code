#!perl -w

use strict;
use warnings;


use lib "V:/vNPI_DIR/sys/scripts/jabil/perl/lib";

use Valor;
use Valor_util;

my $F = new Valor;
my $v = new Valor_util();

my $job  = $ENV{JOB}  || "";
my $step = $ENV{STEP} || "";

my $target_symbol = "r12.12";

if ($job eq "" || $step eq "")
{
    $F->PAUSE(
        "ERROR: JOB o STEP no estan definidos"
    );
    exit 1;
}

print "\n";
print "========================================\n";
print "TAKAYA TEST POINT V04\n";
print "========================================\n";
print "JOB=$job\n";
print "STEP=$step\n";
print "TARGET_SYMBOL=$target_symbol\n";
print "========================================\n";

#################################################
# OBTENER TODAS LAS LAYERS DEL STEP ACTUAL
#################################################

$F->DO_INFO(
    "-t step -e $job/$step -d LAYERS_LIST"
);

my $layers_ref =
$F->{doinfo}{gLAYERS_LIST};

if (
    !defined($layers_ref)
    ||
    ref($layers_ref) ne "ARRAY"
)
{
    $F->PAUSE(
        "ERROR: LAYERS_LIST no devolvio un ARRAY"
    );

    exit 1;
}

my @layers =
grep {
    defined($_)
    &&
    $_ ne ""
}
@{$layers_ref};

if (!@layers)
{
    $F->PAUSE(
        "ERROR: No se encontraron layers"
    );

    exit 1;
}

#################################################
# CONTADORES
#################################################

my $scanned_layers  = 0;
my $modified_layers = 0;
my $updated_pads    = 0;
my $reviewed_pads   = 0;

#################################################
# FASE 1
# ELIMINAR TODOS LOS TEST POINTS
#################################################

print "\n";
print "========================================\n";
print "FASE 1 - LIMPIANDO TEST POINTS\n";
print "========================================\n";

foreach my $layer (@layers)
{
    print "\n";
    print "BORRANDO TEST_POINT EN $layer\n";

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

    $count = 0
        unless defined $count;

    $reviewed_pads += $count;

    print "PAD_COUNT=$count\n";

    if ($count < 1)
    {
        $F->COM("sel_clear_feat");
        next;
    }

    #################################################
    # BORRAR TEST POINT
    #################################################

    $F->COM(
        "sel_delete_atr",
        attributes => ".test_point;",
        pkg_attr   => "no"
    );

    $F->COM("sel_clear_feat");
}

#################################################
# FASE 2
# ASIGNAR TEST POINT SOLO A R12.12
#################################################

print "\n";
print "========================================\n";
print "FASE 2 - ASIGNANDO TEST POINT\n";
print "========================================\n";

foreach my $layer (@layers)
{
    $scanned_layers++;

    print "\n";
    print "----------------------------------------\n";
    print "LAYER=$layer\n";

    $v->setWorkLayer($layer);

    $v->resetFilter();

    $F->COM("sel_clear_feat");

    #################################################
    # SELECCIONAR SOLO R12.12
    #################################################

    $F->COM(
        "sel_multi_feat",
        operation    => "select",
        feat_types   => "pad",
        resize_by    => 0,
        include_syms => $target_symbol
    );

    my $selected_count =
    $v->getSelectedCount();

    $selected_count = 0
        unless defined $selected_count;

    print "R12_12_PAD_COUNT=$selected_count\n";

    if ($selected_count < 1)
    {
        print "STATUS=SKIP_NO_MATCHES\n";

        $F->COM("sel_clear_feat");

        next;
    }

    #################################################
    # AGREGAR TEST POINT
    #################################################

    $F->COM(
        "cur_atr_set",
        attribute => ".test_point"
    );

    $F->COM(
        "sel_change_atr",
        mode     => "add",
        pkg_attr => "no"
    );

    $modified_layers++;

    $updated_pads += $selected_count;

    print "STATUS=TEST_POINT_ADDED\n";
    print "UPDATED_IN_LAYER=$selected_count\n";

    $F->COM("sel_clear_feat");
}

#################################################
# LIMPIEZA FINAL
#################################################

$F->COM("sel_clear_feat");

#################################################
# REPORTE FINAL EN LOG
#################################################

print "\n";
print "========================================\n";
print "TAKAYA TEST POINT V04\n";
print "========================================\n";
print "JOB=$job\n";
print "STEP=$step\n";
print "\n";
print "LAYERS_REVISADAS=$scanned_layers\n";
print "LAYERS_MODIFICADAS=$modified_layers\n";
print "\n";
print "PADS_REVISADOS=$reviewed_pads\n";
print "PADS_R12_12=$updated_pads\n";
print "\n";
print "TEST_POINTS_ELIMINADOS=TODOS\n";
print "TEST_POINTS_AGREGADOS=$updated_pads\n";
print "\n";
print "RESULTADO=SUCCESS\n";
print "========================================\n";

#################################################
# REPORTE FINAL EN PANTALLA
#################################################

$F->PAUSE(

    "TAKAYA TEST POINT V04\n\n" .

    "SUCCESS\n\n" .

    "Filtro aplicado correctamente.\n\n" .

    "Test Points reasignados.\n\n" .

    "Solo los pads R12.12\n" .

    "contienen el atributo\n" .

    ".test_point"

);

exit 0;
