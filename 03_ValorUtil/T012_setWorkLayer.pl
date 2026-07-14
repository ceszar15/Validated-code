#!perl -w

##############################################################################
# Script : T012_setWorkLayer.pl
#
# Objetivo:
#   Cambiar automáticamente la Layer activa
#   utilizando la función setWorkLayer().
#
# Validado:
#   Valor NPI 25.1
#
# Resultado esperado:
#
#       Layer = smt
#
##############################################################################

# Obliga a declarar variables antes de utilizarlas
use strict;

# Activa mensajes de advertencia
use warnings;

# Carga la librería auxiliar de Jabil
use Valor_util;

##############################################################################
# IMPORTANTE
#
# Funciona:
#
#     my $v = new Valor_util();
#
# No usar:
#
#     my $v = new Valor_util(
#         rcom => 1
#     );
#
# Porque genera errores #BUSY
# en Valor NPI 25.1.
#
##############################################################################

# Crear objeto Valor_util
my $v = new Valor_util();

# Cambiar la Layer activa a "smt"
$v->setWorkLayer("smt");

# Validar la Layer activa mediante un comando nativo
$v->{F}->COM("get_work_layer");

# Mostrar el resultado devuelto por Valor
$v->{F}->PAUSE(

    "Layer = " .

    $v->{F}->{COMANS}

);
