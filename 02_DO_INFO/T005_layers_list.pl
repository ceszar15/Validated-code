#!perl -w

##############################################################################
# Script : T005_layers_list.pl
#
# Objetivo:
#   Obtener la lista completa de Layers
#   pertenecientes al STEP actual.
#
# Validado:
#   Valor NPI 25.1
#
# Resultado esperado:
#
#   Lista de Layers del STEP.
#
##############################################################################

# Obliga a declarar variables antes de utilizarlas
use strict;

# Activa mensajes de advertencia
use warnings;

# Carga la API principal de Valor
use Valor;

# Crea una instancia del objeto Valor
my $F = new Valor;

# Ejecuta DO_INFO para recuperar
# todas las capas del STEP actual
$F->DO_INFO(
    "-t step -e $ENV{JOB}/$ENV{STEP} -d LAYERS_LIST"
);

# Convierte el arreglo de layers
# en un texto separado por líneas
my $msg =
join(
    "\n",
    @{$F->{doinfo}{gLAYERS_LIST}}
);

# Muestra el resultado
$F->PAUSE($msg);
