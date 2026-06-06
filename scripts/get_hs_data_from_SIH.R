# =============================================================================
# get_hs_data_from_SIH.R — Consolidação do SIH-RD (HS, L732)
# Brutos já filtrados por DIAG_PRINC == L732 (objeto x_hs, MAIÚSCULAS),
# em data/raw/SIH/sih_{uf}_{ano}_{tri}_hs.RData (648 arquivos; 452 vazios; 632 AIH-HS).
# Layout: 113 cols (2020–24) / 114 (2025, +FONTE_ORC). Só sabor "diagnóstico
# principal" disponível (datasus_hs.md §2). Comorbidades nos secundários (§4).
# Saídas: data/parquet/sih_hs/ (ano+uf) e data/consolidated/sih_hs_nacional.RData
# Rodar: Rscript scripts/get_hs_data_from_SIH.R
# =============================================================================

source(here::here("scripts", "00_setup.R"))

DIR_SIH <- here::here("data/raw/SIH")
PAT <- "^sih_([a-z]{2})_(\\d{4})_(\\d)_hs\\.RData$"

# Comorbidades de interesse (datasus_hs.md §4) — prefixos CID-10 (3 chars)
COMORB <- list(
  obesidade    = "E66", tabaco     = "F17", crohn      = "K50", rcu = "K51",
  dm2          = "E11", depressao  = c("F32","F33"), ansiedade = "F41",
  espondiloartrite = c("M07","M45","M46"), dislipidemia = "E78",
  abscesso_l02 = "L02"   # abscesso como secundário (contexto HS)
)

carregar_obj <- function(fp, obj = "x_hs") {
  e <- new.env(); nm <- load(fp, envir = e)
  get(if (obj %in% nm) obj else nm[1], envir = e)
}

# -----------------------------------------------------------------------------
# 1. Carregar + limpar + tipar arquivo a arquivo (descarta vazios)
# -----------------------------------------------------------------------------
message("== SIH: carregando e consolidando ==")
arqs <- list.files(DIR_SIH, pattern = PAT, full.names = TRUE)

ler_sih <- function(fp) {
  meta <- stringr::str_match(basename(fp), PAT)
  uf <- toupper(meta[2]); ano <- as.integer(meta[3]); tri <- as.integer(meta[4])
  x <- carregar_obj(fp) |> janitor::clean_names()
  log_run("sih", uf, sprintf("%d_T%d", ano, tri),
          "ok", n_lidas = nrow(x), n_hs = nrow(x))
  if (!nrow(x)) return(NULL)
  x |> dplyr::mutate(uf_arquivo = uf, ano = ano, trimestre = tri)
}

lst <- purrr::map(arqs, ler_sih) |> purrr::compact()
ref <- lst[[which.max(purrr::map_int(lst, ncol))]]      # ref com mais colunas (2025, +FONTE_ORC)
lst <- purrr::map(lst, ~ casar_tipos(.x, ref))
sih <- dplyr::bind_rows(lst)                            # union de colunas; NA p/ FONTE_ORC pré-2025
rm(lst); gc(verbose = FALSE)
message(sprintf("SIH consolidado bruto: %d AIH-registros, %d colunas.", nrow(sih), ncol(sih)))

# -----------------------------------------------------------------------------
# 2. Coerção de tipos + enriquecimento
# -----------------------------------------------------------------------------
cols_sec <- intersect(c("diag_secun", paste0("diagsec", 1:9)), names(sih))  # só secundários

sih <- sih |>
  coagir_tipos(monetarias = c("val_tot","val_sh","val_sp","val_uti","val_sadt"),
               datas = c("dt_inter","dt_saida","nasc")) |>
  dplyr::mutate(
    camada     = camada_cid(diag_princ),                 # esperado: tudo "L732"
    cid_ok     = cid_valido(diag_princ),
    sexo       = dplyr::recode(stringr::str_trim(as.character(sexo)),
                               "1"="Masculino","3"="Feminino","2"="Feminino",
                               .default = NA_character_),
    raca_cor   = dplyr::recode(stringr::str_pad(stringr::str_trim(as.character(raca_cor)),2,pad="0"),
                               "01"="Branca","02"="Preta","03"="Parda","04"="Amarela",
                               "05"="Indígena", .default = NA_character_),  # 99 -> NA
    idade_anos = as.integer(round(idade_em_anos(idade, cod_idade))),
    idade_anos = dplyr::if_else(idade_anos >= 0 & idade_anos <= 110, idade_anos, NA_integer_),
    faixa      = harmonizar_faixa(idade_anos),
    uf_zi_sigla = uf_from_mun(uf_zi),                    # UF do estabelecimento (zona)
    uf_res     = uf_from_mun(munic_res),                 # UF de residência do paciente
    carater    = dplyr::recode(stringr::str_pad(stringr::str_trim(as.character(car_int)),2,pad="0"),
                               "01"="Eletivo","02"="Urgência", .default = NA_character_),
    obito_aih  = suppressWarnings(as.integer(morte)),    # 1 = óbito na internação
    aih_continuacao = stringr::str_trim(as.character(ident)) == "5",  # AIH de continuação
    competencia = lubridate::make_date(as.integer(ano_cmpt),
                                       suppressWarnings(as.integer(mes_cmpt)), 1L),
    fonte      = "datasus_sih_rd"
  )

# Matriz binária de comorbidades nos campos SECUNDÁRIOS (não no principal = L732)
sih <- sih |>
  dplyr::bind_cols(
    purrr::imap_dfc(COMORB, function(prefs, nome) {
      hit <- purrr::reduce(
        purrr::map(cols_sec, ~ substr(as.character(sih[[.x]]), 1, 3) %in% prefs),
        `|`)
      tibble::tibble(!!paste0("com_", nome) := hit)
    })
  )

# -----------------------------------------------------------------------------
# 3. QC
# -----------------------------------------------------------------------------
cat("\n• camada de CID (esperado só L732):\n"); print(janitor::tabyl(sih, camada))
cat("• AIH-registros por ano:\n"); print(dplyr::count(sih, ano, name = "registros"))
cat(sprintf("• AIH distintas (n_aih): %d | de continuação (ident=5): %d\n",
            dplyr::n_distinct(sih$n_aih), sum(sih$aih_continuacao, na.rm = TRUE)))
cat(sprintf("• permanência mediana: %.0f dias | óbitos na internação: %d | urgência: %d / eletivo: %d\n",
            stats::median(sih$dias_perm, na.rm = TRUE), sum(sih$obito_aih, na.rm = TRUE),
            sum(sih$carater == "Urgência", na.rm = TRUE), sum(sih$carater == "Eletivo", na.rm = TRUE)))
cat("• prevalência de comorbidades (nos secundários, % das AIH-HS):\n")
print(sih |> dplyr::summarise(dplyr::across(dplyr::starts_with("com_"), ~ round(100*mean(.x),1))) |>
        tidyr::pivot_longer(dplyr::everything(), names_to="comorbidade", values_to="pct") |>
        dplyr::arrange(dplyr::desc(pct)))

# -----------------------------------------------------------------------------
# 4. Persistir
# -----------------------------------------------------------------------------
dir.create(here::here("data/parquet/sih_hs"), showWarnings = FALSE, recursive = TRUE)
sih |>
  dplyr::mutate(uf = uf_arquivo) |>
  arrow::write_dataset(path = here::here("data/parquet/sih_hs"),
                       partitioning = c("ano","uf"), format = "parquet")

sih_hs_nacional <- sih
save(sih_hs_nacional, file = here::here("data/consolidated/sih_hs_nacional.RData"))
saveRDS(sih_hs_nacional, here::here("data/filtered/sih_hs/sih_hs_nacional.rds"))

message(sprintf("\n✓ SIH consolidado: %d AIH-registros (%d AIH distintas), 2020–2025 → Parquet ano+uf.",
                nrow(sih), dplyr::n_distinct(sih$n_aih)))
