#!perl -w

##############################################################################
# Script : T013_resetFilter.pl
#
# Objetivo:
#   Limpiar completamente el filtro activo
#   utilizando la función resetFilter().
#
# Validado:
#   Valor NPI 25.1
#
# Resultado esperado:
#
#       resetFilter OK
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

# Limpiar completamente el filtro popup
# utilizado por Valor
$v->resetFilter();

# Mostrar confirmación
$v->{F}->PAUSE(

    "resetFilter OK"

);
