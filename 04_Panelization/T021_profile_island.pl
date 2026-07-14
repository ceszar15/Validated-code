#!perl -w

##############################################################################
# Script : T021_profile_island.pl
#
# Objetivo:
#   Crear un Profile Island utilizando
#   la geometría actualmente seleccionada.
#
# Validado:
#   Valor NPI 25.1
#
# Requisito:
#
#   Debe existir una selección activa
#   antes de ejecutar el script.
#
# Resultado esperado:
#
#       Profile Island creado
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

##############################################################################
# Configurar modo de creación de Profile
##############################################################################

$F->COM(

    # Comando de configuración
    "profile_mode",

    # Crear Profile principal
    add_island => "no",

    # No utilizar Layer completa
    is_layer   => "no",

    # Trabajar sobre la selección actual
    layer      => ""

);

##############################################################################
# Crear Profile a partir de la selección
##############################################################################

$F->COM(

    "sel_create_profile"

);

##############################################################################
# Mostrar resultado
##############################################################################

$F->PAUSE(

    "STATUS = $F->{STATUS}"

);

##############################################################################
# Flujo validado
#
# Seleccionar contorno
# ↓
# Edit
# ↓
# Create
# ↓
# Profile Island
#
# Valor genera:
#
# profile_mode
# sel_create_profile
#
##############################################################################
