#!perl -w

##############################################################################
# Script : T011_getLayerByFilter.pl
#
# Objetivo:
#   Localizar automáticamente una Layer utilizando
#   filtros semánticos de Valor.
#
# Validado:
#   Valor NPI 25.1
#
# Resultado esperado:
#
#       Top Mask = smt
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

# Buscar automáticamente la Layer
# correspondiente al Solder Mask Top
my $topmask =
$v->getLayerByFilter(

    # Tipo de capa
    "type=solder_mask" .

    # Contexto PCB
    "&context=board" .

    # Lado superior
    "&side=top"
);

# Mostrar resultado obtenido
$v->{F}->PAUSE(

    "Top Mask = $topmask"

);
