#!perl -w

# Obliga a declarar variables antes de utilizarlas
use strict;

# Activa advertencias durante la ejecución
use warnings;

# Ruta de librerías corporativas de Valor
use lib "V:/vNPI_DIR/sys/scripts/jabil/perl/lib";

# Librería principal de Valor
use Valor;

# Librería de utilidades de Valor
use Valor_util;

# Objeto principal para COM, DO_INFO y PAUSE
my $F = new Valor;

# Objeto auxiliar con funciones de Valor_util
my $v = new Valor_util();

# JOB actualmente abierto
my $job  = $ENV{JOB}  || "";

# STEP actualmente abierto
my $step = $ENV{STEP} || "";

# Geometría que debe conservar el atributo .test_point
my $target_symbol = "r12.12";

# Verifica que exista un JOB y STEP válidos
if ($job eq "" || $step eq "")
{
    $F->PAUSE(
        "ERROR: JOB o STEP no estan definidos"
    );

    exit 1;
}

#################################################
# ENCABEZADO DE EJECUCIÓN
#################################################

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

# Solicita a Valor la lista completa de layers
$F->DO_INFO(
    "-t step -e $job/$step -d LAYERS_LIST"
);

# Referencia a las layers encontradas
my $layers_ref =
$F->{doinfo}{gLAYERS_LIST};

# Valida que el resultado sea un ARRAY
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

# Elimina valores vacíos o inválidos
my @layers =
grep {
    defined($_)
    &&
    $_ ne ""
}
@{$layers_ref};

# El STEP debe contener al menos una layer
if (!@layers)
{
    $F->PAUSE(
        "ERROR: No se encontraron layers"
    );

    exit 1;
}

#################################################
# CONTADORES DE REPORTE
#################################################

# Layers revisadas durante la fase 2
my $scanned_layers  = 0;

# Layers donde se agregó .test_point
my $modified_layers = 0;

# Pads r12.12 actualizados
my $updated_pads    = 0;

# Pads revisados durante la limpieza
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

    # Activa la layer actual
    $v->setWorkLayer($layer);

    # Limpia filtros anteriores
    $v->resetFilter();

    # Limpia cualquier selección existente
    $F->COM("sel_clear_feat");

    #################################################
    # SELECCIONAR TODOS LOS PADS
    #################################################

    $F->COM(
        "sel_multi_feat",

        # Seleccionar features
        operation  => "select",

        # Solo pads
        feat_types => "pad",

        # Sin tolerancia de expansión
        resize_by  => 0
    );

    # Obtiene cantidad de pads seleccionados
    my $count =
    $v->getSelectedCount();

    # Protección contra undef
    $count = 0
        unless defined $count;

    # Acumula pads revisados
    $reviewed_pads += $count;

    print "PAD_COUNT=$count\n";

    # Si no hay pads, continuar
    if ($count < 1)
    {
        $F->COM("sel_clear_feat");
        next;
    }

    #################################################
    # ELIMINAR ATRIBUTO .test_point
    #################################################

    $F->COM(
        "sel_delete_atr",

        # Atributo a eliminar
        attributes => ".test_point;",

        # No modificar package attributes
        pkg_attr   => "no"
    );

    # Limpia selección actual
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
    # Incrementa contador de layers revisadas
    $scanned_layers++;

    print "\n";
    print "----------------------------------------\n";
    print "LAYER=$layer\n";

    # Activa la layer actual
    $v->setWorkLayer($layer);

    # Limpia filtros anteriores
    $v->resetFilter();

    # Limpia selecciones previas
    $F->COM("sel_clear_feat");

    #################################################
    # SELECCIONAR SOLO PADS R12.12
    #################################################

    $F->COM(
        "sel_multi_feat",
        operation    => "select",
        feat_types   => "pad",
        resize_by    => 0,

        # Filtra únicamente geometría r12.12
        include_syms => $target_symbol
    );

    # Obtiene cantidad de pads encontrados
    my $selected_count =
    $v->getSelectedCount();

    # Protección contra undef
    $selected_count = 0
        unless defined $selected_count;

    print "R12_12_PAD_COUNT=$selected_count\n";

    # Si la layer no contiene r12.12
    if ($selected_count < 1)
    {
        print "STATUS=SKIP_NO_MATCHES\n";

        $F->COM("sel_clear_feat");

        next;
    }

    #################################################
    # CONFIGURAR ATRIBUTO TEST POINT
    #################################################

    # Define .test_point como atributo actual
    $F->COM(
        "cur_atr_set",
        attribute => ".test_point"
    );

    #################################################
    # APLICAR .test_point A LA SELECCIÓN
    #################################################

    $F->COM(
        "sel_change_atr",

        # Agregar atributo
        mode     => "add",

        # No modificar atributos de package
        pkg_attr => "no"
    );

    # Registra modificación de layer
    $modified_layers++;

    # Acumula pads actualizados
    $updated_pads += $selected_count;

    print "STATUS=TEST_POINT_ADDED\n";
    print "UPDATED_IN_LAYER=$selected_count\n";

    # Limpia selección antes de cambiar de layer
    $F->COM("sel_clear_feat");
}

#################################################
# LIMPIEZA FINAL
#################################################

# Garantiza que no quede ninguna selección activa
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

# Estadísticas de revisión
print "LAYERS_REVISADAS=$scanned_layers\n";
print "LAYERS_MODIFICADAS=$modified_layers\n";

print "\n";

# Estadísticas de pads
print "PADS_REVISADOS=$reviewed_pads\n";
print "PADS_R12_12=$updated_pads\n";

print "\n";

# Resultado de la operación
print "TEST_POINTS_ELIMINADOS=TODOS\n";
print "TEST_POINTS_AGREGADOS=$updated_pads\n";

print "\n";

print "RESULTADO=SUCCESS\n";
print "========================================\n";

#################################################
# REPORTE FINAL AL USUARIO
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

# Fin del programa
exit 0;
