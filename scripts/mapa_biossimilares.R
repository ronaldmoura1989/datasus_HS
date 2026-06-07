# =============================================================================
# mapa_biossimilares.R — Mapa coroplético do tipo dominante de adalimumabe por UF
# Versão simplificada do ada-tipos (fill barplot 27 facetas). Facet 2020 vs 2025.
# Saída: docs/sia_hs_files/figure-html/ada-tipos-mapa-1.png  (fora do relatório)
# Rodar: Rscript scripts/mapa_biossimilares.R
# =============================================================================
suppressPackageStartupMessages({ library(tidyverse); library(arrow); library(sf); library(geobr) })
source(here::here("scripts", "00_setup.R"))

OUTDIR <- here::here("apresentacao/figuras")   # pasta estável (fora do docs/ gerado pelo Quarto)
dir.create(OUTDIR, showWarnings = FALSE, recursive = TRUE)
ANOS_MAPA <- c(2020, 2025)
LABS <- c("0604380062" = "Referência",
          "0604380127" = "Biossimilar A",
          "0604380135" = "Biossimilar B")
NIVEIS <- c("Referência", "Biossimilar A", "Biossimilar B", "Sem registro")
CORES  <- c("Referência" = "#5C3F6C", "Biossimilar A" = "#A87FA8",
            "Biossimilar B" = "#E9CDC9", "Sem registro" = "grey88")

# Malha de UF (cache do projeto, senão baixa via geobr)
malha <- local({
  fp <- here::here("data/denominators/malha_uf.rds")
  if (file.exists(fp)) readRDS(fp)
  else { m <- geobr::read_state(year = 2020, showProgress = FALSE) |> sf::st_simplify(dTolerance = 0.01)
         saveRDS(m, fp); m }
})

# Tipo DOMINANTE (maior nº de dispensações) por UF × ano
ada <- open_dataset(here::here("data/parquet/sia_hs")) |>
  filter(pa_proc_id %in% names(LABS), ano %in% ANOS_MAPA) |>
  select(ano, uf_pcn, pa_proc_id) |> collect() |>
  filter(!is.na(uf_pcn), uf_pcn %in% UFS) |>
  count(ano, uf = uf_pcn, pa_proc_id)

dom <- ada |>
  group_by(ano, uf) |>
  slice_max(n, n = 1, with_ties = FALSE) |>
  ungroup() |>
  mutate(tipo = unname(LABS[pa_proc_id]), share = NA_real_)
# % do tipo dominante (para a legenda/rótulo opcional)
tot <- ada |> group_by(ano, uf) |> summarise(tot = sum(n), .groups = "drop")
dom <- dom |> left_join(tot, by = c("ano","uf")) |> mutate(share = n / tot)

# grade completa UF × ano → marca "Sem registro"
mapdata <- tidyr::expand_grid(uf = UFS, ano = ANOS_MAPA) |>
  left_join(dom, by = c("uf","ano")) |>
  mutate(tipo = factor(ifelse(is.na(tipo), "Sem registro", tipo), levels = NIVEIS)) |>
  left_join(malha, by = c("uf" = "abbrev_state")) |>
  sf::st_as_sf()

p <- ggplot(mapdata) +
  geom_sf(aes(fill = tipo), color = "white", linewidth = 0.15) +
  facet_wrap(~ ano) +
  scale_fill_manual(values = CORES, drop = FALSE) +
  labs(fill = NULL,
       title = "Qual adalimumabe cada estado mais usa para HS",
       subtitle = "Tipo predominante nas dispensações (maior volume). Da referência (2020) aos biossimilares (2025).") +
  theme_void(base_size = 13) +
  theme(plot.title = element_text(face = "bold", color = "#3E2A4D", hjust = 0.5),
        plot.subtitle = element_text(color = "#5b5165", hjust = 0.5),
        legend.position = "bottom",
        strip.text = element_text(face = "bold", color = "#3E2A4D", size = 14))

ggsave(file.path(OUTDIR, "ada-tipos-mapa-1.png"), p, width = 9, height = 5.4, dpi = 150, bg = "white")
message("✓ ada-tipos-mapa-1.png")
cat("\nResumo do tipo dominante por ano:\n")
print(mapdata |> sf::st_drop_geometry() |> count(ano, tipo) |>
        pivot_wider(names_from = tipo, values_from = n, values_fill = 0))
