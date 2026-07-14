#!perl -w

##############################################################################
# Script : T007_nets_list.pl
#
# Objetivo:
#   Obtener la lista completa de Nets
#   pertenecientes al STEP actual.
#
# Validado:
#   Valor NPI 25.1
#
# Resultado esperado:
#
#   Lista de Nets del STEP.
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
# todas las Nets del STEP actual
$F->DO_INFO(
    "-t step -e $ENV{JOB}/$ENV{STEP} -d NETS_LIST"
);

# Convierte el arreglo de Nets
# en texto separado por líneas
my $msg =
join(
    "\n",
    @{$F->{doinfo}{gNETS_LIST}}
);

# Muestra el resultado
$F->PAUSE($msg);
