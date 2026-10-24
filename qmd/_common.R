# =============================================================================
# qmd/_common.R — Setup compartilhado dos relatórios Quarto (HS, v2 2010–2025)
# Sourced no chunk de setup de cada .qmd. O site lê SÓ agregados já suprimidos
# (data/export/hs_v2_agregados.rds, gerado no R550-2 por scripts/exportar_agregados_hs.R)
# e denominadores públicos (IBGE, CNES, IPCA). Nenhum microdado entra no render.
# Números citados no texto: qmd/_numeros.R (R inline; nada digitado à mão — guia §12).
# =============================================================================
suppressPackageStartupMessages({
  library(tidyverse); library(arrow); library(here)
  library(ggpubr); library(scales); library(flextable); library(sf); library(geobr)
})

# Ancora a raiz do projeto independentemente do working dir do Quarto/knitr
here::i_am("qmd/_common.R")

source(here::here("scripts", "00_setup.R"))      # params, PAL_HS, utils, dirs

E <- readRDS(here::here("data/export/hs_v2_agregados.rds"))
IPCA <- arrow::read_parquet(here::here("data/denominators/ipca_anual.parquet"))
sigtab <- readRDS(here::here("data/denominators/sigtab.rds"))   # rótulos SIGTAP (cache)
MARCO <- E$meta$marco
MARCO_DATA <- as.Date(paste0(substr(MARCO, 1, 4), "-", substr(MARCO, 5, 6), "-01"))
MARCO_ANO <- as.integer(substr(MARCO, 1, 4)) + (as.integer(substr(MARCO, 5, 6)) - 1) / 12

# -----------------------------------------------------------------------------
# Tema visual e escalas (paleta PAL_HS — CLAUDE.md §8)
# -----------------------------------------------------------------------------
theme_hs <- function(base_size = 12) {
  ggpubr::theme_pubr(base_size = base_size, legend = "right") +
    theme(plot.title = element_text(color = "#3E2A4D", face = "bold"),
          plot.title.position = "plot",
          plot.subtitle = element_text(color = "#5b5165"),
          strip.background = element_rect(fill = "#EFE7F0", color = NA),
          strip.text = element_text(color = "#3E2A4D", face = "bold"),
          panel.grid.major.y = element_line(color = "grey92"))
}
scale_fill_hs  <- function(...) scale_fill_manual(values = PAL_HS, ...)
scale_color_hs <- function(...) scale_color_manual(values = PAL_HS, ...)
grad_hs <- function(name = NULL, labels = scales::comma)
  scale_fill_gradient(low = "#E9CDC9", high = "#5C3F6C", name = name, labels = labels, na.value = "grey90")
eixo_anos <- function() scale_x_continuous(breaks = seq(min(ANOS), max(ANOS), 1),
                                           guide = guide_axis(angle = 45))

# labs() com quebra automática de título/subtítulo (subtítulos longos eram cortados)
labs <- function(..., title = ggplot2::waiver(), subtitle = ggplot2::waiver()) {
  q <- function(x, w) if (is.character(x)) stringr::str_wrap(x, w) else x
  ggplot2::labs(..., title = q(title, 70), subtitle = q(subtitle, 95))
}

# Rótulos legíveis das comorbidades (colunas com_* vêm de janitor::make_clean_names(rotulo))
ROTULO_COMORB <- local({
  if (!exists("HS_LOOKUP")) source(here::here("scripts", "hs_lookup.R"))
  r <- unique(HS_LOOKUP$rotulo[HS_LOOKUP$dominio == "comorb"])
  c(stats::setNames(r, janitor::make_clean_names(r)), abscesso_l02 = "Abscesso cutâneo (L02)")
})

# Faixa da pandemia e linha do marco de incorporação (ref/normativo_hs.md)
camadas_tempo <- function(marco = TRUE, x_marco = MARCO_ANO, covid = c(2020, 2022)) {
  list(annotate("rect", xmin = covid[1] - 0.5, xmax = covid[2] + 0.5, ymin = -Inf, ymax = Inf,
                fill = "grey85", alpha = 0.45),
       if (marco) geom_vline(xintercept = x_marco, linetype = "dashed", color = "#3E2A4D"))
}

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
    grad_hs(name = legenda %||% valor, labels = function(x) fmt_2(x)) +
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

# Formatação pt-BR. Contagem NA (suprimida, 1–4) e contagens 1–4 aparecem como "<5".
fmt_n <- function(x) ifelse(is.na(x), "<5",
                            ifelse(x > 0 & x < N_SUPRESSAO, "<5",
                                   formatC(round(x), format = "d", big.mark = ".", decimal.mark = ",")))
fmt_1 <- function(x) ifelse(is.na(x), "—", formatC(x, format = "f", digits = 1, big.mark = ".", decimal.mark = ","))
fmt_2 <- function(x) ifelse(is.na(x), "—", formatC(x, format = "f", digits = 2, big.mark = ".", decimal.mark = ","))
fmt_pct <- function(x, d = 1) paste0(formatC(x, format = "f", digits = d, decimal.mark = ","), "%")
fmt_ic <- function(est, lo, hi, d = 1, suf = "")
  paste0(formatC(est, format = "f", digits = d, decimal.mark = ","), suf, " (IC 95% ",
         formatC(lo, format = "f", digits = d, decimal.mark = ","), "–",
         formatC(hi, format = "f", digits = d, decimal.mark = ","), suf, ")")
nota_sup <- "Células com 1 a 4 eventos suprimidas (LGPD), exibidas como \"<5\" ou em branco."

`%||%` <- function(a, b) if (is.null(a)) b else a

source(here::here("qmd", "_numeros.R"))
