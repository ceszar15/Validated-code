#!perl -w

##############################################################################
# Script : T004_get_work_layer.pl
#
# Objetivo:
#   Obtener el Work Layer actualmente activo
#   dentro del editor de Valor.
#
# Validado:
#   Valor NPI 25.1
#
# Resultado esperado:
#
#   Layer = <nombre_layer>
#
##############################################################################

# Obliga a declarar todas las variables
use strict;

# Activa advertencias de Perl
use warnings;

# Carga la API principal de Valor
use Valor;

# Crea una instancia del objeto Valor
my $F = new Valor;

# Ejecuta el comando nativo de Valor
# para obtener la capa activa
$F->COM("get_work_layer");

# COMANS contiene la respuesta devuelta
# por el último comando COM ejecutado
$F->PAUSE(
    "Layer = $F->{COMANS}"
);
