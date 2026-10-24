# =============================================================================
# validar_piloto_hs.R — Critério de aceite da E3 (plano_expansao_2010.md)
# Compara os filtrados HS 2010+ (DBC do R550-2) com a v1 (brutos pré-filtrados),
# por MÊS DE PROCESSAMENTO (arquivo), não por PA_CMP:
#   SIA PE 2021: linhas e Σ PA_QTDAPR por PA_MVM + anti_join por chave nos dois sentidos
#   SIH PE e SP 2021: AIH distintas com DIAG_PRINC L732 por mês
#   SIM 2020–2025: óbitos com L732 em qualquer campo e na causa básica, por ano
# Entradas da v1 em ~/Documentos/ronald/datasus_HS/v1_ref/ (exportadas do repo local).
# Rodar NO R550-2: Rscript validar_piloto_hs.R [--out=~/Documentos/ronald/datasus_filtrado_hs]
# =============================================================================
suppressPackageStartupMessages({ library(dplyr); library(arrow) })

args <- commandArgs(trailingOnly = TRUE)
OUT  <- path.expand(sub("^--out=", "", c(grep("^--out=", args, value = TRUE), "~/Documentos/ronald/datasus_filtrado_hs")[1]))
V1   <- path.expand("~/Documentos/ronald/datasus_HS/v1_ref")
ler  <- function(base, padrao) {
  fs <- list.files(file.path(OUT, base, "filtrado"), pattern = padrao, full.names = TRUE)
  bind_rows(lapply(fs, read_parquet))
}
eh_l732 <- function(v) !is.na(v) & startsWith(toupper(trimws(v)), "L732")
falhas <- character()
checar <- function(nome, ok) { cat(sprintf("[%s] %s\n", if (ok) "OK  " else "FALHA", nome)); if (!ok) falhas <<- c(falhas, nome) }

# -----------------------------------------------------------------------------
# SIA PE 2021
# -----------------------------------------------------------------------------
v2_sia <- ler("SIA-PA", "^PAPE21") |> filter(eh_l732(PA_CIDPRI))
v1_sia <- read_parquet(file.path(V1, "v1_sia_pe2021.parquet"))
por_mvm <- full_join(
  v1_sia |> group_by(mvm = pa_mvm) |> summarise(v1_linhas = n(), v1_qtd = sum(as.numeric(pa_qtdapr))),
  v2_sia |> group_by(mvm = PA_MVM) |> summarise(v2_linhas = n(), v2_qtd = sum(as.numeric(PA_QTDAPR))),
  by = "mvm") |> arrange(mvm)
print(as.data.frame(por_mvm))
checar("SIA PE 2021: linhas e Σqtd por PA_MVM idênticos",
       isTRUE(all(por_mvm$v1_linhas == por_mvm$v2_linhas & por_mvm$v1_qtd == por_mvm$v2_qtd)))

chave <- c("coduni", "cmp", "proc_id", "autoriz", "idade", "sexo", "qtdapr")
k1 <- v1_sia |> transmute(coduni = pa_coduni, cmp = pa_cmp, proc_id = pa_proc_id, autoriz = pa_autoriz,
                          idade = as.character(as.integer(pa_idade)), sexo = pa_sexo,
                          qtdapr = as.character(as.numeric(pa_qtdapr)))
k2 <- v2_sia |> transmute(coduni = PA_CODUNI, cmp = PA_CMP, proc_id = PA_PROC_ID, autoriz = PA_AUTORIZ,
                          idade = as.character(as.integer(PA_IDADE)), sexo = PA_SEXO,
                          qtdapr = as.character(as.numeric(PA_QTDAPR)))
so_v1 <- anti_join(k1, k2, by = chave); so_v2 <- anti_join(k2, k1, by = chave)
cat(sprintf("  anti_join: só na v1 = %d | só na v2 = %d\n", nrow(so_v1), nrow(so_v2)))
if (nrow(so_v1)) print(head(as.data.frame(so_v1))); if (nrow(so_v2)) print(head(as.data.frame(so_v2)))
checar("SIA PE 2021: anti_join vazio nos dois sentidos", nrow(so_v1) == 0 && nrow(so_v2) == 0)

# -----------------------------------------------------------------------------
# SIH PE e SP 2021
# -----------------------------------------------------------------------------
v2_sih <- ler("SIH-RD", "^RD(PE|SP)21") |> filter(eh_l732(DIAG_PRINC))
v1_sih <- read_parquet(file.path(V1, "v1_sih_pesp2021.parquet"))
sih <- full_join(
  v1_sih |> group_by(uf = toupper(uf_arquivo), mes = as.integer(mes_cmpt)) |> summarise(v1_aih = n_distinct(n_aih), .groups = "drop"),
  v2_sih |> group_by(uf = arq_uf, mes = as.integer(arq_mes)) |> summarise(v2_aih = n_distinct(N_AIH), .groups = "drop"),
  by = c("uf", "mes")) |> mutate(across(c(v1_aih, v2_aih), ~ coalesce(.x, 0L))) |> arrange(uf, mes)
print(as.data.frame(sih |> group_by(uf) |> summarise(v1_aih = sum(v1_aih), v2_aih = sum(v2_aih))))
checar("SIH PE+SP 2021: AIH distintas por mês idênticas", all(sih$v1_aih == sih$v2_aih))
cat(sprintf("  SIH L732 em qualquer campo (não recuperável na v1): %d AIH vs %d no principal\n",
            n_distinct(ler("SIH-RD", "^RD(PE|SP)21") |>
                         filter(if_any(any_of(c("DIAG_PRINC", "DIAG_SECUN", paste0("DIAGSEC", 1:9))), eh_l732)) |>
                         pull(N_AIH)),
            n_distinct(v2_sih$N_AIH)))

# -----------------------------------------------------------------------------
# SIM 2020–2025
# -----------------------------------------------------------------------------
v2_sim <- ler("SIM-DO", "^DO") |>
  mutate(ano = substr(DTOBITO, 5, 8),
         qualquer = if_any(any_of(c("CAUSABAS", "CAUSABAS_O", "LINHAA", "LINHAB", "LINHAC", "LINHAD", "LINHAII")),
                           ~ grepl("(^|\\*)L732", coalesce(.x, ""))),
         cb = eh_l732(CAUSABAS))
v1_ref <- read.csv(file.path(V1, "v1_contagens_referencia.csv"), colClasses = "character") |>
  filter(base == "SIM") |> transmute(ano = periodo, v1_qualquer = as.integer(valor), v1_cb = as.integer(valor2))
sim <- v2_sim |> filter(ano >= "2010") |> group_by(ano, status_dado) |>
  summarise(v2_qualquer = sum(qualquer), v2_cb = sum(cb), .groups = "drop") |>
  left_join(v1_ref, by = "ano")
print(as.data.frame(sim))
s_comp <- filter(sim, ano %in% v1_ref$ano)
checar("SIM 2020–2025: v2 ≥ v1 em qualquer campo (regex de causas múltiplas)",
       all(s_comp$v2_qualquer >= s_comp$v1_qualquer))

cat("\n", if (length(falhas)) paste("FALHAS:", paste(falhas, collapse = "; ")) else "PILOTO APROVADO", "\n")
