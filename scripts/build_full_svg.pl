#!/usr/bin/env perl
use strict;
use warnings;

my $repos_count     = $ARGV[0] || "45";
my $stars_count     = $ARGV[1] || "★";
my $followers_count = $ARGV[2] || "14";

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

my $out_w = 38;
my $out_h = 28;

my @charset = split //, q{ .::;~+=-*#%$@@};
my $num_chars = scalar @charset;

my $crop_top_pct = 0.08;
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
        
        # Rigorous Subject Segmentation:
        my $is_bg = 0;
        
        # 1. Crown & Top
        if ($row < 3 && ($col < 13 || $col > 26)) {
            $is_bg = 1;
        }
        # 2. Left side contour (behind hair, ear, neck)
        elsif ($row < 7 && $col < 12) {
            $is_bg = 1;
        }
        elsif ($row >= 7 && $row < 16 && $col < 12) {
            $is_bg = 1; # Clean background shadow behind ear/neck
        }
        elsif ($row >= 16 && $row < 18 && $col < 7) {
            $is_bg = 1;
        }
        # 3. Right side contour (in front of nose profile)
        elsif ($row < 15 && $col > 28) {
            $is_bg = 1;
        }
        elsif ($row < 12 && $col > 27 && $lum > 110) {
            $is_bg = 1;
        }
        # 4. Background wall
        elsif ($row < 16 && $lum > 130 && abs($r - $g) < 20 && abs($r - $b) < 20) {
            $is_bg = 1;
        }
        
        if ($is_bg) {
            $line .= ' ';
        } else {
            my $norm = 1.0 - ($lum / 255.0);
            $norm = ($norm - 0.16) / (0.85 - 0.16);
            $norm = 0 if $norm < 0;
            $norm = 1 if $norm > 1;
            $norm = $norm ** 1.05;
            
            my $idx = int($norm * ($num_chars - 1));
            $idx = 0 if $idx < 0;
            $idx = $num_chars - 1 if $idx >= $num_chars;
            my $char = $charset[$idx];
            
            # Ensure outer boundary characters are clean
            if ($char eq '.' || $char eq ':') {
                if ($col < 12 || $col > 27) {
                    $char = ' ';
                }
            }
            $line .= $char;
        }
    }
    push @ascii_lines, $line;
}

# Construct SVG with generous vertical height (660px) and clean margins
my $svg = qq{<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 880 660" width="100%" height="100%">
  <defs>
    <linearGradient id="bgGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#0c1017" />
      <stop offset="100%" stop-color="#121820" />
    </linearGradient>
    <linearGradient id="headerGrad" x1="0%" y1="0%" x2="100%" y2="0%">
      <stop offset="0%" stop-color="#161b22" />
      <stop offset="100%" stop-color="#21262d" />
    </linearGradient>
    <linearGradient id="borderGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#58a6ff" stop-opacity="0.7" />
      <stop offset="50%" stop-color="#bc8cff" stop-opacity="0.4" />
      <stop offset="100%" stop-color="#3fb950" stop-opacity="0.6" />
    </linearGradient>
    <style>
      .term-text {
        font-family: 'JetBrains Mono', 'Fira Code', 'SF Mono', Menlo, Monaco, Consolas, 'Courier New', monospace;
        font-size: 13px;
        fill: #c9d1d9;
      }
      .title {
        font-family: 'JetBrains Mono', 'Fira Code', 'SF Mono', Menlo, Monaco, Consolas, monospace;
        font-size: 13px;
        font-weight: 600;
        fill: #8b949e;
      }
      .accent-blue { fill: #58a6ff; font-weight: 600; }
      .accent-green { fill: #3fb950; font-weight: 600; }
      .accent-purple { fill: #bc8cff; font-weight: 600; }
      .accent-yellow { fill: #e3b341; font-weight: 600; }
      .accent-cyan { fill: #39c5cf; font-weight: 600; }
      .text-dim { fill: #6e7681; }
      .text-bright { fill: #f0f6fc; font-weight: 600; }
      .ascii-art {
        font-family: 'JetBrains Mono', 'Fira Code', 'SF Mono', Menlo, monospace;
        font-size: 11px;
        line-height: 13.5px;
        fill: #58a6ff;
        white-space: pre;
      }
      .divider { stroke: #30363d; stroke-width: 1; }
      .cursor {
        animation: blink 1s step-end infinite;
        fill: #58a6ff;
      }
      \@keyframes blink {
        0%, 100% { opacity: 1; }
        50% { opacity: 0; }
      }
    </style>
  </defs>

  <!-- Window Frame -->
  <rect x="2" y="2" width="876" height="656" rx="10" fill="url(#bgGrad)" stroke="url(#borderGrad)" stroke-width="1.5" />

  <!-- Terminal Header Bar -->
  <rect x="2" y="2" width="876" height="38" rx="10" fill="url(#headerGrad)" />
  <rect x="2" y="28" width="876" height="12" fill="url(#headerGrad)" />
  <line x1="2" y1="40" x2="878" y2="40" stroke="#30363d" stroke-width="1" />

  <!-- macOS Window Controls -->
  <circle cx="24" cy="20" r="6" fill="#ff5f56" />
  <circle cx="44" cy="20" r="6" fill="#ffbd2e" />
  <circle cx="64" cy="20" r="6" fill="#27c93f" />

  <!-- Title -->
  <text x="440" y="25" text-anchor="middle" class="title">ayushsingh ~ terminal</text>

  <!-- Vertical Divider (Left / Right Column Split) -->
  <line x1="335" y1="40" x2="335" y2="658" class="divider" />

  <!-- ================= LEFT COLUMN: ASCII PORTRAIT & CONTACT ================= -->
  <g transform="translate(18, 55)">
    <text class="ascii-art" xml:space="preserve">};

for my $i (0 .. $#ascii_lines) {
    my $line_content = $ascii_lines[$i];
    # XML Escape
    $line_content =~ s/&/&amp;/g;
    $line_content =~ s/</&lt;/g;
    $line_content =~ s/>/&gt;/g;
    
    my $y_pos = 14 + ($i * 13.5);
    # Balanced tonal palette for hair, face, and attire
    my $color = "#58a6ff";
    if ($i < 6) { $color = "#79c0ff"; }      # Hair
    elsif ($i < 13) { $color = "#a5d6ff"; }  # Facial profile & beard
    elsif ($i < 18) { $color = "#79c0ff"; }  # Neck & collar
    else { $color = "#58a6ff"; }             # Kurta & shoulders
    
    $svg .= qq{<tspan x="6" y="$y_pos" fill="$color">$line_content</tspan>\n};
}

$svg .= qq{    </text>
  </g>

  <!-- Left Column Separator -->
  <line x1="20" y1="465" x2="315" y2="465" class="divider" />

  <!-- Contact Block -->
  <g transform="translate(25, 485)" class="term-text">
    <text x="0" y="14" class="accent-cyan">Contact</text>
    <text x="0" y="28" class="text-dim">──────────────────────────</text>
    
    <text x="0" y="50" class="text-dim">GitHub:   </text>
    <text x="75" y="50" class="text-bright">eayushsingh</text>
    
    <text x="0" y="74" class="text-dim">LinkedIn: </text>
    <text x="75" y="74" class="text-bright">Ayush Singh</text>
    
    <text x="0" y="98" class="text-dim">LeetCode: </text>
    <text x="75" y="98" class="text-bright">eayushsingh</text>

    <text x="0" y="122" class="text-dim">Twitter:  </text>
    <text x="75" y="122" class="text-bright">\@eAyyushhSingh</text>
  </g>

  <!-- ================= RIGHT COLUMN: RECRUITER SPECS ================= -->
  <g transform="translate(360, 55)" class="term-text">
    <!-- Header -->
    <text x="0" y="20" class="accent-green" font-size="16">eayushsingh</text>
    <text x="110" y="20" class="text-dim" font-size="12">@ github</text>
    <circle cx="178" cy="15" r="4" fill="#3fb950" />
    <text x="188" y="19" fill="#3fb950" font-size="11">online</text>
    <text x="0" y="38" class="text-dim">─────────────────────────────────────────────────</text>

    <!-- System Info -->
    <text x="0" y="62" class="accent-blue">OS:</text>
    <text x="95" y="62" class="text-bright">Linux / macOS</text>

    <text x="0" y="84" class="accent-blue">Host:</text>
    <text x="95" y="84" class="text-bright">Ayush Singh</text>

    <text x="0" y="106" class="accent-blue">Location:</text>
    <text x="95" y="106" class="text-bright">India 🇮🇳</text>

    <text x="0" y="128" class="accent-blue">IDE:</text>
    <text x="95" y="128" class="text-bright">VS Code</text>

    <text x="0" y="150" class="accent-blue">Role:</text>
    <text x="95" y="150" class="text-bright">AI Eng · Full-Stack</text>

    <!-- Languages.Programming -->
    <text x="0" y="184" class="accent-purple">Languages.Programming</text>
    <text x="0" y="198" class="text-dim">─────────────────────────────────────────────────</text>
    <text x="0" y="218" class="text-bright">Python · Java · TypeScript</text>
    <text x="0" y="238" class="text-bright">JavaScript · SQL</text>

    <!-- Languages.Framework -->
    <text x="0" y="272" class="accent-purple">Languages.Framework</text>
    <text x="0" y="286" class="text-dim">─────────────────────────────────────────────────</text>
    <text x="0" y="306" class="text-bright">Next.js · React · FastAPI</text>
    <text x="0" y="326" class="text-bright">Spring Boot</text>

    <!-- Focus -->
    <text x="0" y="360" class="accent-yellow">Focus</text>
    <text x="0" y="374" class="text-dim">─────────────────────────────────────────────────</text>
    <text x="0" y="394" class="text-bright">FinTech · AI · Backend</text>
    <text x="0" y="414" class="text-bright">Distributed Systems</text>

    <!-- GitHub Stats -->
    <text x="0" y="448" class="accent-cyan">GitHub Stats</text>
    <text x="0" y="462" class="text-dim">─────────────────────────────────────────────────</text>
    
    <text x="0" y="484" class="text-dim">Repos:</text>
    <text x="110" y="484" class="text-dim">································</text>
    <text x="440" y="484" class="accent-green">$repos_count LIVE</text>

    <text x="0" y="506" class="text-dim">Stars:</text>
    <text x="110" y="506" class="text-dim">································</text>
    <text x="440" y="506" class="accent-green">$stars_count LIVE</text>

    <text x="0" y="528" class="text-dim">Followers:</text>
    <text x="110" y="528" class="text-dim">································</text>
    <text x="440" y="528" class="accent-green">$followers_count LIVE</text>

    <text x="0" y="550" class="text-dim">Commits/yr:</text>
    <text x="110" y="550" class="text-dim">································</text>
    <text x="440" y="550" class="accent-green">LIVE</text>

    <text x="0" y="572" class="text-dim">Contribs/yr:</text>
    <text x="110" y="572" class="text-dim">································</text>
    <text x="440" y="572" class="accent-green">LIVE</text>
    <rect x="480" y="561" width="8" height="14" class="cursor" />
  </g>
</svg>
};

open my $out_fh, '>', 'assets/terminal.svg' or die "Cannot write to assets/terminal.svg: $!";
print $out_fh $svg;
close $out_fh;

print "Successfully wrote assets/terminal.svg (Repos: $repos_count, Stars: $stars_count, Followers: $followers_count)!\n";
