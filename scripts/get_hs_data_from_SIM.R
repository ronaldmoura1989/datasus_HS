# =============================================================================
# get_hs_data_from_SIM.R — Consolidação do SIM-DO HS 2010–2025 (v2, roda no R550-2)
# Entrada: <DIR_FILTRADO>/SIM-DO/{filtrado,denominador}/ (scripts/r550/filtrar_um_hs.R),
#          DBC BRUTOS (não o SIM processado pelo microdatasus da v1); 2025–2026 vêm de
#          SIM-DO/PRELIM (status_dado = PRELIM) e NUNCA entram nas taxas.
# Molde: datasus_EIM/scripts/get_eim_data_from_SIM.R; regras do plano_expansao_2010.md E9.
#
# Três colunas explícitas (guia ref/guia_processamento_datasus.md §6.3):
#   hs_causa_basica = CAUSABAS núcleo (L732) → número PRIMÁRIO
#   hs_cb_ampliado  = CAUSABAS núcleo ou limítrofe (L738/L739) → teto
#   hs_qualquer     = L732 em qualquer campo (CAUSABAS, CAUSABAS_O, LINHAA–D, LINHAII),
#                     regex de causas múltiplas "(^|\*)L732"
# Idade: decode_idade_sim() sobre o IDADE bruto (o idade_decode do microdatasus não existe aqui).
# Saídas: data/consolidated/sim_hs.parquet (óbitos com L73/L02 em qualquer campo)
#         data/consolidated/sim_denominador_agg.parquet
# Rodar (R550-2): Rscript scripts/get_hs_data_from_SIM.R
# =============================================================================

source(here::here("scripts", "00_setup.R"))

DIR_SIM <- file.path(path.expand(DIR_FILTRADO), "SIM-DO")
if (!dir.exists(file.path(DIR_SIM, "filtrado"))) stop("Sem filtrados SIM em ", DIR_SIM)
abrir <- function(sub) arrow::open_dataset(file.path(DIR_SIM, sub), unify_schemas = TRUE)
COLS_MULTI <- c("linhaa", "linhab", "linhac", "linhad", "linhaii")
tem_l732 <- function(v) grepl("(^|\\*)L732", toupper(dplyr::coalesce(v, "")))

sim <- abrir("filtrado") |>
  dplyr::filter(hit_hs | hit_hs_env) |>
  dplyr::select(-dplyr::starts_with("hit_")) |>
  dplyr::collect() |>
  janitor::clean_names()

cols_multi <- intersect(COLS_MULTI, names(sim))
sim <- sim |>
  dplyr::mutate(
    ano             = as.integer(substr(dtobito, 5, 8)),
    camada_cb       = classificar_hs(causabas, "hs"),
    hs_causa_basica = camada_cb %in% "nucleo",
    hs_cb_ampliado  = camada_cb %in% c("nucleo", "limitrofe"),
    hs_qualquer     = hs_causa_basica | tem_l732(causabas_o) |
                      dplyr::if_any(dplyr::all_of(cols_multi), tem_l732),
    hs_parte_ii     = tem_l732(linhaii),
    idade_anos      = decode_idade_sim(idade),
    faixa           = harmonizar_faixa(idade_anos),
    sexo            = dplyr::recode(stringr::str_trim(as.character(sexo)),
                                    "1" = "Masculino", "2" = "Feminino", .default = NA_character_),
    uf_res          = uf_from_mun(codmunres),
    regiao          = mapear_uf_regiao(uf_res),
    uf_arquivo      = arq_uf,
    fonte           = "datasus_sim_do_dbc") |>
  dplyr::filter(ano >= min(ANOS))

# -----------------------------------------------------------------------------
# QC e auditoria do numerador
# -----------------------------------------------------------------------------
cat("\n• óbitos por ano e status — causa básica | CB ampliada | qualquer campo | parte II:\n")
print(sim |> dplyr::group_by(ano, status_dado) |>
        dplyr::summarise(causa_basica = sum(hs_causa_basica), cb_ampliado = sum(hs_cb_ampliado),
                         qualquer = sum(hs_qualquer), parte_ii = sum(hs_parte_ii), .groups = "drop") |>
        as.data.frame())
hsq <- dplyr::filter(sim, hs_qualquer, status_dado == "DEFINITIVO", ano %in% ANOS_SIM)
cat(sprintf("• HS qualquer campo (definitivos %d–%d): %d óbitos | idade mediana %.0f | %% feminino %.1f\n",
            min(ANOS_SIM), max(ANOS_SIM), nrow(hsq), stats::median(hsq$idade_anos, na.rm = TRUE),
            100 * mean(hsq$sexo == "Feminino", na.rm = TRUE)))
cat("• 25 causas básicas mais frequentes entre os óbitos com HS em qualquer campo:\n")
print(as.data.frame(head(dplyr::count(hsq, causabas, sort = TRUE), 25)))

arrow::write_parquet(sim, here::here("data/consolidated/sim_hs.parquet"))

den <- abrir("denominador") |>
  dplyr::group_by(ano, uf_res, sexo, faixa, causabas3, status_dado) |>
  dplyr::summarise(obitos = sum(obitos), .groups = "drop") |>
  dplyr::collect() |>
  dplyr::mutate(ano = as.integer(ano)) |>
  dplyr::filter(ano >= min(ANOS))
arrow::write_parquet(den, here::here("data/consolidated/sim_denominador_agg.parquet"))
print(den |> dplyr::group_by(ano, status_dado) |> dplyr::summarise(obitos = sum(obitos), .groups = "drop") |>
        as.data.frame())

registrar_versao_lookup()
message(sprintf("\n✓ SIM v2: %d óbitos com L73/L02 (%d com HS em qualquer campo, %d como causa básica) → sim_hs.parquet",
                nrow(sim), sum(sim$hs_qualquer), sum(sim$hs_causa_basica)))
