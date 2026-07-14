#!perl -w

##############################################################################
# Script : T018_open_entity.pl
#
# Objetivo:
#   Abrir automáticamente un STEP utilizando
#   el comando open_entity.
#
# Validado:
#   Valor NPI 25.1
#
# Resultado esperado:
#
#       STEP abierto correctamente
#
#       STATUS = 0
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

# Abrir STEP existente
$F->COM(

    # Comando nativo de Valor
    "open_entity",

    # Job actual
    job    => $ENV{JOB},

    # Tipo de entidad
    type   => "step",

    # Nombre del STEP a abrir
    name   => "panel_auto",

    # Abrir editor gráfico
    iconic => "no"
);

# Mostrar resultado de la operación
$F->PAUSE(

    "STATUS = $F->{STATUS}\n" .

    "COMANS = $F->{COMANS}"

);

##############################################################################
# Resultado validado:
#
# STATUS = 0
#
# Graphic Station:
#
# [Step: panel_auto]
#
##############################################################################
