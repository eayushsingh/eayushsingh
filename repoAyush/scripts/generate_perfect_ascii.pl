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

# Generate ASCII at grid size W x H
sub render_art {
    my ($out_w, $out_h, $mode, $charset) = @_;
    my @chars = split //, $charset;
    my $num_chars = scalar @chars;
    
    my @lines;
    for my $row (0 .. $out_h - 1) {
        my $line = '';
        my $y_start = int($row * $abs_height / $out_h);
        my $y_end   = int(($row + 1) * $abs_height / $out_h);
        
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
            
            # Smart Background Removal (Wall & Plant leaves)
            my $is_bg = 0;
            # Wall detection: high luminance + low color saturation (gray/white wall)
            my $max_c = ($r > $g) ? (($r > $b) ? $r : $b) : (($g > $b) ? $g : $b);
            my $min_c = ($r < $g) ? (($r < $b) ? $r : $b) : (($g < $b) ? $g : $b);
            my $saturation = ($max_c > 0) ? ($max_c - $min_c) / $max_c : 0;
            
            # Head bounding box roughly: row < 0.6*out_h, col between 0.2*out_w and 0.85*out_w
            # Top-left corner leaves: col < 0.3*out_w, row < 0.35*out_h, g > r
            if ($row < $out_h * 0.35 && $col < $out_w * 0.35 && $g > $r) {
                $is_bg = 1; # top-left leaves
            } elsif ($row < $out_h * 0.65 && $col > $out_w * 0.78 && $lum > 110) {
                $is_bg = 1; # right wall
            } elsif ($row < $out_h * 0.55 && $col < $out_w * 0.22 && $lum > 120) {
                $is_bg = 1; # left wall
            } elsif ($row < $out_h * 0.65 && $lum > 140 && $saturation < 0.18) {
                $is_bg = 1; # generic wall
            } elsif ($row < $out_h * 0.10 && $col > $out_w * 0.65 && $lum > 100) {
                $is_bg = 1;
            }
            
            if ($is_bg) {
                $line .= ' ';
            } else {
                my $val;
                if ($mode eq 'photo_dense') {
                    # Dark hair/shadows -> dense chars, skin -> medium, bright highlights -> light chars
                    my $norm = 1.0 - ($lum / 255.0);
                    $norm = ($norm - 0.2) / (0.85 - 0.2);
                    $norm = 0 if $norm < 0;
                    $norm = 1 if $norm > 1;
                    my $idx = int($norm * ($num_chars - 1));
                    $line .= $chars[$idx];
                } elsif ($mode eq 'light_on_dark') {
                    # Bright features -> dense chars
                    my $norm = ($lum / 255.0);
                    $norm = ($norm - 0.15) / (0.8 - 0.15);
                    $norm = 0 if $norm < 0;
                    $norm = 1 if $norm > 1;
                    my $idx = int($norm * ($num_chars - 1));
                    $line .= $chars[$idx];
                } elsif ($mode eq 'detailed') {
                    # Fine character gradient
                    my $norm = 1.0 - ($lum / 255.0);
                    $norm = $norm ** 1.3;
                    my $idx = int($norm * ($num_chars - 1));
                    $line .= $chars[$idx];
                }
            }
        }
        push @lines, $line;
    }
    return @lines;
}

print "=== OPTION 1: Andrew6rant Classic Shading (34x27) ===\n";
my @opt1 = render_art(34, 27, 'photo_dense', q{ .':-=+*#%@});
print join("\n", @opt1), "\n\n";

print "=== OPTION 2: High Definition Monospace (36x28) ===\n";
my @opt2 = render_art(36, 28, 'photo_dense', q{ .`',:;+!*?S#@});
print join("\n", @opt2), "\n\n";

print "=== OPTION 3: Clean Stylized Silhouette (32x26) ===\n";
my @opt3 = render_art(32, 26, 'photo_dense', q{ .'`,:;+=xX$#@});
print join("\n", @opt3), "\n\n";
