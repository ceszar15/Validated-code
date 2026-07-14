#!perl -w

##############################################################################
# Script : T017_create_entity.pl
#
# Objetivo:
#   Crear un nuevo STEP dentro del JOB actual.
#
# Validado:
#   Valor NPI 25.1
#
# Resultado esperado:
#
#   Se crea un STEP llamado:
#
#       panel_auto
#
##############################################################################

# Obliga a declarar variables antes de utilizarlas
use strict;

# Activa mensajes de advertencia
use warnings;

# Carga la API principal de Valor
use Valor;

# Crea instancia principal de Valor
my $F = new Valor;

# Ejecuta el comando create_entity
# para crear un nuevo STEP
$F->COM(

    # Comando nativo de Valor
    "create_entity",

    # Job actual
    job  => $ENV{JOB},

    # Tipo de entidad a crear
    type => "step",

    # Nombre del STEP nuevo
    name => "panel_auto"
);

# Muestra estado final del comando
$F->PAUSE(

    "STATUS = $F->{STATUS}"

);
