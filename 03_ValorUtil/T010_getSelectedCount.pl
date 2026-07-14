#!perl -w

##############################################################################
# Script : T010_getSelectedCount.pl
#
# Objetivo:
#   Obtener la cantidad de entidades seleccionadas
#   utilizando la función getSelectedCount()
#   de Valor_util.pm
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
# Porque en Valor NPI 25.1 genera errores #BUSY.
#
##############################################################################

# Crear objeto Valor_util
my $v = new Valor_util();

# Obtener cantidad de entidades seleccionadas
my $count =
$v->getSelectedCount();

# Mostrar resultado
$v->{F}->PAUSE(
    "Selected = $count"
);
