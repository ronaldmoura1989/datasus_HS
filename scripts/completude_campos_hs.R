# =============================================================================
# completude_campos_hs.R — E5 do plano_expansao_2010.md: completude por base × ano
# dos campos que a análise HS usa, NOS REGISTROS HS e no TOTAL da base, lado a lado.
# Uma tendência num campo cujo preenchimento muda mede preenchimento (guia §5):
# esta tabela é nota obrigatória nas figuras por raça/cor, comorbidade e "qualquer campo".
#   total: ~/Documentos/ronald/datasus_raw/logs/schema_resumo.tsv (catálogo do EIM, % por base × ano)
#   HS:    data/parquet/sia_hs (núcleo), data/parquet/sih_hs (HS principal), sim_hs.parquet
# Saída: manifest/completude_hs_por_ano.csv
# Rodar (R550-2, depois dos get_hs_data_from_*.R): Rscript scripts/completude_campos_hs.R
# =============================================================================

source(here::here("scripts", "00_setup.R"))

preench <- function(v, invalidos = character()) {
  v <- trimws(as.character(v))
  round(100 * mean(!is.na(v) & v != "" & !v %in% invalidos), 1)
}

sia <- arrow::open_dataset(here::here("data/parquet/sia_hs")) |>
  dplyr::filter(camada == "nucleo") |>
  dplyr::select(ano, canal, pa_racacor, pa_munpcn, pa_autoriz, pa_cbocod, pa_cidsec, pa_docorig) |>
  dplyr::collect()
c_sia <- sia |> dplyr::group_by(ano) |>
  dplyr::summarise(
    PA_RACACOR = preench(pa_racacor, c("99", "00")),
    PA_MUNPCN  = preench(pa_munpcn, c("000000", "999999")),
    PA_AUTORIZ = preench(pa_autoriz[pa_docorig %in% c("P", "S")], c("0000000000000")),
    PA_CBOCOD  = preench(pa_cbocod),
    PA_CIDSEC  = preench(pa_cidsec, c("0000")),
    n = dplyr::n(), .groups = "drop") |>
  tidyr::pivot_longer(-c(ano, n), names_to = "campo", values_to = "pct_hs") |>
  dplyr::mutate(base = "SIA-PA", recorte_hs = "L732 principal")

sih <- arrow::open_dataset(here::here("data/parquet/sih_hs")) |>
  dplyr::filter(hs_principal) |> dplyr::collect()
cols_sec <- intersect(c("diag_secun", paste0("diagsec", 1:9)), names(sih))
c_sih <- sih |> dplyr::group_by(ano) |>
  dplyr::summarise(
    ALGUM_SECUNDARIO = round(100 * mean(n_sec_preench > 0), 1),
    DIAG_SECUN = preench(diag_secun, c("0000")),
    DIAGSEC1   = if ("diagsec1" %in% names(sih)) preench(diagsec1) else NA_real_,
    RACA_COR   = preench(raca_cor),
    n = dplyr::n_distinct(n_aih), .groups = "drop") |>
  tidyr::pivot_longer(-c(ano, n), names_to = "campo", values_to = "pct_hs") |>
  dplyr::mutate(base = "SIH-RD", recorte_hs = "L732 principal (AIH)")

sim <- arrow::read_parquet(here::here("data/consolidated/sim_hs.parquet")) |>
  dplyr::filter(hs_qualquer)
c_sim <- sim |> dplyr::group_by(ano) |>
  dplyr::summarise(LINHAII = preench(linhaii), CAUSABAS_O = preench(causabas_o),
                   n = dplyr::n(), .groups = "drop") |>
  tidyr::pivot_longer(-c(ano, n), names_to = "campo", values_to = "pct_hs") |>
  dplyr::mutate(base = "SIM-DO", recorte_hs = "L732 qualquer campo")

total <- readr::read_tsv(path.expand("~/Documentos/ronald/datasus_raw/logs/schema_resumo.tsv"),
                         col_types = readr::cols(.default = "c")) |>
  tidyr::pivot_longer(-c(base, ano, colunas, linhas), names_to = "campo", values_to = "pct_total") |>
  dplyr::filter(!is.na(pct_total)) |>
  dplyr::transmute(base, ano = as.integer(ano), campo, pct_total = as.numeric(pct_total))

comp <- dplyr::bind_rows(c_sia, c_sih, c_sim) |>
  dplyr::left_join(total, by = c("base", "ano", "campo")) |>
  dplyr::mutate(n_hs = n) |>
  dplyr::select(base, recorte_hs, campo, ano, n_hs, pct_hs, pct_total) |>
  dplyr::arrange(base, campo, ano)

readr::write_csv(comp, here::here("manifest/completude_hs_por_ano.csv"))
print(comp |> dplyr::select(base, campo, ano, pct_hs) |>
        tidyr::pivot_wider(names_from = ano, values_from = pct_hs, names_sort = TRUE) |> as.data.frame())
message("✓ completude → manifest/completude_hs_por_ano.csv (", nrow(comp), " linhas)")
