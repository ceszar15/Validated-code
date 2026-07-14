#!perl -w

##############################################################################
# Script : T003_get_select_count.pl
#
# Objetivo:
#   Obtener la cantidad de entidades seleccionadas
#   en el editor de Valor.
#
# Validado:
#   Valor NPI 25.1
#
# Resultado esperado:
#
#   Selected = X
#
# Donde X es el número de entidades seleccionadas.
#
##############################################################################

# Obliga a declarar variables antes de utilizarlas
use strict;

# Activa mensajes de advertencia de Perl
use warnings;

# Carga la API principal de Valor
use Valor;

# Crea una instancia del objeto Valor
my $F = new Valor;

# Ejecuta el comando nativo de Valor
# que devuelve la cantidad de elementos seleccionados
$F->COM("get_select_count");

# COMANS contiene la respuesta del último comando COM ejecutado
$F->PAUSE(
    "Selected = $F->{COMANS}"
);
