# =============================================================================
# pseudo_id_motor.R — Motor de pseudo-individualização do SIA-PA (compartilhado)
# Usado por feature_eng_pacientes_SIA.R (nacional) e pseudo_id_PE_recife.R (PE/Recife).
#
# Record linkage determinístico sobre quase-identificadores, resolvido por
# componentes conexos (igraph), com cap de span ≤1 ano de nascimento:
#   estrita       sexo × município × raça/cor × ano_nasc exato   (limite SUPERIOR)
#   intermediária sexo × município × raça/cor × ano_nasc ±1      (estimativa central)
#   frouxa        sexo × município × ano_nasc ±1                 (limite INFERIOR)
# + LIGAÇÃO CERTA por nº da APAC: registros de APAC (pa_docorig P/S) com o mesmo
#   pa_autoriz e o mesmo sexo são o mesmo paciente, em qualquer variante — isso
#   repara município trocado dentro da APAC (ex.: lote 2024-03 do CEAF de PE).
#
# CORREÇÃO (v2, out/2026) em relação ao motor anterior:
#   1. Raça/cor NÃO é mais requisito de chave completa. Antes, todo registro com raça
#      "99"/vazia era forçado a paciente próprio — inclusive na variante frouxa, que
#      não usa raça —, inflando a contagem (MPS em PE: ~1.043–1.117 "pacientes" para
#      ~70 em TRE/mês). Agora raça ausente é a categoria "NI" no bloco (estrita e
#      intermediária) e é ignorada na frouxa.
#   2. Chave incompleta (sem sexo, município ou idade): soma integral no limite
#      superior, zero no inferior e proporcional (taxa de compressão dos completos)
#      na central — antes somava integral nos três.
#   3. Ligação por nº de APAC (acima).
#
# PRINCÍPIO (LGPD): pseudo-ID é AGRUPADOR, não identificador; intervalo, não ponto.
# =============================================================================

suppressPackageStartupMessages({ library(data.table); library(igraph) })

#' Normaliza quase-identificadores. Espera sexo, idade_anos, pa_munpcn, pa_racacor,
#' competencia, pa_autoriz, pa_docorig.
normalizar_quase_id <- function(df) {
  df |>
    dplyr::mutate(
      sexo_n = dplyr::case_when(sexo == "Masculino" ~ "M", sexo == "Feminino" ~ "F",
                                TRUE ~ NA_character_),
      raca_n = { r <- stringr::str_pad(stringr::str_trim(as.character(pa_racacor)), 2, pad = "0")
                 dplyr::if_else(r %in% c("01", "02", "03", "04", "05"), r, "NI") },
      mun_n  = { m <- stringr::str_pad(stringr::str_trim(as.character(pa_munpcn)), 6, pad = "0")
                 dplyr::if_else(stringr::str_detect(m, "^0+$") | m == "999999",
                                NA_character_, m) },
      idade_i = suppressWarnings(as.integer(idade_anos)),
      idade_i = dplyr::if_else(idade_i >= 0 & idade_i <= 110, idade_i, NA_integer_),
      # ano_nasc_proxy = ano(competencia) − idade_anos.  CAUTELA <1 ano (idade em anos inteiros)
      ano_nasc_proxy = as.integer(format(competencia, "%Y")) - idade_i,
      # nº de APAC só é identificador em APAC principal/secundária; BPA-I traz enchimento
      apac_n = dplyr::if_else(pa_docorig %in% c("P", "S") &
                                stringr::str_detect(as.character(pa_autoriz), "^[0-9]{13}$") &
                                !stringr::str_detect(as.character(pa_autoriz), "^0+$"),
                              as.character(pa_autoriz), NA_character_),
      chave_completa = !is.na(sexo_n) & !is.na(mun_n) & !is.na(ano_nasc_proxy))
}

# Pares por bloco × janela de ano de nascimento
construir_pares <- function(el, bloco, janela) {
  a <- el[, c("rid", bloco, "ano_nasc_proxy"), with = FALSE]
  b <- data.table::copy(a); data.table::setnames(b, "rid", "rid_b")
  offs <- if (janela == 0) 0L else seq(-janela, janela)
  b_exp <- data.table::rbindlist(lapply(offs, function(o) {
    bb <- data.table::copy(b); bb[, ano_nasc_proxy := ano_nasc_proxy + o]; bb }))
  pr <- a[b_exp, on = c(bloco, "ano_nasc_proxy"), nomatch = 0L, allow.cartesian = TRUE,
          .(x = rid, y = rid_b)]
  unique(pr[x < y])
}

# Pares certos por nº de APAC (estrela: cada registro → 1º registro da APAC × sexo)
pares_apac <- function(el) {
  ap <- el[!is.na(apac_n), .(rid, apac_n, sexo_n)]
  if (!nrow(ap)) return(data.table::data.table(x = integer(), y = integer()))
  ap[, ancora := min(rid), by = .(apac_n, sexo_n)]
  ap[rid != ancora, .(x = ancora, y = rid)]
}

# Componentes conexos + cap de span ≤1 (encadeamento transitivo em município denso
# volta a exato por ano de nascimento)
contar_pacientes <- function(el, bloco, janela) {
  if (nrow(el) <= 1L) return(nrow(el))
  pares <- unique(data.table::rbindlist(list(construir_pares(el, bloco, janela), pares_apac(el))))
  g <- igraph::graph_from_data_frame(as.data.frame(pares[, .(x, y)]), directed = FALSE,
                                     vertices = data.frame(name = as.character(el$rid)))
  memb <- igraph::components(g)$membership
  dt <- data.table::copy(el)
  dt[, comp := memb[as.character(rid)]]
  dt[, span := max(ano_nasc_proxy) - min(ano_nasc_proxy), by = comp]
  dt[, id_final := data.table::fifelse(span <= 1L, paste0("C", comp),
                                       paste0("C", comp, "_", ano_nasc_proxy))]
  data.table::uniqueN(dt$id_final)
}

#' Gradiente estrita ↔ intermediária ↔ frouxa para um conjunto de registros
#' (já normalizado por normalizar_quase_id()).
resumo_gradiente <- function(s) {
  n_total <- nrow(s)
  s <- dplyr::mutate(s, rid = dplyr::row_number())
  elig <- data.table::as.data.table(
    dplyr::filter(s, chave_completa)[, c("rid", "sexo_n", "mun_n", "raca_n",
                                         "ano_nasc_proxy", "apac_n")])
  n_inc <- n_total - nrow(elig)
  if (nrow(elig) == 0L)
    return(tibble::tibble(registros = n_total, pseudo_estrita = n_total,
                          pseudo_intermediaria = n_total, pseudo_frouxa = 0,
                          n_chave_incompleta = n_inc, pct_chave_completa = 0))
  n_est <- contar_pacientes(elig, c("sexo_n", "mun_n", "raca_n"), 0L)
  n_int <- contar_pacientes(elig, c("sexo_n", "mun_n", "raca_n"), 1L)
  n_frx <- contar_pacientes(elig, c("sexo_n", "mun_n"),           1L)
  # O cap de span pode quebrar a monotonicidade (componente maior com span>1 volta a
  # exato por ano): os limites são o mín./máx. das três chaves.
  sup_ <- max(n_est, n_int, n_frx); inf_ <- min(n_est, n_int, n_frx)
  tibble::tibble(
    registros            = n_total,
    pseudo_estrita       = sup_ + n_inc,                                   # superior
    pseudo_intermediaria = round(n_int + n_inc * n_int / nrow(elig)),      # central
    pseudo_frouxa        = inf_,                                           # inferior
    n_chave_incompleta   = n_inc,
    pct_chave_completa   = round(100 * nrow(elig) / n_total, 1))
}

#' Referência externa para grupos do CEAF: pacientes/mês = mediana mensal de APAC
#' distintas com medicamento (06.04) no ano `ano_ref` (ver separacao_medicamento_apac.R).
ref_ceaf_mes <- function(s, ano_ref = 2024L) {
  m <- s |>
    dplyr::filter(substr(pa_proc_id, 1, 4) == "0604", !is.na(apac_n),
                  as.integer(format(competencia, "%Y")) == ano_ref) |>
    dplyr::group_by(competencia) |>
    dplyr::summarise(n = dplyr::n_distinct(apac_n), .groups = "drop")
  if (!nrow(m)) NA_real_ else stats::median(m$n)
}
