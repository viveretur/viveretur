# build_lang_bars_svg.awk
# Input: cloc --csv (comma-separated), via awk -F','
# Output: standalone SVG (for embedding in README)

function trim(s){ gsub(/^[ \t\r]+|[ \t\r]+$/, "", s); return s }
function dequote(s){ gsub(/"/, "", s); return s }
function norm(s){ s=tolower(trim(dequote(s))); return s }

function xml_escape(s){
  gsub(/&/, "&amp;", s)
  gsub(/</, "&lt;", s)
  gsub(/>/, "&gt;", s)
  gsub(/"/, "&quot;", s)
  gsub(/'\''/, "&apos;", s)
  return s
}

function css_color(lang, total,    l, g){
  l = tolower(lang)
  # A small mapping (extend as you like)
  if (l == "rust") return "#dea584"
  if (l == "c") return "#555555"
  if (l == "c++") return "#f34b7d"
  if (l == "python") return "#3572A5"
  if (l == "go") return "#00ADD8"
  if (l == "javascript") return "#f1e05a"
  if (l == "typescript") return "#3178c6"
  if (l == "shell") return "#89e051"
  if (l == "html") return "#e34c26"
  if (l == "css") return "#563d7c"
  if (l == "lua") return "#000080"
  if (l == "java") return "#b07219"
  if (l == "kotlin") return "#a97bff"

  # deterministic grey for unknown languages
  g = 80 + ((total * 37) % 120)    # 80..199
  return sprintf("#%02x%02x%02x", g, g, g)
}

BEGIN{
  # SVG layout constants
  W = 980
  PAD = 2
  HEADER_H = 42
  ROW_H = 28
  BAR_H = 28
  RX = 10

  # Styling
  BG = "#2b2f34"        # page background (dark neutral)
  CARD = "#353a40"      # table background
  HEAD = "#000000"      # header background
  HEAD_TXT = "#ffffff"  # header text
  TXT = "#f0f0f0"       # label text

  # Rows
  TOP = 10
  LINE_H = 18          # line height for Others row
  OTHER_FSIZE = 14
  MAX_CHARS = 135      # wrap width heuristic; tune for your SVG width/font

  # Scaling: set to 1 for log scale, 0 for linear scale
  USE_LOG = 0
}

NR==1{
  # discover column indices from header
  for (i=1; i<=NF; i++){
    h = norm($i)
    if (h == "language") lang_i = i
    else if (h == "comment") comment_i = i
    else if (h == "code") code_i = i
  }
  next
}

{
  for (i=1; i<=NF; i++){
    $i = trim(dequote($i))
  }

  if (!lang_i) lang_i = 2
  if (!comment_i) comment_i = NF-1
  if (!code_i) code_i = NF

  lang = $(lang_i)

  # Skip requested rows
  if (lang == "Text" || lang == "SUM") next

  # Merge before summing
  if (lang == "C/C++ Header") lang = "C++"

  cmt = $(comment_i)
  cod = $(code_i)
  if (cmt !~ /^[0-9]+$/ || cod !~ /^[0-9]+$/) next

  total = cmt + cod
  if (total < 1) next

  SUM[lang] += total
}

END{
  # Materialize into arrays
  n = 0
  maxv = 0
  for (lang in SUM){
    total = SUM[lang]
    n++
    L[n] = lang
    T[n] = total

    if (USE_LOG) V[n] = log(total + 1) / log(10)   # log10(total+1)
    else         V[n] = total                      # linear

    if (V[n] > maxv) maxv = V[n]
  }

  if (n < 1){
    print "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
    print "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"800\" height=\"60\">"
    print "<text x=\"10\" y=\"35\" font-family=\"system-ui,Segoe UI,Roboto,Helvetica,Arial\" font-size=\"16\">No data</text>"
    print "</svg>"
    exit
  }
  if (maxv <= 0) maxv = 1

  # Sort indices by total desc
  for (i=1; i<=n; i++) idx[i]=i
  for (i=1; i<=n; i++)
    for (j=i+1; j<=n; j++)
      if (T[idx[j]] > T[idx[i]]) { tmp=idx[i]; idx[i]=idx[j]; idx[j]=tmp }

  TOP = 10 # Set most used.
  topn = (n < TOP ? n : TOP)
  has_others = (n > TOP ? 1 : 0)

  # Build wrapped Others lines (if needed) so we can size the SVG/card correctly
  other_lines = 0
  if (has_others) {
    m = 0
    for (k = TOP+1; k <= n; k++) { i = idx[k]; R[++m] = L[i] }
    asort(R)

    # Build one long string: "Others: A, B, C, ..."
    others = "Others: "
    for (j = 1; j <= m; j++) {
      s = xml_escape(R[j])
      others = others (j==1 ? "" : ", ") s
    }

    # Wrap by words into OL[1..other_lines]
    split("", OL); other_lines = 1
    OL[1] = ""
    split(others, WDS, /[ ]+/)

    for (w = 1; w <= length(WDS); w++) {
      word = WDS[w]
      trial = (OL[other_lines] == "" ? word : OL[other_lines] " " word)

      if (length(trial) > MAX_CHARS && OL[other_lines] != "") {
        other_lines++
        OL[other_lines] = word
      } else {
        OL[other_lines] = trial
      }
    }
  }

  rows_bars = topn
  rows_text = (has_others ? other_lines : 0)

  H = PAD + HEADER_H + (rows_bars * ROW_H) + (rows_text * LINE_H) + PAD

  # Bar area: leave some space for left padding; bars still start at left edge of card content
  BAR_X = PAD + 0
  BAR_W = W - (2*PAD)

  print "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
  printf "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 %d %d\" preserveAspectRatio=\"xMinYMin meet\">\n", W, H

  # Card
  SW = 1
  OFF = SW/2
  printf "<rect x=\"%.1f\" y=\"%.1f\" width=\"%.1f\" height=\"%.1f\" rx=\"%d\" ry=\"%d\" fill=\"%s\" stroke=\"#ffffff\" stroke-width=\"%d\"/>\n",
       PAD - OFF, PAD - OFF, (W - 2*PAD) + SW, (H - 2*PAD) + SW, RX, RX, CARD, SW

  # Header bar (inside card, rounded top)
  printf "<rect x=\"%d\" y=\"%d\" width=\"%d\" height=\"%d\" rx=\"%d\" ry=\"%d\" fill=\"%s\"/>\n", PAD, PAD, W-(2*PAD), HEADER_H, RX, RX, HEAD
  # Square off the bottom corners by overlaying a flat strip on the lower part
  printf "<rect x=\"%d\" y=\"%d\" width=\"%d\" height=\"%d\" fill=\"%s\"/>\n", PAD, PAD + RX, W-(2*PAD), HEADER_H - RX, HEAD
  printf "<text x=\"%d\" y=\"%d\" fill=\"%s\" font-family=\"system-ui,Segoe UI,Roboto,Helvetica,Arial\" font-size=\"18\" font-weight=\"600\">Linguae</text>\n",
       PAD+12, PAD+26, HEAD_TXT

  # Render top N bars
  for (k=1; k<=topn; k++){
    i = idx[k]
    y0 = PAD + HEADER_H + (k-1)*ROW_H   # (use your gapless y0 formula)

    frac = V[i] / maxv
    if (frac < 0.01) frac = 0.01
    bw = int(frac * BAR_W)

    col = css_color(L[i], T[i])
    label = xml_escape(L[i])

    printf "<g>\n"

    # visible bar first
    printf "  <rect x=\"%d\" y=\"%d\" width=\"%d\" height=\"%d\" rx=\"4\" ry=\"4\" fill=\"%s\"/>\n", BAR_X, y0, bw, BAR_H, col

    # label (optional: make it not intercept hover)
    printf "  <text x=\"%d\" y=\"%d\" fill=\"%s\" font-family=\"system-ui,Segoe UI,Roboto,Helvetica,Arial\" font-size=\"16\" dominant-baseline=\"middle\" pointer-events=\"none\">%s</text>\n",
           BAR_X+8, y0 + BAR_H/2, TXT, label

    # hitbox LAST so it catches hover everywhere (including over the bar)
    printf "  <rect x=\"%d\" y=\"%d\" width=\"%d\" height=\"%d\" fill=\"transparent\" pointer-events=\"all\">\n", BAR_X, y0, BAR_W, BAR_H
    printf "    <title>%s: %d</title>\n", label, T[i]
    printf "  </rect>\n"

    printf "</g>\n"

  }

  # Final "Others" row (no bar), languages alphabetical
  if (has_others) {
    # y position starts immediately after the last bar row
    base_y = PAD + HEADER_H + (topn * ROW_H)

    # Multi-line text block
    printf "<text x=\"%d\" y=\"%d\" fill=\"%s\" font-family=\"system-ui,Segoe UI,Roboto,Helvetica,Arial\" font-size=\"%d\">\n",
         BAR_X+8, base_y + (LINE_H * 0.75), TXT, OTHER_FSIZE

    for (ln = 1; ln <= other_lines; ln++) {
      dy = (ln == 1 ? 0 : LINE_H)
      printf "  <tspan x=\"%d\" dy=\"%d\">%s</tspan>\n", BAR_X+8, dy, OL[ln]
    }

    print "</text>"
  }


  print "</svg>"
}
