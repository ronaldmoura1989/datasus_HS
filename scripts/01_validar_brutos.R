# =============================================================================
# 01_validar_brutos.R — Validação dos brutos transferidos para data/raw/
# Confirma grade completa, objeto/colunas, filtro por CID e contagens de HS.
# Autossuficiente: NÃO chama ensure_pkg (não precisa de microdatasus aqui).
# Roda: Rscript scripts/01_validar_brutos.R   (a partir da raiz do projeto)
# =============================================================================

suppressPackageStartupMessages({
  library(tidyverse); library(here)
})

# Parâmetros mínimos (subset de 00_setup.R) -----------------------------------
ANOS      <- 2020:2025
ANOS_SIM  <- 2020:2024                 # SIM-DO público vai só até 2024 (2025 = preliminar, à parte)
UFS       <- c("AC","AL","AP","AM","BA","CE","DF","ES","GO","MA","MT","MS","MG",
               "PA","PB","PR","PE","PI","RJ","RN","RS","RO","RR","SC","SP","SE","TO")
TRIS      <- 1:4                        # brutos organizados por TRIMESTRE
FAIXAS_BR <- c(0,5,10,15,20,25,30,35,40,45,50,55,60,65,70,75,80,Inf)
MODO_CAPTURA <- "restrito"; N_SUPRESSAO <- 5
source(here("scripts","utils.R"))

# Layout real dos brutos (reconciliado em 2026-06 — ver CLAUDE.md §7) ----------
# SIA/SIH: {base}_{uf_minusc}_{ano}_{tri}_hs.RData, objeto `x_hs` (MAIÚSCULAS, já filtrado por CID principal)
# SIM:     sim_do_{UF_maiusc}_{ano}.RData,          objeto `x`    (minúsculas, NÃO filtrado)
BASES <- list(
  sia = list(dir = here("data/raw/SIA"), obj = "x_hs", periodo = "tri",
             pat = function(uf,ano,tri) sprintf("sia_%s_%d_%d_hs.RData", tolower(uf), ano, tri),
             cid_col = "PA_CIDPRI"),
  sih = list(dir = here("data/raw/SIH"), obj = "x_hs", periodo = "tri",
             pat = function(uf,ano,tri) sprintf("sih_%s_%d_%d_hs.RData", tolower(uf), ano, tri),
             cid_col = "DIAG_PRINC"),
  sim = list(dir = here("data/raw/SIM"), obj = "x", periodo = "ano",
             pat = function(uf,ano,tri) sprintf("sim_do_%s_%d.RData", toupper(uf), ano),
             cid_col = NA_character_)   # SIM ainda não filtrado
)

carregar_obj <- function(fp, obj) {
  e <- new.env(); nm <- load(fp, envir = e)
  if (!obj %in% nm) obj <- nm[1]
  get(obj, envir = e)
}

# -----------------------------------------------------------------------------
# 1. Grade de arquivos (esperado × presente) — rápido, só nomes
# -----------------------------------------------------------------------------
grade_base <- function(b) {
  cfg <- BASES[[b]]
  grade <- if (cfg$periodo == "tri")
    tidyr::expand_grid(uf = UFS, ano = ANOS, tri = TRIS)
  else
    tidyr::expand_grid(uf = UFS, ano = ANOS_SIM, tri = NA_integer_)
  grade |>
    mutate(
      base = b,
      arquivo = pmap_chr(list(uf, ano, tri), cfg$pat),
      caminho = file.path(cfg$dir, arquivo),
      tamanho = file.info(caminho)$size,
      presente = !is.na(tamanho) & tamanho > 0
    )
}

cat("==================== 1) GRADE DE ARQUIVOS ====================\n")
grades <- map(names(BASES), grade_base) |> set_names(names(BASES))
resumo_grade <- imap_dfr(grades, ~ tibble(
  base = .y, esperados = nrow(.x), presentes = sum(.x$presente),
  faltantes = sum(!.x$presente),
  arquivos_extra = length(setdiff(list.files(BASES[[.y]]$dir, pattern="\\.RData$"),
                                   .x$arquivo))
))
print(resumo_grade)
walk(names(grades), function(b){
  falt <- filter(grades[[b]], !presente)
  if (nrow(falt)) { cat("\n[", toupper(b), "] FALTANTES:\n"); print(select(falt, uf, ano, tri, arquivo)) }
})

# -----------------------------------------------------------------------------
# 2. Validação de conteúdo — SIA e SIH (frames pequenos: carrega tudo)
# -----------------------------------------------------------------------------
validar_conteudo_leve <- function(b) {
  cfg <- BASES[[b]]; g <- filter(grades[[b]], presente)
  cat(sprintf("\n==================== 2) CONTEÚDO: %s (%d arquivos) ====================\n",
              toupper(b), nrow(g)))
  res <- pmap_dfr(list(g$caminho, g$uf, g$ano, g$tri), function(fp, uf, ano, tri){
    x <- carregar_obj(fp, cfg$obj)
    cidcol <- cfg$cid_col
    tem_cid <- !is.na(cidcol) && cidcol %in% names(x)
    n_cid_ok <- if (tem_cid && nrow(x)) sum(grepl("^L732", x[[cidcol]])) else NA_integer_
    tibble(uf, ano, tri, n = nrow(x), ncol = ncol(x),
           obj_ok = TRUE,
           cid_col_presente = tem_cid,
           n_cid_principal_L732 = n_cid_ok,
           filtro_consistente = is.na(n_cid_ok) | n_cid_ok == nrow(x))
  })
  # Consistência de nº de colunas e schema
  ncols <- sort(unique(res$ncol))
  cat("• nº de colunas distintos entre arquivos:", paste(ncols, collapse=", "), "\n")
  cat("• total de registros HS:", sum(res$n), "\n")
  cat("• arquivos com 0 linhas:", sum(res$n == 0), "\n")
  inconsist <- filter(res, !filtro_consistente)
  if (nrow(inconsist)) {
    cat("⚠️  arquivos com CID principal != L732 (inconsistência de filtro):\n")
    print(select(inconsist, uf, ano, tri, n, n_cid_principal_L732))
  } else cat("✓ filtro por", cfg$cid_col, "consistente (todos os registros = L732)\n")
  # Totais por ano
  cat("• registros HS por ano:\n")
  print(res |> group_by(ano) |> summarise(n_arquivos=n(), registros=sum(n), .groups="drop"))
  res
}

res_sia <- validar_conteudo_leve("sia")
res_sih <- validar_conteudo_leve("sih")

# -----------------------------------------------------------------------------
# 3. SIM — schema + PRÉ-SCAN de HS (causabas + linhas), já que é o que falta filtrar
# -----------------------------------------------------------------------------
cat("\n==================== 3) SIM-DO: schema + pré-scan HS ====================\n")
cols_sim_causa <- c("causabas","linhaa","linhab","linhac","linhad","linhaii")
g_sim <- filter(grades$sim, presente)
res_sim <- pmap_dfr(list(g_sim$caminho, g_sim$uf, g_sim$ano), function(fp, uf, ano){
  x <- carregar_obj(fp, "x")
  faltam <- setdiff(cols_sim_causa, names(x))
  hit_cb  <- if ("causabas" %in% names(x)) sum(grepl("L732", x$causabas)) else NA
  cols_lin <- intersect(c("linhaa","linhab","linhac","linhad","linhaii"), names(x))
  hit_lin <- if (length(cols_lin))
    sum(Reduce(`|`, lapply(cols_lin, function(c) grepl("L732", x[[c]]))), na.rm=TRUE) else NA
  hit_any <- if ("causabas" %in% names(x))
    sum(grepl("L732", x$causabas) |
        Reduce(`|`, lapply(cols_lin, function(c) grepl("L732", x[[c]]))), na.rm=TRUE) else NA
  out <- tibble(uf, ano, n = nrow(x), ncol = ncol(x),
                cols_faltando = paste(faltam, collapse=";"),
                hs_causabas = hit_cb, hs_linhas = hit_lin, hs_qualquer = hit_any)
  rm(x); gc(verbose = FALSE)
  out
})
cat("• nº de colunas distintos:", paste(sort(unique(res_sim$ncol)), collapse=", "), "\n")
cat("• total de óbitos (todas as causas):", sum(res_sim$n), "\n")
cat("• óbitos com HS na causa básica:", sum(res_sim$hs_causabas, na.rm=TRUE), "\n")
cat("• óbitos com HS em alguma linha (causa contribuinte):", sum(res_sim$hs_linhas, na.rm=TRUE), "\n")
cat("• óbitos com HS em QUALQUER campo (causabas ∪ linhas):", sum(res_sim$hs_qualquer, na.rm=TRUE), "\n")
if (any(res_sim$cols_faltando != "")) {
  cat("⚠️  arquivos com colunas de causa faltando:\n")
  print(filter(res_sim, cols_faltando != "") |> select(uf, ano, cols_faltando))
}
cat("• HS (qualquer campo) por ano:\n")
print(res_sim |> group_by(ano) |> summarise(obitos=sum(n), hs=sum(hs_qualquer, na.rm=TRUE), .groups="drop"))

# -----------------------------------------------------------------------------
# 4. Persistir resumos para auditoria
# -----------------------------------------------------------------------------
dir.create(here("manifest"), showWarnings = FALSE)
write_csv(resumo_grade,           here("manifest","validacao_grade.csv"))
write_csv(bind_rows(mutate(res_sia, base="sia"), mutate(res_sih, base="sih")),
          here("manifest","validacao_conteudo_sia_sih.csv"))
write_csv(res_sim,                here("manifest","validacao_sim_prescan.csv"))
cat("\n✓ Resumos salvos em manifest/validacao_*.csv\n")
