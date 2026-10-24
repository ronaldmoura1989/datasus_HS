# =============================================================================
# qmd/_numeros.R — Números citados no TEXTO do site, com nomes estáveis.
# Todo número do texto sai daqui ou de E$tot por R inline (guia §12: frases como
# "+9%/ano" ou "~250×" ficaram erradas quando a série mudou). Molde: EIM _discussao_numeros.R.
# Uso nos .qmd: `r fmt_n(TOT$sih_aih_principal)`, `r tend_txt("sia_clinico")`, `r its_txt(...)`.
# =============================================================================

TOT <- E$tot
SA  <- E$serie_ano
val <- function(df, col, ano_) df[[col]][df$ano == ano_]

# Série ambulatorial
N_CLIN_14 <- val(SA, "sia_clinico_qtd", 2014); N_CLIN_25 <- val(SA, "sia_clinico_qtd", 2025)
TRAT_PRIMEIRO_ANO <- min(SA$ano[SA$sia_trat_pacientes > 0])
TRAT_25 <- val(SA, "sia_trat_pacientes", 2025)
COB_10 <- val(E$cobertura_cid, "pct_com_cid", 2010); COB_25 <- val(E$cobertura_cid, "pct_com_cid", 2025)
DP <- E$derm_producao
L732_DERM_14 <- val(DP, "l732_por_mil_bpai_derm", 2014); L732_DERM_25 <- val(DP, "l732_por_mil_bpai_derm", 2025)
BPAI_DERM_14 <- val(DP, "pct_bpai_derm", 2014); BPAI_DERM_25 <- val(DP, "pct_bpai_derm", 2025)

# Tendências (variação anual %, IC 95%) — tabela gerada por taxas_tendencias_hs.R
tend <- function(serie_, excluiu_covid = FALSE, ate_2019 = FALSE) {
  t <- dplyr::filter(E$tendencias, serie == serie_, excluiu_covid == !!excluiu_covid)
  t <- if (ate_2019) dplyr::filter(t, grepl("2019$", anos)) else dplyr::filter(t, !grepl("2019$", anos))
  t[1, ]
}
tend_txt <- function(serie_, ...) { t <- tend(serie_, ...)
  paste0(fmt_ic(t$var_anual_pct, t$ic_inf, t$ic_sup, 1, "%"), " ao ano (", t$anos, ")") }

# Série interrompida
its_row <- function(serie_, cenario_ = "primaria", efeito_ = "nível")
  dplyr::filter(E$its, serie == serie_, cenario == cenario_, startsWith(efeito, efeito_))[1, ]
its_txt <- function(serie_, cenario_ = "primaria", efeito_ = "nível") {
  r <- its_row(serie_, cenario_, efeito_)
  if (startsWith(efeito_, "nível")) fmt_ic(r$estimativa, r$ic_inf, r$ic_sup, 2)
  else fmt_ic(r$estimativa, r$ic_inf, r$ic_sup, 1, "%")
}
ITS_NIVEL_CLIN_IC_CRUZA_1 <- with(dplyr::filter(E$its, serie == "sia_clinico", startsWith(efeito, "nível")),
                                  any(ic_inf <= 1 & ic_sup >= 1))

# Pseudo-pacientes (intervalo frouxa–estrita; central = intermediária)
pseudo <- function(janela_, recorte_) dplyr::filter(E$pseudo, janela == janela_, recorte == recorte_)[1, ]
pseudo_txt <- function(janela_, recorte_) { p <- pseudo(janela_, recorte_)
  paste0(fmt_n(p$pseudo_frouxa), "–", fmt_n(p$pseudo_estrita)) }

# Oferta de dermatologistas
DERM_BR <- E$derm_uf |> dplyr::group_by(ano) |>
  dplyr::summarise(derm = sum(n_dermatologistas), pop = sum(pop), .groups = "drop") |>
  dplyr::mutate(por_100k = 1e5 * derm / pop)
DERM_10 <- val(DERM_BR, "por_100k", 2010); DERM_25 <- val(DERM_BR, "por_100k", 2025)
DERM_UF_25 <- dplyr::filter(E$derm_uf, ano == 2025) |> dplyr::arrange(dplyr::desc(derm_por_100k))
DERM_RAZAO_25 <- max(DERM_UF_25$derm_por_100k) / min(DERM_UF_25$derm_por_100k)
UFC <- E$uf_clinico_2014
R_DERM <- stats::cor(UFC$derm_100k, UFC$taxa_pad, use = "complete.obs")
RHO_DERM <- stats::cor(UFC$derm_100k, UFC$taxa_pad, use = "complete.obs", method = "spearman")

# Adalimumabe: biossimilares e parte das APAC que é HS
LABS_ADA <- c("0604380062" = "Referência", "0604380127" = "Biossimilar A", "0604380135" = "Biossimilar B")
BIO <- E$biossimilar_uf |> dplyr::group_by(ano, pa_proc_id) |>
  dplyr::summarise(n = sum(n, na.rm = TRUE), .groups = "drop") |>
  dplyr::group_by(ano) |> dplyr::mutate(pct = 100 * n / sum(n)) |> dplyr::ungroup()
PCT_REF <- function(ano_) BIO$pct[BIO$ano == ano_ & BIO$pa_proc_id == "0604380062"] %||% 0
ADA_L732_25 <- E$adalimumabe_todos_cid |> dplyr::filter(ano == 2025) |>
  dplyr::summarise(p = 100 * sum(linhas[l732], na.rm = TRUE) / sum(linhas, na.rm = TRUE)) |> dplyr::pull(p)

# SIH
SIH_SEC_MIN <- min(E$sih_sec$pct_com_secundario, na.rm = TRUE)
SIH_SEC_MAX <- max(E$sih_sec$pct_com_secundario, na.rm = TRUE)
SIH_GASTO_REAL <- E$sih_custo |> dplyr::left_join(IPCA, by = "ano") |>
  dplyr::summarise(g = sum(gasto_nominal * fator_para_base, na.rm = TRUE)) |> dplyr::pull(g)

# UFs nos extremos da taxa clínica padronizada (2014–2025), para o texto
.uf_ord <- dplyr::filter(UFC, !is.na(taxa_pad)) |> dplyr::arrange(dplyr::desc(taxa_pad))
.lista <- function(x) paste0(paste(head(x, -1), collapse = ", "), " e ", tail(x, 1))
TOP_UF_CLIN <- .lista(head(.uf_ord$uf, 5))
BOT_UF_CLIN <- .lista(rev(tail(.uf_ord$uf, 5)))

# Faixa da inclinação pós-marco do canal clínico entre todos os cenários da ITS
.pos <- dplyr::filter(E$its, startsWith(serie, "sia_clinico"), startsWith(efeito, "tendência depois"))
.pre <- dplyr::filter(E$its, startsWith(serie, "sia_clinico"), startsWith(efeito, "tendência antes"))
ITS_POS_FAIXA <- paste0(fmt_1(min(.pos$estimativa)), "% a ", fmt_1(max(.pos$estimativa)), "%")
ITS_PRE_FAIXA <- paste0(fmt_1(min(.pre$estimativa)), "% a ", fmt_1(max(.pre$estimativa)), "%")
