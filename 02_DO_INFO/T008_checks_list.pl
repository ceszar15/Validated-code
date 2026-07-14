#!perl -w

##############################################################################
# Script : T008_checks_list.pl
#
# Objetivo:
#   Obtener la lista completa de Checks
#   pertenecientes al STEP actual.
#
# Validado:
#   Valor NPI 25.1
#
# Resultado esperado:
#
#   Lista de Checks del STEP.
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
# todos los Checks del STEP actual
$F->DO_INFO(
    "-t step -e $ENV{JOB}/$ENV{STEP} -d CHECKS_LIST"
);

# Convierte el arreglo de Checks
# en texto separado por líneas
my $msg =
join(
    "\n",
    @{$F->{doinfo}{gCHECKS_LIST}}
);

# Muestra el resultado
$F->PAUSE($msg);
