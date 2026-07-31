#!perl -w

use strict;
use warnings;

use lib "V:/vNPI_DIR/sys/scripts/jabil/perl/lib";

use Valor;
use Valor_util;

sub is_number {
    my ($v) = @_;
    return 0 unless defined $v;
    return $v =~ /^[-+]?(?:\d+(?:\.\d*)?|\.\d+)$/ ? 1 : 0;
}

sub rounded {
    my ($v, $d) = @_;
    return sprintf("%.${d}f", $v);
}

sub normalize_name {
    my ($name) = @_;
    my $n = lc($name || "");
    $n =~ s/[_\-]+/ /g;
    $n =~ s/\s+/ /g;
    $n =~ s/^\s+//;
    $n =~ s/\s+$//;
    return $n;
}

sub is_fab_drawing {
    my ($name) = @_;
    my $n = normalize_name($name);
    return 1 if $n =~ /\bfab\b/ && $n =~ /\b(?:dwg|drawing)\b/;
    return 1 if $n =~ /\bfabrication\b/ && $n =~ /\b(?:dwg|drawing|sheet)\b/;
    return 0;
}

sub internal_name {
    my ($name) = @_;
    my $n = $name;
    $n =~ s/\s+/_/g;
    return $n;
}

sub parse_lines {
    my ($features_ref) = @_;
    my @lines;
    my $arcs = 0;
    my $other = 0;
    my $invalid = 0;

    foreach my $record (@{$features_ref}) {
        if (!defined $record) {
            $invalid++;
            next;
        }

        $record =~ s/^\s+//;
        $record =~ s/\s+$//;
        next if $record eq "";

        if ($record =~ /^#L\s+/) {
            my @f = split(/\s+/, $record);
            if (scalar(@f) < 6) {
                $invalid++;
                next;
            }

            my ($xs, $ys, $xe, $ye) = @f[1 .. 4];
            unless (is_number($xs) && is_number($ys) &&
                    is_number($xe) && is_number($ye)) {
                $invalid++;
                next;
            }

            $xs += 0; $ys += 0; $xe += 0; $ye += 0;
            my $dx = $xe - $xs;
            my $dy = $ye - $ys;
            my $length = sqrt(($dx * $dx) + ($dy * $dy));
            my $orientation = "DIAGONAL";
            $orientation = "HORIZONTAL" if abs($dy) <= 0.000001;
            $orientation = "VERTICAL" if abs($dx) <= 0.000001;

            push @lines, {
                xs => $xs, ys => $ys, xe => $xe, ye => $ye,
                mx => ($xs + $xe) / 2,
                my => ($ys + $ye) / 2,
                dx => $dx, dy => $dy,
                length => $length,
                orientation => $orientation
            };
            next;
        }

        if ($record =~ /^#A\s+/) {
            $arcs++;
            next;
        }

        $other++;
    }

    return (\@lines, $arcs, $other, $invalid);
}

sub detect_pitch {
    my ($lines_ref) = @_;
    my %groups;
    my %same_x;
    my %same_y;
    my $direction_tolerance = 0.0010;
    my $axis_tolerance = 0.0001;

    foreach my $line (@{$lines_ref}) {
        next if $line->{length} < 0.2500;
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
                next if abs($a->{dx} - $b->{dx}) > $direction_tolerance;
                next if abs($a->{dy} - $b->{dy}) > $direction_tolerance;

                my $tx = abs($b->{mx} - $a->{mx});
                my $ty = abs($b->{my} - $a->{my});

                $same_x{rounded($tx, 4)}++
                    if $ty <= $axis_tolerance && $tx >= 0.1000 && $tx <= 20.0000;
                $same_y{rounded($ty, 4)}++
                    if $tx <= $axis_tolerance && $ty >= 0.1000 && $ty <= 20.0000;
            }
        }
    }

    my @x = sort { $same_x{$b} <=> $same_x{$a} || $a cmp $b } keys %same_x;
    my @y = sort { $same_y{$b} <=> $same_y{$a} || $a cmp $b } keys %same_y;
    my $xp = @x ? $x[0] : undef;
    my $yp = @y ? $y[0] : undef;
    my $xc = @x ? $same_x{$x[0]} : 0;
    my $yc = @y ? $same_y{$y[0]} : 0;

    return $yc > $xc ? ("Y", $yp, $yc) : ("X", $xp, $xc);
}

sub detect_panel_region {
    my ($lines_ref) = @_;
    my $tol = 0.0010;

    my @vertical = grep {
        $_->{orientation} eq "VERTICAL" &&
        $_->{length} >= 1.0000 && $_->{length} <= 10.0000
    } @{$lines_ref};

    my @horizontal = grep {
        $_->{orientation} eq "HORIZONTAL" &&
        $_->{length} >= 1.0000 && $_->{length} <= 15.0000
    } @{$lines_ref};

    my @vp;
    my @hp;

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
            next if $width < 4.0000 || $width > 12.0000;

            push @vp, {
                score => $width * $a->{length},
                xmin => $a->{xs} < $b->{xs} ? $a->{xs} : $b->{xs},
                xmax => $a->{xs} > $b->{xs} ? $a->{xs} : $b->{xs}
            };
        }
    }

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
            next if $height < 3.0000 || $height > 10.0000;

            push @hp, {
                score => $height * $a->{length},
                ymin => $a->{ys} < $b->{ys} ? $a->{ys} : $b->{ys},
                ymax => $a->{ys} > $b->{ys} ? $a->{ys} : $b->{ys}
            };
        }
    }

    return undef unless @vp && @hp;
    @vp = sort { $b->{score} <=> $a->{score} } @vp;
    @hp = sort { $b->{score} <=> $a->{score} } @hp;

    return {
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
                next unless abs($a->{dx} + $b->{dx}) <= $tol;
                next unless abs($a->{dy} + $b->{dy}) <= $tol;
                next if abs($b->{my} - $a->{my}) < 0.5000;

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
    return undef if scalar(@keys) < 3;

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

    if ($target_step eq $source_step || $target_step ne "panel_auto_xy_test") {
        $F->PAUSE("ERROR DE SEGURIDAD: Nombre de step temporal no autorizado");
        exit 1;
    }

    $F->DO_INFO("-t job -e $job -d STEPS_LIST");
    my $steps_ref = $F->{doinfo}{gSTEPS_LIST};
    my $exists = 0;

    if (defined($steps_ref) && ref($steps_ref) eq "ARRAY") {
        foreach my $s (@{$steps_ref}) {
            if (defined($s) && $s eq $target_step) {
                $exists = 1;
                last;
            }
        }
    }

    if ($exists) {
        print "EXISTING_TEST_STEP=YES\n";
        print "ACTION=DELETE_TEST_STEP\n";
        $F->COM("delete_entity", job=>$job, type=>"step", name=>$target_step);
    }
    else {
        print "EXISTING_TEST_STEP=NO\n";
    }

    $F->COM("create_entity", job=>$job, type=>"step", name=>$target_step);
    $F->COM("open_entity", job=>$job, type=>"step", name=>$target_step, iconic=>"no");
}

my $F = new Valor;
my $v = new Valor_util();

my $job  = $ENV{JOB}  || "";
my $step = $ENV{STEP} || "";
my $panel_step = "panel_auto_xy_test";
my $safe_feature_limit = 10000;
my $minimum_matches = 20;

if ($job eq "" || $step eq "") {
    $F->PAUSE("ERROR: JOB o STEP no estan definidos");
    exit 1;
}

print "\n========================================\n";
print "AUTO PANEL XY COMBINED V01\n";
print "========================================\n";
print "JOB=$job\n";
print "SOURCE_STEP=$step\n";
print "TARGET_STEP=$panel_step\n";

$F->DO_INFO("-t step -e $job/$step -d LAYERS_LIST");
my $layers_ref = $F->{doinfo}{gLAYERS_LIST};
if (!defined($layers_ref) || ref($layers_ref) ne "ARRAY") {
    $F->PAUSE("ERROR: LAYERS_LIST no devolvio un ARRAY");
    exit 1;
}

my @candidates = sort { $a cmp $b } grep { is_fab_drawing($_) } @{$layers_ref};
my @results;

foreach my $layer (@candidates) {
    $v->setWorkLayer($layer);
    $v->resetFilter();
    $F->COM("filter_area_strt");
    $F->COM(
        "filter_area_end",
        layer=>"", filter_name=>"popup", operation=>"select",
        area_type=>"none", inside_area=>"no", intersect_area=>"no",
        lines_only=>"no", ovals_only=>"no",
        min_len=>0, max_len=>0, min_angle=>0, max_angle=>0
    );

    my $selected = $v->getSelectedCount();
    $selected = 0 unless defined $selected;
    print "LAYER=$layer SELECTED=$selected\n";
    next if $selected < 1 || $selected > $safe_feature_limit;

    my @features = $v->getSelectedFeats(internal_name($layer));
    my ($lines_ref, $arcs, $other, $invalid) = parse_lines(\@features);
    my ($axis, $period, $matches) = detect_pitch($lines_ref);
    print "  AXIS=$axis PERIOD=" . (defined($period) ? $period : "NONE") .
          " MATCHES=$matches LINES=" . scalar(@{$lines_ref}) . "\n";
    next unless defined $period;

    push @results, {
        layer=>$layer, axis=>$axis, period=>$period+0,
        matches=>$matches, lines=>$lines_ref
    };
}

@results = sort { $b->{matches} <=> $a->{matches} || $a->{layer} cmp $b->{layer} } @results;

if (!@results || $results[0]->{matches} < $minimum_matches) {
    $F->PAUSE("STOP: No se encontro evidencia suficiente. No se modifico el JOB.");
    exit 0;
}

my $best = $results[0];

print "\n========================================\n";
print "BEST PATTERN\n";
print "========================================\n";
print "BEST_LAYER=$best->{layer}\n";
print "DOMINANT_AXIS=$best->{axis}\n";
print "DOMINANT_PERIOD=$best->{period}\n";
print "DOMINANT_MATCHES=$best->{matches}\n";

if ($best->{axis} eq "Y") {
    my $adjacent_pitch = $best->{period} / 2;
    my $unit_count = 4;

    print "ENGINE=VERTICAL_1X4\n";
    print "ADJACENT_PITCH=$adjacent_pitch\n";

    safe_recreate_step($F, $job, $step, $panel_step);

    $F->COM(
        "sr_tab_add",
        line=>1, step=>$step, x=>0, y=>0,
        nx=>1, ny=>$unit_count, dx=>0, dy=>$adjacent_pitch,
        angle=>0, flip=>"no"
    );

    print "RESULT=CREATED\n";
    print "NX=1 NY=$unit_count DX=0 DY=$adjacent_pitch ANGLE=0\n";
}
elsif ($best->{axis} eq "X") {
    my $region = detect_panel_region($best->{lines});
    if (!defined $region) {
        $F->PAUSE("STOP: No se pudo detectar la region horizontal. No se modifico el JOB.");
        exit 0;
    }

    my $centers = detect_x_rotation_centers($best->{lines}, $region, $best->{period});
    if (!defined $centers || $centers->{left_matches} < 5 || $centers->{right_matches} < 5) {
        $F->PAUSE("STOP: No se confirmaron centros 180. No se modifico el JOB.");
        exit 0;
    }

    my $row_180_x = 2 * $centers->{left_x};
    my $row_180_y = 2 * $centers->{left_y};

    print "ENGINE=HORIZONTAL_2X2\n";
    print "LEFT_CENTER_X=" . sprintf("%.9f", $centers->{left_x}) . "\n";
    print "LEFT_CENTER_Y=" . sprintf("%.9f", $centers->{left_y}) . "\n";
    print "ROW_180_X=" . sprintf("%.9f", $row_180_x) . "\n";
    print "ROW_180_Y=" . sprintf("%.9f", $row_180_y) . "\n";

    safe_recreate_step($F, $job, $step, $panel_step);

    $F->COM(
        "sr_tab_add",
        line=>1, step=>$step, x=>0, y=>0,
        nx=>2, ny=>1, dx=>$best->{period}, dy=>0,
        angle=>0, flip=>"no"
    );

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
    $F->PAUSE("STOP: Eje no soportado. No se modifico el JOB.");
    exit 0;
}

print "\n========================================\n";
print "COMBINED TEST PANEL CREATED\n";
print "========================================\n";
print "PANEL_STEP=$panel_step\n";
print "SOURCE_LAYER=$best->{layer}\n";
print "SOURCE_STEP=$step\n";

$F->PAUSE(
    "Panel automatico combinado creado.\n\n" .
    "Panel: $panel_step\n" .
    "Fab layer: $best->{layer}\n" .
    "Axis: $best->{axis}\n" .
    "Period: $best->{period}\n\n" .
    "VALIDAR visualmente antes de continuar."
);

exit 0;
