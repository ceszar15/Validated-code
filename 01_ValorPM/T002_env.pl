#!perl -w

##############################################################################
# Script : T002_env.pl
#
# Objetivo:
#   Validar el acceso a las variables de entorno
#   JOB y STEP proporcionadas por Valor.
#
# Validado:
#   Valor NPI 25.1
#
# Resultado esperado:
#
#   JOB=<nombre_job>
#   STEP=<nombre_step>
#
##############################################################################

# Obliga a declarar variables antes de utilizarlas
use strict;

# Activa advertencias de Perl
use warnings;

# Carga la API principal de Valor
use Valor;

# Crea una instancia del objeto Valor
my $F = new Valor;

# Muestra las variables de entorno actuales
# proporcionadas por Valor
$F->PAUSE(

    "JOB=$ENV{JOB}\n" .

    "STEP=$ENV{STEP}"

);
