# =============================================================================
# get_hs_data_from_SIM.R — Filtro de HS e consolidação do SIM-DO
# Part A: filtra os 135 RData (2020–2024, objeto `x`, já processado) por HS
#         em causabas + linhaa..d + linhaii.
# Part B: baixa a prévia 2025 (opendatasus CSV bruto), filtra HS, processa com
#         process_sim() e harmoniza ao schema dos demais anos.
# Saídas: data/filtered/sim_hs/sim_hs_{ano}.RData (opcional) e
#         data/consolidated/sim_hs_nacional.RData
# Rodar: Rscript scripts/get_hs_data_from_SIM.R
# =============================================================================

source(here::here("scripts", "00_setup.R"))   # params, dirs, utils, pacotes
library(microdatasus)   # ATACHAR (não usar só ::): process_sim referencia datasets
                        # internos (tabNaturalidade, tabCBO, tabMun...) como variáveis
                        # livres — só ficam acessíveis com o pacote no search path.

DIR_SIM   <- here::here("data/raw/SIM")
DIR_2025  <- here::here("data/raw/SIM_2025")
URL_2025  <- "https://s3.sa-east-1.amazonaws.com/ckan.saude.gov.br/SIM/csv/Mortalidade_Geral_2025_csv.zip"
COLS_CAUSA <- c("causabas", "linhaa", "linhab", "linhac", "linhad", "linhaii")

carregar_obj <- function(fp, obj = "x") {
  e <- new.env(); nm <- load(fp, envir = e)
  get(if (obj %in% nm) obj else nm[1], envir = e)
}

#' TRUE para linhas com HS (L732) em qualquer campo de causa presente.
eh_hs_sim <- function(df, cols = COLS_CAUSA) {
  cols <- intersect(cols, names(df))
  if (!length(cols)) return(logical(nrow(df)))
  purrr::reduce(
    purrr::map(cols, ~ stringr::str_detect(tidyr::replace_na(as.character(df[[.x]]), ""), "L732")),
    `|`
  )
}

# -----------------------------------------------------------------------------
# Part A — 2020–2024 (RData processados)
# -----------------------------------------------------------------------------
message("== SIM Part A: filtrando 2020–2024 ==")
arqs <- list.files(DIR_SIM, pattern = "^sim_do_.*\\.RData$", full.names = TRUE)

sim_hs_2024 <- purrr::map_dfr(arqs, function(fp) {
  meta <- stringr::str_match(basename(fp), "^sim_do_([A-Z]{2})_(\\d{4})\\.RData$")
  uf_arq <- meta[2]; ano_arq <- as.integer(meta[3])
  x <- carregar_obj(fp, "x")
  hs <- dplyr::filter(x, eh_hs_sim(x))
  n_hs <- nrow(hs)
  if (n_hs) hs <- dplyr::mutate(hs, uf_arquivo = uf_arq, ano = ano_arq, fonte = "datasus_sim_do")
  log_run("sim", uf_arq, ano_arq, if (n_hs) "ok" else "ok",
          n_lidas = nrow(x), n_hs = n_hs)
  rm(x); gc(verbose = FALSE)
  hs
})
message(sprintf("Part A: %d óbitos com HS (2020–2024).", nrow(sim_hs_2024)))

# -----------------------------------------------------------------------------
# Part B — 2025 preliminar (opendatasus, CSV bruto → process_sim)
# -----------------------------------------------------------------------------
sim_hs_2025 <- NULL
ok_2025 <- tryCatch({
  message("== SIM Part B: 2025 preliminar (opendatasus) ==")
  cache_2025 <- here::here("data/filtered/sim_hs/sim_hs_2025_preliminar.rds")
  if (file.exists(cache_2025)) {
    message("2025 processado em cache — skip download/fread/process_sim.")
    sim_hs_2025 <<- readRDS(cache_2025)
    return(TRUE)
  }
  zip_fp <- file.path(DIR_2025, "Mortalidade_Geral_2025_csv.zip")
  # zip válido = unzip(list=) consegue ler o índice; senão, (re)baixar
  zip_ok <- file.exists(zip_fp) &&
    !inherits(try(utils::unzip(zip_fp, list = TRUE), silent = TRUE), "try-error")
  if (!zip_ok) {
    message("Baixando ", basename(zip_fp), " (~96 MB)...")
    options(timeout = 600)
    utils::download.file(URL_2025, zip_fp, mode = "wb", quiet = TRUE, method = "libcurl")
  } else message("zip já presente e íntegro — skip download.")

  csv_nome <- utils::unzip(zip_fp, list = TRUE)$Name[1]
  csv_fp   <- file.path(DIR_2025, csv_nome)
  if (!file.exists(csv_fp)) utils::unzip(zip_fp, exdir = DIR_2025)

  # CSV bruto: separador ';', latin1, ler tudo como character
  raw <- data.table::fread(csv_fp, sep = ";", encoding = "Latin-1",
                           colClasses = "character", showProgress = FALSE)
  raw <- janitor::clean_names(raw)   # CAUSABAS -> causabas etc. (alinha nomes de causa)
  message(sprintf("2025 bruto: %d óbitos, %d colunas.", nrow(raw), ncol(raw)))

  hs_raw <- dplyr::filter(raw, eh_hs_sim(raw))
  message(sprintf("2025: %d óbitos com HS (bruto).", nrow(hs_raw)))

  if (nrow(hs_raw)) {
    # process_sim espera nomes em MAIÚSCULAS (layout DO bruto). Com o pacote atachado,
    # municipality_data = TRUE funciona e dá parity de schema com 2020–2024.
    hs_up <- hs_raw |> dplyr::rename_with(toupper)
    proc  <- process_sim(as.data.frame(hs_up), municipality_data = TRUE)
    proc  <- janitor::clean_names(proc)
    sim_hs_2025 <<- proc |>
      dplyr::mutate(uf_arquivo = if ("mun_res_uf" %in% names(proc)) mun_res_uf
                                 else uf_from_mun(codmunres),
                    ano = 2025L, fonte = "opendatasus_preliminar_2025")
    saveRDS(sim_hs_2025, cache_2025)   # cache p/ re-runs rápidos
    log_run("sim", "BR", 2025, "ok", n_lidas = nrow(raw), n_hs = nrow(hs_raw),
            msg = "preliminar opendatasus")
  }
  TRUE
}, error = function(e) {
  message("⚠️  Part B (2025) falhou: ", conditionMessage(e),
          "\n    → consolidando apenas 2020–2024. Reexecutar para incluir 2025.")
  log_run("sim", "BR", 2025, "erro", msg = conditionMessage(e))
  FALSE
})

# -----------------------------------------------------------------------------
# Consolidação nacional (harmoniza colunas; 2025 pode ter schema ligeiramente distinto)
# -----------------------------------------------------------------------------
sim_hs_nacional <- if (!is.null(sim_hs_2025)) {
  # alinhar tipos do 2025 (lido como character) ao schema-referência 2020–2024
  sim_hs_2025 <- casar_tipos(sim_hs_2025, sim_hs_2024)
  dplyr::bind_rows(sim_hs_2024, sim_hs_2025)    # bind_rows preenche NA p/ colunas ausentes
} else {
  sim_hs_2024
}

# Deriva idade em anos e faixa canônica (consistência num/denominador).
# 2020–2024: process_sim já decodificou (idade_decode preenchido).
# 2025 preliminar: idade veio como código bruto (idade_decode = NA) → decode_idade_sim().
if ("idade" %in% names(sim_hs_nacional)) {
  sim_hs_nacional <- sim_hs_nacional |>
    dplyr::mutate(
      idade_anos = dplyr::if_else(
        is.na(idade_decode),
        decode_idade_sim(idade),
        dplyr::case_when(
          idade_decode == "ano"  ~ as.numeric(idade),
          idade_decode == "mes"  ~ as.numeric(idade) / 12,
          idade_decode %in% c("dia","hora","minuto") ~ 0,
          TRUE ~ as.numeric(idade)
        )
      ),
      faixa = harmonizar_faixa(idade_anos)
    )
}

dir.create(here::here("data/filtered/sim_hs"), showWarnings = FALSE, recursive = TRUE)
saveRDS(sim_hs_nacional, here::here("data/filtered/sim_hs/sim_hs_nacional.rds"))
save(sim_hs_nacional, file = here::here("data/consolidated/sim_hs_nacional.RData"))

message(sprintf("\n✓ SIM consolidado: %d óbitos com HS (%s).",
                nrow(sim_hs_nacional),
                if (!is.null(sim_hs_2025)) "2020–2025" else "2020–2024"))
print(dplyr::count(sim_hs_nacional, ano, name = "obitos_hs"))
