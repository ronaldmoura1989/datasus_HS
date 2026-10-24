# =============================================================================
# filtrar_um_hs.R — Filtra UM DBC do DATASUS para o projeto HS (R550-2)
# Adaptado de datasus_EIM/scripts/r550/filtrar_um.R (mesma lógica de checkpoint,
# denominador, texto/UTF-8 e escrita atômica); escopos em config_filtro_hs.R.
#
# Diferenças em relação ao EIM:
#   - só os escopos HS (hit_hs, hit_hs_env, hit_hs_proc);
#   - SIA-PA: linhas só-L02 NÃO são gravadas; viram agregado_env/<ARQ>.parquet
#     (PA_CIDPRI L02 × competência × UF res × sexo × faixa × docorig × grupo do proc.);
#   - SIA-PA: agregado_derm/<ARQ>.parquet = produção de CBO dermatologista
#     (competência × UF res × UF do estabelecimento × docorig × sexo × faixa), base para
#     "proporção da produção dermatológica com L73.2".
#
# Saídas em <out>/<BASE>/: filtrado/, denominador/, agregado_env/ e agregado_derm/ (SIA), ok/
# Uso: Rscript filtrar_um_hs.R --base=SIA-PA --dbc=/caminho/PAPE2101.dbc --out=~/Documentos/ronald/datasus_filtrado_hs
# =============================================================================
suppressPackageStartupMessages({ library(data.table); library(arrow) })

args <- commandArgs(trailingOnly = TRUE)
arg  <- function(k, d = NULL) { m <- grep(paste0("^--", k, "="), args, value = TRUE); if (length(m)) sub(paste0("^--", k, "="), "", m[1]) else d }
BASE <- arg("base"); DBC <- arg("dbc"); OUT <- path.expand(arg("out", "~/Documentos/ronald/datasus_filtrado_hs"))
STATUS_DADO <- arg("status", if (grepl("/PRELIM/", DBC %||% "")) "PRELIM" else "DEFINITIVO")
stopifnot(!is.null(BASE), !is.null(DBC), file.exists(DBC))
stopifnot("não gravar sobre os filtrados do EIM" = basename(OUT) != "datasus_filtrado")

.self <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
source(file.path(dirname(normalizePath(.self)), "config_filtro_hs.R"))

ARQ  <- sub("\\.dbc$", "", basename(DBC), ignore.case = TRUE)
TAM  <- file.size(DBC)
EH_SIA <- BASE == "SIA-PA"
sub_dirs <- c("filtrado", "denominador", "ok", if (EH_SIA) c("agregado_env", "agregado_derm"))
DIRS <- setNames(file.path(OUT, BASE, sub_dirs), sub_dirs)
for (d in DIRS) dir.create(d, recursive = TRUE, showWarnings = FALSE)
f_saida <- setNames(file.path(DIRS[setdiff(sub_dirs, "ok")], paste0(ARQ, ".parquet")), setdiff(sub_dirs, "ok"))
f_ok   <- file.path(DIRS[["ok"]], paste0(ARQ, ".ok"))
f_stat <- file.path(OUT, "status_filtro.tsv")

registrar <- function(st, n_in = NA, n_out = NA, ncol = NA, seg = NA, msg = "") {
  linha <- paste(format(Sys.time(), "%F %T"), st, BASE, ARQ, TAM, n_in, n_out, ncol, seg, gsub("[\t\n]", " ", msg), sep = "\t")
  lk <- paste0(f_stat, ".lock")
  for (i in 1:50) { if (dir.create(lk, showWarnings = FALSE)) break; Sys.sleep(0.1) }   # lock atômico por mkdir
  if (!file.exists(f_stat)) cat("quando\tstatus\tbase\tarquivo\ttamanho_dbc\tn_in\tn_out\tncol\tsegundos\tmsg\n", file = f_stat)
  cat(linha, "\n", sep = "", file = f_stat, append = TRUE); unlink(lk, recursive = TRUE)
}

# Checkpoint: já processado com este mesmo tamanho de DBC
if (file.exists(f_ok) && all(file.exists(f_saida)) &&
    identical(as.numeric(readLines(f_ok, warn = FALSE)[1]), as.numeric(TAM))) quit(status = 0)

# -----------------------------------------------------------------------------
# Metadados do nome do arquivo
# -----------------------------------------------------------------------------
meta_arquivo <- function(arq) {   # PA/RD: {UF}{AA}{MM}[parte] (mensal) · DO: {UF}{AAAA} (anual)
  m <- regmatches(arq, regexec("^(PA|RD)([A-Z]{2})(\\d{2})(\\d{2})([a-z]?)$", arq, ignore.case = TRUE))[[1]]
  if (length(m)) return(list(uf = toupper(m[3]), ano = 2000L + as.integer(m[4]), mes = as.integer(m[5]), parte = tolower(m[6])))
  m <- regmatches(arq, regexec("^(DO|DN)([A-Z]{2})(\\d{4})$", arq, ignore.case = TRUE))[[1]]
  if (length(m)) return(list(uf = toupper(m[3]), ano = as.integer(m[4]), mes = NA_integer_, parte = ""))
  list(uf = NA_character_, ano = NA_integer_, mes = NA_integer_, parte = "")
}
MT <- meta_arquivo(ARQ)
uf_cod <- c("11"="RO","12"="AC","13"="AM","14"="RR","15"="PA","16"="AP","17"="TO","21"="MA","22"="PI","23"="CE",
            "24"="RN","25"="PB","26"="PE","27"="AL","28"="SE","29"="BA","31"="MG","32"="ES","33"="RJ","35"="SP",
            "41"="PR","42"="SC","43"="RS","50"="MS","51"="MT","52"="GO","53"="DF")
uf_de <- function(mun) unname(uf_cod[substr(as.character(mun), 1, 2)])

# Faixa etária quinquenal (anos) — mesma grade do filtro EIM
faixa5 <- function(idade) {
  br <- c(0, 1, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70, 75, 80, Inf)
  lb <- c("<1", "1-4", "5-9", "10-14", "15-19", "20-24", "25-29", "30-34", "35-39", "40-44",
          "45-49", "50-54", "55-59", "60-64", "65-69", "70-74", "75-79", "80+")
  as.character(cut(idade, br, lb, right = FALSE))
}
idade_sim <- function(x) { x <- suppressWarnings(as.integer(x)); u <- x %/% 100; v <- x %% 100
  data.table::fcase(u == 4, as.numeric(v), u == 5, 100 + v, u %in% 0:3, 0, default = NA_real_) }
idade_sia <- function(x) { v <- suppressWarnings(as.numeric(x)); v[!is.na(v) & (v < 0 | v > 110)] <- NA; v }

texto <- function(v) {   # numérico → texto sem notação científica; texto latin1 → UTF-8 (exigido pelo parquet)
  if (is.numeric(v)) { s <- format(v, scientific = FALSE, trim = TRUE, drop0trailing = TRUE); s[is.na(v)] <- NA_character_; return(s) }
  s <- as.character(v); ruim <- !is.na(s) & !validUTF8(s)
  if (any(ruim)) s[ruim] <- iconv(s[ruim], from = "latin1", to = "UTF-8", sub = "?")
  s
}

# -----------------------------------------------------------------------------
# Denominadores (sobre TODAS as linhas, antes do filtro)
# ⚠️ Corrige o filtrar_um.R do EIM: lá as medidas do `j` usavam g("COL"), que devolve
#    a coluna INTEIRA do arquivo, não o subconjunto do grupo → cada estrato recebia a
#    soma do arquivo todo (Σ PA_QTDAPR/PA_VALAPR no SIA; óbitos/diárias no SIH). As
#    contagens .N e uniqueN(N_AIH) não eram afetadas. Aqui as colunas ausentes no ano
#    são criadas como NA e o `j` usa os nomes diretamente (avaliados por grupo).
# -----------------------------------------------------------------------------
garantir_cols <- function(x, cols) {
  for (c in setdiff(cols, names(x))) data.table::set(x, j = c, value = NA_character_)
  invisible(x)
}
denominador <- function(x) {
  switch(BASE,
    "SIA-PA" = { garantir_cols(x, c("PA_QTDAPR", "PA_VALAPR", "PA_CMP", "PA_DOCORIG", "PA_PROC_ID", "PA_MUNPCN"))
      x[, .(linhas = .N, qtd_apr = sum(as.numeric(PA_QTDAPR), na.rm = TRUE),
            val_apr = sum(as.numeric(PA_VALAPR), na.rm = TRUE)),
        by = .(cmp = PA_CMP, docorig = PA_DOCORIG, grupo_proc = substr(PA_PROC_ID, 1, 4),
               uf_res = uf_de(PA_MUNPCN))] },
    "SIH-RD" = { garantir_cols(x, c("MORTE", "DIAS_PERM", "ANO_CMPT", "MES_CMPT", "IDENT", "MUNIC_RES", "MUNIC_MOV", "SEXO"))
      x[, .(aih = uniqueN(N_AIH), obitos = sum(as.integer(MORTE) == 1L, na.rm = TRUE),
            diarias = sum(as.numeric(DIAS_PERM), na.rm = TRUE)),
        by = .(ano_cmpt = ANO_CMPT, mes_cmpt = MES_CMPT, ident = IDENT,
               uf_res = uf_de(MUNIC_RES), uf_mov = uf_de(MUNIC_MOV), sexo = SEXO)] },
    "SIM-DO" = { garantir_cols(x, c("DTOBITO", "CODMUNRES", "SEXO", "IDADE", "CAUSABAS"))
      x[, .(obitos = .N),
        by = .(ano = substr(DTOBITO, 5, 8), uf_res = uf_de(CODMUNRES), sexo = SEXO,
               faixa = faixa5(idade_sim(IDADE)), causabas3 = substr(CAUSABAS, 1, 3))] })
}

# SIA: agregados HS calculados na leitura (o L02 é volumoso demais para linhas)
agregado_sia <- function(x, linhas_sel, extra) {   # extra = estratos além dos comuns
  g <- function(c) if (c %in% names(x)) x[[c]][linhas_sel] else rep(NA_character_, sum(linhas_sel))
  d <- data.table(cmp = g("PA_CMP"), uf_res = uf_de(g("PA_MUNPCN")), sexo = g("PA_SEXO"),
                  faixa = faixa5(idade_sia(g("PA_IDADE"))), docorig = g("PA_DOCORIG"),
                  qtd = as.numeric(g("PA_QTDAPR")))
  for (k in names(extra)) d[[k]] <- extra[[k]](g)
  d[, .(linhas = .N, qtd_apr = sum(qtd, na.rm = TRUE)), by = setdiff(names(d), "qtd")]
}
agregado_env <- function(x) {
  cid <- toupper(trimws(x[["PA_CIDPRI"]]))
  agregado_sia(x, startsWith(cid, "L02") & !is.na(cid),
               list(cid4 = function(g) substr(toupper(trimws(g("PA_CIDPRI"))), 1, 4),
                    grupo_proc = function(g) substr(g("PA_PROC_ID"), 1, 4)))
}
agregado_derm <- function(x) {
  sel <- if ("PA_CBOCOD" %in% names(x)) x[["PA_CBOCOD"]] %chin% CBO_DERM else rep(FALSE, nrow(x))
  agregado_sia(x, sel,
               list(uf_estab = function(g) uf_de(g("PA_UFMUN")),
                    cid_l732 = function(g) startsWith(toupper(trimws(g("PA_CIDPRI"))), "L732")))
}

# -----------------------------------------------------------------------------
# Flags por escopo
# -----------------------------------------------------------------------------
casa_prefixo <- function(v, prefs) {          # v = vetor de códigos; prefixos de tamanhos variados
  v <- toupper(gsub("^\\s+|\\s+$", "", as.character(v), useBytes = TRUE)); hit <- rep(FALSE, length(v))
  for (n in sort(unique(nchar(prefs)))) hit <- hit | (substr(v, 1, n) %chin% prefs[nchar(prefs) == n])
  hit & !is.na(v)
}
flags <- function(x) {
  cc <- intersect(COLS_CID[[BASE]], names(x)); cm <- intersect(COLS_CID_MULTI[[BASE]] %||% character(), names(x))
  cp <- intersect(COLS_PROC[[BASE]], names(x))
  out <- list()
  for (e in names(ESCOPO_CID)) {
    h <- rep(FALSE, nrow(x))
    for (c in cc) h <- h | casa_prefixo(x[[c]], ESCOPO_CID[[e]])
    if (length(cm)) { rx <- regex_multi(ESCOPO_CID[[e]], BASE)
      for (c in cm) h <- h | (grepl(rx, x[[c]], perl = TRUE, useBytes = TRUE, ignore.case = TRUE) & !is.na(x[[c]])) }
    out[[paste0("hit_", e)]] <- h
  }
  for (e in names(ESCOPO_PROC)) {
    h <- rep(FALSE, nrow(x)); for (c in cp) h <- h | casa_prefixo(x[[c]], ESCOPO_PROC[[e]])
    out[[paste0("hit_", e)]] <- h
  }
  as.data.table(out)
}

# -----------------------------------------------------------------------------
# Execução
# -----------------------------------------------------------------------------
meta <- function(d) d[, `:=`(arq = ARQ, arq_uf = MT$uf, arq_ano = MT$ano, arq_mes = MT$mes,
                             arq_parte = MT$parte, status_dado = STATUS_DADO)]
gravar <- function(d, f) { arrow::write_parquet(d, paste0(f, ".tmp"), compression = "zstd"); paste0(f, ".tmp") }

t0 <- Sys.time()
res <- tryCatch({
  x <- data.table::setDT(read.dbc::read.dbc(DBC, as.is = TRUE))
  data.table::setnames(x, toupper(names(x)))
  n_in <- nrow(x); nc <- ncol(x)

  saidas <- list(denominador = meta(denominador(x)))
  if (EH_SIA) {
    saidas$agregado_env  <- meta(agregado_env(x))
    saidas$agregado_derm <- meta(agregado_derm(x))
  }

  fl <- flags(x)
  so_agr <- paste0("hit_", ESCOPO_SO_AGREGADO[[BASE]] %||% character())
  keep <- Reduce(`|`, fl[, setdiff(names(fl), so_agr), with = FALSE])
  y <- x[keep]; fl <- fl[keep]; rm(x); invisible(gc(verbose = FALSE))
  for (c in names(y)) data.table::set(y, j = c, value = texto(y[[c]]))
  saidas$filtrado <- cbind(meta(y), fl)

  tmps <- vapply(names(saidas), function(k) gravar(saidas[[k]], f_saida[[k]]), "")
  file.rename(tmps, sub("\\.tmp$", "", tmps))
  writeLines(as.character(TAM), f_ok)
  list(st = "OK", n_in = n_in, n_out = nrow(y), nc = nc, msg = "")
}, error = function(e) list(st = "ERRO", n_in = NA, n_out = NA, nc = NA, msg = conditionMessage(e)))

registrar(res$st, res$n_in, res$n_out, res$nc, round(as.numeric(difftime(Sys.time(), t0, units = "secs")), 1), res$msg)
quit(status = if (res$st == "OK") 0 else 1)
