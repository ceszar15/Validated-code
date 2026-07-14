#!perl -w

##############################################################################
# Script : T009_prof_limits.pl
#
# Objetivo:
#   Obtener los límites geométricos del Profile
#   del STEP actual.
#
# Validado:
#   Valor NPI 25.1
#
# Resultado esperado:
#
#   xmin = ...
#   xmax = ...
#   ymin = ...
#   ymax = ...
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

# Recupera los límites del profile
$F->DO_INFO(
    "-t step -e $ENV{JOB}/$ENV{STEP} -d PROF_LIMITS"
);

# Muestra los valores obtenidos
$F->PAUSE(

    "xmin = " .
    $F->{doinfo}{gPROF_LIMITSxmin} . "\n" .

    "xmax = " .
    $F->{doinfo}{gPROF_LIMITSxmax} . "\n" .

    "ymin = " .
    $F->{doinfo}{gPROF_LIMITSymin} . "\n" .

    "ymax = " .
    $F->{doinfo}{gPROF_LIMITSymax}

);
