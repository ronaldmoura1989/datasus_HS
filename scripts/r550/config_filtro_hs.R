# =============================================================================
# config_filtro_hs.R — Escopos da filtragem HS dos DBC 2010+ (R550-2)
# Adaptado de datasus_EIM/scripts/r550/config_filtro.R. Os prefixos vêm de
# hs_lookup.R (nunca copiados à mão); a camada é decidida na consolidação.
#
#   hit_hs      ← L73 (núcleo L732, limítrofe L738/L739, diferencial L730/L731)
#   hit_hs_env  ← L02 (envelope). SIA: NÃO grava linhas, vira agregado na leitura
#                 (agregado_env/); SIH e SIM: grava linhas.
#   hit_hs_proc ← adalimumabe (todos os códigos SIGTAP), em QUALQUER CID
# Colunas por base: as mesmas do EIM (CIDs principal, secundários, causas múltiplas).
# =============================================================================

.dir_cfg <- local({
  a <- commandArgs(trailingOnly = FALSE); f <- sub("^--file=", "", grep("^--file=", a, value = TRUE))
  if (length(f)) dirname(normalizePath(f[1])) else getwd()
})
if (!exists("HS_LOOKUP")) {
  lk <- c(file.path(.dir_cfg, "hs_lookup.R"), file.path(.dir_cfg, "..", "hs_lookup.R"))
  source(lk[file.exists(lk)][1])
}

ESCOPO_CID <- list(
  hs     = grep("^L73", hs_prefixos("hs"), value = TRUE),
  hs_env = grep("^L02", hs_prefixos("hs"), value = TRUE)
)
ESCOPO_PROC <- list(hs_proc = hs_prefixos("proc"))

# Escopos cujas linhas NÃO são gravadas, por base (viram agregado)
ESCOPO_SO_AGREGADO <- list("SIA-PA" = "hs_env")

# CBO de dermatologista (mesmo vetor de scripts/get_dermatologistas_cnes.R)
CBO_DERM <- c("223117", "225135")

COLS_CID <- list(
  "SIA-PA" = c("PA_CIDPRI", "PA_CIDSEC", "PA_CIDCAS"),
  "SIH-RD" = c("DIAG_PRINC", "DIAG_SECUN", paste0("DIAGSEC", 1:9), "CID_ASSO", "CID_MORTE"),
  "SIM-DO" = c("CAUSABAS", "CAUSABAS_O"))
# SIM: causas múltiplas concatenadas com "*" ("*A419*J960") → casar em qualquer posição
COLS_CID_MULTI <- list("SIM-DO" = c("LINHAA", "LINHAB", "LINHAC", "LINHAD", "LINHAII"))
COLS_PROC <- list("SIA-PA" = "PA_PROC_ID", "SIH-RD" = c("PROC_REA", "PROC_SOLIC"),
                  "SIM-DO" = character())

regex_multi <- function(prefs, base) paste0("(^|\\*)(", paste(sort(unique(prefs)), collapse = "|"), ")")
