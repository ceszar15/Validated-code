#!perl -w

##############################################################################
# Script : T019_sr_tab_add.pl
#
# Objetivo:
#   Crear un Step Repeat utilizando
#   la tabla SR de Valor.
#
# Validado:
#   Valor NPI 25.1
#
# Resultado esperado:
#
#       2 boards colocadas
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

# Crear una línea dentro de la tabla SR
$F->COM(

    # Comando descubierto durante la investigación
    "sr_tab_add",

    # Número de línea dentro de la tabla
    line  => 1,

    # STEP origen que será repetido
    step  => "stp",

    # Posición inicial del SR
    x     => 0,
    y     => 0,

    # Número de repeticiones en X
    nx    => 2,

    # Número de repeticiones en Y
    ny    => 1,

    # Pitch horizontal
    dx    => 3.6382,

    # Pitch vertical
    dy    => 0,

    # Rotación de las copias
    angle => 0,

    # No reflejar geometría
    flip  => "no"
);

# Mostrar estado del comando ejecutado
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
# PCB     PCB
#
##############################################################################
