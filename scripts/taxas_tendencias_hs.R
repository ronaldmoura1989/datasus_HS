# =============================================================================
# taxas_tendencias_hs.R — E12 do plano_expansao_2010.md: taxas padronizadas,
# tendência quasi-Poisson (com e sem 2020–2022) e série interrompida (ITS).
# Roda no R550-2 depois de get_hs_data_from_{SIA,SIH,SIM}.R e feature_eng_pacientes_SIA.R.
#
# Séries (bases em paralelo, NUNCA somadas):
#   sia_clinico   Σ pa_qtdapr, L732 principal, BPA-I + APAC sem medicamento (detecção clínica)
#   sia_trat      pacientes em tratamento com adalimumabe (mediana mensal de APAC) — taxa bruta
#   sih_principal AIH distintas com L732 no diagnóstico principal
#   sim           só contagens (N pequeno; sem taxa de mortalidade por HS)
# Marco da ITS (ref/normativo_hs.md): 201911 = Portaria SAES/MS 1.217/2019 (L73.2 passa a
#   ser compatível com o adalimumabe 06.04.38.006-2); alternativa 201811 (pós-incorporação,
#   Portaria SCTIE 48/2018). O canal clínico começa em 201401: antes disso a consulta
#   especializada (0301010072) só era registrada em BPA-C, sem CID (ref/sigtap_hs.csv).
# Saídas (já com supressão N < N_SUPRESSAO):
#   data/consolidated/taxas_hs.parquet, tendencias_hs.csv, its_hs.csv
# Rodar (R550-2): Rscript scripts/taxas_tendencias_hs.R
# =============================================================================

source(here::here("scripts", "00_setup.R"))
source(here::here("scripts", "calcular_taxas.R"))

MARCOS <- c(normativo = "201911", alternativo = "201811")
INICIO_CLINICO <- "201401"
pop <- carregar_pop()
pop_ano <- pop |> dplyr::group_by(ano) |> dplyr::summarise(pop = sum(pop), .groups = "drop")

# -----------------------------------------------------------------------------
# 1. Numeradores
# -----------------------------------------------------------------------------
sia <- arrow::open_dataset(here::here("data/parquet/sia_hs")) |>
  dplyr::filter(camada == "nucleo") |>
  dplyr::select(ano, mes, pa_cmp, canal, uf_pcn, regiao, sexo, faixa, pa_qtdapr) |>
  dplyr::collect()
clin <- dplyr::filter(sia, canal %in% c("clinico_apac", "clinico_bpai"))
num_clin <- contar_estrato(clin, col_uf = "uf_pcn", peso = "pa_qtdapr")

sih <- arrow::open_dataset(here::here("data/parquet/sih_hs")) |>
  dplyr::filter(hs_principal) |>
  dplyr::select(ano, mes, n_aih, uf_res, regiao, sexo, faixa) |>
  dplyr::collect()
num_sih <- contar_estrato(sih, col_uf = "uf_res", distinct_por = "n_aih")

trat <- arrow::read_parquet(here::here("data/consolidated/sia_pacientes_tratamento.parquet"))
sim <- arrow::read_parquet(here::here("data/consolidated/sim_hs.parquet"))

# -----------------------------------------------------------------------------
# 2. Taxas padronizadas (Brasil × ano, região × ano, UF em pessoa-anos)
# -----------------------------------------------------------------------------
pop_reg <- dplyr::mutate(pop, regiao = mapear_uf_regiao(uf))
add_reg <- function(num) dplyr::mutate(num, regiao = mapear_uf_regiao(uf))
taxas <- dplyr::bind_rows(
  taxas_padronizadas(num_clin, pop, "ano") |> dplyr::mutate(serie = "sia_clinico", nivel = "BR"),
  taxas_padronizadas(add_reg(num_clin), pop_reg, c("regiao", "ano")) |> dplyr::mutate(serie = "sia_clinico", nivel = "regiao"),
  taxas_padronizadas(num_clin, pop, "uf") |> dplyr::mutate(serie = "sia_clinico", nivel = "uf_pool"),
  taxas_padronizadas(num_sih, pop, "ano") |> dplyr::mutate(serie = "sih_principal", nivel = "BR"),
  taxas_padronizadas(add_reg(num_sih), pop_reg, c("regiao", "ano")) |> dplyr::mutate(serie = "sih_principal", nivel = "regiao"),
  taxas_padronizadas(num_sih, pop, "uf") |> dplyr::mutate(serie = "sih_principal", nivel = "uf_pool"),
  trat |> dplyr::filter(uf == "BR") |> dplyr::left_join(pop_ano, by = "ano") |>
    dplyr::transmute(ano, eventos = pacientes_mes_mediana, pop,
                     taxa_bruta = 1e5 * eventos / pop, serie = "sia_tratamento", nivel = "BR") |>
    suprimir_taxa())
arrow::write_parquet(taxas, here::here("data/consolidated/taxas_hs.parquet"))

cat("\n• taxas nacionais por ano (padronizada/100 mil; tratamento = bruta):\n")
print(taxas |> dplyr::filter(nivel == "BR") |>
        dplyr::transmute(serie, ano, eventos, taxa = round(dplyr::coalesce(taxa_pad, taxa_bruta), 3)) |>
        tidyr::pivot_wider(names_from = serie, values_from = c(eventos, taxa)) |> as.data.frame())

# -----------------------------------------------------------------------------
# 3. Tendência anual quasi-Poisson (série toda, sem 2020–2022, pré-pandemia)
# -----------------------------------------------------------------------------
serie_br <- function(s) taxas |> dplyr::filter(serie == s, nivel == "BR")
tend_seguro <- function(d, ...) if (dplyr::n_distinct(d$ano) < 3) NULL else tendencia_poisson(d, ...)
tend <- purrr::map_dfr(c("sia_clinico", "sih_principal", "sia_tratamento"), function(s) {
  d <- serie_br(s) |> dplyr::filter(eventos > 0)
  if (s == "sia_clinico") d <- dplyr::filter(d, ano >= as.integer(substr(INICIO_CLINICO, 1, 4)))
  dplyr::bind_rows(tend_seguro(d), tend_seguro(d, excluir_covid = TRUE),
                   tend_seguro(dplyr::filter(d, ano <= 2019))) |>
    dplyr::mutate(serie = s, .before = 1)
})
sim_ano <- sim |> dplyr::filter(status_dado == "DEFINITIVO", ano %in% ANOS_SIM) |>
  dplyr::group_by(ano) |> dplyr::summarise(eventos = sum(hs_qualquer), .groups = "drop") |>
  dplyr::left_join(pop_ano, by = "ano")
tend <- dplyr::bind_rows(tend, tendencia_poisson(sim_ano) |> dplyr::mutate(serie = "sim_qualquer", .before = 1))
readr::write_csv(tend, here::here("data/consolidated/tendencias_hs.csv"))
cat("\n• tendências (variação anual %, IC 95%):\n"); print(as.data.frame(tend))

# -----------------------------------------------------------------------------
# 4. Série interrompida mensal (marco normativo pré-especificado + alternativo)
# -----------------------------------------------------------------------------
pop_mes <- pop_ano |> dplyr::mutate(pop = pop / 12)
mensal <- function(df, valor, inicio) {
  df |> dplyr::mutate(cmp = sprintf("%d%02d", ano, mes)) |>
    dplyr::group_by(cmp, ano) |> dplyr::summarise(eventos = {{ valor }}, .groups = "drop") |>
    dplyr::right_join(tidyr::expand_grid(ano = ANOS, mes = 1:12) |>
                        dplyr::transmute(ano, cmp = sprintf("%d%02d", ano, mes)), by = c("cmp", "ano")) |>
    dplyr::mutate(eventos = tidyr::replace_na(eventos, 0)) |>
    dplyr::left_join(pop_mes, by = "ano") |>
    dplyr::filter(cmp >= inicio)
}
s_clin <- mensal(clin, sum(as.numeric(pa_qtdapr), na.rm = TRUE), INICIO_CLINICO)
s_sih  <- mensal(sih, dplyr::n_distinct(n_aih), "201001")
its <- purrr::imap_dfr(MARCOS, function(m, nome) dplyr::bind_rows(
  its_poisson(s_clin, m) |> dplyr::mutate(serie = "sia_clinico", marco_tipo = nome, .before = 1),
  its_poisson(s_sih, m)  |> dplyr::mutate(serie = "sih_principal", marco_tipo = nome, .before = 1)))
readr::write_csv(its, here::here("data/consolidated/its_hs.csv"))
cat("\n• série interrompida (quasi-Poisson, harmônicos sazonais, indicadora COVID):\n")
print(as.data.frame(its |> dplyr::mutate(dplyr::across(c(estimativa, ic_inf, ic_sup), ~ round(.x, 3)))))

message("\n✓ taxas_hs.parquet, tendencias_hs.csv, its_hs.csv gravados (com supressão).")
