# =============================================================================
# get_ipca.R — Deflator anual (IPCA) para os valores monetários do SIH (decisão nº 12
# do plano_expansao_2010.md). IBGE/SIDRA tabela 1737, variável 2266 (número-índice,
# dez/1993 = 100), mensal → média anual; fator para R$ do ANO_BASE.
# Cache: data/denominators/ipca_anual.parquet (skip-if-exists).
# Rodar: Rscript scripts/get_ipca.R
# =============================================================================

source(here::here("scripts", "00_setup.R"))

ANO_BASE <- 2025
OUT <- here::here("data/denominators/ipca_anual.parquet")
if (file.exists(OUT)) { message("IPCA em cache — skip. Apague p/ refazer."); quit(save = "no") }

meses <- paste(sprintf("%d%02d", rep(ANOS, each = 12), 1:12), collapse = ",")
raw <- sidrar::get_sidra(api = paste0("/t/1737/n1/all/v/2266/p/", meses))
ipca <- raw |>
  janitor::clean_names() |>
  dplyr::transmute(ano = as.integer(substr(mes_codigo, 1, 4)), indice = as.numeric(valor)) |>
  dplyr::group_by(ano) |>
  dplyr::summarise(indice_medio = mean(indice), meses = dplyr::n(), .groups = "drop") |>
  dplyr::mutate(fator_para_base = indice_medio[ano == ANO_BASE] / indice_medio, ano_base = ANO_BASE)

stopifnot(all(ANOS %in% ipca$ano), all(ipca$meses == 12))
arrow::write_parquet(ipca, OUT)
print(as.data.frame(ipca))
message("✓ IPCA anual → ", basename(OUT), " (R$ de ", ANO_BASE, ")")
