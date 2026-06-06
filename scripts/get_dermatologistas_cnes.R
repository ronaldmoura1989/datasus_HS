# =============================================================================
# get_dermatologistas_cnes.R — Nº de dermatologistas por UF × ano (CNES-PF)
# Fonte externa para contextualizar a OFERTA assistencial (confundidor de acesso).
# CNES-PF (vínculos profissionais); CBO dermatologista = 223117 e 225135.
# Mês de referência por ano (padrão 06); dedup por profissional único (cpfunico).
# Cache: skip-if-exists. Saída: data/denominators/dermatologistas_uf.parquet (+ .rds)
# Rodar: Rscript scripts/get_dermatologistas_cnes.R
# =============================================================================

source(here::here("scripts", "00_setup.R"))
suppressPackageStartupMessages(library(microdatasus))
options(timeout = 600)

OUT <- here::here("data/denominators/dermatologistas_uf.parquet")
if (file.exists(OUT)) {
  message("Dermatologistas já em cache (", OUT, ") — skip. Apague p/ refazer.")
  quit(save = "no")
}

CBO_DERM <- c("223117", "225135")   # Médico dermatologista (tabCBO)
MES_REF  <- 6                        # competência de referência (mid-ano)

#' Conta dermatologistas distintos numa UF×ano (mês de referência), com fallback
#' de mês caso a competência não exista ainda.
conta_derm_uf_ano <- function(uf, ano, meses = c(MES_REF, 3, 12, 1)) {
  for (m in meses) {
    raw <- tryCatch(
      microdatasus::fetch_datasus(year_start = ano, month_start = m,
                                  year_end = ano, month_end = m, uf = uf,
                                  information_system = "CNES-PF"),
      error = function(e) NULL)
    if (is.null(raw) || !nrow(raw)) next
    raw <- janitor::clean_names(raw)
    cbo_col <- if ("cbo" %in% names(raw)) "cbo" else "cbounico"
    # cns_prof (CNS do profissional) é o id confiável; cpfunico vem majoritariamente vazio
    id_col  <- dplyr::first(intersect(c("cns_prof","cpf_prof","cpfunico"), names(raw)))
    derm <- raw[raw[[cbo_col]] %in% CBO_DERM, , drop = FALSE]
    derm <- derm[!is.na(derm[[id_col]]) & trimws(as.character(derm[[id_col]])) != "", , drop = FALSE]
    n <- dplyr::n_distinct(derm[[id_col]])
    log_run("sia", uf, sprintf("CNES_%d_%02d", ano, m), "ok",
            n_lidas = nrow(raw), n_hs = n, msg = "dermatologistas")
    return(tibble::tibble(uf = uf, ano = ano, mes_ref = m, n_dermatologistas = n))
  }
  message("⚠️  sem CNES-PF p/ ", uf, " ", ano)
  tibble::tibble(uf = uf, ano = ano, mes_ref = NA_integer_, n_dermatologistas = NA_integer_)
}

message("== CNES-PF: contando dermatologistas (", length(UFS), " UF × ",
        length(ANOS), " anos) ==")
grade <- tidyr::expand_grid(uf = UFS, ano = ANOS)
derm <- purrr::pmap_dfr(grade, function(uf, ano) {
  r <- conta_derm_uf_ano(uf, ano)
  message(sprintf("  %s %d: %s dermatologistas", uf, ano,
                  ifelse(is.na(r$n_dermatologistas), "NA", r$n_dermatologistas)))
  gc(verbose = FALSE)
  r
})

# Densidade por 100 mil (denominador IBGE Censo 2022, total por UF)
pop_uf <- arrow::read_parquet(here::here("data/denominators/pop_ibge.parquet")) |>
  dplyr::filter(ano == 2022) |>
  dplyr::group_by(uf) |> dplyr::summarise(pop = sum(pop), .groups = "drop")

derm <- derm |>
  dplyr::left_join(pop_uf, by = "uf") |>
  dplyr::mutate(regiao = mapear_uf_regiao(uf),
                derm_por_100k = 1e5 * n_dermatologistas / pop)

arrow::write_parquet(derm, OUT)
saveRDS(derm, here::here("data/denominators/dermatologistas_uf.rds"))

cat("\n• total de pares UF×ano:", nrow(derm), "| faltantes:",
    sum(is.na(derm$n_dermatologistas)), "\n")
cat("• dermatologistas por 100 mil (2024, top/bottom):\n")
print(derm |> dplyr::filter(ano == 2024) |> dplyr::arrange(dplyr::desc(derm_por_100k)) |>
        dplyr::select(uf, n_dermatologistas, derm_por_100k) |>
        dplyr::slice(c(1:4, (dplyr::n()-3):dplyr::n())))
message(sprintf("\n✓ Dermatologistas CNES: %d linhas → %s", nrow(derm), basename(OUT)))
