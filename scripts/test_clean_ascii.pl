#!/usr/bin/env perl
use strict;
use warnings;

my $bmp_file = 'assets/cropped_tight.bmp';
open my $fh, '<:raw', $bmp_file or die "Cannot open $bmp_file: $!";

my $header;
read($fh, $header, 54) == 54 or die "Invalid BMP header";
my ($hdr_size, $width, $height, $planes, $bpp) = unpack('V l l v v', substr($header, 14, 16));
my $abs_height = abs($height);
my $row_size = int(($bpp * $width + 31) / 32) * 4;

seek($fh, 54, 0);
my @pixels;

for my $y (0 .. $abs_height - 1) {
    my $row_data;
    read($fh, $row_data, $row_size) == $row_size or die "Error reading row $y";
    for my $x (0 .. $width - 1) {
        my $b = ord(substr($row_data, $x * 3, 1));
        my $g = ord(substr($row_data, $x * 3 + 1, 1));
        my $r = ord(substr($row_data, $x * 3 + 2, 1));
        my $actual_y = ($height > 0) ? ($abs_height - 1 - $y) : $y;
        $pixels[$actual_y][$x] = [$r, $g, $b];
    }
}
close $fh;

# Targeted ASCII generator with precise hair & face segmentation
sub render_clean_portrait {
    my ($out_w, $out_h) = @_;
    my @charset = split //, q{ .'`:,;~+=-*#%$@};
    my $num_chars = scalar @charset;
    
    my @lines;
    # Start sampling from crown of hair (ignore top 12% background leaves)
    my $crop_top_pct = 0.12;
    my $usable_h = $abs_height * (1.0 - $crop_top_pct);
    
    for my $row (0 .. $out_h - 1) {
        my $line = '';
        my $y_start = int($abs_height * $crop_top_pct + $row * $usable_h / $out_h);
        my $y_end   = int($abs_height * $crop_top_pct + ($row + 1) * $usable_h / $out_h);
        
        for my $col (0 .. $out_w - 1) {
            my $x_start = int($col * $width / $out_w);
            my $x_end   = int(($col + 1) * $width / $out_w);
            
            my ($total_r, $total_g, $total_b, $count) = (0, 0, 0, 0);
            for my $y ($y_start .. $y_end - 1) {
                for my $x ($x_start .. $x_end - 1) {
                    my ($r, $g, $b) = @{$pixels[$y][$x]};
                    $total_r += $r;
                    $total_g += $g;
                    $total_b += $b;
                    $count++;
                }
            }
            next if $count == 0;
            my $r = $total_r / $count;
            my $g = $total_g / $count;
            my $b = $total_b / $count;
            my $lum = 0.299 * $r + 0.587 * $g + 0.114 * $b;
            
            # Subject vs Background test:
            my $is_bg = 0;
            
            # 1. Top background (above crown)
            if ($row < 2 && ($col < $out_w * 0.35 || $col > $out_w * 0.70)) {
                $is_bg = 1;
            }
            # 2. Right background (in front of face / nose / chest)
            elsif ($row < $out_h * 0.58 && $col > $out_w * 0.78) {
                $is_bg = 1;
            }
            elsif ($row < $out_h * 0.45 && $col > $out_w * 0.72 && $lum > 115) {
                $is_bg = 1;
            }
            # 3. Left background (behind ear / neck)
            elsif ($row < $out_h * 0.50 && $col < $out_w * 0.24 && $lum > 110) {
                $is_bg = 1;
            }
            elsif ($row < $out_h * 0.30 && $col < $out_w * 0.30 && $lum > 110) {
                $is_bg = 1;
            }
            # 4. General wall luminance
            elsif ($row < $out_h * 0.55 && $lum > 140 && abs($r - $g) < 20 && abs($r - $b) < 20) {
                $is_bg = 1;
            }
            
            if ($is_bg) {
                $line .= ' ';
            } else {
                # Contrast mapping
                # Hair is dark (<70), face is medium (80-140), highlights (>140), shirt (patterned magenta)
                my $norm = 1.0 - ($lum / 255.0);
                # Stretch contrast
                $norm = ($norm - 0.20) / (0.85 - 0.20);
                $norm = 0 if $norm < 0;
                $norm = 1 if $norm > 1;
                $norm = $norm ** 1.1; # gamma
                
                my $idx = int($norm * ($num_chars - 1));
                $idx = 0 if $idx < 0;
                $idx = $num_chars - 1 if $idx >= $num_chars;
                $line .= $charset[$idx];
            }
        }
        push @lines, $line;
    }
    return @lines;
}

print "--- CLEAN PORTRAIT (32 cols x 24 rows) ---\n";
my @p24 = render_clean_portrait(32, 24);
print join("\n", @p24), "\n\n";

print "--- CLEAN PORTRAIT (34 cols x 26 rows) ---\n";
my @p26 = render_clean_portrait(34, 26);
print join("\n", @p26), "\n\n";

print "--- CLEAN PORTRAIT (36 cols x 28 rows) ---\n";
my @p28 = render_clean_portrait(36, 28);
print join("\n", @p28), "\n\n";
