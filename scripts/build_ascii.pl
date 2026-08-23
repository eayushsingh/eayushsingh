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

# Generate ASCII at 38 cols x 27 rows
my $out_w = 38;
my $out_h = 27;

# Character density ramp from light to dense
my @charset = split //, q{ .'`:,;~+=-*#%$@};
my $num_chars = scalar @charset;

my $crop_top_pct = 0.10;
my $usable_h = $abs_height * (1.0 - $crop_top_pct);

my @ascii_lines;
my @color_lines; # Store hue/intensity for styling

for my $row (0 .. $out_h - 1) {
    my $line = '';
    my @row_colors;
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
        
        # Segment Subject vs Background:
        my $is_bg = 0;
        
        # 1. Top leaves / background
        if ($row < 2 && ($col < $out_w * 0.35 || $col > $out_w * 0.68)) {
            $is_bg = 1;
        }
        # 2. Right background (ahead of profile)
        elsif ($row < $out_h * 0.55 && $col > $out_w * 0.77) {
            $is_bg = 1;
        }
        elsif ($row < $out_h * 0.42 && $col > $out_w * 0.71 && $lum > 115) {
            $is_bg = 1;
        }
        # 3. Left background (behind neck/hair)
        elsif ($row < $out_h * 0.48 && $col < $out_w * 0.22 && $lum > 110) {
            $is_bg = 1;
        }
        elsif ($row < $out_h * 0.28 && $col < $out_w * 0.28 && $lum > 110) {
            $is_bg = 1;
        }
        # 4. Light neutral background wall
        elsif ($row < $out_h * 0.52 && $lum > 138 && abs($r - $g) < 18 && abs($r - $b) < 18) {
            $is_bg = 1;
        }
        
        if ($is_bg) {
            $line .= ' ';
            push @row_colors, '#000000';
        } else {
            my $norm = 1.0 - ($lum / 255.0);
            $norm = ($norm - 0.18) / (0.85 - 0.18);
            $norm = 0 if $norm < 0;
            $norm = 1 if $norm > 1;
            $norm = $norm ** 1.05;
            
            my $idx = int($norm * ($num_chars - 1));
            $idx = 0 if $idx < 0;
            $idx = $num_chars - 1 if $idx >= $num_chars;
            my $char = $charset[$idx];
            $char = ' ' if $char eq ' ';
            $line .= $char;
            
            # Shading color
            if ($norm > 0.65) {
                push @row_colors, '#58a6ff'; # Hair / deep dark features (bright blue/cyan highlight)
            } elsif ($norm > 0.40) {
                push @row_colors, '#79c0ff'; # Face outline / beard / shadows
            } else {
                push @row_colors, '#c9d1d9'; # Skin highlights
            }
        }
    }
    push @ascii_lines, $line;
}

print "Generated " . scalar(@ascii_lines) . " lines:\n";
for my $i (0 .. $#ascii_lines) {
    printf "%2d: %s\n", $i, $ascii_lines[$i];
}
