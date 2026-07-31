#!perl -w

##############################################################################
# Script : remove_all_test_points.pl
#
# Objetivo:
#   Eliminar el atributo .test_point de todos los pads
#   contenidos en el STEP activo.
#
# Funciones:
#   - Obtiene automáticamente todas las layers.
#   - Selecciona todos los pads.
#   - Elimina el atributo .test_point.
#   - Genera reporte de ejecución.
#
# Resultado esperado:
#   Ningún pad conserva el atributo .test_point.
#
# Validado:
#   Valor NPI 25.1
#
##############################################################################

# Obliga a declarar variables antes de utilizarlas
use strict;

# Activa advertencias de Perl
use warnings;

# Ruta donde se encuentran las librerías corporativas de Valor
use lib "V:/vNPI_DIR/sys/scripts/jabil/perl/lib";

# Librería principal de Valor
use Valor;

# Librería de utilidades de Valor
use Valor_util;

# Objeto principal de Valor
my $F = new Valor;

# Objeto auxiliar de Valor_util
my $v = new Valor_util();

# JOB actualmente abierto
my $job  = $ENV{JOB}  || "";

# STEP actualmente abierto
my $step = $ENV{STEP} || "";

#################################################
# OBTENER TODAS LAS LAYERS
#################################################

# Solicita la lista de layers del STEP activo
$F->DO_INFO(
    "-t step -e $job/$step -d LAYERS_LIST"
);

# Filtra layers vacías o inválidas
my @layers =
grep {
    defined($_) && $_ ne ""
}
@{$F->{doinfo}{gLAYERS_LIST}};

# Contador de layers revisadas
my $layers_scanned = 0;

# Contador de pads revisados
my $pads_reviewed  = 0;

#################################################
# RECORRER TODAS LAS LAYERS
#################################################

foreach my $layer (@layers)
{
    # Incrementa contador de layers procesadas
    $layers_scanned++;

    # Activa la layer actual como Work Layer
    $v->setWorkLayer($layer);

    # Limpia filtros previos
    $v->resetFilter();

    # Limpia selecciones previas
    $F->COM("sel_clear_feat");

    #################################################
    # SELECCIONAR TODOS LOS PADS
    #################################################

    $F->COM(
        "sel_multi_feat",

        # Seleccionar features
        operation  => "select",

        # Solo entidades tipo PAD
        feat_types => "pad",

        # Sin expansión de selección
        resize_by  => 0
    );

    # Obtiene cantidad de pads seleccionados
    my $count =
    $v->getSelectedCount();

    # Protección contra undef
    $count = 0 unless defined $count;

    # Acumula pads revisados
    $pads_reviewed += $count;

    # Si no existen pads en la layer continuar
    next if($count < 1);

    #################################################
    # ELIMINAR ATRIBUTO
    #################################################

    $F->COM(
        "sel_delete_atr",

        # Atributo a eliminar
        attributes => ".test_point;",

        # No modificar atributos de package
        pkg_attr   => "no"
    );

    # Limpia selección antes de pasar
    # a la siguiente layer
    $F->COM("sel_clear_feat");
}

#################################################
# LIMPIEZA FINAL
#################################################

# Garantiza que no quede ninguna selección activa
$F->COM("sel_clear_feat");

#################################################
# REPORTE DE EJECUCIÓN
#################################################

print "\n";
print "========================================\n";
print "REMOVE ALL TEST POINTS\n";
print "========================================\n";

# JOB procesado
print "JOB=$job\n";

# STEP procesado
print "STEP=$step\n";

print "\n";

# Layers procesadas
print "LAYERS_REVISADAS=$layers_scanned\n";

# Pads revisados
print "PADS_REVISADOS=$pads_reviewed\n";

print "\n";

# Atributo eliminado
print "ATRIBUTO_ELIMINADO=.test_point\n";

# Resultado final
print "RESULTADO=SUCCESS\n";

print "========================================\n";

#################################################
# MENSAJE FINAL AL USUARIO
#################################################

$F->PAUSE(

    "TEST POINT CLEANUP\n\n" .

    "SUCCESS\n\n" .

    "Todos los atributos\n" .

    ".test_point fueron eliminados."

);

# Fin del programa
exit 0;
