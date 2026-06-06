# =============================================================================
# qmd/_common.R — Setup compartilhado dos relatórios Quarto (HS)
# Sourced no chunk de setup de cada .qmd. Carrega params/paleta, dados
# consolidados, tema visual e helpers (KPI, mapa geobr, tabela flextable).
# =============================================================================
suppressPackageStartupMessages({
  library(tidyverse); library(arrow); library(here)
  library(ggpubr); library(scales); library(flextable); library(sf); library(geobr)
})

# Ancora a raiz do projeto independentemente do working dir do Quarto/knitr
here::i_am("qmd/_common.R")

source(here::here("scripts", "00_setup.R"))      # params, PAL_HS, utils, dirs
source(here::here("scripts", "calcular_taxas.R"))# taxas_padronizadas(), contar_estrato()...

# -----------------------------------------------------------------------------
# Dados consolidados (lazy onde grande)
# -----------------------------------------------------------------------------
D <- local({
  list(
    sia  = arrow::open_dataset(here::here("data/parquet/sia_hs")),
    siap = arrow::open_dataset(here::here("data/parquet/sia_hs_pacientes")),
    sih  = readRDS(here::here("data/filtered/sih_hs/sih_hs_nacional.rds")),
    sim  = readRDS(here::here("data/filtered/sim_hs/sim_hs_nacional.rds")),
    pop  = carregar_pop(),
    sens = readr::read_csv(here::here("manifest/sia_pseudo_pacientes_sensibilidade.csv"),
                           show_col_types = FALSE)
  )
})

# -----------------------------------------------------------------------------
# Tema visual e escalas (paleta PAL_HS — CLAUDE.md §8)
# -----------------------------------------------------------------------------
theme_hs <- function(base_size = 12) {
  ggpubr::theme_pubr(base_size = base_size, legend = "right") +
    theme(plot.title = element_text(color = "#3E2A4D", face = "bold"),
          plot.subtitle = element_text(color = "#5b5165"),
          strip.background = element_rect(fill = "#EFE7F0", color = NA),
          strip.text = element_text(color = "#3E2A4D", face = "bold"),
          panel.grid.major.y = element_line(color = "grey92"))
}
scale_fill_hs  <- function(...) scale_fill_manual(values = PAL_HS, ...)
scale_color_hs <- function(...) scale_color_manual(values = PAL_HS, ...)
grad_hs <- function(name = NULL, labels = scales::comma)
  scale_fill_gradient(low = "#E9CDC9", high = "#5C3F6C", name = name, labels = labels)

# -----------------------------------------------------------------------------
# Mapa coroplético por UF (geobr; malha cacheada)
# -----------------------------------------------------------------------------
malha_uf <- function() {
  fp <- here::here("data/denominators/malha_uf.rds")
  if (file.exists(fp)) return(readRDS(fp))
  m <- geobr::read_state(year = 2020, showProgress = FALSE) |>
    sf::st_simplify(dTolerance = 0.01)
  saveRDS(m, fp); m
}

#' Mapa de UF: df precisa de coluna `uf` (sigla) + a coluna de valor.
mapa_uf <- function(df, valor, titulo = NULL, legenda = NULL) {
  m <- malha_uf() |> dplyr::left_join(df, by = c("abbrev_state" = "uf"))
  ggplot(m) +
    geom_sf(aes(fill = .data[[valor]]), color = "white", linewidth = 0.15) +
    grad_hs(name = legenda %||% valor) +
    labs(title = titulo) +
    theme_void(base_size = 12) +
    theme(plot.title = element_text(color = "#3E2A4D", face = "bold", hjust = 0.5),
          legend.position = "right")
}

# -----------------------------------------------------------------------------
# Tabela flextable temada
# -----------------------------------------------------------------------------
tabela_hs <- function(df, titulo = NULL, nota = NULL) {
  ft <- flextable::flextable(df) |>
    flextable::theme_booktabs() |>
    flextable::bg(part = "header", bg = "#5C3F6C") |>
    flextable::color(part = "header", color = "white") |>
    flextable::bold(part = "header") |>
    flextable::fontsize(size = 10, part = "all") |>
    flextable::padding(padding = 4, part = "all") |>
    flextable::autofit()
  if (!is.null(titulo)) ft <- flextable::set_caption(ft, titulo)
  if (!is.null(nota)) ft <- flextable::add_footer_lines(ft, nota) |>
    flextable::fontsize(size = 8, part = "footer") |>
    flextable::color(color = "#5b5165", part = "footer")
  ft
}

# -----------------------------------------------------------------------------
# Cartões de KPI (HTML) — uso: cat(kpi_row(list(c(valor,rótulo), ...)))
# -----------------------------------------------------------------------------
kpi_row <- function(cards) {
  itens <- vapply(cards, function(c)
    sprintf('<div class="kpi-card"><div class="v">%s</div><div class="l">%s</div></div>',
            c[[1]], c[[2]]), character(1))
  paste0('<div class="kpi-row">', paste(itens, collapse = ""), "</div>")
}
fmt_n <- function(x) formatC(x, format = "d", big.mark = ".")
fmt_1 <- function(x) formatC(x, format = "f", digits = 1, big.mark = ".", decimal.mark = ",")

`%||%` <- function(a, b) if (is.null(a)) b else a
