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

if ($job eq "" || $step eq "") {
    $F->PAUSE("ERROR: JOB o STEP no estan definidos");
    exit 1;
}

print "\n";
print "========================================\n";
print "TAKAYA ATTRIBUTES ALL LAYERS V03\n";
print "========================================\n";
print "JOB=$job\n";
print "STEP=$step\n";
print "TARGET_FEATURE_TYPE=pad\n";
print "TARGET_SYMBOL=$target_symbol\n";
print "SCOPE=ALL_LAYERS_IN_CURRENT_STEP\n";
print "========================================\n";

#################################################
# OBTENER TODAS LAS LAYERS DEL STEP ACTUAL
#################################################

$F->DO_INFO(
    "-t step -e $job/$step -d LAYERS_LIST"
);

my $layers_ref = $F->{doinfo}{gLAYERS_LIST};

if (!defined($layers_ref) || ref($layers_ref) ne "ARRAY") {
    $F->PAUSE("ERROR: LAYERS_LIST no devolvio un ARRAY");
    exit 1;
}

my @layers = grep {
    defined($_) && $_ ne ""
} @{$layers_ref};

if (!@layers) {
    $F->PAUSE("ERROR: No se encontraron layers en el step actual");
    exit 1;
}

my $scanned_layers  = 0;
my $modified_layers = 0;
my $updated_pads    = 0;

#################################################
# RECORRER TODAS LAS LAYERS
#################################################

foreach my $layer (@layers) {

    $scanned_layers++;

    print "\n";
    print "----------------------------------------\n";
    print "LAYER=$layer\n";

    $v->setWorkLayer($layer);
    $v->resetFilter();

    $F->COM("sel_clear_feat");

    #################################################
    # SELECCIONAR SOLO PADS CON SYMBOL r12.12
    # EN LA LAYER ACTUAL
    #################################################

    $F->COM(
        "sel_multi_feat",
        operation    => "select",
        feat_types   => "pad",
        resize_by    => 0,
        include_syms => $target_symbol
    );

    my $selected_count = $v->getSelectedCount();
    $selected_count = 0 unless defined $selected_count;

    print "R12_12_PAD_COUNT=$selected_count\n";

    if ($selected_count < 1) {
        print "STATUS=SKIP_NO_MATCHES\n";
        next;
    }

    #################################################
    # CONFIGURAR LOS TRES ATRIBUTOS TAKAYA
    #################################################

    $F->COM(
        "cur_atr_set",
        attribute => ".test_point"
    );

    $F->COM(
        "cur_atr_set",
        attribute => ".comp_height",
        float     => 0
    );

    $F->COM(
        "cur_atr_set",
        attribute => ".pad_usage",
        option    => "toeprint"
    );

    #################################################
    # AGREGAR ATRIBUTOS A LA SELECCION
    #################################################

    $F->COM(
        "sel_change_atr",
        mode     => "add",
        pkg_attr => "no"
    );

    $modified_layers++;
    $updated_pads += $selected_count;

    print "STATUS=ATTRIBUTES_ADDED\n";
    print "UPDATED_IN_LAYER=$selected_count\n";

    $F->COM("sel_clear_feat");
}

#################################################
# LIMPIEZA Y RESULTADO
#################################################

$F->COM("sel_clear_feat");

print "\n";
print "========================================\n";
print "FINAL RESULT\n";
print "========================================\n";
print "SCANNED_LAYERS=$scanned_layers\n";
print "MODIFIED_LAYERS=$modified_layers\n";
print "UPDATED_PADS=$updated_pads\n";
print "ATTRIBUTE_1=.test_point\n";
print "ATTRIBUTE_2=.comp_height FLOAT=0\n";
print "ATTRIBUTE_3=.pad_usage OPTION=toeprint\n";

if ($updated_pads < 1) {
    print "RESULT=NO_R12_12_PADS_FOUND\n";

    $F->PAUSE(
        "No se encontraron pads con symbol r12.12.\n\n" .
        "Layers revisadas: $scanned_layers\n" .
        "No se modifico ningun feature."
    );

    exit 0;
}

print "RESULT=ATTRIBUTES_ADDED\n";

$F->PAUSE(
    "Atributos Takaya agregados en todas las layers del step.\n\n" .
    "Layers revisadas: $scanned_layers\n" .
    "Layers modificadas: $modified_layers\n" .
    "Pads r12.12 actualizados: $updated_pads\n\n" .
    "Atributos:\n" .
    ".test_point\n" .
    ".comp_height = 0\n" .
    ".pad_usage = toeprint\n\n" .
    "VALIDACION: revisa una muestra en cada layer modificada."
);

exit 0;
