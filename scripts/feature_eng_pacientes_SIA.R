# =============================================================================
# feature_eng_pacientes_SIA.R — Pseudo-pacientes e pacientes em tratamento (HS, v2)
# E11 do plano_expansao_2010.md; roda no R550-2 (o pseudo-ID não sai do servidor).
# Motor: scripts/pseudo_id_motor.R (cópia sem alterações de datasus_EIM/scripts/), com
# as correções do guia §11: raça/cor ausente = categoria "NI" (a v1 forçava paciente
# próprio e inflava o limite superior), ligação CERTA por nº de APAC (pa_autoriz + sexo),
# chave incompleta proporcional na estimativa central. Método DETERMINÍSTICO.
#
# Saídas (só AGREGADOS; nenhuma chave de pseudo-ID é gravada):
#   manifest/sia_pseudo_pacientes_v2.csv  intervalo [frouxa ; estrita] + central, por
#     janela (2020–2025 = comparação com a v1; cada ano; 2010–2025 = só sensibilidade,
#     a fragmentação cresce com a janela) × recorte (núcleo, clínico, medicamento)
#   data/consolidated/sia_pacientes_tratamento.parquet  pacientes em tratamento com
#     adalimumabe = MEDIANA MENSAL de APAC distintas (L732, canal medicamento), ano × UF
# Rodar (R550-2, após get_hs_data_from_SIA.R): Rscript scripts/feature_eng_pacientes_SIA.R
# =============================================================================

source(here::here("scripts", "00_setup.R"))
source(here::here("scripts", "pseudo_id_motor.R"))

sia <- arrow::open_dataset(here::here("data/parquet/sia_hs")) |>
  dplyr::filter(camada == "nucleo") |>
  dplyr::select(ano, mes, canal, uf_pcn, sexo, idade_anos, pa_munpcn, pa_racacor,
                competencia, pa_autoriz, pa_docorig, pa_proc_id) |>
  dplyr::collect() |>
  normalizar_quase_id()

recortes <- list(nucleo = c("medicamento", "clinico_apac", "clinico_bpai", "outro"),
                 clinico = c("clinico_apac", "clinico_bpai"),
                 medicamento = "medicamento")
janelas <- c(list(`2020-2025` = 2020:2025), stats::setNames(as.list(ANOS), ANOS),
             list(`2010-2025` = ANOS))

grade <- tidyr::expand_grid(janela = names(janelas), recorte = names(recortes))
res <- purrr::pmap_dfr(grade, function(janela, recorte) {
  s <- dplyr::filter(sia, ano %in% janelas[[janela]], canal %in% recortes[[recorte]])
  if (!nrow(s)) return(NULL)
  message(sprintf("  %s × %s: %d registros", janela, recorte, nrow(s)))
  dplyr::bind_cols(tibble::tibble(janela = janela, recorte = recorte), resumo_gradiente(s))
})
res <- dplyr::mutate(res, registros_por_paciente = round(registros / pseudo_intermediaria, 2))
readr::write_csv(res, here::here("manifest/sia_pseudo_pacientes_v2.csv"))

cat("\n• pseudo-pacientes — janelas longas (registros | frouxa | central | estrita):\n")
print(as.data.frame(dplyr::filter(res, janela %in% c("2020-2025", "2010-2025"))))

# Pacientes em tratamento com adalimumabe (guia §8.2): APAC distintas por mês → mediana anual
trat <- sia |>
  dplyr::filter(canal == "medicamento", !is.na(apac_n)) |>
  dplyr::group_by(ano, mes, uf = dplyr::coalesce(uf_pcn, "NI")) |>
  dplyr::summarise(apac = dplyr::n_distinct(apac_n), .groups = "drop")
trat_uf <- trat |> dplyr::group_by(ano, uf) |>
  dplyr::summarise(pacientes_mes_mediana = stats::median(apac), meses = dplyr::n(), .groups = "drop")
trat_br <- trat |> dplyr::group_by(ano, mes) |> dplyr::summarise(apac = sum(apac), .groups = "drop") |>
  dplyr::group_by(ano) |>
  dplyr::summarise(pacientes_mes_mediana = stats::median(apac), meses = dplyr::n(), .groups = "drop") |>
  dplyr::mutate(uf = "BR")
trat_out <- dplyr::bind_rows(trat_br, trat_uf)
arrow::write_parquet(trat_out, here::here("data/consolidated/sia_pacientes_tratamento.parquet"))
cat("\n• pacientes em tratamento com adalimumabe (Brasil, mediana mensal de APAC):\n")
print(as.data.frame(trat_br))

message("\n✓ pseudo-pacientes → manifest/sia_pseudo_pacientes_v2.csv; tratamento → sia_pacientes_tratamento.parquet")
