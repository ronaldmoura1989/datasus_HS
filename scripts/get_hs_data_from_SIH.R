# =============================================================================
# get_hs_data_from_SIH.R — Consolidação do SIH-RD HS 2010–2025 (v2, roda no R550-2)
# Entrada: <DIR_FILTRADO>/SIH-RD/{filtrado,denominador}/ (scripts/r550/filtrar_um_hs.R).
# Molde: datasus_EIM/scripts/get_eim_data_from_SIH.R; regras do plano_expansao_2010.md E8.
#
# Regras (guia ref/guia_processamento_datasus.md §6.2):
#   - unidade = AIH DISTINTA (N_AIH); IDENT == 5 marcado como continuação;
#   - ano = ANO_CMPT (competência do arquivo); fora de ANOS sai;
#   - DOIS SABORES: (a) principal = DIAG_PRINC (série primária, comparável ao SIA);
#     (b) qualquer campo = principal + secundários (TETO: cresce com o preenchimento,
#     DIAG_SECUN até 2014 e DIAGSEC1–9 depois — guia §5);
#   - comorbidade = CID secundário DENTRO da AIH-HS (lookup, domínio "comorb"):
#     "registrada na AIH", nunca prevalência;
#   - texto → número em valores/diárias; NÃO reconverter latin1.
# Saídas (data/ do repo no R550-2):
#   data/parquet/sih_hs/                  AIH com L73 ou L02 em qualquer campo (ano + uf de residência)
#   data/consolidated/sih_denominador_agg.parquet  todas as AIH (ano × mês × ident × uf × sexo)
# Rodar (R550-2): Rscript scripts/get_hs_data_from_SIH.R
# =============================================================================

source(here::here("scripts", "00_setup.R"))

DIR_SIH <- file.path(path.expand(DIR_FILTRADO), "SIH-RD")
if (!dir.exists(file.path(DIR_SIH, "filtrado"))) stop("Sem filtrados SIH em ", DIR_SIH)
abrir <- function(sub) arrow::open_dataset(file.path(DIR_SIH, sub), unify_schemas = TRUE)
PRIOR <- c("nucleo", "limitrofe", "diferencial", "envelope")   # camada "mais forte" primeiro

message("== SIH: AIH com L73/L02 ==")
sih <- abrir("filtrado") |>
  dplyr::filter(hit_hs | hit_hs_env) |>
  dplyr::select(-dplyr::starts_with("hit_")) |>
  dplyr::collect() |>
  janitor::clean_names() |>
  dplyr::filter(as.integer(ano_cmpt) %in% ANOS)

cols_sec <- intersect(c("diag_secun", paste0("diagsec", 1:9)), names(sih))
cam_sec <- purrr::map(cols_sec, ~ classificar_hs(sih[[.x]], "hs"))
# camada mais forte entre os secundários (nucleo > limitrofe > diferencial > envelope)
melhor <- function(lst) {
  if (!length(lst)) return(rep(NA_character_, nrow(sih)))
  idx <- purrr::map(lst, ~ match(.x, PRIOR)) |> purrr::reduce(pmin, na.rm = TRUE)
  PRIOR[idx]
}
comorb <- HS_LOOKUP |> dplyr::filter(dominio == "comorb") |>
  dplyr::mutate(nome = janitor::make_clean_names(rotulo, allow_dupes = TRUE))

sih <- sih |>
  coagir_tipos(monetarias = c("val_tot", "val_sh", "val_sp", "val_uti", "val_sadt"),
               datas = c("dt_inter", "dt_saida", "nasc")) |>
  dplyr::mutate(
    ano              = as.integer(ano_cmpt),
    mes              = as.integer(mes_cmpt),
    competencia      = lubridate::make_date(ano, mes, 1L),
    camada_principal = classificar_hs(diag_princ, "hs"),
    camada_sec       = melhor(cam_sec),
    camada_qualquer  = PRIOR[pmin(match(camada_principal, PRIOR), match(camada_sec, PRIOR), na.rm = TRUE)],
    hs_principal     = camada_principal %in% "nucleo",                       # sabor (a)
    hs_qualquer      = hs_principal | camada_sec %in% "nucleo",              # sabor (b)
    # secundário preenchido = CID sintaticamente válido (o vazio vem como "0000" ou branco)
    n_sec_preench    = rowSums(as.data.frame(purrr::map(cols_sec, ~ cid_valido(sih[[.x]]) %in% TRUE))),
    dias_perm        = suppressWarnings(as.numeric(dias_perm)),
    sexo_cod2  = stringr::str_trim(as.character(sexo)) %in% "2",   # fora do layout (1/3); contar
    sexo       = dplyr::recode(stringr::str_trim(as.character(sexo)),
                               "1" = "Masculino", "3" = "Feminino", "2" = "Feminino",
                               .default = NA_character_),
    raca_cor   = dplyr::recode(stringr::str_pad(stringr::str_trim(as.character(raca_cor)), 2, pad = "0"),
                               "01" = "Branca", "02" = "Preta", "03" = "Parda", "04" = "Amarela",
                               "05" = "Indígena", .default = NA_character_),
    idade_anos = as.integer(floor(idade_em_anos(idade, cod_idade))),
    idade_anos = dplyr::if_else(idade_anos >= 0 & idade_anos <= 110, idade_anos, NA_integer_),
    faixa      = harmonizar_faixa(idade_anos),
    uf_res     = uf_from_mun(munic_res),       # residência (epidemiologia)
    uf_mov     = uf_from_mun(munic_mov),       # hospital (oferta)
    regiao     = mapear_uf_regiao(uf_res),
    carater    = dplyr::recode(stringr::str_pad(stringr::str_trim(as.character(car_int)), 2, pad = "0"),
                               "01" = "Eletivo", "02" = "Urgência", .default = NA_character_),
    obito_aih  = suppressWarnings(as.integer(morte)) %in% 1L,
    uti        = suppressWarnings(as.numeric(uti_mes_to)) > 0,
    aih_continuacao = stringr::str_trim(as.character(ident)) == "5",   # [CONFIRMAR no dicionário]
    uf_arquivo = arq_uf,
    fonte      = "datasus_sih_rd_dbc")

# Matriz de comorbidades nos SECUNDÁRIOS (prefixo de 3 caracteres, lookup "comorb")
for (nm in unique(comorb$nome)) {
  prefs <- comorb$prefixo[comorb$nome == nm]
  sih[[paste0("com_", nm)]] <- purrr::reduce(
    purrr::map(cols_sec, ~ substr(toupper(trimws(sih[[.x]])), 1, 3) %in% prefs), `|`, .init = FALSE)
}
sih$com_abscesso_l02 <- purrr::reduce(
  purrr::map(cam_sec, ~ .x %in% "envelope"), `|`, .init = FALSE)

# -----------------------------------------------------------------------------
# QC
# -----------------------------------------------------------------------------
cat("\n• AIH por camada no principal × camada em qualquer campo (AIH distintas):\n")
print(sih |> dplyr::distinct(n_aih, camada_principal, camada_qualquer) |>
        janitor::tabyl(camada_qualquer, camada_principal))
cat("• AIH distintas com HS por ano — principal | qualquer campo | % com algum secundário:\n")
print(sih |> dplyr::group_by(ano) |>
        dplyr::summarise(principal = dplyr::n_distinct(n_aih[hs_principal]),
                         qualquer  = dplyr::n_distinct(n_aih[hs_qualquer]),
                         pct_sec_preench_hs = round(100 * mean(n_sec_preench[hs_principal] > 0), 1),
                         .groups = "drop") |> as.data.frame())
hsp <- dplyr::filter(sih, hs_principal)
cat(sprintf("• HS principal: %d AIH | continuação (ident=5): %d | sexo código 2: %d | idade mediana %.0f | óbitos %d\n",
            dplyr::n_distinct(hsp$n_aih), sum(hsp$aih_continuacao, na.rm = TRUE), sum(hsp$sexo_cod2, na.rm = TRUE),
            stats::median(hsp$idade_anos, na.rm = TRUE), sum(hsp$obito_aih)))
cat("• top 12 PROC_REA nas AIH HS (principal):\n")
print(as.data.frame(head(dplyr::count(hsp, proc_rea, sort = TRUE), 12)))
cat(sprintf("• linhas com L02 (envelope) em algum campo e sem L73: %d\n",
            sum(is.na(sih$camada_qualquer) | sih$camada_qualquer == "envelope")))

unlink(here::here("data/parquet/sih_hs"), recursive = TRUE)
sih |> dplyr::mutate(uf = dplyr::coalesce(uf_res, "NI")) |>
  arrow::write_dataset(here::here("data/parquet/sih_hs"), partitioning = c("ano", "uf"), format = "parquet")

message("== SIH: denominador ==")
den <- abrir("denominador") |>
  dplyr::group_by(ano_cmpt, mes_cmpt, ident, uf_res, uf_mov, sexo) |>
  dplyr::summarise(aih = sum(aih), obitos = sum(obitos), diarias = sum(diarias), .groups = "drop") |>
  dplyr::collect() |>
  dplyr::mutate(ano = as.integer(ano_cmpt)) |>
  dplyr::filter(ano %in% ANOS)
arrow::write_parquet(den, here::here("data/consolidated/sih_denominador_agg.parquet"))
print(den |> dplyr::group_by(ano) |> dplyr::summarise(aih = sum(aih)) |> as.data.frame())

registrar_versao_lookup()
message(sprintf("\n✓ SIH v2: %d AIH com L73/L02 (%d HS principal, %d HS qualquer campo) → data/parquet/sih_hs.",
                dplyr::n_distinct(sih$n_aih), dplyr::n_distinct(sih$n_aih[sih$hs_principal]),
                dplyr::n_distinct(sih$n_aih[sih$hs_qualquer])))
