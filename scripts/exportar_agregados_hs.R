# =============================================================================
# exportar_agregados_hs.R — E13, opção (a): o site só lê AGREGADOS já suprimidos
# Roda no R550-2 depois do pipeline (scripts/r550/rodar_pipeline_hs.sh). Monta as
# tabelas prontas para as figuras/tabelas dos .qmd, aplica supressão LGPD
# (1 ≤ N < N_SUPRESSAO → NA, inclusive nas taxas) e grava:
#   data/export/hs_v2_agregados.rds   lista nomeada de tabelas + totais (`tot`) + metadados
#   data/export/csv/<tabela>.csv      as mesmas tabelas, para auditoria
# Nenhum microdado, chave de pseudo-ID ou município sai daqui (só UF/região/Brasil).
# Inclui as revisões da 1ª rodada (plano_expansao_2010.md, status): normalização do canal
# clínico pela produção dermatológica; ITS com COVID até 2022, sem 2020–2021 e sem
# anatomopatológico/citologia (L73.2 compatível a partir de 2019).
# Copiar para o local: rsync R550-2:Documentos/ronald/datasus_HS/data/export/ data/export/
# Rodar (R550-2): Rscript scripts/exportar_agregados_hs.R
# =============================================================================

source(here::here("scripts", "00_setup.R"))
source(here::here("scripts", "calcular_taxas.R"))

sup <- function(x) ifelse(!is.na(x) & x > 0 & x < N_SUPRESSAO, NA, x)   # supressão de célula
sup_df <- function(df, cols) dplyr::mutate(df, dplyr::across(dplyr::all_of(cols), sup))
E <- list()
cons <- function(f) here::here("data/consolidated", f)

pop <- carregar_pop()
pop_ano <- pop |> dplyr::group_by(ano) |> dplyr::summarise(pop = sum(pop), .groups = "drop")

sia <- arrow::open_dataset(here::here("data/parquet/sia_hs")) |>
  dplyr::select(ano, mes, pa_cmp, canal, camada, uf_pcn, uf_estab, regiao, sexo, faixa, raca_cor,
                idade_anos, pa_qtdapr, pa_proc_id, pa_autoriz, pa_munpcn, pa_ufmun, pa_docorig) |>
  dplyr::collect()
nuc <- dplyr::filter(sia, camada == "nucleo")
clin <- dplyr::filter(nuc, canal %in% c("clinico_apac", "clinico_bpai"))
med  <- dplyr::filter(nuc, canal == "medicamento")

sih_all <- arrow::open_dataset(here::here("data/parquet/sih_hs")) |> dplyr::collect()
sih <- dplyr::filter(sih_all, hs_principal)
sim <- arrow::read_parquet(cons("sim_hs.parquet"))
simd <- dplyr::filter(sim, hs_qualquer, status_dado == "DEFINITIVO", ano %in% ANOS_SIM)
trat <- arrow::read_parquet(cons("sia_pacientes_tratamento.parquet"))
taxas <- arrow::read_parquet(cons("taxas_hs.parquet"))
derm_uf <- arrow::read_parquet(here::here("data/denominators/dermatologistas_uf.parquet"))

# -----------------------------------------------------------------------------
# 1. Séries nacionais por ano (todas as bases, em paralelo)
# -----------------------------------------------------------------------------
E$serie_ano <- tidyr::expand_grid(ano = ANOS) |>
  dplyr::left_join(clin |> dplyr::group_by(ano) |>
                     dplyr::summarise(sia_clinico_linhas = dplyr::n(),
                                      sia_clinico_qtd = sum(pa_qtdapr, na.rm = TRUE)), by = "ano") |>
  dplyr::left_join(med |> dplyr::group_by(ano) |>
                     dplyr::summarise(sia_medic_linhas = dplyr::n(),
                                      sia_medic_seringas = sum(pa_qtdapr, na.rm = TRUE)), by = "ano") |>
  dplyr::left_join(trat |> dplyr::filter(uf == "BR") |>
                     dplyr::select(ano, sia_trat_pacientes = pacientes_mes_mediana), by = "ano") |>
  dplyr::left_join(sih_all |> dplyr::group_by(ano) |>
                     dplyr::summarise(sih_principal = dplyr::n_distinct(n_aih[hs_principal]),
                                      sih_qualquer = dplyr::n_distinct(n_aih[hs_qualquer])), by = "ano") |>
  dplyr::left_join(sim |> dplyr::filter(ano %in% ANOS) |> dplyr::group_by(ano, status_sim = status_dado) |>
                     dplyr::summarise(sim_qualquer = sum(hs_qualquer), sim_cb = sum(hs_causa_basica),
                                      .groups = "drop"), by = "ano") |>
  dplyr::mutate(dplyr::across(-c(ano, status_sim), ~ tidyr::replace_na(.x, 0))) |>
  sup_df(c("sih_principal", "sih_qualquer", "sim_qualquer", "sim_cb"))

# Totais (nacionais; só o necessário ao texto — sem célula pequena isolada)
E$tot <- list(
  sia_nucleo_linhas = nrow(nuc), sia_linhas_l73 = nrow(sia),
  sia_clinico_linhas = nrow(clin), sia_clinico_qtd = sum(clin$pa_qtdapr, na.rm = TRUE),
  sia_medic_linhas = nrow(med), pct_medic = 100 * nrow(med) / nrow(nuc),
  sia_fem_pct = 100 * mean(nuc$sexo == "Feminino", na.rm = TRUE),
  sia_idade_mediana = stats::median(nuc$idade_anos, na.rm = TRUE),
  sih_aih_principal = dplyr::n_distinct(sih$n_aih),
  sih_aih_qualquer = dplyr::n_distinct(sih_all$n_aih[sih_all$hs_qualquer]),
  sih_perm_mediana = stats::median(sih$dias_perm, na.rm = TRUE),
  sih_urg_pct = 100 * mean(sih$carater == "Urgência", na.rm = TRUE),
  sih_gasto_nominal = sum(sih$val_tot, na.rm = TRUE),
  sih_pct_sec = 100 * mean(sih$n_sec_preench > 0),
  sih_obitos = sum(sih$obito_aih), sih_idade_mediana = stats::median(sih$idade_anos, na.rm = TRUE),
  sim_qualquer_def = nrow(simd), sim_cb_def = sum(simd$hs_causa_basica),
  sim_parte_ii_def = sum(simd$hs_parte_ii),
  sim_idade_mediana = stats::median(simd$idade_anos, na.rm = TRUE),
  sim_fem_pct = 100 * mean(simd$sexo == "Feminino", na.rm = TRUE),
  sim_prelim = sum(sim$hs_qualquer[sim$status_dado == "PRELIM" & sim$ano == 2025]),
  anos = range(ANOS), anos_sim = range(ANOS_SIM))

# -----------------------------------------------------------------------------
# 2. Taxas, tendências e ITS (já suprimidas em taxas_tendencias_hs.R)
# -----------------------------------------------------------------------------
num_clin <- contar_estrato(clin, col_uf = "uf_pcn", peso = "pa_qtdapr")
alvo_f <- c("20-24", "25-29", "30-34", "35-39")
E$taxas <- dplyr::bind_rows(
  taxas,
  taxa_bruta(dplyr::filter(num_clin, sexo == "Feminino", faixa %in% alvo_f),
             dplyr::filter(pop, sexo == "Feminino", faixa %in% alvo_f), "ano") |>
    dplyr::mutate(serie = "sia_clinico_mulheres_20_39", nivel = "BR"),
  taxas_padronizadas(contar_estrato(dplyr::filter(sih_all, hs_qualquer), "uf_res", distinct_por = "n_aih"),
                     pop, "ano") |> dplyr::mutate(serie = "sih_qualquer", nivel = "BR"))
E$tendencias <- readr::read_csv(cons("tendencias_hs.csv"), show_col_types = FALSE)

# Produção dermatológica (CBO 223117/225135): parte com L732 no BPA-I → normaliza o canal
# clínico pelo crescimento do registro individualizado
derm_prod <- arrow::read_parquet(cons("sia_derm_agg.parquet"))
E$derm_producao <- derm_prod |>
  dplyr::group_by(ano) |>
  dplyr::summarise(qtd_derm = sum(qtd_apr), qtd_derm_bpai = sum(qtd_apr[docorig == "I"]),
                   qtd_derm_l732 = sum(qtd_apr[cid_l732 %in% TRUE & docorig == "I"]), .groups = "drop") |>
  dplyr::mutate(l732_por_mil_bpai_derm = 1000 * qtd_derm_l732 / qtd_derm_bpai,
                pct_bpai_derm = 100 * qtd_derm_bpai / qtd_derm) |>
  sup_df("qtd_derm_l732")
den <- arrow::read_parquet(cons("sia_denominador_agg.parquet"))
E$cobertura_cid <- den |> dplyr::group_by(ano) |>
  dplyr::summarise(qtd_total = sum(qtd_apr), qtd_bpai = sum(qtd_apr[docorig == "I"]),
                   qtd_com_cid = sum(qtd_apr[docorig %in% c("I", "P", "S")]), .groups = "drop") |>
  dplyr::mutate(pct_com_cid = 100 * qtd_com_cid / qtd_total, pct_bpai = 100 * qtd_bpai / qtd_total)

# ITS: primária (marco 201911, COVID 2020-03 a 2021-12) + sensibilidades
MARCO <- "201911"; INICIO_CLIN <- "201401"
COVID_22 <- sprintf("%d%02d", rep(2020:2022, each = 12), 1:12)[-(1:2)]
pop_mes <- dplyr::mutate(pop_ano, pop = pop / 12)
mensal <- function(df, inicio, valor = c("qtd", "aih")) {
  valor <- match.arg(valor)
  df |> dplyr::mutate(cmp = sprintf("%d%02d", ano, mes)) |>
    dplyr::group_by(cmp, ano) |>
    dplyr::summarise(eventos = if (valor == "qtd") sum(pa_qtdapr, na.rm = TRUE) else dplyr::n_distinct(n_aih),
                     .groups = "drop") |>
    dplyr::right_join(tidyr::expand_grid(ano = ANOS, m = 1:12) |>
                        dplyr::transmute(ano, cmp = sprintf("%d%02d", ano, m)), by = c("cmp", "ano")) |>
    dplyr::mutate(eventos = tidyr::replace_na(eventos, 0)) |>
    dplyr::left_join(pop_mes, by = "ano") |>
    dplyr::filter(cmp >= inicio)
}
ANAT <- c("0203020030", "0203010035")   # anatomopatológico/citologia (ref/sigtap_hs.csv)
s_clin <- mensal(clin, INICIO_CLIN)
s_clin_sem_anat <- mensal(dplyr::filter(clin, !pa_proc_id %in% ANAT), INICIO_CLIN)
s_sih <- mensal(sih, "201001", "aih")
sem_covid <- function(s) dplyr::filter(s, !cmp %in% COVID_MESES)
cenarios <- list(
  primaria             = list(m = MARCO,    cv = COVID_MESES, f = identity),
  marco_alternativo    = list(m = "201811", cv = COVID_MESES, f = identity),
  covid_ate_2022       = list(m = MARCO,    cv = COVID_22,    f = identity),
  sem_2020_2021        = list(m = MARCO,    cv = character(), f = sem_covid))
its <- purrr::imap_dfr(cenarios, function(c, nome) dplyr::bind_rows(
  its_poisson(c$f(s_clin), c$m, c$cv) |> dplyr::mutate(serie = "sia_clinico"),
  its_poisson(c$f(s_sih),  c$m, c$cv) |> dplyr::mutate(serie = "sih_principal")) |>
    dplyr::mutate(cenario = nome))
its <- dplyr::bind_rows(its, its_poisson(s_clin_sem_anat, MARCO) |>
                          dplyr::mutate(serie = "sia_clinico_sem_anatomopat", cenario = "primaria"))
E$its <- dplyr::select(its, serie, cenario, efeito, estimativa, ic_inf, ic_sup, marco, n_meses, dispersao)
E$its_ajuste <- dplyr::bind_rows(
  its_ajuste(s_clin, MARCO) |> dplyr::mutate(serie = "sia_clinico"),
  its_ajuste(s_sih, MARCO)  |> dplyr::mutate(serie = "sih_principal")) |>
  dplyr::select(serie, cmp, ano, mes, eventos, ajustado, contrafactual, pop) |>
  sup_df("eventos")

# -----------------------------------------------------------------------------
# 3. Perfil (pirâmides, raça/cor), geografia, fluxo, procedimentos
# -----------------------------------------------------------------------------
periodo <- function(ano) dplyr::if_else(ano <= 2019, "2010–2019", "2020–2025")
E$piramide <- dplyr::bind_rows(
  clin |> dplyr::count(faixa, sexo, name = "n") |> dplyr::mutate(base = "SIA clínico (linhas)"),
  med  |> dplyr::count(faixa, sexo, name = "n") |> dplyr::mutate(base = "SIA adalimumabe (linhas)"),
  sih  |> dplyr::distinct(n_aih, .keep_all = TRUE) |> dplyr::count(faixa, sexo, name = "n") |>
    dplyr::mutate(base = "SIH (AIH)"),
  simd |> dplyr::count(faixa, sexo, name = "n") |> dplyr::mutate(base = "SIM (óbitos, qualquer campo)")) |>
  dplyr::filter(!is.na(faixa), !is.na(sexo)) |>
  dplyr::mutate(faixa = as.character(faixa)) |> sup_df("n")
E$raca <- nuc |>
  dplyr::mutate(canal = dplyr::if_else(canal == "medicamento", "adalimumabe", "clínico"),
                periodo = periodo(ano),
                raca_cor = dplyr::coalesce(raca_cor, "Não informada")) |>
  dplyr::count(canal, periodo, raca_cor, name = "n") |> sup_df("n")
E$completude <- readr::read_csv(here::here("manifest/completude_hs_por_ano.csv"), show_col_types = FALSE)

E$heatmap <- nuc |>
  dplyr::filter(!is.na(uf_pcn)) |>
  dplyr::mutate(canal = dplyr::if_else(canal == "medicamento", "adalimumabe (linhas)", "clínico (Σ qtd)")) |>
  dplyr::group_by(canal, ano, uf = uf_pcn) |>
  dplyr::summarise(n = dplyr::if_else(dplyr::first(canal) == "adalimumabe (linhas)",
                                      as.numeric(dplyr::n()), sum(pa_qtdapr, na.rm = TRUE)), .groups = "drop") |>
  tidyr::complete(canal, ano = ANOS, uf = UFS, fill = list(n = 0)) |>
  dplyr::mutate(regiao = mapear_uf_regiao(uf)) |> sup_df("n")

E$derm_uf <- derm_uf
# taxa clínica por UF no período 2014–2025 (canal clínico com CID) para cruzar com oferta
E$uf_clinico_2014 <- taxas_padronizadas(dplyr::filter(num_clin, ano >= 2014), pop, "uf") |>
  dplyr::left_join(derm_uf |> dplyr::filter(ano >= 2014) |> dplyr::group_by(uf) |>
                     dplyr::summarise(derm_100k = mean(derm_por_100k), .groups = "drop"), by = "uf") |>
  dplyr::mutate(regiao = mapear_uf_regiao(uf))
# referências nacionais em pessoa-anos (taxa DIRETA do país, não média das UFs)
br_pool <- function(num, anos) taxas_padronizadas(dplyr::mutate(dplyr::filter(num, ano %in% anos), .br = "BR"),
                                                  dplyr::mutate(pop, .br = "BR"), ".br")
num_sih <- contar_estrato(sih, col_uf = "uf_res", distinct_por = "n_aih")
E$br_pool <- dplyr::bind_rows(br_pool(num_clin, 2014:2025) |> dplyr::mutate(serie = "sia_clinico", anos = "2014–2025"),
                              br_pool(num_sih, ANOS) |> dplyr::mutate(serie = "sih_principal", anos = "2010–2025"))
E$trat_uf <- trat |> dplyr::filter(uf != "BR") |>
  dplyr::left_join(pop |> dplyr::group_by(uf, ano) |> dplyr::summarise(pop = sum(pop), .groups = "drop"),
                   by = c("uf", "ano")) |>
  dplyr::mutate(por_100k = 1e5 * pacientes_mes_mediana / pop) |>
  sup_df("pacientes_mes_mediana") |>
  dplyr::mutate(por_100k = dplyr::if_else(is.na(pacientes_mes_mediana), NA_real_, por_100k))

limpa_mun <- function(m) { m <- stringr::str_pad(as.character(m), 6, pad = "0")
  dplyr::if_else(stringr::str_detect(m, "^0+$") | m == "999999", NA_character_, m) }
E$fluxo <- nuc |>
  dplyr::mutate(res = limpa_mun(pa_munpcn), est = limpa_mun(pa_ufmun),
                canal = dplyr::if_else(canal == "medicamento", "adalimumabe", "clínico")) |>
  dplyr::filter(!is.na(res), !is.na(est)) |>
  dplyr::mutate(uf = uf_from_mun(res),
                categoria = dplyr::case_when(res == est ~ "No próprio município",
                                             uf == uf_from_mun(est) ~ "Outro município do estado",
                                             TRUE ~ "Outro estado")) |>
  dplyr::filter(uf %in% UFS) |>
  dplyr::count(canal, uf, categoria, name = "n") |> sup_df("n")

E$proc <- nuc |>
  dplyr::mutate(periodo = periodo(ano)) |>
  dplyr::group_by(canal, periodo, pa_proc_id) |>
  dplyr::summarise(linhas = dplyr::n(), qtd = sum(pa_qtdapr, na.rm = TRUE), .groups = "drop") |>
  sup_df(c("linhas", "qtd"))
E$biossimilar_uf <- med |> dplyr::filter(!is.na(uf_pcn)) |>
  dplyr::count(ano, uf = uf_pcn, pa_proc_id, name = "n") |>
  dplyr::mutate(regiao = mapear_uf_regiao(uf)) |> sup_df("n")
E$adalimumabe_todos_cid <- arrow::read_parquet(cons("sia_adalimumabe_agg.parquet")) |>
  dplyr::mutate(l732 = camada %in% "nucleo") |>
  dplyr::group_by(ano, proc, l732) |>
  dplyr::summarise(linhas = sum(linhas), seringas = sum(qtd_apr), .groups = "drop") |> sup_df(c("linhas", "seringas"))
E$envelope <- arrow::read_parquet(cons("sia_hs_envelope_agg.parquet")) |>
  dplyr::group_by(ano, cid4) |> dplyr::summarise(linhas = sum(linhas), qtd = sum(qtd_apr), .groups = "drop") |>
  sup_df(c("linhas", "qtd"))
E$camadas_sia <- sia |> dplyr::count(ano, camada, name = "linhas") |> sup_df("linhas")
E$pseudo <- readr::read_csv(here::here("manifest/sia_pseudo_pacientes_v2.csv"), show_col_types = FALSE)

# -----------------------------------------------------------------------------
# 4. SIH e SIM
# -----------------------------------------------------------------------------
sih1 <- dplyr::distinct(sih, n_aih, .keep_all = TRUE)
E$sih_carater <- sih1 |> dplyr::count(ano, carater, name = "n") |> sup_df("n")
E$sih_perm <- sih1 |> dplyr::mutate(dias = pmin(dias_perm, 30)) |> dplyr::count(dias, name = "n") |> sup_df("n")
com_cols <- grep("^com_", names(sih1), value = TRUE)
# Só o período inteiro: subperíodos + total permitiriam recuperar célula suprimida por diferença
E$sih_comorb <- dplyr::mutate(sih1, periodo = paste0(min(ANOS), "–", max(ANOS))) |>
  dplyr::group_by(periodo) |>
  dplyr::summarise(aih = dplyr::n(), com_secundario = sum(n_sec_preench > 0),
                   dplyr::across(dplyr::all_of(com_cols), sum), .groups = "drop") |>
  tidyr::pivot_longer(dplyr::all_of(com_cols), names_to = "comorbidade", values_to = "n") |>
  dplyr::mutate(comorbidade = stringr::str_remove(comorbidade, "^com_")) |> sup_df("n")
E$sih_custo <- sih1 |> dplyr::group_by(ano) |>
  dplyr::summarise(aih = dplyr::n(), gasto_nominal = sum(val_tot, na.rm = TRUE), .groups = "drop") |>
  dplyr::mutate(gasto_nominal = dplyr::if_else(aih < N_SUPRESSAO, NA_real_, gasto_nominal)) |> sup_df("aih")
E$sih_proc <- sih1 |> dplyr::mutate(periodo = periodo(ano)) |> dplyr::count(periodo, proc_rea, name = "n") |>
  sup_df("n")
E$sih_sec <- sih1 |> dplyr::group_by(ano) |>
  dplyr::summarise(aih = dplyr::n(), pct_com_secundario = 100 * mean(n_sec_preench > 0), .groups = "drop") |>
  dplyr::mutate(pct_com_secundario = dplyr::if_else(aih < N_SUPRESSAO, NA_real_, pct_com_secundario)) |> sup_df("aih")
E$sih_uf <- taxas |> dplyr::filter(serie == "sih_principal", nivel == "uf_pool")

E$sim_posicao <- simd |>
  dplyr::mutate(posicao = dplyr::case_when(hs_causa_basica ~ "Causa básica",
                                           hs_parte_ii & !hs_causa_basica ~ "Parte II (contribuinte)",
                                           TRUE ~ "Parte I (linhas a–d)")) |>
  dplyr::count(posicao, name = "obitos") |> sup_df("obitos")
E$sim_causas <- simd |> dplyr::mutate(cap = substr(causabas, 1, 3)) |>
  dplyr::count(cap, name = "obitos") |> dplyr::arrange(dplyr::desc(obitos)) |> sup_df("obitos")
E$sim_periodo <- simd |> dplyr::mutate(periodo = dplyr::if_else(ano <= 2017, "2010–2017", "2018–2024")) |>
  dplyr::count(periodo, name = "obitos") |> sup_df("obitos")

E$meta <- list(gerado = format(Sys.time(), "%F %T"), lookup_hash = hs_lookup_hash(), marco = MARCO,
               inicio_clinico = INICIO_CLIN, n_supressao = N_SUPRESSAO, pop = "ibge_projecao_2024",
               fonte = "DBC DATASUS 2010+ (R550-2), scripts/r550/filtrar_um_hs.R")

dir.create(here::here("data/export/csv"), recursive = TRUE, showWarnings = FALSE)
saveRDS(E, here::here("data/export/hs_v2_agregados.rds"))
purrr::iwalk(E[vapply(E, is.data.frame, logical(1))],
             ~ readr::write_csv(.x, here::here("data/export/csv", paste0(.y, ".csv"))))
cat("\n• ITS (todos os cenários):\n")
print(as.data.frame(dplyr::mutate(E$its, dplyr::across(c(estimativa, ic_inf, ic_sup), ~ round(.x, 2)))))
cat("\n• canal clínico normalizado pela produção dermatológica (L732 por mil BPA-I de dermatologista):\n")
print(as.data.frame(E$derm_producao))
message("\n✓ export: ", sum(vapply(E, is.data.frame, logical(1))), " tabelas → data/export/hs_v2_agregados.rds")
