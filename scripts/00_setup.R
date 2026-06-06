# =============================================================================
# 00_setup.R — Ambiente, parâmetros globais, paleta e diretórios
# Projeto DATASUS — Hidradenite Supurativa (HS, CID-10 L73.2 = "L732")
# Ver CLAUDE.md §2, §3, §4 e datasus_hs.md para a metodologia.
# =============================================================================

# -----------------------------------------------------------------------------
# 0. Helper de instalação resiliente (CRAN -> Bioconductor -> GitHub)
#    Em projeto com renv ativo é redundante, mas mantido como fallback.
# -----------------------------------------------------------------------------
ensure_pkg <- function(pkgs, github = list()) {
  cran <- "https://cloud.r-project.org"
  for (p in pkgs) {
    if (requireNamespace(p, quietly = TRUE)) next
    try(install.packages(p, repos = cran), silent = TRUE)
    if (requireNamespace(p, quietly = TRUE)) next
    if (!requireNamespace("BiocManager", quietly = TRUE))
      install.packages("BiocManager", repos = cran)
    try(BiocManager::install(p, update = FALSE, ask = FALSE), silent = TRUE)
    if (requireNamespace(p, quietly = TRUE)) next
    if (!is.null(github[[p]])) {
      if (!requireNamespace("remotes", quietly = TRUE))
        install.packages("remotes", repos = cran)
      remotes::install_github(github[[p]], upgrade = "never")
    }
    if (!requireNamespace(p, quietly = TRUE))
      stop(sprintf("Falha ao instalar '%s'", p))
  }
  invisible(NULL)
}

pkgs_cran <- c("tidyverse","data.table","arrow","janitor","naniar","rstatix",
               "broom","epitools","ggplot2","scales","patchwork","cowplot","ggpubr",
               "flextable","officer","gt","geobr","sidrar","renv","yaml",
               "digest","here")
# Pinar ref/SHA (ex.: "rfsaldanha/microdatasus@<sha>") p/ o lockfile reproduzir a
# MESMA versão de process_sia/sih/sim — argumentos variam entre versões (CLAUDE.md §7).
pkgs_github <- list(microdatasus = "rfsaldanha/microdatasus",
                    read.dbc     = "danicat/read.dbc")
ensure_pkg(pkgs_cran, github = pkgs_github)

suppressPackageStartupMessages({
  library(tidyverse)
  library(janitor)
  library(arrow)
  library(here)
})

# Override de namespaces (caso algum script carregue Bioconductor junto do tidyverse)
select <- dplyr::select
filter <- dplyr::filter
rename <- dplyr::rename
slice  <- dplyr::slice
count  <- dplyr::count

# Reprodutibilidade — usado em qualquer amostragem/bootstrap (IC de taxas)/jitter
set.seed(42)

# -----------------------------------------------------------------------------
# 1. Parâmetros globais
# -----------------------------------------------------------------------------
ANOS  <- 2020:2025
MESES <- 1:12                 # SIA/SIH são MENSAIS → unidade de iteração = UF×ano×mês
UFS   <- c("AC","AL","AP","AM","BA","CE","DF","ES","GO","MA","MT","MS","MG",
           "PA","PB","PR","PE","PI","RJ","RN","RS","RO","RR","SC","SP","SE","TO")

# ⚠️ TRIMESTRES é SÓ p/ AGREGAÇÃO temporal em relatórios — NÃO é chave de iteração
# nem de nome de arquivo (SIA/SIH iteram por mês; SIM por ano — ver CLAUDE.md §7).
TRIMESTRES <- list(T1 = c(1,3), T2 = c(4,6), T3 = c(7,9), T4 = c(10,12))

# CID alvo — Hidradenite Supurativa
CID_ALVO     <- "L732"        # representação DATASUS (sem ponto)
MODO_CAPTURA <- "restrito"    # "restrito" | "ampliado"

# Faixas etárias CANÔNICAS — mesma grade no numerador (paciente) e no denominador
# (IBGE), senão a taxa padronizada é inválida (ver utils.R::harmonizar_faixa()).
FAIXAS_BR    <- c(0,5,10,15,20,25,30,35,40,45,50,55,60,65,70,75,80,Inf)
POP_PADRAO   <- "censo2022"   # "censo2022" (comparações internas) | "oms" (internac.)
N_SUPRESSAO  <- 5             # LGPD: suprimir células com N < 5 na divulgação

# Anos a sinalizar como período anômalo (queda de produção eletiva — datasus_hs.md §9.11)
ANOS_COVID   <- c(2020, 2021)

# Paleta visual do projeto (CLAUDE.md §8) — espectro rosé → roxo
PAL_HS <- c("#5C3F6C", "#816095", "#E9CDC9", "#A87FA8", "#D8B4C4", "#6E4E82", "#3E2A4D")
PAL_HS_GRAD <- c(low = "#E9CDC9", high = "#5C3F6C")   # escalas contínuas

# -----------------------------------------------------------------------------
# 2. Diretórios (criação idempotente — recursive = TRUE)
# -----------------------------------------------------------------------------
DIRS <- c(
  "scripts", "qmd",
  "data/raw/sia_files_hs", "data/raw/SIH_files", "data/raw/SIM_DO",
  "data/filtered/sia_hs",  "data/filtered/sih_hs", "data/filtered/sim_hs",
  "data/denominators/sia", "data/denominators/sih", "data/denominators/sim",
  "data/parquet/sia_hs",   "data/parquet/sih_hs",  "data/parquet/sim_hs",
  "data/consolidated",
  "logs", "manifest", "docs"
)
purrr::walk(DIRS, ~ dir.create(here::here(.x), recursive = TRUE, showWarnings = FALSE))

# -----------------------------------------------------------------------------
# 3. Funções utilitárias
# -----------------------------------------------------------------------------
source(here::here("scripts", "utils.R"))

message("00_setup.R carregado — ANOS=", min(ANOS), ":", max(ANOS),
        " | CID_ALVO=", CID_ALVO, " | MODO_CAPTURA=", MODO_CAPTURA)
