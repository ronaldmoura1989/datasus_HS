# =============================================================================
# figuras_apresentacao.R — Figuras da apresentação para pacientes (v2, 2010–2025)
# Lê SÓ os agregados suprimidos (data/export/hs_v2_agregados.rds) e denominadores
# públicos — substitui plots_exploratorios_pe.R, mapa_biossimilares.R e
# doses_adalimumabe.R (v1, liam microdados). Cada figura mantém o tamanho em
# polegadas da imagem que ocupa no apresentacao_HS_15min.pptx, para a troca no
# deck não distorcer a moldura editada à mão.
# Saídas: apresentacao/figuras/*-v2.png
# Rodar: Rscript scripts/figuras_apresentacao.R
# =============================================================================
suppressPackageStartupMessages({ library(tidyverse); library(sf); library(ggpubr) })
source(here::here("scripts", "00_setup.R"))

E <- readRDS(here::here("data/export/hs_v2_agregados.rds"))
OUTDIR <- here::here("apresentacao/figuras")
dir.create(OUTDIR, showWarnings = FALSE, recursive = TRUE)
salvar <- function(p, nome, w, h, dpi) {
  ggsave(file.path(OUTDIR, nome), p, width = w, height = h, dpi = dpi, bg = "white")
  message("✓ ", nome)
}
tema <- function(base = 13) ggpubr::theme_pubr(base_size = base, legend = "top") +
  theme(plot.title = element_text(color = "#3E2A4D", face = "bold"), plot.title.position = "plot",
        plot.subtitle = element_text(color = "#5b5165"),
        panel.grid.major.y = element_line(color = "grey92"))
quebra <- function(x, w = 80) stringr::str_wrap(x, w)   # subtítulos longos eram cortados
num_br <- function(x) formatC(x, format = "d", big.mark = ".", decimal.mark = ",")
malha <- readRDS(here::here("data/denominators/malha_uf.rds"))
pop <- arrow::read_parquet(here::here("data/denominators/pop_ibge.parquet"))
FAIXAS <- levels(harmonizar_faixa(seq(0, 85, by = 5)))
LABS_ADA <- c("0604380062" = "Referência", "0604380127" = "Biossimilar A", "0604380135" = "Biossimilar B")
CORES_ADA <- c("Referência" = "#5C3F6C", "Biossimilar A" = "#A87FA8", "Biossimilar B" = "#E9CDC9")

# (1) Pirâmide sexo × idade — SIA, todos os canais (slide "Quem é o paciente")
pir <- E$piramide |>
  filter(startsWith(base, "SIA")) |>
  group_by(faixa, sexo) |> summarise(n = sum(n, na.rm = TRUE), .groups = "drop") |>
  mutate(faixa = factor(faixa, levels = FAIXAS), n = ifelse(sexo == "Masculino", -n, n))
p1 <- ggplot(pir, aes(faixa, n, fill = sexo)) +
  geom_col(width = 0.85) + coord_flip() +
  scale_y_continuous(labels = function(x) num_br(abs(x))) +
  scale_fill_manual(values = c(Masculino = "#816095", Feminino = "#5C3F6C")) +
  labs(x = "Faixa etária", y = "Registros ambulatoriais", fill = NULL,
       title = "Quem é atendido por HS no SUS",
       subtitle = paste0("Registros ambulatoriais por sexo e idade, ", min(ANOS), "–", max(ANOS), ". ",
                         round(E$tot$sia_fem_pct), "% são mulheres; idade mediana ", E$tot$sia_idade_mediana, " anos.")) +
  tema() + theme(legend.position = "right")
salvar(p1, "piramide-v2.png", 8, 4.8, 300)

# (2) Mapa da detecção clínica padronizada por UF, 2014–2025 (slide "Onde você mora")
m2 <- malha |> left_join(select(E$uf_clinico_2014, uf, taxa_pad), by = c("abbrev_state" = "uf"))
p2 <- ggplot(m2) +
  geom_sf(aes(fill = taxa_pad), color = "white", linewidth = 0.15) +
  scale_fill_gradient(low = "#E9CDC9", high = "#5C3F6C", na.value = "grey88",
                      name = "por 100 mil\n(pessoa-anos)",
                      labels = function(x) formatC(x, format = "f", digits = 1, decimal.mark = ",")) +
  labs(title = "Onde a HS é diagnosticada no SUS",
       subtitle = quebra("Atendimentos clínicos com o CID da HS, padronizados por idade e sexo (2014–2025). Cinza: poucos casos para mostrar.")) +
  theme_void(base_size = 13) +
  theme(plot.title = element_text(color = "#3E2A4D", face = "bold"), plot.title.position = "plot",
        plot.subtitle = element_text(color = "#5b5165"))
salvar(p2, "mapa-uf-v2.png", 8, 4.8, 300)

# (3) Pacientes em tratamento com adalimumabe por 100 mil: PE × Brasil (slide "Cada vez mais")
pop_ano <- pop |> group_by(ano) |> summarise(pop = sum(pop), .groups = "drop")
serie <- bind_rows(
  E$serie_ano |> select(ano, pac = sia_trat_pacientes) |> left_join(pop_ano, by = "ano") |>
    transmute(ano, v = 1e5 * pac / pop, local = "Brasil"),
  E$trat_uf |> filter(uf == "PE") |> transmute(ano, v = por_100k, local = "Pernambuco")) |>
  filter(ano >= 2019, !is.na(v), v > 0) |>
  mutate(local = factor(local, levels = c("Brasil", "Pernambuco")))
p3 <- ggplot(serie, aes(ano, v, color = local)) +
  geom_line(linewidth = 1.2) + geom_point(size = 2.6) +
  geom_text(data = filter(serie, ano == max(ano)), aes(label = local), hjust = 0, nudge_x = 0.12,
            size = 3.6, fontface = "bold", show.legend = FALSE) +
  scale_color_manual(values = c("Brasil" = "#A87FA8", "Pernambuco" = "#5C3F6C")) +
  scale_x_continuous(breaks = 2019:max(ANOS), expand = expansion(mult = c(0.03, 0.2))) +
  scale_y_continuous(labels = function(x) formatC(x, format = "f", digits = 1, decimal.mark = ",")) +
  coord_cartesian(clip = "off") +
  labs(x = NULL, y = "pacientes/mês por 100 mil hab.",
       title = "Pessoas em tratamento com adalimumabe para HS",
       subtitle = quebra("O SUS passa a oferecer o medicamento para HS em novembro de 2019. Mediana mensal de pacientes, por 100 mil habitantes.")) +
  tema() + theme(legend.position = "none")
salvar(p3, "tratamento-pe-v2.png", 8, 4.8, 150)

# (4) Onde o paciente é atendido, por UF de residência — PE em destaque (todos os canais)
fl <- E$fluxo |> group_by(uf, categoria) |> summarise(n = sum(n, na.rm = TRUE), .groups = "drop") |>
  group_by(uf) |> mutate(prop = n / sum(n)) |> ungroup() |>
  mutate(categoria = factor(categoria, levels = c("No próprio município", "Outro município do estado", "Outro estado")))
ord <- fl |> filter(categoria == "No próprio município") |> arrange(prop) |> pull(uf)
fl <- mutate(fl, uf = factor(uf, levels = ord))
p4 <- ggplot(fl, aes(prop, uf, fill = categoria)) +
  geom_col(width = 0.85) +
  scale_fill_manual(values = c("No próprio município" = "#5C3F6C", "Outro município do estado" = "#A87FA8",
                               "Outro estado" = "#E9CDC9")) +
  scale_x_continuous(labels = scales::percent_format(), expand = c(0, 0)) +
  labs(x = "Composição dos atendimentos", y = NULL, fill = NULL,
       title = "Onde o paciente de HS é atendido, por estado de residência",
       subtitle = paste0("Consultas, exames e medicamento, ", min(ANOS), "–", max(ANOS), ". PE em destaque."),
       caption = "Categorias com menos de 5 atendimentos omitidas: estados pequenos podem aparecer com 100% local.") +
  tema() +
  theme(axis.text.y = element_text(color = ifelse(levels(fl$uf) == "PE", "#5C3F6C", "grey35"),
                                   face = ifelse(levels(fl$uf) == "PE", "bold", "plain")),
        panel.grid.major.y = element_blank())
salvar(p4, "fluxo-atendimento-uf-v2.png", 8, 7.5, 150)

# (5) Oferta de dermatologistas × detecção clínica, por UF (2014–2025)
sc <- filter(E$uf_clinico_2014, !is.na(taxa_pad))
r <- cor(sc$derm_100k, sc$taxa_pad)
p5 <- ggplot(sc, aes(derm_100k, taxa_pad)) +
  geom_smooth(method = "lm", formula = y ~ x, se = TRUE, color = "#5C3F6C", fill = "#D8B4C4", alpha = 0.4) +
  geom_point(aes(color = regiao), size = 3.2) +
  geom_text(aes(label = uf), size = 3, vjust = -0.9, color = "#3E2A4D", check_overlap = TRUE) +
  scale_color_manual(values = PAL_HS) +
  scale_y_continuous(labels = function(x) formatC(x, format = "f", digits = 1, decimal.mark = ",")) +
  labs(x = "Dermatologistas por 100 mil hab. (média 2014–2025)",
       y = "Diagnósticos de HS por 100 mil (padronizado)", color = "Região",
       title = "Onde há mais dermatologistas, encontra-se mais HS",
       subtitle = paste0("Cada ponto é um estado. Correlação r = ", formatC(r, format = "f", digits = 2, decimal.mark = ","),
                         ": a detecção acompanha a oferta de especialistas.")) +
  tema() + theme(legend.position = "right")
salvar(p5, "derm-scatter-v2.png", 8, 5.2, 300)

# (6) Tipo de adalimumabe predominante por UF, 2020 × 2025
ANOS_MAPA <- c(2020, max(ANOS))
dom <- E$biossimilar_uf |>
  filter(pa_proc_id %in% names(LABS_ADA), ano %in% ANOS_MAPA, !is.na(n)) |>
  group_by(ano, uf) |> slice_max(n, n = 1, with_ties = FALSE) |> ungroup() |>
  mutate(tipo = unname(LABS_ADA[pa_proc_id]))
niveis <- c(names(CORES_ADA), "Sem registro ou poucos casos")
m6 <- tidyr::expand_grid(uf = UFS, ano = ANOS_MAPA) |>
  left_join(select(dom, uf, ano, tipo), by = c("uf", "ano")) |>
  mutate(tipo = factor(coalesce(tipo, niveis[4]), levels = niveis)) |>
  left_join(malha, by = c("uf" = "abbrev_state")) |> sf::st_as_sf()
p6 <- ggplot(m6) +
  geom_sf(aes(fill = tipo), color = "white", linewidth = 0.15) +
  facet_wrap(~ ano) +
  scale_fill_manual(values = c(CORES_ADA, "Sem registro ou poucos casos" = "grey88"), drop = FALSE) +
  labs(fill = NULL, title = "Qual adalimumabe cada estado mais usa para HS",
       subtitle = paste0("Tipo predominante nas dispensações. Da referência (2020) aos biossimilares (", max(ANOS), ").")) +
  theme_void(base_size = 13) +
  theme(plot.title = element_text(face = "bold", color = "#3E2A4D", hjust = 0.5),
        plot.subtitle = element_text(color = "#5b5165", hjust = 0.5), legend.position = "bottom",
        strip.text = element_text(face = "bold", color = "#3E2A4D", size = 14))
salvar(p6, "ada-tipos-mapa-v2.png", 9, 5.4, 150)

# (7) Seringas de adalimumabe para HS por tipo e ano (antigo doses_adalimumabe.R)
ser <- E$adalimumabe_todos_cid |>
  filter(l732, proc %in% names(LABS_ADA), ano >= 2019) |>
  mutate(tipo = factor(unname(LABS_ADA[proc]), levels = names(CORES_ADA)))
tot <- ser |> group_by(ano) |> summarise(s = sum(seringas, na.rm = TRUE), .groups = "drop")
p7 <- ggplot(ser, aes(factor(ano), seringas, fill = tipo)) +
  geom_col(width = 0.78, na.rm = TRUE) +
  geom_text(data = tot, aes(factor(ano), s, label = num_br(s)), inherit.aes = FALSE,
            vjust = -0.5, size = 3.4, color = "#3E2A4D", fontface = "bold") +
  scale_fill_manual(values = CORES_ADA) +
  scale_y_continuous(labels = num_br, expand = expansion(mult = c(0, 0.1))) +
  labs(x = NULL, y = "Seringas de 40 mg", fill = NULL,
       title = "Adalimumabe dispensado para HS no SUS",
       subtitle = "Seringas por ano e tipo (CID L73.2).") +
  tema()
salvar(p7, "doses-adalimumabe-barras-v2.png", 8, 4.8, 150)
