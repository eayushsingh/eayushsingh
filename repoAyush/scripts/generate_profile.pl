#!/usr/bin/env perl
use strict;
use warnings;
use File::Path qw(make_path);

my $root_dir = '.';
my $gen_dir  = "$root_dir/generated";
make_path($gen_dir) unless -d $gen_dir;

# 1. Fetch live GitHub metrics using curl
my $username = "eayushsingh";
print "--- [1/3] Fetching Live GitHub Metrics for $username ---\n";
my $user_json = `curl -s "https://api.github.com/users/$username"`;
my ($repos) = $user_json =~ /"public_repos":\s*(\d+)/;
my ($followers) = $user_json =~ /"followers":\s*(\d+)/;
$repos ||= 45;
$followers ||= 13;

my $repos_json = `curl -s "https://api.github.com/users/$username/repos?per_page=100"`;
my $total_stars = 0;
while ($repos_json =~ /"stargazers_count":\s*(\d+)/g) {
    $total_stars += $1;
}
my $stars = ($total_stars > 0) ? "$total_stars" : "1";
print "Metrics: Repos=$repos | Stars=$stars | Followers=$followers\n";

# 2. Crop subject photo and extract pixels
print "--- [2/3] Processing Photograph to ASCII Portrait ---\n";
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

my $out_w = 44;
my $out_h = 29;
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
        
        my $is_bg = 0;
        if ($row < 2 && ($col < $out_w * 0.32 || $col > $out_w * 0.70)) { $is_bg = 1; }
        elsif ($row < $out_h * 0.22 && $col < $out_w * 0.30) { $is_bg = 1; }
        elsif ($row >= $out_h * 0.22 && $row < $out_h * 0.58 && $col < $out_w * 0.30) { $is_bg = 1; }
        elsif ($row >= $out_h * 0.58 && $row < $out_h * 0.65 && $col < $out_w * 0.16) { $is_bg = 1; }
        elsif ($row < $out_h * 0.55 && $col > $out_w * 0.76) { $is_bg = 1; }
        elsif ($row < $out_h * 0.42 && $col > $out_w * 0.70 && $lum > 110) { $is_bg = 1; }
        elsif ($row < $out_h * 0.55 && $lum > 135 && abs($r - $g) < 18 && abs($r - $b) < 18) { $is_bg = 1; }
        
        if ($is_bg) {
            $line .= ' ';
        } else {
            my $norm = 1.0 - ($lum / 255.0);
            $norm = ($norm - 0.14) / (0.86 - 0.14);
            $norm = 0 if $norm < 0;
            $norm = 1 if $norm > 1;
            $norm = $norm ** 1.15;
            my $idx = int($norm * ($num_chars - 1));
            $idx = 0 if $idx < 0;
            $idx = $num_chars - 1 if $idx >= $num_chars;
            my $char = $charset[$idx];
            if (($char eq '.' || $char eq "'" || $char eq '`' || $char eq ':' || $char eq ';') && ($col < $out_w * 0.29 || $col > $out_w * 0.72)) {
                $char = ' ';
            }
            if ($char eq "'" || $char eq '`') {
                $char = ' ';
            }
            $line .= $char;
        }
    }
    push @ascii_lines, $line;
}

sub build_svg_content {
    my ($theme) = @_;
    my $is_dark = ($theme eq 'dark');
    
    my $c_bg        = $is_dark ? "#0d1117" : "#ffffff";
    my $c_header_bg = $is_dark ? "#161b22" : "#f6f8fa";
    my $c_border    = $is_dark ? "#30363d" : "#d0d7de";
    my $c_subtle    = $is_dark ? "#21262d" : "#eaeef2";
    my $c_title     = $is_dark ? "#8b949e" : "#57606a";
    my $c_text      = $is_dark ? "#c9d1d9" : "#24292f";
    my $c_bright    = $is_dark ? "#f0f6fc" : "#1f2328";
    my $c_dim       = $is_dark ? "#7d8590" : "#656d76";
    my $c_leader    = $is_dark ? "#21262d" : "#d0d7de";
    my $c_green     = $is_dark ? "#3fb950" : "#1a7f37";
    my $c_blue      = $is_dark ? "#58a6ff" : "#0969da";
    my $c_section   = $is_dark ? "#79c0ff" : "#0969da";
    my $c_ascii     = $is_dark ? "#c9d1d9" : "#24292f";

    my $w = 880;
    my $h = 640;
    my $split_x = 345;
    my $right_x = 370;

    my $out = qq{<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 $w $h" width="100%" height="100%">
  <defs>
    <style>
      .term-text {
        font-family: 'JetBrains Mono', 'Fira Code', 'Cascadia Mono', 'SF Mono', Menlo, Monaco, Consolas, monospace;
        font-size: 12px;
        fill: $c_text;
      }
      .title {
        font-family: 'JetBrains Mono', 'Fira Code', 'SF Mono', Menlo, monospace;
        font-size: 12px;
        font-weight: 500;
        fill: $c_title;
      }
      .accent-blue { fill: $c_blue; font-weight: 500; }
      .accent-green { fill: $c_green; font-weight: 600; }
      .accent-section { fill: $c_section; font-weight: 600; }
      .text-dim { fill: $c_dim; }
      .text-leader { fill: $c_leader; }
      .text-bright { fill: $c_bright; }
      .ascii-art {
        font-family: 'JetBrains Mono', 'Fira Code', 'SF Mono', Menlo, monospace;
        font-size: 9.8px;
        line-height: 12px;
        fill: $c_ascii;
        white-space: pre;
      }
      .divider { stroke: $c_border; stroke-width: 1; }
      .subtle-divider { stroke: $c_subtle; stroke-width: 1; }
      .cursor { fill: $c_green; animation: blink 1s step-end infinite; }
      \@keyframes blink { 0%, 100% { opacity: 1; } 50% { opacity: 0; } }
    </style>
  </defs>

  <!-- Terminal Window Frame -->
  <rect x="1" y="1" width="878" height="638" rx="6" fill="$c_bg" stroke="$c_border" stroke-width="1" />

  <!-- Minimal Header Bar -->
  <rect x="1" y="1" width="878" height="32" rx="6" fill="$c_header_bg" />
  <rect x="1" y="22" width="878" height="11" fill="$c_header_bg" />
  <line x1="1" y1="33" x2="879" y2="33" class="divider" />

  <!-- Subtle Traffic Lights -->
  <circle cx="18" cy="17" r="4" fill="#ff5f56" />
  <circle cx="32" cy="17" r="4" fill="#ffbd2e" />
  <circle cx="46" cy="17" r="4" fill="#27c93f" />

  <!-- Terminal Title -->
  <text x="440" y="21" text-anchor="middle" class="title">ayushsingh ~</text>

  <!-- Vertical Splitter -->
  <line x1="$split_x" y1="33" x2="$split_x" y2="639" class="divider" />

  <!-- ================= LEFT: ASCII PORTRAIT & CONTACT ================= -->
  <g transform="translate(14, 46)">
    <text class="ascii-art" xml:space="preserve">};

    for my $i (0 .. $#ascii_lines) {
        my $escaped = $ascii_lines[$i];
        $escaped =~ s/&/&amp;/g;
        $escaped =~ s/</&lt;/g;
        $escaped =~ s/>/&gt;/g;
        my $y_pos = 11 + ($i * 12.0);
        $out .= qq{      <tspan x="4" y="$y_pos">$escaped</tspan>\n};
    }

    $out .= qq{    </text>
  </g>

  <!-- Left Separator -->
  <line x1="18" y1="462" x2="327" y2="462" class="subtle-divider" />

  <!-- Contact Block -->
  <g transform="translate(24, 478)" class="term-text">
    <text x="0" y="14" class="accent-section">Contact</text>
    <text x="0" y="26" class="text-dim">──────────────────────────</text>
    <text x="0" y="46" class="text-dim">GitHub:</text>
    <text x="75" y="46" class="text-bright">eayushsingh</text>
    <text x="0" y="66" class="text-dim">LinkedIn:</text>
    <text x="75" y="66" class="text-bright">Ayush Singh</text>
    <text x="0" y="86" class="text-dim">LeetCode:</text>
    <text x="75" y="86" class="text-bright">eayushsingh</text>
  </g>

  <!-- ================= RIGHT: NEOFETCH SPECS & STATS ================= -->
  <g transform="translate($right_x, 46)" class="term-text">
    <!-- Identity Header -->
    <text x="0" y="16" class="accent-green" font-size="14" font-weight="600">ayushsingh</text>
    <text x="100" y="16" class="text-dim" font-size="11">@ github</text>
    <circle cx="165" cy="12" r="3" fill="$c_green" />
    <text x="173" y="16" fill="$c_green" font-size="10">online</text>
    <text x="0" y="28" class="text-dim">─────────────────────────────────────────────────</text>

    <!-- System Info -->
    <text x="0" y="48" class="accent-blue">OS:</text>
    <text x="90" y="48" class="text-bright">macOS / Linux</text>
    <text x="0" y="66" class="accent-blue">Host:</text>
    <text x="90" y="66" class="text-bright">Ayush Singh</text>
    <text x="0" y="84" class="accent-blue">Location:</text>
    <text x="90" y="84" class="text-bright">India 🇮🇳</text>
    <text x="0" y="102" class="accent-blue">IDE:</text>
    <text x="90" y="102" class="text-bright">VS Code</text>
    <text x="0" y="120" class="accent-blue">Role:</text>
    <text x="90" y="120" class="text-bright">AI Engineer · Full-Stack Developer</text>

    <!-- Languages.Programming -->
    <text x="0" y="146" class="accent-section">Languages.Programming</text>
    <text x="0" y="158" class="text-dim">─────────────────────────────────────────────────</text>
    <text x="0" y="174" class="text-bright">Python · Java · JavaScript</text>
    <text x="0" y="190" class="text-bright">TypeScript · SQL</text>

    <!-- Languages.Framework -->
    <text x="0" y="214" class="accent-section">Languages.Framework</text>
    <text x="0" y="226" class="text-dim">─────────────────────────────────────────────────</text>
    <text x="0" y="242" class="text-bright">Next.js · React · Spring Boot</text>
    <text x="0" y="258" class="text-bright">FastAPI</text>

    <!-- Data.Infrastructure -->
    <text x="0" y="282" class="accent-section">Data.Infrastructure</text>
    <text x="0" y="294" class="text-dim">─────────────────────────────────────────────────</text>
    <text x="0" y="310" class="text-bright">PostgreSQL · Supabase · Redis</text>
    <text x="0" y="326" class="text-bright">Docker</text>

    <!-- Focus -->
    <text x="0" y="350" class="accent-section">Focus</text>
    <text x="0" y="362" class="text-dim">─────────────────────────────────────────────────</text>
    <text x="0" y="378" class="text-bright">FinTech · AI · Backend</text>
    <text x="0" y="394" class="text-bright">Distributed Systems</text>

    <!-- GitHub Stats -->
    <text x="0" y="418" class="accent-section">GitHub Stats</text>
    <text x="0" y="430" class="text-dim">─────────────────────────────────────────────────</text>

    <text x="0" y="450" class="text-dim">Repos:</text>
    <text x="110" y="450" class="text-leader">································</text>
    <text x="430" y="450" class="accent-green">$repos</text>

    <text x="0" y="468" class="text-dim">Stars:</text>
    <text x="110" y="468" class="text-leader">································</text>
    <text x="430" y="468" class="accent-green">$stars</text>

    <text x="0" y="486" class="text-dim">Followers:</text>
    <text x="110" y="486" class="text-leader">································</text>
    <text x="430" y="486" class="accent-green">$followers</text>

    <text x="0" y="504" class="text-dim">Commits/yr:</text>
    <text x="110" y="504" class="text-leader">································</text>
    <text x="430" y="504" class="accent-green">LIVE</text>

    <text x="0" y="522" class="text-dim">Contribs/yr:</text>
    <text x="110" y="522" class="text-leader">································</text>
    <text x="430" y="522" class="accent-green">LIVE</text>
    <rect x="472" y="512" width="6.5" height="12" class="cursor" />
  </g>
</svg>};

    return $out;
}

print "--- [3/3] Generating profile-dark.svg and profile-light.svg ---\n";
my $dark_svg = build_svg_content('dark');
open my $dfh, '>', "$gen_dir/profile-dark.svg" or die "Cannot write to $gen_dir/profile-dark.svg: $!";
print $dfh $dark_svg;
close $dfh;
print "Written: $gen_dir/profile-dark.svg\n";

my $light_svg = build_svg_content('light');
open my $lfh, '>', "$gen_dir/profile-light.svg" or die "Cannot write to $gen_dir/profile-light.svg: $!";
print $lfh $light_svg;
close $lfh;
print "Written: $gen_dir/profile-light.svg\n";

open my $tfh, '>', "assets/terminal.svg" or die "Cannot write to assets/terminal.svg: $!";
print $tfh $dark_svg;
close $tfh;
print "Written: assets/terminal.svg\n";

print "Profile generation completed successfully!\n";
