# =============================================================================
# calcular_taxas.R — Biblioteca de taxas (brutas, PADRONIZADAS, tendência e série
# interrompida) para HS, v2 2010–2025. Molde: datasus_EIM/scripts/calcular_taxas.R.
# Padronização DIRETA por idade × sexo (epitools::ageadjust.direct, IC gama), com
# população-padrão Brasil 2022 da Projeção IBGE Revisão 2024 (POP_PADRAO).
# Princípio (datasus_hs.md §1, §5): taxas de DETECÇÃO/USO, não prevalência.
#
# Correções herdadas do EIM (guia ref/guia_processamento_datasus.md §10):
#   - contar_estrato() AVISA quantas linhas descarta (uf/sexo/faixa ausente);
#   - taxas_padronizadas() restringe o denominador aos anos do numerador
#     ("anos-fantasma": SIM só vai até 2024, a população até 2025);
#   - supressão N < N_SUPRESSAO na própria taxa e no IC (suprimir_taxa).
#
# Uso:
#   source("scripts/calcular_taxas.R"); pop <- carregar_pop()
#   num <- contar_estrato(sia_clinico, col_uf = "uf_pcn", peso = "pa_qtdapr")
#   taxas_padronizadas(num, pop, grupos = "ano")
#   tendencia_poisson(serie, excluir_covid = TRUE)
#   its_poisson(serie_mensal, marco = "201911")
# Rodar direto (Rscript) executa uma validação/demonstração.
# =============================================================================

if (!exists("UFS")) source(here::here("scripts", "00_setup.R"))
suppressPackageStartupMessages({ library(epitools); library(broom) })

# Estratos de padronização = sexo × faixa (34). Níveis de faixa = harmonizar_faixa().
.FAIXA_LEVELS <- levels(harmonizar_faixa(seq(0, 85, by = 5)))

#' Carrega o denominador IBGE (Projeções 2024, anual).
carregar_pop <- function() {
  fp <- here::here("data/denominators/pop_ibge.parquet")
  if (!file.exists(fp)) stop("Rode scripts/get_denominadores_ibge.R primeiro.")
  arrow::read_parquet(fp) |>
    dplyr::mutate(faixa = factor(as.character(faixa), levels = .FAIXA_LEVELS))
}

#' Conta eventos por estrato (uf × ano × sexo × faixa [× extra]).
#' @param col_uf coluna de UF de residência ("uf_pcn" no SIA, "uf_res" no SIH/SIM)
#' @param extra colunas adicionais de estratificação (ex.: "canal", "mes")
#' @param distinct_por conta entidades distintas (ex.: "n_aih", "pa_autoriz")
#' @param peso soma esta coluna em vez de contar linhas (ex.: "pa_qtdapr" no SIA:
#'        o PA é produção, e uma linha pode ter várias unidades — CLAUDE.md §5)
contar_estrato <- function(df, col_uf, extra = NULL, distinct_por = NULL, peso = NULL) {
  d <- df |>
    dplyr::mutate(uf = .data[[col_uf]], ano = as.integer(ano),
                  faixa = factor(as.character(faixa), levels = .FAIXA_LEVELS))
  n_antes <- nrow(d)
  d <- dplyr::filter(d, !is.na(uf), !is.na(sexo), !is.na(faixa), uf %in% UFS)
  if (nrow(d) < n_antes)
    message(sprintf("contar_estrato(): %d/%d linhas descartadas (uf/sexo/faixa ausente ou uf fora de UFS).",
                    n_antes - nrow(d), n_antes))
  chave <- c("uf", "ano", "sexo", "faixa", extra)
  g <- dplyr::group_by(d, dplyr::across(dplyr::all_of(chave)))
  if (!is.null(distinct_por)) dplyr::summarise(g, n = dplyr::n_distinct(.data[[distinct_por]]), .groups = "drop")
  else if (!is.null(peso))    dplyr::summarise(g, n = sum(as.numeric(.data[[peso]]), na.rm = TRUE), .groups = "drop")
  else                        dplyr::summarise(g, n = dplyr::n(), .groups = "drop")
}

#' População-padrão nacional (Brasil 2022 da projeção) por estrato sexo×faixa.
pop_padrao <- function(pop, ano_ref = 2022) {
  pop |> dplyr::filter(ano == ano_ref) |>
    dplyr::group_by(sexo, faixa) |>
    dplyr::summarise(stdpop = sum(pop), .groups = "drop")
}

#' Taxas BRUTAS + PADRONIZADAS (direta, idade×sexo) por grupo, com IC gama.
#' @param grupos colunas de agregação presentes no denominador (ex.: "uf", c("uf","ano")).
#'        Inclua `ano` para taxa anual; omita p/ taxa em pessoa-tempo (pessoa-anos).
#' @param anos anos mantidos no DENOMINADOR; por padrão, os do numerador (evita anos-fantasma)
#' @param suprimir apaga taxa e IC quando eventos < N_SUPRESSAO
taxas_padronizadas <- function(num, pop, grupos, ano_ref = 2022, por = 1e5, conf = 0.95,
                               suprimir = TRUE,
                               anos = if ("ano" %in% names(num)) sort(unique(num$ano)) else NULL) {
  std <- pop_padrao(pop, ano_ref)
  if (!is.null(anos)) pop <- dplyr::filter(pop, ano %in% anos)
  chave <- c(grupos, "sexo", "faixa")
  d <- pop |> dplyr::group_by(dplyr::across(dplyr::all_of(chave))) |>
    dplyr::summarise(pop = sum(pop), .groups = "drop")
  n <- num |> dplyr::group_by(dplyr::across(dplyr::all_of(chave))) |>
    dplyr::summarise(n = sum(n), .groups = "drop")
  out <- d |>
    dplyr::left_join(n, by = chave) |>
    dplyr::mutate(n = tidyr::replace_na(n, 0)) |>
    dplyr::left_join(std, by = c("sexo", "faixa")) |>
    dplyr::group_by(dplyr::across(dplyr::all_of(grupos))) |>
    dplyr::group_modify(function(.x, .key) {
      a <- epitools::ageadjust.direct(count = .x$n, pop = .x$pop,
                                      stdpop = .x$stdpop, conf.level = conf)
      tibble::tibble(eventos = sum(.x$n), pop = sum(.x$pop),
                     taxa_bruta = por * unname(a["crude.rate"]),
                     taxa_pad   = por * unname(a["adj.rate"]),
                     ic_inf     = por * unname(a["lci"]),
                     ic_sup     = por * unname(a["uci"]))
    }) |>
    dplyr::ungroup()
  if (suprimir) suprimir_taxa(out) else out
}

#' Taxa BRUTA por grupo, IC de Poisson exato e supressão N<5. Filtre `num`/`pop`
#' antes se quiser um estrato (ex.: mulheres 20–39).
taxa_bruta <- function(num, pop, grupos, por = 1e5, suprimir = TRUE,
                       anos = if ("ano" %in% names(num)) sort(unique(num$ano)) else NULL) {
  if (!is.null(anos)) pop <- dplyr::filter(pop, ano %in% anos)
  n <- num |> dplyr::group_by(dplyr::across(dplyr::all_of(grupos))) |>
    dplyr::summarise(eventos = sum(n), .groups = "drop")
  d <- pop |> dplyr::group_by(dplyr::across(dplyr::all_of(grupos))) |>
    dplyr::summarise(pop = sum(pop), .groups = "drop")
  out <- d |> dplyr::left_join(n, by = grupos) |>
    dplyr::mutate(eventos = tidyr::replace_na(eventos, 0), taxa_bruta = por * eventos / pop)
  ic <- epitools::pois.exact(round(out$eventos), pt = out$pop / por)
  out$ic_inf <- ic$lower; out$ic_sup <- ic$upper
  if (suprimir) suprimir_taxa(out) else out
}

#' Tendência anual: quasi-Poisson `eventos ~ ano + offset(log(pop))`.
#' Devolve a variação anual (exp(β) − 1) × 100 % com IC 95%. Um IC que cruza o zero
#' NÃO é tendência (rotulo "sem tendência").
#' @param dados colunas `ano`, `eventos` e a coluna de offset
tendencia_poisson <- function(dados, offset_col = "pop", excluir_covid = FALSE) {
  d <- dados
  if (excluir_covid) d <- dplyr::filter(d, !ano %in% ANOS_COVID)
  m <- stats::glm(eventos ~ ano, family = quasipoisson(link = "log"),
                  offset = log(d[[offset_col]]), data = d)
  broom::tidy(m, conf.int = TRUE, exponentiate = TRUE) |>
    dplyr::filter(term == "ano") |>
    dplyr::transmute(var_anual_pct = 100 * (estimate - 1), ic_inf = 100 * (conf.low - 1),
                     ic_sup = 100 * (conf.high - 1), p_valor = p.value,
                     leitura = dplyr::if_else(ic_inf > 0 | ic_sup < 0,
                                              dplyr::if_else(var_anual_pct > 0, "alta", "queda"),
                                              "sem tendência"),
                     anos = paste(range(d$ano), collapse = "–"), excluiu_covid = excluir_covid)
}

#' Série interrompida (ITS) mensal: quasi-Poisson segmentado
#'   eventos ~ t + pos + t_pos + sin/cos(mês) + covid + offset(log(pop))
#' pos = mudança de NÍVEL no marco; t_pos = mudança de INCLINAÇÃO (plano §4.2).
#' @param dados colunas `cmp` (AAAAMM), `eventos`, `pop` (população mensal ou anual/12)
#' @param marco competência AAAAMM do marco pré-especificado (ref/normativo_hs.md)
#' @param covid competências AAAAMM com a indicadora de pandemia
#' @return razões de taxas (nível, inclinação antes/depois em %/ano) com IC 95%
COVID_MESES <- sprintf("%d%02d", rep(2020:2021, each = 12), 1:12)[-(1:2)]   # 2020-03 a 2021-12

# Prepara a série mensal: t em MESES DE CALENDÁRIO (permite excluir meses sem
# distorcer o tempo), indicadoras de nível/inclinação no marco, COVID e sazonalidade.
.its_dados <- function(dados, marco, covid) {
  mes_abs <- function(cmp) as.integer(substr(cmp, 1, 4)) * 12L + as.integer(substr(cmp, 5, 6))
  dados |>
    dplyr::arrange(cmp) |>
    dplyr::mutate(t = mes_abs(cmp) - mes_abs(min(cmp)) + 1L, mes = as.integer(substr(cmp, 5, 6)),
                  pos = as.integer(cmp >= marco), t_pos = pmax(0L, mes_abs(cmp) - mes_abs(marco) + 1L) * pos,
                  covid = as.integer(cmp %in% covid),
                  s1 = sin(2 * pi * mes / 12), c1 = cos(2 * pi * mes / 12))
}
.its_modelo <- function(d) {
  f <- if (any(d$covid == 1)) eventos ~ t + pos + t_pos + s1 + c1 + covid else eventos ~ t + pos + t_pos + s1 + c1
  stats::glm(f, family = quasipoisson(link = "log"), offset = log(pop), data = d)
}

#' Valores ajustados e CONTRAFACTUAL (sem marco: pos = t_pos = 0) da ITS, para figura.
its_ajuste <- function(dados, marco, covid = COVID_MESES) {
  d <- .its_dados(dados, marco, covid); m <- .its_modelo(d)
  d$ajustado <- stats::predict(m, newdata = d, type = "response")
  d$contrafactual <- dplyr::if_else(d$pos == 1L,
    stats::predict(m, newdata = dplyr::mutate(d, pos = 0L, t_pos = 0L), type = "response"), NA_real_)
  d
}

its_poisson <- function(dados, marco, covid = COVID_MESES) {
  d <- .its_dados(dados, marco, covid)
  m <- .its_modelo(d)
  b <- stats::coef(m); V <- stats::vcov(m)
  ic <- function(est, se) c(est, est - 1.96 * se, est + 1.96 * se)
  pre  <- ic(12 * b[["t"]], 12 * sqrt(V["t", "t"]))
  post <- ic(12 * (b[["t"]] + b[["t_pos"]]),
             12 * sqrt(V["t", "t"] + V["t_pos", "t_pos"] + 2 * V["t", "t_pos"]))
  niv  <- ic(b[["pos"]], sqrt(V["pos", "pos"]))
  tibble::tibble(
    efeito = c("nível no marco (razão de taxas)", "tendência antes (%/ano)", "tendência depois (%/ano)"),
    estimativa = c(exp(niv[1]), 100 * (exp(pre[1]) - 1), 100 * (exp(post[1]) - 1)),
    ic_inf     = c(exp(niv[2]), 100 * (exp(pre[2]) - 1), 100 * (exp(post[2]) - 1)),
    ic_sup     = c(exp(niv[3]), 100 * (exp(pre[3]) - 1), 100 * (exp(post[3]) - 1)),
    marco = marco, n_meses = nrow(d), dispersao = summary(m)$dispersion)
}

# -----------------------------------------------------------------------------
# Validação / demonstração (só quando rodado via Rscript)
# -----------------------------------------------------------------------------
if (sys.nframe() == 0) {
  message("== calcular_taxas.R: validação ==")
  pop <- carregar_pop()
  sia <- arrow::open_dataset(here::here("data/parquet/sia_hs")) |>
    dplyr::filter(camada == "nucleo") |>
    dplyr::select(ano, canal, uf_pcn, sexo, faixa, pa_qtdapr) |> dplyr::collect()
  num <- contar_estrato(dplyr::filter(sia, canal != "medicamento"), col_uf = "uf_pcn", peso = "pa_qtdapr")
  cat("numerador SIA clínico: Σqtd =", sum(num$n), "em", nrow(num), "estratos\n\n")

  cat("• Série nacional — taxa de detecção clínica SIA padronizada (idade×sexo)/100 mil:\n")
  serie <- taxas_padronizadas(num, pop, grupos = "ano")
  print(serie |> dplyr::mutate(dplyr::across(c(taxa_bruta, taxa_pad, ic_inf, ic_sup), ~ round(.x, 2))))
  cat("\n• Tendência anual (quasi-Poisson), com e sem 2020–2022:\n")
  print(dplyr::bind_rows(tendencia_poisson(serie), tendencia_poisson(serie, excluir_covid = TRUE)))
  message("\n✓ calcular_taxas.R validado.")
}
