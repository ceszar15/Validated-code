#!/usr/bin/perl

# Obliga a declarar variables antes de utilizarlas
use strict;

# Activa advertencias durante la ejecución
use warnings;

# Ruta donde se encuentran las librerías corporativas de Valor
use lib "V:/vNPI_DIR/sys/scripts/jabil/perl/lib";

# Librería principal de Valor
use Valor;

# Librería de utilidades de Valor
use Valor_util;

# Librería gráfica utilizada para la selección manual de capas
use Tk;

#################################################
# INICIALIZACIÓN DE OBJETOS
#################################################

# Objeto principal para COM, DO_INFO y PAUSE
my $F = new Valor;

# Objeto auxiliar de Valor_util
my $v = new Valor_util();

#################################################
# OBTENER JOB Y STEP ACTUALMENTE ACTIVOS
#################################################

# JOB actualmente abierto en la sesión
my $job  = $ENV{JOB}  || "";

# STEP actualmente abierto en la sesión
my $step = $ENV{STEP} || "";

# El script requiere un JOB y STEP válidos
if ($job eq "" || $step eq "")
{
    $F->PAUSE(
        "ERROR: JOB o STEP no estan definidos en la sesion actual."
    );

    exit 1;
}

#################################################
# OBTENER TODAS LAS LAYERS DEL STEP
#################################################

# Solicita la lista de layers del STEP activo
$F->DO_INFO(
    "-t step -e $job/$step -d LAYERS_LIST"
);

# Referencia al resultado devuelto por DO_INFO
my $layers_ref = $F->{doinfo}{gLAYERS_LIST};

# Verifica que LAYERS_LIST exista y contenga datos válidos
if (
    !defined($layers_ref)
    ||
    ref($layers_ref) ne "ARRAY"
    ||
    scalar(@{$layers_ref}) == 0
)
{
    $F->PAUSE(
        "ERROR: No se pudo obtener la lista de capas del Job."
    );

    exit 1;
}

# Copia todas las layers a un arreglo de trabajo
my @all_layers = @{$layers_ref};

############################################

#################################################
# INTERFAZ GRÁFICA DE SELECCIÓN
#
# Permite al usuario elegir:
#
#   1. Layer de cobre origen
#   2. Layer Drill de referencia
#   3. Layer Solder Paste
#
#################################################

# Valor inicial para Layer de Cobre
my $selected_copper = $default_copper;

# Valor inicial para Layer Drill
my $selected_drill  = $default_drill;

# Valor inicial para Layer Paste
my $selected_paste  = $default_paste;

# Bandera utilizada para detectar cancelación
my $user_cancelled  = 0;

#################################################
# CREAR VENTANA PRINCIPAL
#################################################

# Crear ventana Tk principal
my $mw = MainWindow->new;

# Título de la ventana
$mw->title(
    "Filtro TP + Validacion Paste - Valor NPI"
);

# Tamaño inicial de la ventana
$mw->geometry("460x320");

# Impide redimensionar la ventana
$mw->resizable(0, 0);

#################################################
# SELECCIÓN DE CAPA ORIGEN
#################################################

# Etiqueta descriptiva
$mw->Label(
    -text =>
    "1. Selecciona la LAYER ORIGEN (Cobre Top/Bottom):",
    -font => "Helvetica 9 bold"
)->pack(
    -anchor => 'w',
    -padx   => 15,
    -pady   => 3
);

# Lista desplegable con capas de cobre detectadas
$mw->Optionmenu(
    -options  => \@copper_layers,
    -variable => \$selected_copper,
)->pack(
    -fill => 'x',
    -padx => 15,
    -pady => 3
);

#################################################
# SELECCIÓN DE CAPA DRILL
#################################################

# Etiqueta descriptiva
$mw->Label(
    -text =>
    "2. Selecciona la LAYER DRILL (Referencia):",
    -font => "Helvetica 9 bold"
)->pack(
    -anchor => 'w',
    -padx   => 15,
    -pady   => 3
);

# Lista desplegable con capas Drill detectadas
$mw->Optionmenu(
    -options  => \@drill_layers,
    -variable => \$selected_drill,
)->pack(
    -fill => 'x',
    -padx => 15,
    -pady => 3
);

#################################################
# SELECCIÓN DE CAPA PASTE
#################################################

# Etiqueta descriptiva
$mw->Label(
    -text =>
    "3. Selecciona la LAYER SOLDER PASTE (Bot/Top):",
    -font => "Helvetica 9 bold"
)->pack(
    -anchor => 'w',
    -padx   => 15,
    -pady   => 3
);

# Lista desplegable con todas las layers disponibles
$mw->Optionmenu(
    -options  => \@all_layers,
    -variable => \$selected_paste,
)->pack(
    -fill => 'x',
    -padx => 15,
    -pady => 3
);

#################################################
# BOTONES DE CONTROL
#################################################

# Frame para contener botones
my $bf =
$mw->Frame()->pack(
    -fill => 'x',
    -pady => 15
);

#################################################
# BOTÓN PROCESAR
#
# Cierra la ventana y permite continuar
# con la ejecución del script.
#################################################

$bf->Button(
    -text    => " Procesar ",

    -command => sub {

        # Cerrar ventana
        $mw->destroy;
    }
)->pack(
    -side => 'left',
    -padx => 60
);

#################################################
# BOTÓN CANCELAR
#
# Marca operación cancelada por usuario
# y cierra la ventana.
#################################################

$bf->Button(
    -text    => "Cancelar",

    -command => sub {

        # Registrar cancelación
        $user_cancelled = 1;

        # Cerrar ventana
        $mw->destroy;
    }
)->pack(
    -side => 'right',
    -padx => 60
);

#################################################
# INICIAR INTERFAZ
#################################################

# Mantiene la ventana activa
# hasta que el usuario presione
# Procesar o Cancelar
MainLoop;

#################################################
# VERIFICAR CANCELACIÓN
#################################################

# Si el usuario canceló la operación
# finalizar sin modificar el JOB
if ($user_cancelled)
{
    print
    "STATUS: Operacion cancelada por el usuario.\n";

    exit 0;
}

#################################################
# GUARDAR SELECCIONES DEL USUARIO
#################################################

# Layer de cobre seleccionada
my $work_layer =
$selected_copper;

# Layer Drill seleccionada
my $drill_layer =
$selected_drill;

# Layer Paste seleccionada
my $paste_layer =
$selected_paste;

#################################################
# GENERAR NOMBRES DE CAPAS TEMPORALES
#################################################

my $temp_tp_layer  = "";
my $good_tp_layer  = "";
my $paste_tp_layer = "";

#################################################
# DETECTAR LADO TOP
#################################################

if ($work_layer =~ /top/i)
{
    $temp_tp_layer  = "tp-drill-top";
    $good_tp_layer  = "tp-good-top";
    $paste_tp_layer = "tp-paste-top";
}

#################################################
# DETECTAR LADO BOTTOM
#################################################

elsif ($work_layer =~ /bot/i)
{
    $temp_tp_layer  = "tp-drill-bot";
    $good_tp_layer  = "tp-good-bot";
    $paste_tp_layer = "tp-paste-bot";
}

#################################################
# CUALQUIER OTRO NOMBRE DE CAPA
#################################################

else
{
    $temp_tp_layer  = "tp-drill-" . $work_layer;
    $good_tp_layer  = "tp-good-" . $work_layer;
    $paste_tp_layer = "tp-paste-" . $work_layer;
}
#################################################
# REPORTE DE CONFIGURACIÓN
#
# Muestra las capas seleccionadas por el usuario
# y las capas temporales que serán utilizadas.
#################################################

print "\n========================================\n";
print "EXTRACCION Y VALIDACION DE TEST POINTS\n";
print "========================================\n";

print "JOB             = $job\n";
print "STEP            = $step\n";

print "LAYER ORIGEN    = $work_layer\n";
print "LAYER DRILL     = $drill_layer\n";
print "LAYER PASTE     = $paste_layer\n";

print "LAYER TEMP      = $temp_tp_layer\n";
print "LAYER PASTE TP  = $paste_tp_layer\n";
print "LAYER FINAL     = $good_tp_layer\n";

#################################################
# CREAR CAPAS TEMPORALES
#
# Si alguna de las capas de trabajo no existe
# la crea automáticamente.
#################################################

foreach my $target_layer
(
    $temp_tp_layer,
    $good_tp_layer,
    $paste_tp_layer
)
{
    # Verifica si la capa ya existe
    my $target_exists =
    grep { $_ eq $target_layer } @all_layers;

    if (!$target_exists)
    {
        print
        "STATUS: Creando capa '$target_layer' en Matrix...\n";

        $F->COM(
            "create_layer",

            layer     => $target_layer,

            context   => "board",

            type      => "drill",

            polarity  => "positive",

            ins_layer => $work_layer
        );
    }
}

#################################################
# LIMPIAR CAPAS TEMPORALES
#
# Elimina información previa de ejecuciones
# anteriores.
#################################################

foreach my $clr_layer
(
    $temp_tp_layer,
    $paste_tp_layer,
    $good_tp_layer
)
{
    # Mostrar layer temporal
    $F->COM(
        "display_layer",
        name    => $clr_layer,
        display => "yes",
        number  => 1
    );

    # Convertir en work layer
    $v->setWorkLayer($clr_layer);

    # Select All
    $F->COM(
        "edt_menu_item",
        menu_num => 250
    );

    # Si existen features se eliminan
    if ($v->getSelectedCount() > 0)
    {
        $F->COM("sel_delete");
    }

    # Ocultar layer nuevamente
    $F->COM(
        "display_layer",
        name    => $clr_layer,
        display => "no",
        number  => 1
    );
}

#################################################
# PASO 1
#
# EXTRACCIÓN DE CANDIDATOS TP
#
# Busca pads redondos:
#
#   - Dentro del profile
#   - Con tamaño mínimo
#   - Con soldadura expuesta
#
#################################################

# Mostrar capa origen
$F->COM(
    "display_layer",
    name    => $work_layer,
    display => "yes",
    number  => 1
);

# Activar capa origen
$v->setWorkLayer($work_layer);

#################################################
# CONFIGURAR FILTROS DE SELECCIÓN
#################################################

# Seleccionar únicamente pads
$F->COM(
    "filter_set",
    filter_name  => "popup",
    update_popup => "no",
    feat_types   => "pad"
);

# Solo geometría positiva
$F->COM(
    "filter_set",
    filter_name  => "popup",
    update_popup => "no",
    polarity     => "positive"
);

# Tamaño mínimo X = 8 mils
$F->COM(
    "filter_adv_set",
    filter_name  => "popup",
    update_popup => "no",
    min_dx       => 8
);

# Tamaño mínimo Y = 8 mils
$F->COM(
    "filter_adv_set",
    filter_name  => "popup",
    update_popup => "no",
    min_dy       => 8
);

# Debe estar presente en solder mask
$F->COM(
    "filter_adv_set",
    filter_name  => "popup",
    update_popup => "no",
    tbsm         => "yes"
);

# Solo símbolos circulares tipo r*
$F->COM(
    "filter_set",
    filter_name  => "popup",
    update_popup => "no",
    include_syms => "r*"
);

# Excluir símbolos rectangulares
$F->COM(
    "filter_set",
    filter_name  => "popup",
    update_popup => "no",
    exclude_syms => "rect*"
);

# Solo features dentro del profile
$F->COM(
    "filter_set",
    filter_name  => "popup",
    update_popup => "no",
    profile      => "in"
);

#################################################
# EJECUTAR FILTRO
#################################################

$F->COM("filter_area_strt");

$F->COM(
    "filter_area_end",

    layer          => "",
    filter_name    => "popup",

    operation      => "select",

    area_type      => "none",

    inside_area    => "no",

    intersect_area => "no",

    lines_only     => "no",

    ovals_only     => "no",

    min_len        => 0,

    max_len        => 0,

    min_angle      => 0,

    max_angle      => 0
);

# Reset del filtro
$F->COM(
    "filter_reset",
    filter_name => "popup"
);

# Cantidad de candidatos encontrados
my $selected_count =
$v->getSelectedCount() || 0;

print
"PADS EXTRAIDOS DE '$work_layer' (DENTRO DEL PROFILE) = $selected_count\n";

# Si no existe ningún candidato terminar
if ($selected_count == 0)
{
    $F->PAUSE(
        "WARNING: No se encontraron pads dentro del profile en la capa $work_layer."
    );

    exit 0;
}

#################################################
# COPIAR CANDIDATOS
#
# Guarda los candidatos en la layer temporal
# utilizada para validación de Annular Ring.
#################################################

$F->COM(
    "sel_copy_other",

    dest         => "layer_name",

    target_layer => $temp_tp_layer,

    invert       => "no",

    dx           => 0,

    dy           => 0,

    size         => 0
);

#################################################
# PASO 2
#
# VALIDACIÓN DE ANNULAR RING
#
# Reduce temporalmente los pads y compara
# contra la capa Drill.
#
#################################################

# Ocultar cobre
$F->COM(
    "display_layer",
    name    => $work_layer,
    display => "no",
    number  => 1
);

# Mostrar layer temporal
$F->COM(
    "display_layer",
    name    => $temp_tp_layer,
    display => "yes",
    number  => 1
);

# Activar layer temporal
$v->setWorkLayer($temp_tp_layer);

#################################################
# SELECCIONAR TODO
#################################################

$F->COM(
    "edt_menu_item",
    menu_num => 250
);

#################################################
# REDUCIR 15.99 MILS
#
# Simula el margen mínimo de Annular Ring.
#################################################

$F->COM(
    "sel_resize",
    size => -15.99
);

#################################################
# VALIDAR CONTRA DRILL
#################################################

$F->COM(
    "sel_ref_feat",

    layers       => $drill_layer,

    use          => "filter",

    mode         => "cover",

    f_types      => "line;pad;surface;arc;text",

    polarity     => "positive;negative",

    include_syms => "",

    exclude_syms => ""
);

#################################################
# INVERTIR SELECCIÓN
#
# Los que sobreviven son los que cumplen
# Annular Ring requerido.
#################################################

$F->COM("sel_reverse");

# Cantidad de candidatos válidos
my $good_tp_count =
$v->getSelectedCount() || 0;

print
"PADS QUE CUMPLEN ANNULAR RING (>= 8 mils) = $good_tp_count\n";

#################################################
# COPIAR APROBADOS A CAPA FINAL
#################################################

if ($good_tp_count > 0)
{
    $F->COM(
        "sel_copy_other",

        dest         => "layer_name",

        target_layer => $good_tp_layer,

        invert       => "no",

        dx           => 0,

        dy           => 0,

        size         => 0
    );
}
#################################################
# PASO 3
#
# VALIDACIÓN MEDIANTE SOLDER PASTE
#
# Recupera candidatos que no cumplen
# Annular Ring pero sí tienen apertura
# funcional en la capa Paste.
#################################################

$F->COM(
    "sel_ref_feat",

    layers       => $drill_layer,

    use          => "filter",

    mode         => "cover",

    f_types      => "line;pad;surface;arc;text",

    polarity     => "positive;negative",

    include_syms => "",

    exclude_syms => ""
);

# Cantidad de pads que NO cumplieron Annular Ring
my $fail_ar_count =
$v->getSelectedCount() || 0;

print
"PADS QUE NO CUMPLEN ANNULAR RING = $fail_ar_count\n";

# Si existen candidatos no aprobados
if ($fail_ar_count > 0)
{
    #################################################
    # COPIAR RECHAZADOS A CAPA INTERMEDIA
    #################################################

    $F->COM(
        "sel_copy_other",

        dest         => "layer_name",

        target_layer => $paste_tp_layer,

        invert       => "no",

        dx           => 0,

        dy           => 0,

        size         => 0
    );

    #################################################
    # CAMBIAR A CAPA INTERMEDIA PASTE
    #################################################

    $F->COM(
        "display_layer",
        name    => $temp_tp_layer,
        display => "no",
        number  => 1
    );

    $F->COM(
        "display_layer",
        name    => $paste_tp_layer,
        display => "yes",
        number  => 1
    );

    $v->setWorkLayer($paste_tp_layer);

    #################################################
    # SELECCIONAR TODO
    #################################################

    $F->COM(
        "edt_menu_item",
        menu_num => 250
    );

    #################################################
    # RECUPERAR GEOMETRÍA ORIGINAL
    #
    # Revierte el resize negativo
    # aplicado durante la validación.
    #################################################

    $F->COM(
        "sel_resize",
        size => 15.99
    );

    #################################################
    # VALIDACIÓN CONTRA SOLDER PASTE
    #################################################

    $F->COM(
        "sel_ref_feat",

        layers       => $paste_layer,

        use          => "filter",

        mode         => "cover",

        f_types      => "line;pad;surface;arc;text",

        polarity     => "positive;negative",

        include_syms => "",

        exclude_syms => ""
    );

    # Cantidad de TP recuperados mediante Paste
    my $rescued_tp_count =
    $v->getSelectedCount() || 0;

    print
    "PADS RESCATADOS POR SOLDER PASTE ($paste_layer) = $rescued_tp_count\n";

    #################################################
    # COPIAR RESCATADOS A CAPA FINAL
    #################################################

    if ($rescued_tp_count > 0)
    {
        $F->COM(
            "sel_copy_other",

            dest         => "layer_name",

            target_layer => $good_tp_layer,

            invert       => "no",

            dx           => 0,

            dy           => 0,

            size         => 0
        );
    }
}

#################################################
# CAMBIAR VISTA A CAPA FINAL
#################################################

$F->COM(
    "display_layer",
    name    => $paste_tp_layer,
    display => "no",
    number  => 1
);

$F->COM(
    "display_layer",
    name    => $good_tp_layer,
    display => "yes",
    number  => 1
);

$v->setWorkLayer($good_tp_layer);

#################################################
# ELIMINAR FIDUCIALES
#
# Remueve:
#
#   g_fiducial
#   l_fiducial
#
#################################################

print
"STATUS: Depurando fiduciales en capa final '$good_tp_layer'...\n";

my $total_fidu_removed = 0;

foreach my $fid_opt
(
    "g_fiducial",
    "l_fiducial"
)
{
    $F->COM(
        "filter_reset",
        filter_name => "popup"
    );

    $F->COM(
        "filter_set",
        filter_name  => "popup",
        update_popup => "no",
        feat_types   => "pad"
    );

    $F->COM(
        "filter_atr_set",

        filter_name => "popup",

        attribute   => ".pad_usage",

        entity      => "feature",

        condition   => "yes",

        option      => $fid_opt
    );

    $F->COM("filter_area_strt");

    $F->COM(
        "filter_area_end",

        layer          => "",

        filter_name    => "popup",

        operation      => "select",

        area_type      => "none",

        inside_area    => "no",

        intersect_area => "no",

        lines_only     => "no",

        ovals_only     => "no",

        min_len        => 0,

        max_len        => 0,

        min_angle      => 0,

        max_angle      => 0
    );

    my $count =
    $v->getSelectedCount() || 0;

    if ($count > 0)
    {
        $total_fidu_removed += $count;

        $F->COM("sel_delete");
    }
}

print
"FIDUCIALES REMOVIDOS DE LA CAPA FINAL = $total_fidu_removed\n";

#################################################
# NORMALIZAR A r12.12
#################################################

print
"STATUS: Aplicando cambio de simbolo (r12.12)...\n";

$F->COM(
    "filter_reset",
    filter_name => "popup"
);

$F->COM(
    "filter_set",
    filter_name  => "popup",
    update_popup => "no",
    include_syms => "r*"
);

$F->COM("filter_area_strt");

$F->COM(
    "filter_area_end",

    layer          => "",

    filter_name    => "popup",

    operation      => "select",

    area_type      => "none",

    inside_area    => "no",

    intersect_area => "no",

    lines_only     => "no",

    ovals_only     => "no",

    min_len        => 0,

    max_len        => 0,

    min_angle      => 0,

    max_angle      => 0
);

my $selected_to_reshape =
$v->getSelectedCount() || 0;

if ($selected_to_reshape > 0)
{
    # Select Symbol Change
    $F->COM(
        "edt_menu_item",
        menu_num => 230
    );

    # Convertir todos a r12.12
    $F->COM(
        "sel_change_sym",
        symbol => "r12.12"
    );
}

#################################################
# AGREGAR ATRIBUTO .test_point
#################################################

print
"STATUS: Asignando atributo '.test_point'...\n";

$F->COM(
    "cur_atr_set",
    attribute => ".test_point"
);

$F->COM(
    "sel_change_atr",

    mode     => "add",

    pkg_attr => "no"
);

#################################################
# ACTUALIZAR CAPA ORIGEN
#
# Elimina TP viejos y copia TP válidos.
#################################################

print
"STATUS: Actualizando capa origen...\n";

# (Aquí continúa exactamente tu bloque 15 original)

#################################################
# RESUMEN FINAL
#################################################

$F->COM(
    "edt_menu_item",
    menu_num => 250
);

my $total_good =
$v->getSelectedCount() || 0;

$F->COM("sel_clear_feat");

print "\n========================================\n";
print "PROCESO FINALIZADO CON EXITO\n";
print "CAPA ORIGEN RESTRUCTURADA = $work_layer\n";
print "TOTAL TPS VALIDADOS        = $total_good\n";
print "========================================\n";

exit 0;

