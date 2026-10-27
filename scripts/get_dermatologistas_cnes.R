# =============================================================================
# get_dermatologistas_cnes.R — Nº de dermatologistas por UF × ano (CNES-PF), 2010–2025
# Fonte externa para contextualizar a OFERTA assistencial (confundidor de acesso).
# v2 (plano_expansao_2010.md E10, roda no R550-2): lê os DBC brutos de junho de cada
# ano baixados por scripts/r550/baixar_cnes_pf.py (o guia desaconselha fetch_datasus).
#   CBO dermatologista = 223117 (em uso no início da série) e 225135 (depois);
#   profissional único = CNS_PROF; prof_sus = PROF_SUS == "1" (atende SUS);
#   densidade por 100 mil sobre a população projetada DO MESMO ANO (a v1 usava o
#   Censo 2022 fixo em todos os anos).
# Saída: data/denominators/dermatologistas_uf.{parquet,rds}
# Rodar (R550-2): Rscript scripts/get_dermatologistas_cnes.R
# =============================================================================

source(here::here("scripts", "00_setup.R"))

DIR_PF   <- path.expand("~/Documentos/ronald/datasus_raw/CNES-PF")
CBO_DERM <- c("223117", "225135")
MES_REF  <- 6
OUT      <- here::here("data/denominators/dermatologistas_uf.parquet")

conta_derm <- function(uf, ano) {
  fp <- file.path(DIR_PF, sprintf("PF%s%02d%02d.dbc", uf, ano %% 100, MES_REF))
  if (!file.exists(fp)) {
    message("⚠️  sem CNES-PF para ", uf, " ", ano)
    return(tibble::tibble(uf = uf, ano = ano, mes_ref = NA_integer_, n_dermatologistas = NA_integer_,
                          n_derm_sus = NA_integer_, n_por_cbo = NA_character_))
  }
  x <- read.dbc::read.dbc(fp, as.is = TRUE)
  d <- x[x$CBO %in% CBO_DERM & !is.na(x$CNS_PROF) & trimws(x$CNS_PROF) != "", c("CNS_PROF", "CBO", "PROF_SUS")]
  por_cbo <- tapply(d$CNS_PROF, d$CBO, dplyr::n_distinct)
  r <- tibble::tibble(uf = uf, ano = ano, mes_ref = MES_REF,
                      n_dermatologistas = dplyr::n_distinct(d$CNS_PROF),
                      n_derm_sus = dplyr::n_distinct(d$CNS_PROF[d$PROF_SUS %in% "1"]),
                      n_por_cbo = paste(names(por_cbo), por_cbo, sep = "=", collapse = ";"))
  rm(x); invisible(gc(verbose = FALSE))
  r
}

message("== CNES-PF: dermatologistas (", length(UFS), " UF × ", length(ANOS), " anos) ==")
derm <- tidyr::expand_grid(uf = UFS, ano = ANOS) |> purrr::pmap_dfr(conta_derm)

pop_uf <- arrow::read_parquet(here::here("data/denominators/pop_ibge.parquet")) |>
  dplyr::group_by(uf, ano) |> dplyr::summarise(pop = sum(pop), .groups = "drop")

derm <- derm |>
  dplyr::left_join(pop_uf, by = c("uf", "ano")) |>
  dplyr::mutate(regiao = mapear_uf_regiao(uf),
                derm_por_100k = 1e5 * n_dermatologistas / pop,
                derm_sus_por_100k = 1e5 * n_derm_sus / pop)

stopifnot(nrow(derm) == length(UFS) * length(ANOS))
arrow::write_parquet(derm, OUT)
saveRDS(derm, here::here("data/denominators/dermatologistas_uf.rds"))

cat("\n• pares UF×ano:", nrow(derm), "| faltantes:", sum(is.na(derm$n_dermatologistas)), "\n")
cat("• Brasil por ano (dermatologistas | atendem SUS | por 100 mil):\n")
print(derm |> dplyr::group_by(ano) |>
        dplyr::summarise(derm = sum(n_dermatologistas), sus = sum(n_derm_sus),
                         por_100k = round(1e5 * derm / sum(pop), 2), .groups = "drop") |> as.data.frame())
message(sprintf("\n✓ Dermatologistas CNES 2010–2025: %d linhas → %s", nrow(derm), basename(OUT)))
