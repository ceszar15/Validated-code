#!perl -w                                           # Define que es un script en Perl y activa las advertencias de sintaxis (-w)


use strict;                                         # Exige la declaración explícita de variables (con 'my') para evitar errores de ámbito
use warnings;                                       # Muestra alertas de ejecución en la consola de Perl

use lib "V:/vNPI_DIR/sys/scripts/jabil/perl/lib"; # Añade esta ruta al Path de Perl para poder importar librerías personalizadas

use Valor;                                          # Carga la librería principal de interacción con la API de Valor Genesis/ODB++
use Valor_util;                                     # Carga utilidades personalizadas auxiliares para manipular capas y selección de objetos

sub is_number {
    my ($v) = @_;                                   # Obtiene el valor pasado como argumento
    return 0 unless defined $v;                     # Si no está definido, retorna 0 (falso)
    return $v =~ /^[-+]?(?:\d+(?:\.\d*)?|\.\d+)$/ ? 1 : 0; # Comprueba mediante una expresión regular si el string es un número real
}

sub rounded {
    my ($v, $d) = @_;                               # Recibe el valor '$v' y el número de decimales '$d'
    return sprintf("%.${d}f", $v);                  # Retorna el número redondeado y formateado como flotante
}

sub normalize_name {
    my ($name) = @_;                                # Recibe el nombre de la capa o archivo
    my $n = lc($name || "");                        # Convierte todo el texto a minúsculas
    $n =~ s/[_\-]+/ /g;                             # Reemplaza guiones bajos y guiones por espacios en blanco
    $n =~ s/\s+/ /g;                                # Limpia espacios duplicados dejando solo uno
    $n =~ s/^\s+//;                                 # Remueve espacios sobrantes al inicio del texto
    $n =~ s/\s+$//;                                 # Remueve espacios sobrantes al final del texto
    return $n;                                      # Retorna el texto normalizado
}

sub is_fab_drawing {
    my ($name) = @_;                                # Recibe el nombre original de la capa
    my $n = normalize_name($name);                  # Llama a la función anterior para normalizar la cadena
    return 1 if $n =~ /\bfab\b/ && $n =~ /\b(?:dwg|drawing)\b/;           # Retorna 1 si contiene "fab" y "dwg" o "drawing"
    return 1 if $n =~ /\bfabrication\b/ && $n =~ /\b(?:dwg|drawing|sheet)\b/; # Retorna 1 si contiene "fabrication" y "dwg", "drawing" o "sheet"
    return 0;                                       # Si no coincide con un dibujo de fabricación, retorna 0
}

sub internal_name {
    my ($name) = @_;                                # Recibe un nombre de capa
    my $n = $name;                                  # Copia el valor a una variable local
    $n =~ s/\s+/_/g;                                # Sustituye cualquier espacio en blanco por guiones bajos
    return $n;                                      # Retorna el nombre sanitizado para uso interno
}

sub parse_lines {
    my ($features_ref) = @_;                        # Recibe una referencia al array de entidades (features) leídas de Valor
    my @lines;                                      # Almacenará la lista de líneas procesadas
    my $arcs = 0;                                   # Contador para arcos
    my $other = 0;                                  # Contador para otros tipos de geometría (pads, superficies, etc.)
    my $invalid = 0;                                # Contador de líneas inválidas o descartadas

    foreach my $record (@{$features_ref}) {         # Itera sobre cada registro geométrico obtenido
        if (!defined $record) {                     # Si el registro no existe
            $invalid++;                             # Incrementa contador de inválidos
            next;                                   # Salta a la siguiente iteración
        }

        $record =~ s/^\s+//;                        # Remueve espacios iniciales del registro
        $record =~ s/\s+$//;                        # Remueve espacios finales del registro
        next if $record eq "";                      # Salta registros vacíos

        if ($record =~ /^#L\s+/) {                  # Comprueba si el registro es una Línea (empieza por #L)
            my @f = split(/\s+/, $record);          # Divide la cadena en columnas separadas por espacios
            if (scalar(@f) < 6) {                   # Si no tiene al menos 6 campos (comandos básicos de punto inicial y final)
                $invalid++;                         # Se considera inválida
                next;                               # Pasa al siguiente registro
            }

            my ($xs, $ys, $xe, $ye) = @f[1 .. 4];   # Extrae las coordenadas X-inicial, Y-inicial, X-final y Y-final
            unless (is_number($xs) && is_number($ys) &&
                    is_number($xe) && is_number($ye)) { # Valida que todas las coordenadas sean números
                $invalid++;
                next;
            }

            $xs += 0; $ys += 0; $xe += 0; $ye += 0;  # Convierte explícitamente las variables numéricas
            my $dx = $xe - $xs;                     # Calcula el desplazamiento horizontal
            my $dy = $ye - $ys;                     # Calcula el desplazamiento vertical
            my $length = sqrt(($dx * $dx) + ($dy * $dy)); # Calcula la longitud usando Pitágoras
            my $orientation = "DIAGONAL";           # Orientación por defecto
            $orientation = "HORIZONTAL" if abs($dy) <= 0.000001; # Es horizontal si el cambio en Y es despreciable
            $orientation = "VERTICAL" if abs($dx) <= 0.000001;   # Es vertical si el cambio en X es despreciable

            push @lines, {                           # Añade una estructura hash con las propiedades calculadas a @lines
                xs => $xs, ys => $ys, xe => $xe, ye => $ye,
                mx => ($xs + $xe) / 2,              # Punto medio X
                my => ($ys + $ye) / 2,              # Punto medio Y
                dx => $dx, dy => $dy,
                length => $length,
                orientation => $orientation
            };
            next;
        }

        if ($record =~ /^#A\s+/) {                  # Si el registro identifica un Arco (#A)
            $arcs++;                                # Incrementa el contador de arcos
            next;
        }

        $other++;                                   # Si no es línea ni arco, lo cuenta en 'otros'
    }

    return (\@lines, $arcs, $other, $invalid);      # Retorna referencia a líneas y contadores
}

sub detect_pitch {
    my ($lines_ref) = @_;                          # Recibe la lista de líneas analizadas
    my %groups;                                     # Almacena grupos de líneas por patrones idénticos
    my %same_x;                                     # Conteo de distancias repetidas en eje X
    my %same_y;                                     # Conteo de distancias repetidas en eje Y
    my $direction_tolerance = 0.0010;               # Tolerancia para diferencias de dirección/longitud
    my $axis_tolerance = 0.0001;                    # Tolerancia de alineación sobre los ejes

    foreach my $line (@{$lines_ref}) {
        next if $line->{length} < 0.2500;           # Filtra y descarta líneas de longitud menor a 0.25 pulgadas
        my $signature = join(                       # Genera una "firma" única basada en su longitud y desplazamientos
            "|",
            rounded($line->{length}, 4),
            rounded(abs($line->{dx}), 4),
            rounded(abs($line->{dy}), 4)
        );
        push @{$groups{$signature}}, $line;         # Agrupa las líneas que poseen exactamente la misma firma
    }

    foreach my $signature (keys %groups) {
        my @g = @{$groups{$signature}};             # Lista de líneas en un mismo grupo
        next if scalar(@g) < 2 || scalar(@g) > 100; # Ignora grupos sin parejas o excesivamente grandes (>100)

        for (my $i = 0; $i < scalar(@g) - 1; $i++) {# Compara pares de líneas dentro del mismo grupo
            for (my $j = $i + 1; $j < scalar(@g); $j++) {
                my $a = $g[$i];
                my $b = $g[$j];
                next if abs($a->{dx} - $b->{dx}) > $direction_tolerance; # Omite si la dirección difiere en X
                next if abs($a->{dy} - $b->{dy}) > $direction_tolerance; # Omite si la dirección difiere en Y

                my $tx = abs($b->{mx} - $a->{mx});  # Calcula la distancia entre puntos medios en X
                my $ty = abs($b->{my} - $a->{my});  # Calcula la distancia entre puntos medios en Y

                # Acumula la frecuencia de apariciones de distancias idénticas dentro de límites lógicos
                $same_x{rounded($tx, 4)}++
                    if $ty <= $axis_tolerance && $tx >= 0.1000 && $tx <= 20.0000;
                $same_y{rounded($ty, 4)}++
                    if $tx <= $axis_tolerance && $ty >= 0.1000 && $ty <= 20.0000;
            }
        }
    }

    # Ordena las distancias halladas de mayor a menor frecuencia acumulada
    my @x = sort { $same_x{$b} <=> $same_x{$a} || $a cmp $b } keys %same_x;
    my @y = sort { $same_y{$b} <=> $same_y{$a} || $a cmp $b } keys %same_y;
    my $xp = @x ? $x[0] : undef;                    # Toma el paso (pitch) dominatemente más repetido en X
    my $yp = @y ? $y[0] : undef;                    # Toma el paso dominatemente más repetido en Y
    my $xc = @x ? $same_x{$x[0]} : 0;              # Frecuencia de ese pitch en X
    my $yc = @y ? $same_y{$y[0]} : 0;              # Frecuencia de ese pitch en Y

    return $yc > $xc ? ("Y", $yp, $yc) : ("X", $xp, $xc); # Retorna el eje con mayor patrón detectado
}

sub detect_panel_region {
    my ($lines_ref) = @_;
    my $tol = 0.0010;

    # Filtra líneas verticales que midan entre 1.0 y 10.0 pulgadas
    my @vertical = grep {
        $_->{orientation} eq "VERTICAL" &&
        $_->{length} >= 1.0000 && $_->{length} <= 10.0000
    } @{$lines_ref};

    # Filtra líneas horizontales entre 1.0 y 15.0 pulgadas
    my @horizontal = grep {
        $_->{orientation} eq "HORIZONTAL" &&
        $_->{length} >= 1.0000 && $_->{length} <= 15.0000
    } @{$lines_ref};

    my @vp;
    my @hp;

    # Evalúa pares de líneas verticales paralelas para deducir los límites del ancho del panel
    for (my $i = 0; $i < scalar(@vertical) - 1; $i++) {
        for (my $j = $i + 1; $j < scalar(@vertical); $j++) {
            my $a = $vertical[$i];
            my $b = $vertical[$j];
            next if abs($a->{length} - $b->{length}) > $tol;

            my $ay1 = $a->{ys} < $a->{ye} ? $a->{ys} : $a->{ye};
            my $ay2 = $a->{ys} > $a->{ye} ? $a->{ys} : $a->{ye};
            my $by1 = $b->{ys} < $b->{ye} ? $b->{ys} : $b->{ye};
            my $by2 = $b->{ys} > $b->{ye} ? $b->{ys} : $b->{ye};
            next if abs($ay1 - $by1) > $tol || abs($ay2 - $by2) > $tol;

            my $width = abs($a->{xs} - $b->{xs});
            next if $width < 4.0000 || $width > 12.0000;   # Filtra si el ancho está fuera del rango del panel

            push @vp, {
                score => $width * $a->{length},            # Asigna una puntuación proportional al área
                xmin => $a->{xs} < $b->{xs} ? $a->{xs} : $b->{xs},
                xmax => $a->{xs} > $b->{xs} ? $a->{xs} : $b->{xs}
            };
        }
    }

    # Evalúa parejas de líneas horizontales para deducir el alto del panel
    for (my $i = 0; $i < scalar(@horizontal) - 1; $i++) {
        for (my $j = $i + 1; $j < scalar(@horizontal); $j++) {
            my $a = $horizontal[$i];
            my $b = $horizontal[$j];
            next if abs($a->{length} - $b->{length}) > $tol;

            my $ax1 = $a->{xs} < $a->{xe} ? $a->{xs} : $a->{xe};
            my $ax2 = $a->{xs} > $a->{xe} ? $a->{xs} : $a->{xe};
            my $bx1 = $b->{xs} < $b->{xe} ? $b->{xs} : $b->{xe};
            my $bx2 = $b->{xs} > $b->{xe} ? $b->{xs} : $b->{xe};
            next if abs($ax1 - $bx1) > $tol || abs($ax2 - $bx2) > $tol;

            my $height = abs($a->{ys} - $b->{ys});
            next if $height < 3.0000 || $height > 10.0000; # Filtra por altura esperada

            push @hp, {
                score => $height * $a->{length},
                ymin => $a->{ys} < $b->{ys} ? $a->{ys} : $b->{ys},
                ymax => $a->{ys} > $b->{ys} ? $a->{ys} : $b->{ys}
            };
        }
    }

    return undef unless @vp && @hp;                       # Si no detectó ambos límites, retorna nulo
    @vp = sort { $b->{score} <=> $a->{score} } @vp;      # Selecciona la mejor opción vertical
    @hp = sort { $b->{score} <=> $a->{score} } @hp;      # Selecciona la mejor opción horizontal

    return {                                               # Retorna las coordenadas límites (Boundary Box)
        xmin => $vp[0]->{xmin}, xmax => $vp[0]->{xmax},
        ymin => $hp[0]->{ymin}, ymax => $hp[0]->{ymax}
    };
}

sub detect_x_rotation_centers {
    my ($lines_ref, $region_ref, $pitch) = @_;
    my $tol = 0.0010;
    my %groups;
    my %count;
    my %sum_x;
    my %sum_y;
    my %samples;

    foreach my $line (@{$lines_ref}) {
        next if $line->{length} < 0.2500;
        # Descarta geometría fuera de la región del panel detectada previa
        next if $line->{mx} < $region_ref->{xmin} - 0.01;
        next if $line->{mx} > $region_ref->{xmax} + 0.01;
        next if $line->{my} < $region_ref->{ymin} - 0.01;
        next if $line->{my} > $region_ref->{ymax} + 0.01;

        my $signature = join(
            "|",
            rounded($line->{length}, 4),
            rounded(abs($line->{dx}), 4),
            rounded(abs($line->{dy}), 4)
        );
        push @{$groups{$signature}}, $line;
    }

    foreach my $signature (keys %groups) {
        my @g = @{$groups{$signature}};
        next if scalar(@g) < 2 || scalar(@g) > 100;

        for (my $i = 0; $i < scalar(@g) - 1; $i++) {
            for (my $j = $i + 1; $j < scalar(@g); $j++) {
                my $a = $g[$i];
                my $b = $g[$j];
                # Busca características invertidas (p. ej., rotadas 180 grados entre sí)
                next unless abs($a->{dx} + $b->{dx}) <= $tol;
                next unless abs($a->{dy} + $b->{dy}) <= $tol;
                next if abs($b->{my} - $a->{my}) < 0.5000;

                # Calcula el punto de simetría/rotación
                my $cx = ($a->{mx} + $b->{mx}) / 2;
                my $cy = ($a->{my} + $b->{my}) / 2;
                my $key = rounded($cx, 4) . "," . rounded($cy, 4);
                my $sx = abs($b->{mx} - $a->{mx});
                next if $sx > 2.0000;

                $count{$key}++;
                $sum_x{$key} += $cx;
                $sum_y{$key} += $cy;
                $samples{$key}++;
            }
        }
    }

    my @keys = sort { $count{$b} <=> $count{$a} || $a cmp $b } keys %count;
    return undef if scalar(@keys) < 3;                      # Debe encontrar al menos 3 candidatos a centros

    # Deduce los centros exactos de rotación para arreglos girados 180°
    my $global = $keys[0];
    my $gx = $sum_x{$global} / $samples{$global};
    my $gy = $sum_y{$global} / $samples{$global};
    my ($left, $right);
    my ($lx, $ly, $rx, $ry);
    my $best_score = -1;

    for (my $i = 1; $i < scalar(@keys) - 1; $i++) {
        for (my $j = $i + 1; $j < scalar(@keys); $j++) {
            my $x1 = $sum_x{$keys[$i]} / $samples{$keys[$i]};
            my $y1 = $sum_y{$keys[$i]} / $samples{$keys[$i]};
            my $x2 = $sum_x{$keys[$j]} / $samples{$keys[$j]};
            my $y2 = $sum_y{$keys[$j]} / $samples{$keys[$j]};
            next if abs($y1 - $gy) > 0.0010 || abs($y2 - $gy) > 0.0010;
            next if abs((($x1 + $x2) / 2) - $gx) > 0.0010;
            next if abs(abs($x2 - $x1) - $pitch) > 0.0010;

            my $score = $count{$keys[$i]} + $count{$keys[$j]};
            if ($score > $best_score) {
                $best_score = $score;
                if ($x1 < $x2) {
                    ($left, $right, $lx, $ly, $rx, $ry) =
                        ($keys[$i], $keys[$j], $x1, $y1, $x2, $y2);
                }
                else {
                    ($left, $right, $lx, $ly, $rx, $ry) =
                        ($keys[$j], $keys[$i], $x2, $y2, $x1, $y1);
                }
            }
        }
    }

    return undef unless defined $left;
    return {
        left_x => $lx, left_y => $ly,
        right_x => $rx, right_y => $ry,
        left_matches => $count{$left},
        right_matches => $count{$right},
        global_x => $gx, global_y => $gy
    };
}

sub safe_recreate_step {
    my ($F, $job, $source_step, $target_step) = @_;

    # Validación estricta de seguridad para evitar sobrescribir el step original o no autorizado
    if ($target_step eq $source_step || $target_step ne "panel_auto_xy_test") {
        $F->PAUSE("ERROR DE SEGURIDAD: Nombre de step temporal no autorizado");
        exit 1;                                     # Detiene la ejecución
    }

    $F->DO_INFO("-t job -e $job -d STEPS_LIST");     # Obtiene la lista actual de steps en el trabajo
    my $steps_ref = $F->{doinfo}{gSTEPS_LIST};
    my $exists = 0;

    if (defined($steps_ref) && ref($steps_ref) eq "ARRAY") {
        foreach my $s (@{$steps_ref}) {
            if (defined($s) && $s eq $target_step) {
                $exists = 1;                         # Marca si el step temporal ya existe
                last;
            }
        }
    }

    if ($exists) {
        print "EXISTING_TEST_STEP=YES\n";
        print "ACTION=DELETE_TEST_STEP\n";
        $F->COM("delete_entity", job=>$job, type=>"step", name=>$target_step); # Elimina el step temporal viejo
    }
    else {
        print "EXISTING_TEST_STEP=NO\n";
    }

    $F->COM("create_entity", job=>$job, type=>"step", name=>$target_step);     # Crea el step totalmente nuevo
    $F->COM("open_entity", job=>$job, type=>"step", name=>$target_step, iconic=>"no"); # Abre el step creado
}

my $F = new Valor;                                  # Instancia el objeto de la API de Valor Genesis
my $v = new Valor_util();                           # Instancia el objeto de utilidades auxiliares

my $job  = $ENV{JOB}  || "";                        # Lee el nombre del JOB de las variables de entorno
my $step = $ENV{STEP} || "";                        # Lee el nombre del STEP de las variables de entorno
my $panel_step = "panel_auto_xy_test";             # Nombre prefijado para el Step resultante del panel
my $safe_feature_limit = 10000;                     # Límite máximo de entidades por capa para evitar bloqueos
my $minimum_matches = 20;                           # Mínimo de repeticiones requeridas para considerar válido un patrón

# Detiene el script si no se ejecutó desde un entorno ODB++ válido
if ($job eq "" || $step eq "") {
    $F->PAUSE("ERROR: JOB o STEP no estan definidos");
    exit 1;
}

# Impresión de logs iniciales
print "\n========================================\n";
print "AUTO PANEL XY COMBINED V01\n";
print "========================================\n";
print "JOB=$job\n";
print "SOURCE_STEP=$step\n";
print "TARGET_STEP=$panel_step\n";

# Pide a Valor la lista de capas (layers) disponibles en el Step
$F->DO_INFO("-t step -e $job/$step -d LAYERS_LIST");
my $layers_ref = $F->{doinfo}{gLAYERS_LIST};
if (!defined($layers_ref) || ref($layers_ref) ne "ARRAY") {
    $F->PAUSE("ERROR: LAYERS_LIST no devolvio un ARRAY");
    exit 1;
}

# Filtra y ordena alfabéticamente solo las capas identificadas como "Fabrication Drawing"
my @candidates = sort { $a cmp $b } grep { is_fab_drawing($_) } @{$layers_ref};
my @results;

# Ciclo sobre cada capa candidata encontrada
foreach my $layer (@candidates) {
    $v->setWorkLayer($layer);                      # Establece la capa de trabajo actual
    $v->resetFilter();                              # Limpia cualquier filtro geométrico
    $F->COM("filter_area_strt");                    # Inicia selección por área en Valor
    $F->COM(
        "filter_area_end",
        layer=>"", filter_name=>"popup", operation=>"select",
        area_type=>"none", inside_area=>"no", intersect_area=>"no",
        lines_only=>"no", ovals_only=>"no",
        min_len=>0, max_len=>0, min_angle=>0, max_angle=>0
    );                                              # Selecciona todos los objetos geométricos presentes en la capa

    my $selected = $v->getSelectedCount();          # Cuenta cuántas entidades se seleccionaron
    $selected = 0 unless defined $selected;
    print "LAYER=$layer SELECTED=$selected\n";
    next if $selected < 1 || $selected > $safe_feature_limit; # Ignora capas vacías o gigantescas

    my @features = $v->getSelectedFeats(internal_name($layer)); # Obtiene las geometrías detalladas
    my ($lines_ref, $arcs, $other, $invalid) = parse_lines(\@features); # Extrae únicamente las líneas
    my ($axis, $period, $matches) = detect_pitch($lines_ref);         # Detecta si hay un patrón repetitivo
    print "  AXIS=$axis PERIOD=" . (defined($period) ? $period : "NONE") .
          " MATCHES=$matches LINES=" . scalar(@{$lines_ref}) . "\n";
    next unless defined $period;                    # Si no encuentra paso constante, salta la capa

    push @results, {                                # Almacena los resultados válidos hallados en la capa
        layer=>$layer, axis=>$axis, period=>$period+0,
        matches=>$matches, lines=>$lines_ref
    };
}

# Ordena los resultados por el número de coincidencias de patrón encontradas (de mayor a menor)
@results = sort { $b->{matches} <=> $a->{matches} || $a->{layer} cmp $b->{layer} } @results;

# Si no hubo hallazgos suficientes, muestra pausa y cancela el proceso de forma segura
if (!@results || $results[0]->{matches} < $minimum_matches) {
    $F->PAUSE("STOP: No se encontro evidencia suficiente. No se modifico el JOB.");
    exit 0;
}

my $best = $results[0];                             # Selecciona el mejor patrón de simetría/matriz

print "\n========================================\n";
print "BEST PATTERN\n";
print "========================================\n";
print "BEST_LAYER=$best->{layer}\n";
print "DOMINANT_AXIS=$best->{axis}\n";
print "DOMINANT_PERIOD=$best->{period}\n";
print "DOMINANT_MATCHES=$best->{matches}\n";

# --- RAMA 1: Modificación para Paneles Verticales (Eje Y) ---
if ($best->{axis} eq "Y") {
    my $adjacent_pitch = $best->{period} / 2;       # Distancia entre placas consecutivas en Y
    my $unit_count = 4;                            # Matriz de 4 unidades verticalmente

    print "ENGINE=VERTICAL_1X4\n";
    print "ADJACENT_PITCH=$adjacent_pitch\n";

    safe_recreate_step($F, $job, $step, $panel_step); # Recrea el step 'panel_auto_xy_test' de forma limpia

    # Agrega la matriz repetitiva de placas (Step & Repeat) 1x4
    $F->COM(
        "sr_tab_add",
        line=>1, step=>$step, x=>0, y=>0,
        nx=>1, ny=>$unit_count, dx=>0, dy=>$adjacent_pitch,
        angle=>0, flip=>"no"
    );

    print "RESULT=CREATED\n";
    print "NX=1 NY=$unit_count DX=0 DY=$adjacent_pitch ANGLE=0\n";
}
# --- RAMA 2: Modificación para Paneles Horizontales (Eje X, Matriz 2x2 con rotaciones) ---
elsif ($best->{axis} eq "X") {
    my $region = detect_panel_region($best->{lines}); # Encuentra los límites generales
    if (!defined $region) {
        $F->PAUSE("STOP: No se pudo detectar la region horizontal. No se modifico el JOB.");
        exit 0;
    }

    my $centers = detect_x_rotation_centers($best->{lines}, $region, $best->{period}); # Deduce centros 180°
    if (!defined $centers || $centers->{left_matches} < 5 || $centers->{right_matches} < 5) {
        $F->PAUSE("STOP: No se confirmaron centros 180. No se modifico el JOB.");
        exit 0;
    }

    my $row_180_x = 2 * $centers->{left_x};         # Calcula punto de compensación X para la fila rotada
    my $row_180_y = 2 * $centers->{left_y};         # Calcula punto de compensación Y para la fila rotada

    print "ENGINE=HORIZONTAL_2X2\n";
    print "LEFT_CENTER_X=" . sprintf("%.9f", $centers->{left_x}) . "\n";
    print "LEFT_CENTER_Y=" . sprintf("%.9f", $centers->{left_y}) . "\n";
    print "ROW_180_X=" . sprintf("%.9f", $row_180_x) . "\n";
    print "ROW_180_Y=" . sprintf("%.9f", $row_180_y) . "\n";

    safe_recreate_step($F, $job, $step, $panel_step); # Prepara el Step temporal objetivo

    # Fila 1: Dos unidades a 0 grados alineadas en X
    $F->COM(
        "sr_tab_add",
        line=>1, step=>$step, x=>0, y=>0,
        nx=>2, ny=>1, dx=>$best->{period}, dy=>0,
        angle=>0, flip=>"no"
    );

    # Fila 2: Dos unidades invertidas (rotadas 180 grados)
    $F->COM(
        "sr_tab_add",
        line=>2, step=>$step, x=>$row_180_x, y=>$row_180_y,
        nx=>2, ny=>1, dx=>$best->{period}, dy=>0,
        angle=>180, flip=>"no"
    );

    print "RESULT=CREATED\n";
    print "ROWS=2 COLUMNS=2 PITCH_X=$best->{period} ANGLES=0,180\n";
}
else {
    $F->PAUSE("STOP: Eje no soportado. No se modifico el JOB."); # Si no encuentra eje X o Y claro, finaliza
    exit 0;
}

# Impresión final de estatus
print "\n========================================\n";
print "COMBINED TEST PANEL CREATED\n";
print "========================================\n";
print "PANEL_STEP=$panel_step\n";
print "SOURCE_LAYER=$best->{layer}\n";
print "SOURCE_STEP=$step\n";

# Despliega un mensaje emergente interactivo en Valor solicitando revisión humana obligatoria
$F->PAUSE(
    "Panel automatico combinado creado.\n\n" .
    "Panel: $panel_step\n" .
    "Fab layer: $best->{layer}\n" .
    "Axis: $best->{axis}\n" .
    "Period: $best->{period}\n\n" .
    "VALIDAR visualmente antes de continuar."
);

exit 0;                                             # Termina la ejecución exitosamente (código de salida 0)
