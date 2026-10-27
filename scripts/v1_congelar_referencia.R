# =============================================================================
# v1_congelar_referencia.R — E0 do plano_expansao_2010.md
# Congela a v1 (2020–2025, brutos pré-filtrados) como referência de validação da v2:
#   manifest/v1_checksums.csv            sha256 de data/raw/{SIA,SIH,SIM} e consolidados
#   manifest/v1_contagens_referencia.csv contagens por base × UF do arquivo × período
#     SIA: linhas e Σ pa_qtdapr por pa_mvm (mês de PROCESSAMENTO) e por pa_cmp
#     SIH: AIH distintas (diag_princ L732) por ano_cmpt × mes_cmpt
#     SIM: óbitos com L732 em qualquer campo e como causa básica, por ano
# Só leitura do que já existe; não altera brutos nem consolidados.
# Rodar: Rscript scripts/v1_congelar_referencia.R
# =============================================================================
suppressPackageStartupMessages({ library(tidyverse); library(arrow) })
source(here::here("scripts", "00_setup.R"))

# -----------------------------------------------------------------------------
# 1. Checksums
# -----------------------------------------------------------------------------
# Os brutos ficam no OneDrive só na nuvem (placeholder de 0 B): sha256 forçaria baixar
# tudo. Para eles grava nome + tamanho lógico; sha256 só do que já está no disco
# (parquet e consolidados).
brutos <- list.files(here::here("data/raw", c("SIA", "SIH", "SIM")), full.names = TRUE)
locais <- c(list.files(here::here("data/parquet"), recursive = TRUE, full.names = TRUE),
            list.files(here::here("data/consolidated"), full.names = TRUE))
checks <- tibble(arquivo = c(brutos, locais),
                 bytes   = file.size(arquivo),
                 sha256  = c(rep(NA_character_, length(brutos)),
                             purrr::map_chr(locais, ~ digest::digest(file = .x, algo = "sha256")))) |>
  mutate(arquivo = stringr::str_remove(arquivo, paste0("^", here::here(), "/")))
readr::write_csv(checks, here::here("manifest/v1_checksums.csv"))
message("✓ checksums: ", nrow(checks), " arquivos")

# -----------------------------------------------------------------------------
# 2. Contagens de referência
# -----------------------------------------------------------------------------
sia <- open_dataset(here::here("data/parquet/sia_hs")) |>
  filter(pa_cidpri == "L732") |>
  select(uf_arquivo, pa_mvm, pa_cmp, pa_docorig, pa_qtdapr) |> collect() |>
  mutate(qtd = as.numeric(pa_qtdapr))

por_periodo_sia <- function(col)
  sia |> group_by(uf = toupper(uf_arquivo), periodo = as.character(.data[[col]])) |>
    summarise(valor = n(), valor2 = sum(qtd, na.rm = TRUE), .groups = "drop") |>
    mutate(chave = col)
ref_sia <- purrr::map_dfr(c("pa_mvm", "pa_cmp"), por_periodo_sia) |>
  transmute(base = "SIA", chave, uf, periodo, metrica = "linhas|soma_qtdapr", valor, valor2)

ref_sih <- open_dataset(here::here("data/parquet/sih_hs")) |>
  filter(diag_princ == "L732") |>
  select(uf_arquivo, ano_cmpt, mes_cmpt, n_aih) |> collect() |>
  group_by(uf = toupper(uf_arquivo), periodo = paste0(ano_cmpt, stringr::str_pad(mes_cmpt, 2, pad = "0"))) |>
  summarise(valor = n_distinct(n_aih), .groups = "drop") |>
  transmute(base = "SIH", chave = "ano_mes_cmpt", uf, periodo, metrica = "aih_distintas", valor, valor2 = NA_real_)

e <- new.env(); load(here::here("data/consolidated/sim_hs_nacional.RData"), envir = e)
sim <- e$sim_hs_nacional
cols_sim <- intersect(c("causabas", "causabas_o", "linhaa", "linhab", "linhac", "linhad", "linhaii"), names(sim))
ref_sim <- sim |>
  mutate(qualquer = dplyr::if_any(all_of(cols_sim), ~ stringr::str_detect(coalesce(.x, ""), "L732")),
         cb       = stringr::str_detect(coalesce(causabas, ""), "^L732")) |>
  group_by(periodo = as.character(ano)) |>
  summarise(valor = sum(qualquer), valor2 = sum(cb), .groups = "drop") |>
  transmute(base = "SIM", chave = "ano", uf = "BR", periodo, metrica = "obitos_qualquer|causa_basica", valor, valor2)

ref <- bind_rows(ref_sia, ref_sih, ref_sim)
readr::write_csv(ref, here::here("manifest/v1_contagens_referencia.csv"))

message("✓ referência v1: ", nrow(ref), " linhas")
ref |> group_by(base, chave) |> summarise(valor = sum(valor), valor2 = sum(valor2), .groups = "drop") |> print()
