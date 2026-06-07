# =============================================================================
# doses_adalimumabe.R — Volume dispensado de adalimumabe (HS) por ano e UF
# ⚠️ O SIA-PA NÃO registra o valor (R$) de medicamentos de alto custo (campos
#    zerados). Usamos a métrica REAL disponível: nº de seringas 40 mg (pa_qtdapr).
# Saídas (só para a apresentação): apresentacao/figuras/
#   - doses-adalimumabe-barras-1.png  (barplot empilhado por tipo, por ano)
#   - doses-adalimumabe-mapa-1.png     (mapa coroplético facet 2020 vs 2025)
# Rodar: Rscript scripts/doses_adalimumabe.R
# =============================================================================
suppressPackageStartupMessages({ library(tidyverse); library(arrow); library(sf); library(geobr); library(ggpubr) })
source(here::here("scripts", "00_setup.R"))

OUTDIR <- here::here("apresentacao/figuras")
dir.create(OUTDIR, showWarnings = FALSE, recursive = TRUE)

LABS <- c("0604380062" = "Referência", "0604380127" = "Biossimilar A", "0604380135" = "Biossimilar B")
CORES <- c("Referência" = "#5C3F6C", "Biossimilar A" = "#A87FA8", "Biossimilar B" = "#E9CDC9")
tema <- function(base = 12) ggpubr::theme_pubr(base_size = base, legend = "top") +
  theme(plot.title = element_text(color = "#3E2A4D", face = "bold"),
        plot.subtitle = element_text(color = "#5b5165"))

d <- open_dataset(here::here("data/parquet/sia_hs")) |>
  filter(pa_proc_id %in% names(LABS)) |>
  select(ano, uf_pcn, pa_proc_id, pa_qtdapr) |> collect() |>
  filter(!is.na(uf_pcn), uf_pcn %in% UFS) |>
  mutate(qtd = suppressWarnings(as.numeric(pa_qtdapr)),
         tipo = factor(unname(LABS[pa_proc_id]),
                       levels = c("Referência","Biossimilar A","Biossimilar B")))

# -----------------------------------------------------------------------------
# (1) Barplot nacional: seringas dispensadas por ano, empilhado por tipo
# -----------------------------------------------------------------------------
bar <- d |> group_by(ano, tipo) |> summarise(doses = sum(qtd, na.rm = TRUE), .groups = "drop")
tot <- bar |> group_by(ano) |> summarise(doses = sum(doses), .groups = "drop")

p1 <- ggplot(bar, aes(factor(ano), doses, fill = tipo)) +
  geom_col(width = 0.78) +
  geom_text(data = tot, aes(factor(ano), doses, label = scales::comma(round(doses), big.mark = ".")),
            inherit.aes = FALSE, vjust = -0.5, size = 3.2, color = "#3E2A4D", fontface = "bold") +
  scale_fill_manual(values = CORES) +
  scale_y_continuous(labels = scales::label_number(big.mark = "."),
                     expand = expansion(mult = c(0, 0.1))) +
  labs(x = NULL, y = "Seringas de 40 mg dispensadas", fill = NULL,
       title = "Adalimumabe dispensado para HS: volume por ano e tipo",
       subtitle = "Seringas de 40 mg (pa_qtdapr). O valor em R$ do alto custo não consta no SIA-PA.") +
  tema()
ggsave(file.path(OUTDIR, "doses-adalimumabe-barras-1.png"), p1, width = 8, height = 4.8, dpi = 150, bg = "white")
message("✓ doses-adalimumabe-barras-1.png")
cat("\nSeringas dispensadas por ano (total):\n"); print(tot |> mutate(doses = round(doses)))

# -----------------------------------------------------------------------------
# (2) Mapa coroplético: seringas por UF, facet 2020 vs 2025
# -----------------------------------------------------------------------------
malha <- local({
  fp <- here::here("data/denominators/malha_uf.rds")
  if (file.exists(fp)) readRDS(fp)
  else { m <- geobr::read_state(year = 2020, showProgress = FALSE) |> sf::st_simplify(dTolerance = 0.01)
         saveRDS(m, fp); m }
})

mapd <- d |> filter(ano %in% c(2020, 2025)) |>
  group_by(ano, uf = uf_pcn) |> summarise(doses = sum(qtd, na.rm = TRUE), .groups = "drop")
mapd <- tidyr::expand_grid(uf = UFS, ano = c(2020, 2025)) |>
  left_join(mapd, by = c("uf","ano")) |> mutate(doses = tidyr::replace_na(doses, 0)) |>
  left_join(malha, by = c("uf" = "abbrev_state")) |> sf::st_as_sf()

p2 <- ggplot(mapd) +
  geom_sf(aes(fill = doses), color = "white", linewidth = 0.15) +
  facet_wrap(~ ano) +
  scale_fill_gradient(low = "#F3E9E6", high = "#3E2A4D", trans = "log1p",
                      breaks = c(0, 100, 1000, 10000, 40000),
                      labels = scales::label_number(big.mark = ".")) +
  labs(fill = "Seringas\n(40 mg)",
       title = "Onde o adalimumabe é dispensado para HS — 2020 vs 2025",
       subtitle = "Volume de seringas de 40 mg por estado de residência. Escala de cor logarítmica.") +
  theme_void(base_size = 13) +
  theme(plot.title = element_text(face = "bold", color = "#3E2A4D", hjust = 0.5),
        plot.subtitle = element_text(color = "#5b5165", hjust = 0.5),
        legend.position = "right",
        strip.text = element_text(face = "bold", color = "#3E2A4D", size = 14))
ggsave(file.path(OUTDIR, "doses-adalimumabe-mapa-1.png"), p2, width = 9, height = 5.4, dpi = 150, bg = "white")
message("✓ doses-adalimumabe-mapa-1.png")
