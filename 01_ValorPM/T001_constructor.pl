#!perl -w

##############################################################################
# Script : T001_constructor.pl
#
# Objetivo:
#   Validar la carga de la librería Valor.pm
#   y la creación de un objeto Valor.
#
# Validado:
#   Valor NPI 25.1
#
# Resultado esperado:
#   Aparece una ventana con:
#
#       Valor OK
#
##############################################################################

# Obliga a declarar todas las variables antes de usarlas
use strict;

# Activa mensajes de advertencia de Perl
use warnings;

# Carga la API principal de Valor
use Valor;

# Crea una instancia del objeto Valor
my $F = new Valor;

# Muestra una ventana de pausa dentro de Valor
# para confirmar que la librería fue cargada correctamente
$F->PAUSE(
    "Valor OK"
);
