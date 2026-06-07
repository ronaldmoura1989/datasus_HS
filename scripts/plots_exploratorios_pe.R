# =============================================================================
# plots_exploratorios_pe.R — Plots exploratórios para a apresentação (Pernambuco)
# (1) Taxa de detecção padronizada: Brasil vs Pernambuco
# (2) "Invasão"/evasão: onde o paciente é atendido (próprio município / outro
#     município do estado / outro estado), por UF de residência.
# Saídas (apenas as figuras, fora do relatório): docs/sia_hs_files/figure-html/
# Rodar: Rscript scripts/plots_exploratorios_pe.R
# =============================================================================
suppressPackageStartupMessages({ library(tidyverse); library(arrow); library(ggpubr) })
source(here::here("scripts", "00_setup.R"))
source(here::here("scripts", "calcular_taxas.R"))

OUTDIR <- here::here("apresentacao/figuras")   # pasta estável (fora do docs/ gerado pelo Quarto)
dir.create(OUTDIR, showWarnings = FALSE, recursive = TRUE)

tema <- function() ggpubr::theme_pubr(legend = "top") +
  theme(plot.title = element_text(color = "#3E2A4D", face = "bold"),
        plot.subtitle = element_text(color = "#5b5165"),
        panel.grid.major.y = element_line(color = "grey92"))

pop <- carregar_pop()

# -----------------------------------------------------------------------------
# (1) Taxa padronizada: Brasil vs Pernambuco
# -----------------------------------------------------------------------------
sia <- open_dataset(here::here("data/parquet/sia_hs")) |>
  select(ano, uf_pcn, sexo, faixa) |> collect()
num <- contar_estrato(sia, col_uf = "uf_pcn")

nat <- taxas_padronizadas(num, pop, grupos = "ano") |> mutate(local = "Brasil")
pe  <- taxas_padronizadas(num, pop, grupos = c("uf","ano")) |>
  filter(uf == "PE") |> select(-uf) |> mutate(local = "Pernambuco")
serie <- bind_rows(nat, pe) |>
  mutate(local = factor(local, levels = c("Brasil","Pernambuco")))

p1 <- ggplot(serie, aes(ano, taxa_pad, color = local, fill = local)) +
  geom_ribbon(aes(ymin = ic_inf, ymax = ic_sup), alpha = 0.18, color = NA) +
  geom_line(linewidth = 1.2) +
  geom_point(size = 2.6) +
  geom_text(data = filter(serie, ano == max(ano)),
            aes(label = local), hjust = 0, nudge_x = 0.08, vjust = 0.4, size = 3.4,
            fontface = "bold", show.legend = FALSE) +
  scale_color_manual(values = c("Brasil" = "#A87FA8", "Pernambuco" = "#5C3F6C")) +
  scale_fill_manual(values  = c("Brasil" = "#A87FA8", "Pernambuco" = "#5C3F6C")) +
  scale_x_continuous(breaks = ANOS, expand = expansion(mult = c(0.02, 0.26))) +
  coord_cartesian(clip = "off") +
  labs(x = NULL, y = "por 100 mil (padronizada)", color = NULL, fill = NULL,
       title = "Taxa de detecção ambulatorial de HS: Pernambuco vs Brasil",
       subtitle = "Padronizada por idade e sexo (Censo 2022); faixa = IC 95%.") +
  tema() + theme(legend.position = "none")

ggsave(file.path(OUTDIR, "serie-pad-pe-1.png"), p1, width = 8, height = 4.8, dpi = 150, bg = "white")
message("✓ serie-pad-pe-1.png")
print(serie |> select(local, ano, taxa_pad) |>
        pivot_wider(names_from = local, values_from = taxa_pad) |> mutate(across(-ano, ~round(.x,1))))

# -----------------------------------------------------------------------------
# (2) Local de atendimento (próprio município / outro município do estado / outro estado)
# -----------------------------------------------------------------------------
fluxo <- open_dataset(here::here("data/parquet/sia_hs")) |>
  select(pa_munpcn, pa_ufmun) |> collect() |>
  mutate(res = str_pad(as.character(pa_munpcn), 6, pad = "0"),
         est = str_pad(as.character(pa_ufmun), 6, pad = "0")) |>
  filter(!str_detect(res, "^0+$"), !str_detect(est, "^0+$"),
         res != "999999", est != "999999") |>
  mutate(uf = uf_from_mun(res), uf_est = uf_from_mun(est),
         categoria = case_when(
           res == est            ~ "No próprio município",
           uf == uf_est          ~ "Outro município do estado",
           TRUE                  ~ "Outro estado")) |>
  filter(!is.na(uf), uf %in% UFS) |>
  count(uf, categoria) |>
  group_by(uf) |> mutate(prop = n / sum(n)) |> ungroup() |>
  mutate(categoria = factor(categoria,
           levels = c("No próprio município","Outro município do estado","Outro estado")),
         regiao = mapear_uf_regiao(uf))

# ordenar UFs por % atendido no próprio município (crescente: mais "evasão" no topo)
ord <- fluxo |> filter(categoria == "No próprio município") |> arrange(prop) |> pull(uf)
fluxo <- mutate(fluxo, uf = factor(uf, levels = ord))
# destacar PE no eixo
cores_uf <- ifelse(levels(fluxo$uf) == "PE", "#5C3F6C", "grey35")
faces_uf <- ifelse(levels(fluxo$uf) == "PE", "bold", "plain")

p2 <- ggplot(fluxo, aes(prop, uf, fill = categoria)) +
  geom_col(width = 0.85) +
  scale_fill_manual(values = c("No próprio município" = "#5C3F6C",
                               "Outro município do estado" = "#A87FA8",
                               "Outro estado" = "#E9CDC9")) +
  scale_x_continuous(labels = scales::percent_format(), expand = c(0, 0)) +
  labs(x = "Composição dos atendimentos", y = NULL, fill = NULL,
       title = "Onde o paciente de HS é atendido, por estado de residência",
       subtitle = "Proporção atendida no próprio município vs. fora dele (evasão). PE em destaque.") +
  tema() +
  theme(axis.text.y = element_text(color = cores_uf, face = faces_uf),
        panel.grid.major.y = element_blank(), legend.position = "top")

ggsave(file.path(OUTDIR, "fluxo-atendimento-uf-1.png"), p2, width = 8, height = 7.5, dpi = 150, bg = "white")
message("✓ fluxo-atendimento-uf-1.png")
cat("\nPernambuco — composição do local de atendimento:\n")
print(fluxo |> filter(uf == "PE") |> transmute(categoria, pct = round(100*prop,1)))
