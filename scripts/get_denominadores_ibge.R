# =============================================================================
# get_denominadores_ibge.R — Denominador populacional IBGE ANUAL (Projeções 2024)
# Estrutura UF × ano × sexo × faixa QUINQUENAL (FAIXAS_BR), para ANOS (2010–2025).
# Molde: datasus_EIM/scripts/get_denominadores_ibge.R (guia ref/guia_processamento_datasus.md §9).
#
# FONTE: IBGE, Projeções da População — Revisão 2024, tabela 2 "População por sexo e
# idade quinquenal 2000/2070" (Brasil, Grandes Regiões, UFs):
#   https://ftp.ibge.gov.br/Projecao_da_Populacao/Projecao_da_Populacao_2024/
#     projecoes_2024_tab2_grupo_quinquenal.xlsx
# Uma ÚNICA série (retroprojeção + projeção, ancoradas no Censo 2022) — sem o degrau
# entre fontes. Substitui a v1 (Censo 2022 via sidrar replicado como CONSTANTE em
# 2020–2025, guardada em pop_ibge_v1_censo2022.parquet), que fazia toda tendência de
# taxa refletir só o numerador. 80-84, 85-89 e 90+ são somados em "80+".
#
# Cache: o xlsx fica em data/denominators/ibge_projecao_2024/ (baixa se ausente).
# Saída: data/denominators/pop_ibge.{parquet,rds}
# Rodar: Rscript scripts/get_denominadores_ibge.R
# =============================================================================

source(here::here("scripts", "00_setup.R"))
options(timeout = 600)

URL  <- "https://ftp.ibge.gov.br/Projecao_da_Populacao/Projecao_da_Populacao_2024/projecoes_2024_tab2_grupo_quinquenal.xlsx"
XLSX <- here::here("data/denominators/ibge_projecao_2024/projecoes_2024_tab2_grupo_quinquenal.xlsx")
OUT_PARQUET <- here::here("data/denominators/pop_ibge.parquet")
OUT_RDS     <- here::here("data/denominators/pop_ibge.rds")
if (!file.exists(XLSX)) {
  dir.create(dirname(XLSX), recursive = TRUE, showWarnings = FALSE)
  utils::download.file(URL, XLSX, mode = "wb", quiet = TRUE)
}
FAIXA_LEVELS <- levels(harmonizar_faixa(seq(0, 85, by = 5)))

# Cabeçalho na linha 6 (GRUPO ETÁRIO, SEXO, CÓD., SIGLA, LOCAL, 2000…2070)
bruto <- readxl::read_excel(XLSX, sheet = 1, skip = 5, col_types = "text",
                            .name_repair = "minimal")
names(bruto)[1:5] <- c("grupo", "sexo", "cod", "sigla", "local")

pop_ibge <- bruto |>
  dplyr::filter(sigla %in% UFS, sexo %in% c("Homens", "Mulheres")) |>
  tidyr::pivot_longer(-c(grupo, sexo, cod, sigla, local), names_to = "ano", values_to = "pop") |>
  dplyr::mutate(ano = suppressWarnings(as.integer(ano)), pop = as.numeric(pop)) |>
  dplyr::filter(ano %in% ANOS, !is.na(pop)) |>
  dplyr::mutate(
    lo    = as.integer(stringr::str_extract(grupo, "^\\d+")),
    faixa = dplyr::if_else(lo >= 80, "80+", sprintf("%d-%d", lo, lo + 4L)),
    sexo  = dplyr::recode(sexo, "Homens" = "Masculino", "Mulheres" = "Feminino")) |>
  dplyr::group_by(uf = sigla, ano, sexo, faixa) |>
  dplyr::summarise(pop = sum(pop), .groups = "drop") |>
  dplyr::mutate(faixa = factor(faixa, levels = FAIXA_LEVELS),
                regiao = mapear_uf_regiao(uf), base_pop = "ibge_projecao_2024") |>
  dplyr::select(regiao, uf, ano, sexo, faixa, pop, base_pop) |>
  dplyr::arrange(ano, uf, sexo, faixa)

esperado <- 27 * length(ANOS) * 2 * length(FAIXA_LEVELS)
cat(sprintf("\n• dimensões: %d (esperado %d) | faixa NA: %d | anos: %s\n",
            nrow(pop_ibge), esperado, sum(is.na(pop_ibge$faixa)), paste(range(pop_ibge$ano), collapse = "–")))
br <- pop_ibge |> dplyr::group_by(ano) |> dplyr::summarise(pop = sum(pop))
cat("• Brasil por ano (milhões):", paste0(br$ano, "=", round(br$pop / 1e6, 1), collapse = " "), "\n")
stopifnot(nrow(pop_ibge) == esperado, !anyNA(pop_ibge$faixa), !anyNA(pop_ibge$regiao))

arrow::write_parquet(pop_ibge, OUT_PARQUET); saveRDS(pop_ibge, OUT_RDS)
message(sprintf("\n✓ Denominadores IBGE (Projeções 2024, anual %d–%d): %d linhas → %s",
                min(ANOS), max(ANOS), nrow(pop_ibge), basename(OUT_PARQUET)))
