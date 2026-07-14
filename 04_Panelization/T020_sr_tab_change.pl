#!perl -w

##############################################################################
# Script : T020_sr_tab_change.pl
#
# Objetivo:
#   Modificar una línea existente dentro
#   de la tabla Step Repeat.
#
# Validado:
#   Valor NPI 25.1
#
# Resultado esperado:
#
#       Cambio exitoso del Step Repeat
#
##############################################################################

# Obliga a declarar variables antes de utilizarlas
use strict;

# Activa mensajes de advertencia
use warnings;

# Carga la API principal de Valor
use Valor;

# Crear objeto principal Valor
my $F = new Valor;

# Modificar una línea existente
# de la tabla Step Repeat
$F->COM(

    # Comando descubierto durante la investigación
    "sr_tab_change",

    # Línea a modificar
    line  => 1,

    # STEP origen
    step  => "stp",

    # Posición inicial
    x     => 0,
    y     => 0,

    # Número de repeticiones horizontales
    nx    => 2,

    # Número de repeticiones verticales
    ny    => 1,

    # Nuevo pitch horizontal
    dx    => 4.5,

    # Pitch vertical
    dy    => 0,

    # Rotación
    angle => 0,

    # Sin espejo
    flip  => "no"
);

# Mostrar estado final del comando
$F->PAUSE(

    "STATUS = $F->{STATUS}"

);

##############################################################################
# Resultado validado:
#
# STATUS = 0
#
# Visual:
#
# PCB -------- PCB
#
# Cambio exitoso de separación
# entre boards.
#
##############################################################################
