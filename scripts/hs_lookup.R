# =============================================================================
# hs_lookup.R — Tabela de definição de caso da Hidradenite Supurativa (HS)
# A definição de caso É esta tabela (guia ref/guia_processamento_datasus.md §7;
# molde: datasus_EIM/scripts/eim_lookup.R). Mudar a tabela muda TODOS os números:
# registrar cada versão com registrar_versao_lookup() → manifest/hs_lookup_versao.csv.
#
# CONTRATO DE MATCH: prefixo casado no INÍCIO do código (sem ponto, maiúsculo, sem
#   espaços), MAIS ESPECÍFICO PRIMEIRO (ordenado por desc(nchar(prefixo))): o primeiro
#   match vale ("L732" vence "L73").
#
# CAMADAS (dominio "hs" — CID):
#   nucleo      = L73.2, inequívoco → número PRIMÁRIO
#   limitrofe   = L73.8/L73.9, folicular especificada/não especificada → possível
#                 subcodificação de HS (sensibilidade)
#   diferencial = L73.0/L73.1, outras doenças foliculares → contexto, NUNCA HS
#   envelope    = L02 (abscesso cutâneo/furúnculo/antraz) → TETO de subcodificação,
#                 NUNCA caso. No SIA vira só agregado na filtragem (volume).
# dominio "proc" — SIGTAP (10 dígitos):
#   medicamento = adalimumabe, todos os códigos com o nome no microdatasus::sigtab
#                 (conferido em 2026-10-23); vigência e instrumento em ref/sigtap_hs.csv
# dominio "comorb" — CID secundário DENTRO da AIH-HS (não entra no filtro):
#   comorbidade = datasus_hs.md §4
# =============================================================================

suppressPackageStartupMessages(library(dplyr))

HS_LOOKUP <- tibble::tribble(
  ~dominio, ~prefixo,     ~camada,        ~rotulo,                                ~obs,
  # ---- L73: afecções foliculares ---------------------------------------------
  "hs",     "L732",       "nucleo",       "Hidradenite supurativa",               "Caso-índice (captura restrita).",
  "hs",     "L738",       "limitrofe",    "Outras afecções foliculares espec.",   "Possível miscodificação de HS.",
  "hs",     "L739",       "limitrofe",    "Afecção folicular não especificada",   "Possível subcodificação de HS.",
  "hs",     "L730",       "diferencial",  "Acne queloideana",                     "Outra doença; antes somada em 'L73x'.",
  "hs",     "L731",       "diferencial",  "Pseudofoliculite da barba",            "Outra doença; antes somada em 'L73x'.",
  "hs",     "L73",        "limitrofe",    "L73 sem 4º caractere",                 "Fallback: categoria sem subcódigo.",
  # ---- L02: envelope (abscesso cutâneo, furúnculo, antraz) -------------------
  "hs",     "L020",       "envelope",     "Abscesso cutâneo — face",              "",
  "hs",     "L021",       "envelope",     "Abscesso cutâneo — pescoço",           "",
  "hs",     "L022",       "envelope",     "Abscesso cutâneo — tronco",            "Topografia sugestiva (axila/inframamária/inguinal).",
  "hs",     "L023",       "envelope",     "Abscesso cutâneo — nádega",            "Topografia sugestiva (glútea/perineal).",
  "hs",     "L024",       "envelope",     "Abscesso cutâneo — membros",           "",
  "hs",     "L028",       "envelope",     "Abscesso cutâneo — outras local.",     "",
  "hs",     "L029",       "envelope",     "Abscesso cutâneo — não especificada",  "",
  "hs",     "L02",        "envelope",     "L02 sem 4º caractere",                 "Fallback.",
  # ---- Procedimentos SIGTAP: adalimumabe (qualquer CID) ----------------------
  "proc",   "0601010019", "medicamento",  "Adalimumabe 40 mg (tratamento mensal)", "Vigência 200801–201005; L73.2 nunca compatível.",
  "proc",   "0604380011", "medicamento",  "Adalimumabe 40 mg seringa",            "Vigência 201003–; L73.2 nunca compatível.",
  "proc",   "0604380062", "medicamento",  "Adalimumabe 40 mg seringa",            "Referência. Vigência 201101–; L73.2 desde 201911 (Port. SAES 1.217/2019).",
  "proc",   "0604380097", "medicamento",  "Adalimumabe 40 mg frasco-ampola",      "Vigência 201907–; L73.2 nunca compatível.",
  "proc",   "0604380127", "medicamento",  "Adalimumabe 40 mg — biossimilar A",    "Vigência e L73.2 desde 202207 (Port. SAES 211/2022).",
  "proc",   "0604380135", "medicamento",  "Adalimumabe 40 mg — biossimilar B",    "Vigência e L73.2 desde 202209 (Port. SAES 442/2022).",
  "proc",   "0604380143", "medicamento",  "Adalimumabe 40 mg — biossimilar C",    "Vigência e L73.2 desde 202603 (Port. Conj. 40/2026); fora da série.",
  # ---- Comorbidades (CID secundário na AIH-HS) -------------------------------
  "comorb", "E66",        "comorbidade",  "Obesidade",                            "",
  "comorb", "F17",        "comorbidade",  "Tabaco",                               "",
  "comorb", "K50",        "comorbidade",  "Doença de Crohn",                      "",
  "comorb", "K51",        "comorbidade",  "Retocolite ulcerativa",                "",
  "comorb", "E11",        "comorbidade",  "Diabetes tipo 2",                      "",
  "comorb", "F32",        "comorbidade",  "Depressão",                            "",
  "comorb", "F33",        "comorbidade",  "Depressão",                            "Recorrente.",
  "comorb", "F41",        "comorbidade",  "Ansiedade",                            "",
  "comorb", "M07",        "comorbidade",  "Espondiloartrite/artrite",             "[CONFIRMAR] datasus_hs.md §4.",
  "comorb", "M45",        "comorbidade",  "Espondiloartrite/artrite",             "[CONFIRMAR] datasus_hs.md §4.",
  "comorb", "M46",        "comorbidade",  "Espondiloartrite/artrite",             "[CONFIRMAR] datasus_hs.md §4.",
  "comorb", "E78",        "comorbidade",  "Dislipidemia",                         ""
) |>
  dplyr::arrange(dominio, dplyr::desc(nchar(prefixo)), prefixo)   # MAIS ESPECÍFICO PRIMEIRO

stopifnot(!anyDuplicated(HS_LOOKUP[c("dominio", "prefixo")]))

# Prefixos usados pela filtragem dos DBC (scripts/r550/config_filtro_hs.R)
hs_prefixos <- function(dominio = "hs", camadas = NULL) {
  lk <- HS_LOOKUP[HS_LOOKUP$dominio == dominio, ]
  if (!is.null(camadas)) lk <- lk[lk$camada %in% camadas, ]
  unique(lk$prefixo)
}

#' Classifica códigos pela lookup (primeiro match, mais específico primeiro).
#' @param x vetor de CID (ou código SIGTAP); normalizado para maiúsculo, sem espaços/ponto
#' @param dominio "hs" | "proc" | "comorb"
#' @param campo coluna da lookup a devolver ("camada", "rotulo", "prefixo")
#' @return vetor do tamanho de x; NA quando nenhum prefixo casa
classificar_hs <- function(x, dominio = "hs", campo = "camada") {
  lk <- HS_LOOKUP[HS_LOOKUP$dominio == dominio, ]
  v  <- toupper(gsub("[[:space:].]", "", as.character(x)))
  out <- rep(NA_character_, length(v))
  for (i in seq_len(nrow(lk))) {                       # lk já está do mais específico ao menos
    m <- is.na(out) & !is.na(v) & startsWith(v, lk$prefixo[i])
    out[m] <- lk[[campo]][i]
  }
  out
}

hs_lookup_hash <- function() digest::digest(as.data.frame(HS_LOOKUP), algo = "sha256")

#' Acrescenta a versão atual em manifest/hs_lookup_versao.csv (só se o hash for novo).
registrar_versao_lookup <- function(arq = here::here("manifest", "hs_lookup_versao.csv")) {
  h <- hs_lookup_hash()
  ant <- if (file.exists(arq)) utils::read.csv(arq, colClasses = "character") else NULL
  if (!is.null(ant) && h %in% ant$hash) return(invisible(h))
  nova <- data.frame(data = format(Sys.Date()), hash = h, n_linhas = nrow(HS_LOOKUP),
                     n_cid_hs = sum(HS_LOOKUP$dominio == "hs"),
                     n_proc = sum(HS_LOOKUP$dominio == "proc"),
                     autor = Sys.getenv("USER"))
  utils::write.csv(rbind(ant, nova), arq, row.names = FALSE)
  invisible(h)
}
