# =============================================================================
# calcular_taxas.R — Biblioteca de taxas (brutas e PADRONIZADAS) para HS
# Padronização DIRETA por idade × sexo, população-padrão Censo 2022, IC gama
# (epitools::ageadjust.direct). Consome numeradores (SIA/SIH/SIM) + pop_ibge.
# Princípio (datasus_hs.md §1, §5): são taxas de DETECÇÃO/USO, não prevalência.
#
# Uso (a partir de um .qmd ou script):
#   source("scripts/calcular_taxas.R")
#   pop <- carregar_pop()
#   num <- contar_estrato(sia_df, col_uf = "uf_pcn")     # uf,ano,sexo,faixa,n
#   taxas_padronizadas(num, pop, grupos = c("uf"))        # 1 taxa pad por UF (pool de anos)
#   taxa_bruta_serie(num, pop, grupos = "ano")            # série temporal nacional
# Rodar direto (Rscript) executa uma validação/demonstração.
# =============================================================================

if (!exists("UFS")) source(here::here("scripts", "00_setup.R"))
suppressPackageStartupMessages(library(epitools))

# Estratos de padronização = sexo × faixa (34). Níveis de faixa = harmonizar_faixa().
.FAIXA_LEVELS <- levels(harmonizar_faixa(seq(0, 85, by = 5)))

#' Carrega o denominador IBGE (Censo 2022).
carregar_pop <- function() {
  fp <- here::here("data/denominators/pop_ibge.parquet")
  if (!file.exists(fp)) stop("Rode scripts/get_denominadores_ibge.R primeiro.")
  arrow::read_parquet(fp) |>
    dplyr::mutate(faixa = factor(as.character(faixa), levels = .FAIXA_LEVELS))
}

#' Conta eventos por estrato (uf × ano × sexo × faixa) a partir de um data.frame
#' de microdados já enriquecido (sexo "Masculino"/"Feminino"; faixa canônica).
#' @param col_uf coluna de UF a usar (residência: "uf_pcn" no SIA, "uf_res" no SIH/SIM)
#' @param distinct_por se não-NULL, conta entidades distintas (ex.: "id_paciente",
#'        "n_aih") em vez de registros — para numerador de pessoas/internações.
contar_estrato <- function(df, col_uf, distinct_por = NULL) {
  d <- df |>
    dplyr::transmute(uf = .data[[col_uf]], ano = as.integer(ano),
                     sexo, faixa = factor(as.character(faixa), levels = .FAIXA_LEVELS),
                     .ent = if (is.null(distinct_por)) dplyr::row_number() else .data[[distinct_por]]) |>
    dplyr::filter(!is.na(uf), !is.na(sexo), !is.na(faixa), uf %in% UFS)
  if (is.null(distinct_por))
    dplyr::count(d, uf, ano, sexo, faixa, name = "n")
  else
    d |> dplyr::group_by(uf, ano, sexo, faixa) |>
      dplyr::summarise(n = dplyr::n_distinct(.ent), .groups = "drop")
}

#' População-padrão nacional (Censo 2022) por estrato sexo×faixa (pesos da padronização).
pop_padrao <- function(pop, ano_ref = 2022) {
  pop |> dplyr::filter(ano == ano_ref) |>
    dplyr::group_by(sexo, faixa) |>
    dplyr::summarise(stdpop = sum(pop), .groups = "drop")
}

#' Taxas BRUTAS + PADRONIZADAS (direta, idade×sexo) por grupo, com IC gama.
#' @param grupos colunas de agregação presentes no denominador (ex.: "uf", c("uf","ano"),
#'        c("regiao","ano")). Inclua `ano` para taxa anual; omita p/ taxa em pessoa-tempo
#'        (denominador somado sobre anos = pessoa-anos).
#' @param por base da taxa (1e5 = por 100 mil).
taxas_padronizadas <- function(num, pop, grupos, ano_ref = 2022, por = 1e5,
                               conf = 0.95) {
  std <- pop_padrao(pop, ano_ref)
  chave_estrato <- c(grupos, "sexo", "faixa")
  # denominador e numerador agregados ao nível grupos×estrato
  d <- pop |> dplyr::group_by(dplyr::across(dplyr::all_of(chave_estrato))) |>
    dplyr::summarise(pop = sum(pop), .groups = "drop")
  n <- num |> dplyr::group_by(dplyr::across(dplyr::all_of(chave_estrato))) |>
    dplyr::summarise(n = sum(n), .groups = "drop")
  base <- d |>
    dplyr::left_join(n, by = chave_estrato) |>
    dplyr::mutate(n = tidyr::replace_na(n, 0)) |>
    dplyr::left_join(std, by = c("sexo", "faixa"))
  base |>
    dplyr::group_by(dplyr::across(dplyr::all_of(grupos))) |>
    dplyr::group_modify(function(.x, .key) {
      a <- epitools::ageadjust.direct(count = .x$n, pop = .x$pop,
                                      stdpop = .x$stdpop, conf.level = conf)
      tibble::tibble(
        eventos    = sum(.x$n),
        pop        = sum(.x$pop),
        taxa_bruta = por * unname(a["crude.rate"]),
        taxa_pad   = por * unname(a["adj.rate"]),
        ic_inf     = por * unname(a["lci"]),
        ic_sup     = por * unname(a["uci"])
      )
    }) |>
    dplyr::ungroup()
}

#' Taxa BRUTA por grupo (sem padronização) — útil p/ séries e estratos específicos
#' (ex.: mulheres 20–39). Filtre `num`/`pop` antes se quiser um estrato.
taxa_bruta <- function(num, pop, grupos, por = 1e5) {
  n <- num |> dplyr::group_by(dplyr::across(dplyr::all_of(grupos))) |>
    dplyr::summarise(eventos = sum(n), .groups = "drop")
  d <- pop |> dplyr::group_by(dplyr::across(dplyr::all_of(grupos))) |>
    dplyr::summarise(pop = sum(pop), .groups = "drop")
  n |> dplyr::left_join(d, by = grupos) |>
    dplyr::mutate(taxa_bruta = por * eventos / pop)
}

# -----------------------------------------------------------------------------
# Validação / demonstração (só quando rodado via Rscript)
# -----------------------------------------------------------------------------
if (sys.nframe() == 0) {
  message("== calcular_taxas.R: validação ==")
  pop <- carregar_pop()
  sia <- arrow::open_dataset(here::here("data/parquet/sia_hs")) |>
    dplyr::select(ano, uf_pcn, sexo, faixa) |> dplyr::collect()
  num <- contar_estrato(sia, col_uf = "uf_pcn")
  cat("numerador SIA: ", sum(num$n), "registros em", nrow(num), "estratos\n\n")

  cat("• Série nacional — taxa de detecção SIA padronizada (idade×sexo)/100 mil:\n")
  print(taxas_padronizadas(num, pop, grupos = "ano") |>
          dplyr::mutate(dplyr::across(c(taxa_bruta, taxa_pad, ic_inf, ic_sup), ~ round(.x, 1))))

  cat("\n• Taxa padronizada por UF (pool 2020–2025, pessoa-anos) — top 8:\n")
  print(taxas_padronizadas(num, pop, grupos = "uf") |>
          dplyr::arrange(dplyr::desc(taxa_pad)) |> dplyr::slice_head(n = 8) |>
          dplyr::mutate(dplyr::across(c(taxa_bruta, taxa_pad, ic_inf, ic_sup), ~ round(.x, 1))))

  cat("\n• Estrato-alvo (mulheres 20–39) — taxa bruta nacional por ano:\n")
  print(taxa_bruta(
    dplyr::filter(num, sexo=="Feminino", faixa %in% c("20-24","25-29","30-34","35-39")),
    dplyr::filter(pop, sexo=="Feminino", faixa %in% c("20-24","25-29","30-34","35-39")),
    grupos = "ano") |> dplyr::mutate(taxa_bruta = round(taxa_bruta, 1)))
  message("\n✓ calcular_taxas.R validado.")
}
