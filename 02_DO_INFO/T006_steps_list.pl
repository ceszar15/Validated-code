#!perl -w

##############################################################################
# Script : T006_steps_list.pl
#
# Objetivo:
#   Obtener la lista completa de STEPs
#   pertenecientes al JOB actual.
#
# Validado:
#   Valor NPI 25.1
#
# Resultado esperado:
#
#   Lista de STEPs del JOB.
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
# todos los STEPs del JOB actual
$F->DO_INFO(
    "-t job -e $ENV{JOB} -d STEPS_LIST"
);

# Convierte el arreglo de STEPs
# en texto separado por líneas
my $msg =
join(
    "\n",
    @{$F->{doinfo}{gSTEPS_LIST}}
);

# Muestra los resultados
$F->PAUSE($msg);
