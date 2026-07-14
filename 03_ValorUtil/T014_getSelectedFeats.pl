#!perl -w

##############################################################################
# Script : T014_getSelectedFeats.pl
#
# Objetivo:
#   Recuperar las Features seleccionadas
#   de una Layer específica utilizando
#   getSelectedFeats().
#
# Validado:
#   Valor NPI 25.1
#
# Resultado esperado:
#
#       Features = X
#
# Donde X es la cantidad de Features
# recuperadas.
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

# Recuperar las Features seleccionadas
# de la Layer "smt"
my @feat =
$v->getSelectedFeats("smt");

# Obtener la cantidad de Features recuperadas
my $count =
scalar(@feat);

# Mostrar resultado
$v->{F}->PAUSE(

    "Features = $count"

);

##############################################################################
# Ejemplo de información disponible
#
# #P 0.2755524 0.3523622 r45 P 0 0 N 433;
#
# Net=POS3V3
#
# COMP=J5
#
# PIN=P2_8
#
# PIN_TYPE=UT
#
# geometry=045RD0295NT_TOL
#
# pad_usage=toeprint
#
##############################################################################
