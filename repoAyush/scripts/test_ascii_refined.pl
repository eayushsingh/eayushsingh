#!/usr/bin/env perl
use strict;
use warnings;

# Ensure clean crop of Ayush's head, face profile, jawline, neck, and shoulders
system("sips -c 250 195 --cropOffset 50 0 assets/profile.jpg --out assets/subject_crop.jpg >/dev/null 2>&1");
system("sips -s format bmp assets/subject_crop.jpg --out assets/subject_crop.bmp >/dev/null 2>&1");

my $bmp_file = 'assets/subject_crop.bmp';
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

# Generate high-contrast, artistic ASCII portrait (44 cols x 29 rows)
my $out_w = 44;
my $out_h = 29;
# Neofetch character ramp: artistic, dense, distinct
my @charset = split //, q{ .':;=+*#%@};
my $num_chars = scalar @charset;

my $crop_top_pct = 0.05;
my $usable_h = $abs_height * (1.0 - $crop_top_pct);

my @ascii_lines;
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
        
        # High-precision subject segmentation:
        my $is_bg = 0;
        # 1. Top crown boundaries
        if ($row < 2 && ($col < $out_w * 0.32 || $col > $out_w * 0.70)) { $is_bg = 1; }
        # 2. Left side wall (behind hair, ear, neck)
        elsif ($row < $out_h * 0.22 && $col < $out_w * 0.30) { $is_bg = 1; }
        elsif ($row >= $out_h * 0.22 && $row < $out_h * 0.58 && $col < $out_w * 0.30) { $is_bg = 1; }
        elsif ($row >= $out_h * 0.58 && $row < $out_h * 0.65 && $col < $out_w * 0.16) { $is_bg = 1; }
        # 3. Right side wall (in front of nose profile)
        elsif ($row < $out_h * 0.55 && $col > $out_w * 0.76) { $is_bg = 1; }
        elsif ($row < $out_h * 0.42 && $col > $out_w * 0.70 && $lum > 110) { $is_bg = 1; }
        # 4. Background wall threshold
        elsif ($row < $out_h * 0.55 && $lum > 135 && abs($r - $g) < 18 && abs($r - $b) < 18) { $is_bg = 1; }
        
        if ($is_bg) {
            $line .= ' ';
        } else {
            my $norm = 1.0 - ($lum / 255.0);
            $norm = ($norm - 0.14) / (0.86 - 0.14);
            $norm = 0 if $norm < 0;
            $norm = 1 if $norm > 1;
            # Subtle S-curve for high local contrast
            $norm = $norm ** 1.15;
            
            my $idx = int($norm * ($num_chars - 1));
            $idx = 0 if $idx < 0;
            $idx = $num_chars - 1 if $idx >= $num_chars;
            my $char = $charset[$idx];
            
            # Clean boundary artifacts
            if ($char eq '.' || $char eq "'") {
                if ($col < $out_w * 0.30 || $col > $out_w * 0.72) {
                    $char = ' ';
                }
            }
            $line .= $char;
        }
    }
    push @ascii_lines, $line;
}

print "Generated " . scalar(@ascii_lines) . " lines:\n";
for my $i (0 .. $#ascii_lines) {
    printf "%2d: %s\n", $i, $ascii_lines[$i];
}
