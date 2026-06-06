# =============================================================================
# get_denominadores_ibge.R — Denominadores populacionais IBGE via sidrar (SIDRA)
# Estrutura UF × sexo × faixa etária (FAIXAS_BR) a partir do CENSO 2022 (tab 9514).
#
# DECISÃO DE MÉTODO (datasus_hs.md §5):
#   Denominador = estrutura do CENSO 2022, CONSTANTE para 2020–2025.
#   Por quê: (a) é a população-padrão do projeto; (b) é completo (27×17×2) e de
#   metodologia única → SEM o degrau Censo↔projeção; (c) as taxas são de
#   DETECÇÃO/USO e a tendência é guiada pelo numerador (que cresce ~10× no período),
#   enquanto a mudança populacional real é <2%/ano.
#   Escalonamento anual pela estimativa (tab 6579) foi AVALIADO e REJEITADO: o 6579
#   está em base de PROJEÇÃO (~212 M) divergente do Censo (~203 M) e não publica
#   2022 nem 2023 → escalonar reintroduz a descontinuidade que se quer evitar.
#   (Para análise de sensibilidade futura, escalar a estrutura pela estimativa de
#    cada ano — não implementado aqui para não importar o degrau.)
#
# Cache: skip-if-exists (API SIDRA é lenta/instável).
# Saída: data/denominators/pop_ibge.parquet (+ .rds)
# Rodar: Rscript scripts/get_denominadores_ibge.R
# =============================================================================

source(here::here("scripts", "00_setup.R"))
suppressPackageStartupMessages(library(sidrar))
options(timeout = 600)

OUT_PARQUET <- here::here("data/denominators/pop_ibge.parquet")
OUT_RDS     <- here::here("data/denominators/pop_ibge.rds")

if (file.exists(OUT_PARQUET)) {
  message("Denominadores já em cache (", OUT_PARQUET, ") — skip. Apague p/ refazer.")
  quit(save = "no")
}

# Grupos quinquenais (c287). ⚠️ Na tab 9514 o agregado 113623 ("80 anos ou mais")
# vem VAZIO → usar os sub-grupos 49108(80-84)+49109(85-89)+49110(90+) e somar em "80+".
GRUPOS <- c(93070,93084,93085,93086,93087,93088,93089,93090,93091,93092,
            93093,93094,93095,93096,93097,93098,   # 0-4 … 75-79
            49108,49109,49110)                      # 80-84, 85-89, 90+ → "80+"
# Níveis canônicos de faixa — IDÊNTICOS aos do numerador (harmonizar_faixa) p/ join
FAIXA_LEVELS <- levels(harmonizar_faixa(seq(0, 85, by = 5)))

uf_sigla <- function(nome) {
  m <- c("Rondônia"="RO","Acre"="AC","Amazonas"="AM","Roraima"="RR","Pará"="PA",
         "Amapá"="AP","Tocantins"="TO","Maranhão"="MA","Piauí"="PI","Ceará"="CE",
         "Rio Grande do Norte"="RN","Paraíba"="PB","Pernambuco"="PE","Alagoas"="AL",
         "Sergipe"="SE","Bahia"="BA","Minas Gerais"="MG","Espírito Santo"="ES",
         "Rio de Janeiro"="RJ","São Paulo"="SP","Paraná"="PR","Santa Catarina"="SC",
         "Rio Grande do Sul"="RS","Mato Grosso do Sul"="MS","Mato Grosso"="MT",
         "Goiás"="GO","Distrito Federal"="DF")
  unname(m[nome])
}
# "0 a 4 anos"->"0-4" ; 80-84/85-89/90+ -> "80+" (terminal aberto do FAIXAS_BR)
faixa_label <- function(desc) {
  lo <- suppressWarnings(as.integer(stringr::str_extract(desc, "^\\d+")))
  dplyr::case_when(
    is.na(lo)  ~ NA_character_,
    lo >= 80   ~ "80+",
    TRUE       ~ stringr::str_replace(desc, "(\\d+) a (\\d+) anos", "\\1-\\2")
  )
}

# -----------------------------------------------------------------------------
# 1. Estrutura Censo 2022 — UF × sexo × faixa
# -----------------------------------------------------------------------------
message("== SIDRA 9514: Censo 2022 (UF × sexo × idade) ==")
api_censo <- paste0("/t/9514/n3/all/v/93/p/2022/c2/4,5/c287/",
                    paste(GRUPOS, collapse = ","), "/c286/113635")
censo <- sidrar::get_sidra(api = api_censo) |> janitor::clean_names()

pop_estrutura <- censo |>
  dplyr::transmute(
    uf    = uf_sigla(unidade_da_federacao),
    sexo  = dplyr::recode(sexo, "Homens"="Masculino","Mulheres"="Feminino"),
    faixa = faixa_label(idade),
    pop   = as.numeric(valor)
  ) |>
  dplyr::filter(!is.na(uf), !is.na(faixa), !is.na(pop)) |>
  dplyr::group_by(uf, sexo, faixa) |>                 # soma 80-84+85-89+90+ em "80+"
  dplyr::summarise(pop = sum(pop), .groups = "drop")

cat("• faixas distintas vindas do Censo:", dplyr::n_distinct(pop_estrutura$faixa),
    "\n  ", paste(sort(unique(pop_estrutura$faixa)), collapse = ", "), "\n")

# -----------------------------------------------------------------------------
# 2. Replicar a estrutura 2022 para cada ano (denominador constante)
# -----------------------------------------------------------------------------
pop_ibge <- tidyr::expand_grid(ano = ANOS, pop_estrutura) |>
  dplyr::mutate(
    faixa     = factor(faixa, levels = FAIXA_LEVELS),
    regiao    = mapear_uf_regiao(uf),
    base_pop  = "censo2022_constante"
  ) |>
  dplyr::select(regiao, uf, ano, sexo, faixa, pop, base_pop)

# -----------------------------------------------------------------------------
# 3. QC + persistir
# -----------------------------------------------------------------------------
esp <- 27 * length(ANOS) * 2 * length(FAIXA_LEVELS)
cat(sprintf("\n• dimensões: %d linhas (esperado 27×%d×2×%d = %d) | faixa NA: %d\n",
            nrow(pop_ibge), length(ANOS), length(FAIXA_LEVELS), esp, sum(is.na(pop_ibge$faixa))))
{ s <- sum(dplyr::filter(pop_ibge, ano==2022)$pop)
  cat(sprintf("• Brasil 2022 (soma dos 17 grupos): %s (Censo total 203.080.756; gap %.1f%% = idade ignorada não distribuída)\n",
              format(s, big.mark=".", scientific=FALSE), 100*(1 - s/203080756))) }
cat("• exemplo SP × sexo × faixa (constante p/ todo ano):\n")
print(pop_ibge |> dplyr::filter(uf=="SP", ano==2022, faixa %in% c("20-24","80+")) |>
        dplyr::select(uf, sexo, faixa, pop))

arrow::write_parquet(pop_ibge, OUT_PARQUET)
saveRDS(pop_ibge, OUT_RDS)
message(sprintf("\n✓ Denominadores IBGE (Censo 2022 constante): %d linhas → %s",
                nrow(pop_ibge), basename(OUT_PARQUET)))
