# =============================================================================
# get_hs_data_from_SIA.R — Consolidação do SIA-PA (HS, L732)
# Brutos já filtrados por pa_cidpri == L732 (objeto x_hs, MAIÚSCULAS),
# em data/raw/SIA/sia_{uf}_{ano}_{tri}_hs.RData (648 arquivos; 33 vazios).
# Saídas: data/parquet/sia_hs/ (particionado ano+uf) e
#         data/consolidated/sia_hs_nacional.RData
# Rodar: Rscript scripts/get_hs_data_from_SIA.R
# =============================================================================

source(here::here("scripts", "00_setup.R"))   # params, dirs, utils, pacotes

DIR_SIA <- here::here("data/raw/SIA")
PAT <- "^sia_([a-z]{2})_(\\d{4})_(\\d)_hs\\.RData$"

carregar_obj <- function(fp, obj = "x_hs") {
  e <- new.env(); nm <- load(fp, envir = e)
  get(if (obj %in% nm) obj else nm[1], envir = e)
}

# -----------------------------------------------------------------------------
# 1. Carregar + limpar + tipar arquivo a arquivo (descarta vazios → sem clash de tipo)
# -----------------------------------------------------------------------------
message("== SIA: carregando e consolidando ==")
arqs <- list.files(DIR_SIA, pattern = PAT, full.names = TRUE)

ler_sia <- function(fp) {
  meta <- stringr::str_match(basename(fp), PAT)
  uf <- toupper(meta[2]); ano <- as.integer(meta[3]); tri <- as.integer(meta[4])
  x <- carregar_obj(fp) |> janitor::clean_names()
  log_run("sia", uf, sprintf("%d_T%d", ano, tri),
          if (nrow(x)) "ok" else "ok", n_lidas = nrow(x), n_hs = nrow(x))
  if (!nrow(x)) return(NULL)                       # vazios não contribuem registros
  x |> dplyr::mutate(uf_arquivo = uf, ano = ano, trimestre = tri)
}

lst <- purrr::map(arqs, ler_sia) |> purrr::compact()
# harmoniza tipos contra o maior frame antes do bind (robusto a int/double entre arquivos)
ref <- lst[[which.max(purrr::map_int(lst, nrow))]]
lst <- purrr::map(lst, ~ casar_tipos(.x, ref))
sia <- dplyr::bind_rows(lst)
rm(lst); gc(verbose = FALSE)
message(sprintf("SIA consolidado bruto: %d registros, %d colunas.", nrow(sia), ncol(sia)))

# -----------------------------------------------------------------------------
# 2. Coerção de tipos + enriquecimento
# -----------------------------------------------------------------------------
sia <- sia |>
  coagir_tipos(monetarias = c("pa_valpro","pa_valapr","pa_vl_cf","pa_vl_cl","pa_vl_inc")) |>
  dplyr::mutate(
    camada     = camada_cid(pa_cidpri),                      # esperado: tudo "L732"
    cid_ok     = cid_valido(pa_cidpri),
    sexo       = dplyr::recode(toupper(stringr::str_trim(pa_sexo)),
                               F = "Feminino", M = "Masculino", .default = NA_character_),
    raca_cor   = dplyr::recode(stringr::str_pad(stringr::str_trim(pa_racacor), 2, pad = "0"),
                               "01"="Branca","02"="Preta","03"="Parda","04"="Amarela",
                               "05"="Indígena", .default = NA_character_),  # 99 -> NA
    idade_anos = suppressWarnings(as.integer(pa_idade)),     # SIA-PA: idade em anos (3 díg.)
    idade_anos = dplyr::if_else(idade_anos >= 0 & idade_anos <= 110, idade_anos, NA_integer_),
    faixa      = harmonizar_faixa(idade_anos),
    uf_pcn     = uf_from_mun(pa_munpcn),                     # UF de residência do paciente
    competencia = lubridate::ym(pa_cmp),                    # AAAAMM -> Date (1º dia do mês)
    fonte      = "datasus_sia_pa"
  )

# QC rápido
cat("\n• camada de CID (esperado só L732):\n"); print(janitor::tabyl(sia, camada))
cat("• registros por ano:\n"); print(dplyr::count(sia, ano, name = "registros"))
cat(sprintf("• idade NA: %d | sexo NA: %d | raça NA(99): %d | uf_pcn NA: %d\n",
            sum(is.na(sia$idade_anos)), sum(is.na(sia$sexo)),
            sum(is.na(sia$raca_cor)), sum(is.na(sia$uf_pcn))))

# -----------------------------------------------------------------------------
# 3. Persistir: Parquet particionado (ano + uf) + consolidado RData
# -----------------------------------------------------------------------------
dir.create(here::here("data/parquet/sia_hs"), showWarnings = FALSE, recursive = TRUE)
sia |>
  dplyr::mutate(uf = uf_arquivo) |>                          # partição por UF do arquivo
  arrow::write_dataset(path = here::here("data/parquet/sia_hs"),
                       partitioning = c("ano", "uf"), format = "parquet")

sia_hs_nacional <- sia
save(sia_hs_nacional, file = here::here("data/consolidated/sia_hs_nacional.RData"))
saveRDS(sia_hs_nacional, here::here("data/filtered/sia_hs/sia_hs_nacional.rds"))

message(sprintf("\n✓ SIA consolidado: %d registros (2020–2025) → Parquet ano+uf + consolidated.",
                nrow(sia)))
