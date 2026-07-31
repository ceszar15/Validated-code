#!perl -w

# Obliga a declarar variables antes de utilizarlas
use strict;

# Activa advertencias durante la ejecución
use warnings;

# Ruta de librerías corporativas para Valor NPI
use lib "V:/vNPI_DIR/sys/scripts/jabil/perl/lib";

# Librería principal de Valor
use Valor;

# Librería de utilidades de Valor
use Valor_util;

# Objeto principal para COM, DO_INFO y PAUSE
my $F = new Valor;

# Objeto auxiliar con funciones utilitarias
my $v = new Valor_util();

# Obtiene el JOB actualmente abierto
my $job = $ENV{JOB} || "";

# Obtiene el STEP actualmente abierto
my $step = $ENV{STEP} || "";

# Símbolo utilizado para identificar Test Points Takaya
my $target_symbol = "r12.12";

# Verifica que exista un JOB y STEP abiertos
if ($job eq "" || $step eq "") {

    $F->PAUSE(
        "ERROR: JOB o STEP no estan definidos"
    );

    exit 1;
}

#################################################
# ENCABEZADO DE EJECUCIÓN
#################################################

print "\n";
print "========================================\n";
print "TAKAYA ATTRIBUTES ALL LAYERS V03\n";
print "========================================\n";
print "JOB=$job\n";
print "STEP=$step\n";
print "TARGET_FEATURE_TYPE=pad\n";
print "TARGET_SYMBOL=$target_symbol\n";
print "SCOPE=ALL_LAYERS_IN_CURRENT_STEP\n";
print "========================================\n";

#################################################
# OBTENER TODAS LAS LAYERS DEL STEP
#################################################

# Solicita la lista de layers pertenecientes
# al STEP actual
$F->DO_INFO(
    "-t step -e $job/$step -d LAYERS_LIST"
);

# Referencia al resultado devuelto por DO_INFO
my $layers_ref = $F->{doinfo}{gLAYERS_LIST};

# Valida que el resultado sea un ARRAY
if (!defined($layers_ref) || ref($layers_ref) ne "ARRAY") {

    $F->PAUSE(
        "ERROR: LAYERS_LIST no devolvio un ARRAY"
    );

    exit 1;
}

# Elimina entradas vacías o inválidas
my @layers = grep {
    defined($_) && $_ ne ""
} @{$layers_ref};

# Debe existir al menos una layer
if (!@layers) {

    $F->PAUSE(
        "ERROR: No se encontraron layers en el step actual"
    );

    exit 1;
}

#################################################
# CONTADORES DE REPORTE
#################################################

# Cantidad total de layers revisadas
my $scanned_layers = 0;

# Cantidad de layers modificadas
my $modified_layers = 0;

# Cantidad total de pads actualizados
my $updated_pads = 0;

#################################################
# RECORRER TODAS LAS LAYERS DEL STEP
#################################################

foreach my $layer (@layers) {

    # Incrementa contador de layers revisadas
    $scanned_layers++;

    print "\n";
    print "----------------------------------------\n";
    print "LAYER=$layer\n";

    # Convierte la layer actual en Work Layer
    $v->setWorkLayer($layer);

    # Limpia cualquier filtro existente
    $v->resetFilter();

    # Limpia selecciones anteriores
    $F->COM("sel_clear_feat");

    #################################################
    # SELECCIONAR TODOS LOS PADS r12.12
    #################################################

    $F->COM(
        "sel_multi_feat",

        # Seleccionar features
        operation => "select",

        # Solo entities tipo PAD
        feat_types => "pad",

        # Sin tolerancia de expansión
        resize_by => 0,

        # Filtrar únicamente símbolo r12.12
        include_syms => $target_symbol
    );

    # Obtener cantidad de pads encontrados
    my $selected_count =
        $v->getSelectedCount();

    # Protección contra valores indefinidos
    $selected_count = 0
        unless defined $selected_count;

    print "R12_12_PAD_COUNT=$selected_count\n";

    # Si la layer no contiene r12.12
    # continuar con la siguiente
    if ($selected_count < 1) {

        print "STATUS=SKIP_NO_MATCHES\n";

        next;
    }

    #################################################
    # CONFIGURACIÓN DE ATRIBUTOS TAKAYA
    #################################################

    # Configura atributo Test Point
    $F->COM(
        "cur_atr_set",
        attribute => ".test_point"
    );

    # Configura altura de componente
    $F->COM(
        "cur_atr_set",
        attribute => ".comp_height",
        float => 0
    );

    # Configura uso Takaya
    $F->COM(
        "cur_atr_set",
        attribute => ".pad_usage",
        option => "toeprint"
    );

    #################################################
    # APLICAR ATRIBUTOS
    #################################################

    $F->COM(
        "sel_change_atr",

        # Agregar atributos
        mode => "add",

        # No modificar package attributes
        pkg_attr => "no"
    );

    # Registrar modificación de layer
    $modified_layers++;

    # Acumular pads actualizados
    $updated_pads += $selected_count;

    print "STATUS=ATTRIBUTES_ADDED\n";
    print "UPDATED_IN_LAYER=$selected_count\n";

    # Limpiar selección antes de cambiar de layer
    $F->COM("sel_clear_feat");
}

#################################################
# LIMPIEZA FINAL
#################################################

# Garantiza que no quede ninguna selección activa
$F->COM("sel_clear_feat");

#################################################
# REPORTE FINAL
#################################################

print "\n";
print "========================================\n";
print "FINAL RESULT\n";
print "========================================\n";

print "SCANNED_LAYERS=$scanned_layers\n";
print "MODIFIED_LAYERS=$modified_layers\n";
print "UPDATED_PADS=$updated_pads\n";

print "ATTRIBUTE_1=.test_point\n";
print "ATTRIBUTE_2=.comp_height FLOAT=0\n";
print "ATTRIBUTE_3=.pad_usage OPTION=toeprint\n";

#################################################
# CASO SIN COINCIDENCIAS
#################################################

if ($updated_pads < 1) {

    print "RESULT=NO_R12_12_PADS_FOUND\n";

    $F->PAUSE(
        "No se encontraron pads con symbol r12.12.\n\n" .
        "Layers revisadas: $scanned_layers\n" .
        "No se modifico ningun feature."
    );

    exit 0;
}

#################################################
# CASO EXITOSO
#################################################

print "RESULT=ATTRIBUTES_ADDED\n";

$F->PAUSE(
    "Atributos Takaya agregados en todas las layers del step.\n\n" .
    "Layers revisadas: $scanned_layers\n" .
    "Layers modificadas: $modified_layers\n" .
    "Pads r12.12 actualizados: $updated_pads\n\n" .
    "Atributos:\n" .
    ".test_point\n" .
    ".comp_height = 0\n" .
    ".pad_usage = toeprint\n\n" .
    "VALIDACION: revisa una muestra en cada layer modificada."
);

# Fin del programa
exit 0;
