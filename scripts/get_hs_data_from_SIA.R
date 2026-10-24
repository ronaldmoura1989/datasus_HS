# =============================================================================
# get_hs_data_from_SIA.R — Consolidação do SIA-PA HS 2010–2025 (v2, roda no R550-2)
# Entrada: <DIR_FILTRADO>/SIA-PA/{filtrado,agregado_env,agregado_derm,denominador}/
#          (scripts/r550/filtrar_um_hs.R: DBC 2010+, colunas em TEXTO, flags hit_*).
# Molde: datasus_EIM/scripts/get_eim_data_from_SIA.R; regras do plano_expansao_2010.md E7.
#
# Regras (guia ref/guia_processamento_datasus.md §6.1):
#   - ANO ANALÍTICO = ano de PA_CMP (atendimento), não do arquivo; PA_CMP fora de ANOS sai
#     (os arquivos de 2026 só servem para fechar as competências de 2025);
#   - camada pelo CID PRINCIPAL (série longa: PA_CIDSEC some depois de 2014 — guia §5);
#   - CANAL: medicamento = APAC (P/S) de adalimumabe; clinico_apac = outra APAC;
#     clinico_bpai = BPA-I. O BPA-C não tem CID e não entra no numerador;
#   - texto → número nas quantidades/valores; NÃO reconverter latin1 (já é UTF-8).
# Saídas (data/ do repo no R550-2):
#   data/parquet/sia_hs/                   L73 no principal, registro completo (ano + uf de residência)
#   data/consolidated/sia_hs_l73_so_secundario.parquet  auditoria (L73 só em cidsec/cidcas)
#   data/consolidated/sia_adalimumabe_agg.parquet       adalimumabe em QUALQUER CID (agregado)
#   data/consolidated/sia_hs_envelope_agg.parquet       L02 no principal (agregado)
#   data/consolidated/sia_derm_agg.parquet              produção de CBO dermatologista
#   data/consolidated/sia_denominador_agg.parquet       todo o SIA-PA (cmp × docorig × grupo × uf)
# Rodar (R550-2): Rscript scripts/get_hs_data_from_SIA.R
# =============================================================================

source(here::here("scripts", "00_setup.R"))

DIR_SIA <- file.path(path.expand(DIR_FILTRADO), "SIA-PA")
if (!dir.exists(file.path(DIR_SIA, "filtrado"))) stop("Sem filtrados SIA em ", DIR_SIA)
CMP_MIN <- sprintf("%d01", min(ANOS)); CMP_MAX <- sprintf("%d12", max(ANOS))
MON <- c("pa_valpro", "pa_valapr", "pa_vl_cf", "pa_vl_cl", "pa_vl_inc")
abrir <- function(sub) arrow::open_dataset(file.path(DIR_SIA, sub), unify_schemas = TRUE)
na_ni <- function(uf) dplyr::coalesce(uf, "NI")

# -----------------------------------------------------------------------------
# 1. Registros L73 (núcleo, limítrofe, diferencial)
# -----------------------------------------------------------------------------
message("== SIA: registros L73 ==")
l73 <- abrir("filtrado") |>
  dplyr::filter(hit_hs) |>
  dplyr::select(-dplyr::starts_with("hit_")) |>
  dplyr::collect() |>
  janitor::clean_names() |>
  dplyr::mutate(camada = classificar_hs(pa_cidpri, "hs"),
                camada_sec = dplyr::coalesce(classificar_hs(pa_cidsec, "hs"), classificar_hs(pa_cidcas, "hs")))

so_sec <- dplyr::filter(l73, is.na(camada))
sia <- l73 |>
  dplyr::filter(!is.na(camada), pa_cmp >= CMP_MIN, pa_cmp <= CMP_MAX) |>
  coagir_tipos(monetarias = MON) |>
  dplyr::mutate(
    ano        = as.integer(substr(pa_cmp, 1, 4)),
    mes        = as.integer(substr(pa_cmp, 5, 6)),
    competencia = lubridate::ym(pa_cmp),
    pa_qtdapr  = suppressWarnings(as.numeric(pa_qtdapr)),
    pa_qtdpro  = suppressWarnings(as.numeric(pa_qtdpro)),
    adalimumabe = classificar_hs(pa_proc_id, "proc") %in% "medicamento",
    canal = dplyr::case_when(
      pa_docorig %in% c("P", "S") & adalimumabe ~ "medicamento",
      pa_docorig %in% c("P", "S")               ~ "clinico_apac",
      pa_docorig == "I"                         ~ "clinico_bpai",
      TRUE                                      ~ "outro"),
    sexo       = dplyr::recode(toupper(stringr::str_trim(pa_sexo)),
                               F = "Feminino", M = "Masculino", .default = NA_character_),
    raca_cor   = dplyr::recode(stringr::str_pad(stringr::str_trim(pa_racacor), 2, pad = "0"),
                               "01" = "Branca", "02" = "Preta", "03" = "Parda", "04" = "Amarela",
                               "05" = "Indígena", .default = NA_character_),   # 99 -> NA
    idade_anos = suppressWarnings(as.integer(pa_idade)),
    idade_anos = dplyr::if_else(idade_anos >= 0 & idade_anos <= 110, idade_anos, NA_integer_),
    faixa      = harmonizar_faixa(idade_anos),
    uf_pcn     = uf_from_mun(pa_munpcn),          # residência (epidemiologia)
    uf_estab   = uf_from_mun(pa_ufmun),           # estabelecimento (oferta)
    regiao     = mapear_uf_regiao(uf_pcn),
    uf_arquivo = arq_uf,
    fonte      = "datasus_sia_pa_dbc")

fora <- nrow(l73) - nrow(so_sec) - nrow(sia)
cat(sprintf("\n• L73 lidos: %d | só no secundário (auditoria): %d | PA_CMP fora de %s–%s: %d | mantidos: %d\n",
            nrow(l73), nrow(so_sec), CMP_MIN, CMP_MAX, fora, nrow(sia)))
cat("• camada × canal (linhas):\n"); print(janitor::tabyl(sia, camada, canal))
cat("• núcleo por ano e canal (linhas | Σ qtd_apr):\n")
print(sia |> dplyr::filter(camada == "nucleo") |>
        dplyr::group_by(ano, canal) |>
        dplyr::summarise(linhas = dplyr::n(), qtd = sum(pa_qtdapr, na.rm = TRUE), .groups = "drop") |>
        tidyr::pivot_wider(names_from = canal, values_from = c(linhas, qtd), values_fill = 0) |>
        as.data.frame())
cat("• top 15 procedimentos do núcleo por canal:\n")
print(sia |> dplyr::filter(camada == "nucleo") |> dplyr::count(canal, pa_proc_id, sort = TRUE) |>
        dplyr::group_by(canal) |> dplyr::slice_head(n = 15) |> as.data.frame())
cat(sprintf("• núcleo: idade mediana %.0f | %% feminino %.1f | uf_pcn NA %d | raça NA %.1f%%\n",
            median(sia$idade_anos[sia$camada == "nucleo"], na.rm = TRUE),
            100 * mean(sia$sexo[sia$camada == "nucleo"] == "Feminino", na.rm = TRUE),
            sum(is.na(sia$uf_pcn)), 100 * mean(is.na(sia$raca_cor))))

unlink(here::here("data/parquet/sia_hs"), recursive = TRUE)
sia |> dplyr::mutate(uf = na_ni(uf_pcn)) |>
  arrow::write_dataset(here::here("data/parquet/sia_hs"), partitioning = c("ano", "uf"), format = "parquet")
arrow::write_parquet(so_sec, here::here("data/consolidated/sia_hs_l73_so_secundario.parquet"))
rm(l73, so_sec); invisible(gc(verbose = FALSE))

# -----------------------------------------------------------------------------
# 2. Adalimumabe em QUALQUER CID (agregado; auditoria de vigência e de CID)
# -----------------------------------------------------------------------------
message("== SIA: adalimumabe (todos os CID) ==")
ada <- abrir("filtrado") |>
  dplyr::filter(hit_hs_proc, PA_CMP >= CMP_MIN, PA_CMP <= CMP_MAX) |>
  dplyr::mutate(cid4 = substr(PA_CIDPRI, 1, 4), uf2 = substr(PA_MUNPCN, 1, 2),
                qtd = as.numeric(PA_QTDAPR)) |>
  dplyr::group_by(cmp = PA_CMP, proc = PA_PROC_ID, cid4, uf2, docorig = PA_DOCORIG) |>
  dplyr::summarise(linhas = dplyr::n(), qtd_apr = sum(qtd, na.rm = TRUE),
                   apac = dplyr::n_distinct(PA_AUTORIZ), .groups = "drop") |>
  dplyr::collect() |>
  dplyr::mutate(ano = as.integer(substr(cmp, 1, 4)), uf_pcn = uf_from_mun(uf2),
                camada = classificar_hs(cid4, "hs")) |>
  dplyr::select(-uf2)
arrow::write_parquet(ada, here::here("data/consolidated/sia_adalimumabe_agg.parquet"))
cat("• adalimumabe por código × ano (linhas), L732 vs outros CID:\n")
print(ada |> dplyr::group_by(ano, proc, l732 = camada %in% "nucleo") |>
        dplyr::summarise(linhas = sum(linhas), .groups = "drop") |>
        tidyr::pivot_wider(names_from = c(proc, l732), values_from = linhas, values_fill = 0) |>
        as.data.frame())

# -----------------------------------------------------------------------------
# 3. Agregados gravados na leitura (envelope L02, dermatologia, denominador)
# -----------------------------------------------------------------------------
agregar <- function(sub, chaves, medidas) {
  abrir(sub) |>
    dplyr::filter(cmp >= CMP_MIN, cmp <= CMP_MAX) |>
    dplyr::group_by(dplyr::across(dplyr::all_of(chaves))) |>
    dplyr::summarise(dplyr::across(dplyr::all_of(medidas), ~ sum(.x, na.rm = TRUE)), .groups = "drop") |>
    dplyr::collect() |>
    dplyr::mutate(ano = as.integer(substr(cmp, 1, 4)))
}
message("== SIA: agregados ==")
env <- agregar("agregado_env", c("cmp", "uf_res", "sexo", "faixa", "cid4", "docorig", "grupo_proc"),
               c("linhas", "qtd_apr"))
derm <- agregar("agregado_derm", c("cmp", "uf_res", "uf_estab", "docorig", "sexo", "faixa", "cid_l732"),
                c("linhas", "qtd_apr"))
den <- agregar("denominador", c("cmp", "docorig", "grupo_proc", "uf_res"), c("linhas", "qtd_apr", "val_apr"))
arrow::write_parquet(env,  here::here("data/consolidated/sia_hs_envelope_agg.parquet"))
arrow::write_parquet(derm, here::here("data/consolidated/sia_derm_agg.parquet"))
arrow::write_parquet(den,  here::here("data/consolidated/sia_denominador_agg.parquet"))

cobertura <- den |> dplyr::group_by(ano) |>
  dplyr::summarise(qtd_total = sum(qtd_apr), qtd_com_cid = sum(qtd_apr[docorig %in% c("I", "P", "S")]),
                   .groups = "drop") |>
  dplyr::mutate(pct_com_cid = round(100 * qtd_com_cid / qtd_total, 1))
cat("• fração do volume SIA-PA (Σ qtd_apr) em instrumentos COM CID (BPA-I/APAC):\n"); print(as.data.frame(cobertura))
cat(sprintf("• envelope L02: %s linhas | derm: %s linhas | denominador: %s linhas lidas\n",
            format(sum(env$linhas), big.mark = "."), format(sum(derm$linhas), big.mark = "."),
            format(sum(den$linhas), big.mark = ".")))

registrar_versao_lookup()
message(sprintf("\n✓ SIA v2: %d registros L73 (%d núcleo) → data/parquet/sia_hs + agregados.",
                nrow(sia), sum(sia$camada == "nucleo")))
