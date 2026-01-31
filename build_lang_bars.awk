# build_lang_bars.awk  (outputs HTML fragment only; header-driven CSV)

function trim(s){ gsub(/^[ \t\r]+|[ \t\r]+$/, "", s); return s }
function dequote(s){ gsub(/"/, "", s); return s }

function norm(s,    t){
  t = tolower(s)
  t = trim(dequote(t))
  return t
}

function css_class(s,    t) {
  t = tolower(s)
  gsub(/\+\+/, "pp", t)          # C++ -> cpp
  gsub(/[#]/, "sharp", t)        # C#  -> csharp-ish
  gsub(/[^a-z0-9]+/, "-", t)
  gsub(/^-+|-+$/, "", t)
  return "lang-" t
}

function rand_grey(    g) {
  g = 80 + int(rand() * 120)     # 80..199
  return sprintf("#%02x%02x%02x", g, g, g)
}

BEGIN{
  srand()
  # known classes (optional)
  KNOWN["lang-rust"]=1
  KNOWN["lang-c"]=1
  KNOWN["lang-cpp"]=1
  KNOWN["lang-python"]=1
  KNOWN["lang-go"]=1
  KNOWN["lang-javascript"]=1
  KNOWN["lang-typescript"]=1
  KNOWN["lang-shell"]=1
  KNOWN["lang-html"]=1
  KNOWN["lang-css"]=1
  KNOWN["lang-lua"]=1
  KNOWN["lang-java"]=1
  KNOWN["lang-kotlin"]=1
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
  # strip quotes + trim from all fields
  for (i=1; i<=NF; i++){
    $i = trim(dequote($i))
  }

  # fall back if header didn’t match (last resort)
  if (!lang_i) lang_i = 2
  if (!comment_i) comment_i = NF-1
  if (!code_i) code_i = NF

  lang = $(lang_i)
  if (lang == "C/C++ Header") lang = "C++"

  # skip these rows exactly
  if (lang == "Text" || lang == "SUM") next

  cmt = $(comment_i)
  cod = $(code_i)
  if (cmt !~ /^[0-9]+$/ || cod !~ /^[0-9]+$/) next

  total = cmt + cod
  if (total < 1) next

  SUM[lang] += total
}

END{
  n = 0
  maxlg = 0
  for (lang in SUM) {
    total = SUM[lang]
    if (total < 1) continue
    n++
    L[n] = lang
    T[n] = total
    G[n] = total # log(total + 1) / log(10)
    if (G[n] > maxlg) maxlg = G[n]
  }
  
  if (n < 1){
    print "<!-- no rows matched: check cloc CSV header/columns -->"
    exit
  }
  if (maxlg <= 0) maxlg = 1

  # sort indices by total desc
  for (i=1; i<=n; i++) idx[i]=i
  for (i=1; i<=n; i++)
    for (j=i+1; j<=n; j++)
      if (T[idx[j]] > T[idx[i]]) { tmp=idx[i]; idx[i]=idx[j]; idx[j]=tmp }

  print "<link rel=\"stylesheet\" href=\"lang_bars.css\">"
  print "<table class=\"bars\">"
  print "<thead><tr><th>Language distribution</th></tr></thead>"
  print "<tbody>"

  for (k=1; k<=n; k++){
    i = idx[k]
    pct = (G[i] / maxlg) * 100
    if (pct < 1) pct = 1

    cls = css_class(L[i])

    printf "<tr><td class=\"barcell\">"
    if (KNOWN[cls]) {
      printf "<div class=\"bar %s\" title=\"%d\" style=\"width:%.2f%%\"></div>", cls, T[i], pct
    } else {
      grey = rand_grey()
      printf "<div class=\"bar\" title=\"%d\" style=\"width:%.2f%%;background:%s\"></div>", T[i], pct, grey
    }
    printf "<div class=\"label\">%s</div>", L[i]
    print "</td></tr>"
  }

  print "</tbody></table>"
}
