#!/usr/bin/env perl
use strict;
use warnings;

my $bmp_file = $ARGV[0] || 'assets/cropped.bmp';
open my $fh, '<:raw', $bmp_file or die "Cannot open $bmp_file: $!";

# Read BMP Header
my $header;
read($fh, $header, 54) == 54 or die "Invalid BMP header";
my ($magic, $size, $offset) = unpack('v V x4 V', substr($header, 0, 14));
my ($hdr_size, $width, $height, $planes, $bpp) = unpack('V l l v v', substr($header, 14, 16));

my $abs_height = abs($height);
my $row_size = int(($bpp * $width + 31) / 32) * 4;

seek($fh, $offset, 0);
my @pixels; # [y][x] = [r, g, b]

for my $y (0 .. $abs_height - 1) {
    my $row_data;
    read($fh, $row_data, $row_size) == $row_size or die "Error reading row $y";
    for my $x (0 .. $width - 1) {
        my $b = ord(substr($row_data, $x * 3, 1));
        my $g = ord(substr($row_data, $x * 3 + 1, 1));
        my $r = ord(substr($row_data, $x * 3 + 2, 1));
        # if height is positive, BMP is stored bottom-to-top
        my $actual_y = ($height > 0) ? ($abs_height - 1 - $y) : $y;
        $pixels[$actual_y][$x] = [$r, $g, $b];
    }
}
close $fh;

# Generate ASCII at target character grid: e.g., 38 chars wide x 28 chars high
sub generate_ascii {
    my ($out_w, $out_h, $bg_thresh, $contrast, $charset) = @_;
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
            my $avg_r = $total_r / $count;
            my $avg_g = $total_g / $count;
            my $avg_b = $total_b / $count;
            
            # Perceived Luminance
            my $lum = 0.299 * $avg_r + 0.587 * $avg_g + 0.114 * $avg_b;
            
            # Detect background:
            # Wall is off-white/light gray (r,g,b all > 135 and close to each other)
            # Hanging creeper at top (y < height*0.25 and g > r and g > b)
            my $is_bg = 0;
            if ($row < $out_h * 0.22 && ($avg_g > $avg_r + 10 || ($avg_r > 130 && $avg_g > 130 && $avg_b > 130))) {
                # Top vines/wall
                # Only if not dark hair
                if ($lum > 90) { $is_bg = 1; }
            } elsif ($col > $out_w * 0.55 && $row < $out_h * 0.70 && $lum > $bg_thresh) {
                # Right side background wall (to the right of face/neck)
                $is_bg = 1;
            } elsif ($col < $out_w * 0.20 && $row < $out_h * 0.40 && $lum > $bg_thresh) {
                # Left side background wall (behind head)
                $is_bg = 1;
            } elsif ($row < $out_h * 0.55 && $lum > 155 && abs($avg_r - $avg_g) < 25 && abs($avg_r - $avg_b) < 25) {
                $is_bg = 1;
            }
            
            if ($is_bg) {
                $line .= ' ';
            } else {
                # Contrast stretch for dark terminal
                # In dark terminal: dark hair/beard -> dense characters or bright chars?
                # On dark background terminal:
                # To see features: skin/highlights = bright chars (@, %, #, *), shadows/hair = darker chars or vice-versa?
                # Let's test standard ASCII shading:
                my $norm = $lum / 255.0;
                $norm = ($norm - 0.1) / (0.8 - 0.1);
                $norm = 0 if $norm < 0;
                $norm = 1 if $norm > 1;
                $norm = $norm ** $contrast;
                
                my $idx = int((1.0 - $norm) * ($num_chars - 1));
                $idx = 0 if $idx < 0;
                $idx = $num_chars - 1 if $idx >= $num_chars;
                $line .= $chars[$idx];
            }
        }
        push @lines, $line;
    }
    return @lines;
}

print "--- VARIANT 1: Density Shading (38x26) ---\n";
my @v1 = generate_ascii(38, 26, 140, 1.2, q{ .:-=+*#%@});
print join("\n", @v1), "\n\n";

print "--- VARIANT 2: High Contrast (36x28) ---\n";
my @v2 = generate_ascii(36, 28, 145, 1.5, q{ .':;+!*?S#@});
print join("\n", @v2), "\n\n";

print "--- VARIANT 3: Andrew6rant Style (36x26) ---\n";
my @v3 = generate_ascii(36, 26, 140, 1.3, q{ .',:;+=xX$#@});
print join("\n", @v3), "\n\n";
