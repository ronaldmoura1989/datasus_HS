# =============================================================================
# utils.R — Funções utilitárias do pipeline DATASUS HS
# Carregado por 00_setup.R. Depende de tidyverse/stringr/janitor já anexados.
# Convenções e contratos: ver CLAUDE.md §5 e datasus_hs.md.
# =============================================================================

# -----------------------------------------------------------------------------
# 1. Detecção / classificação de CID
# -----------------------------------------------------------------------------

#' Rotula a CAMADA de captura de um código CID (passada única — datasus_hs.md §2).
#'
#' Substitui o antigo detectar_cid() booleano: gera as 3 camadas de uma vez.
#' ⚠️ Não existem subcódigos oficiais L7320/L7321 — L73.2 tem 4 caracteres.
#' Normaliza para 4 chars e compara por igualdade (evita regex aberta).
#'
#' @return "L732" | "L73x" | "L02x" | NA_character_
#'   Restrito  → camada == "L732"
#'   Ampliado  → camada %in% c("L732","L73x","L02x"), reportadas em camadas separadas
camada_cid <- function(campo) {
  x <- stringr::str_sub(stringr::str_trim(toupper(as.character(campo))), 1, 4)
  dplyr::case_when(
    x == "L732"                    ~ "L732",   # caso-índice (restrito)
    stringr::str_detect(x, "^L73") ~ "L73x",   # demais foliculares
    stringr::str_detect(x, "^L02") ~ "L02x",   # ENVELOPE de subcodificação (teto, não caso)
    TRUE                           ~ NA_character_
  )
}

#' Conveniência: vetor lógico de "é HS no modo escolhido".
#' @param modo "restrito" (só L732) | "ampliado" (L732 + L73x + L02x)
eh_hs <- function(campo, modo = MODO_CAPTURA) {
  cam <- camada_cid(campo)
  if (modo == "restrito")      !is.na(cam) & cam == "L732"
  else if (modo == "ampliado") !is.na(cam)
  else stop("modo inválido: use 'restrito' ou 'ampliado'")
}

#' CID sintaticamente válido (1 letra + >=2 dígitos). Marca malformados ANTES de
#' filtrar, para virar indicador de qualidade (datasus_hs.md §6.8) e não sumir em silêncio.
cid_valido <- function(campo) {
  stringr::str_detect(stringr::str_trim(toupper(as.character(campo))), "^[A-Z][0-9]{2}")
}

#' Normaliza uma célula de CID do SIM (causabas/linhas), que pode conter VÁRIOS
#' códigos e marcadores dagger/asterisco. Aplicar APÓS corrigir encoding.
#' @return lista de vetores de códigos por elemento de `x`
normalizar_cid_sim <- function(x) {
  x |>
    toupper() |>
    stringr::str_remove_all("[†*]") |>          # daga (†) e asterisco da notação CID
    stringr::str_extract_all("[A-Z][0-9]{2,3}")      # lista de códigos por célula
}

#' Detecta HS (L732) em qualquer um dos campos de causa do SIM.
#' @param ... vetores das colunas (causabas, linhaa..linhad, linhaii)
detecta_hs_sim <- function(...) {
  cols <- list(...)
  cods_por_linha <- purrr::pmap(cols, function(...) {
    unlist(purrr::map(list(...), ~ unlist(normalizar_cid_sim(.x))))
  })
  purrr::map_lgl(cods_por_linha, ~ any(stringr::str_sub(.x, 1, 4) == "L732"))
}

#' Detecta dinamicamente as colunas de diagnóstico do SIH (varia entre anos).
#' Usa any_of a jusante (nem todo ano tem os 9 diagsec).
detectar_cols_diag <- function(df) {
  cols <- names(df) |> stringr::str_subset("^diag(_?princ|sec)")
  union("diag_princ", cols) |> intersect(names(df))
}

# -----------------------------------------------------------------------------
# 2. Encoding e tipos (DATASUS é ISO-8859-1 / latin1)
# -----------------------------------------------------------------------------

#' Corrige encoding latin1 -> UTF-8 em todas as colunas de texto.
#' Confirmar se o process_*() da versão instalada já trata — não reconverter (CLAUDE.md §5).
corrigir_encoding <- function(df) {
  dplyr::mutate(df, dplyr::across(where(is.character),
                                  ~ iconv(.x, from = "latin1", to = "UTF-8")))
}

#' Coage tipos logo após clean_names(). Colunas variam por base → parametrizar.
#' @param monetarias chr: colunas a virar double via parse_number
#' @param datas      chr: colunas AAAAMMDD a virar Date via ymd
coagir_tipos <- function(df, monetarias = character(), datas = character()) {
  monetarias <- intersect(monetarias, names(df))
  datas      <- intersect(datas, names(df))
  df |>
    dplyr::mutate(dplyr::across(dplyr::all_of(monetarias),
                                ~ readr::parse_number(as.character(.x)))) |>
    dplyr::mutate(dplyr::across(dplyr::all_of(datas),
                                ~ lubridate::ymd(.x, quiet = TRUE)))
}

# -----------------------------------------------------------------------------
# 3. Idade e faixas etárias (numerador ↔ denominador na MESMA grade)
# -----------------------------------------------------------------------------

#' Converte idade para ANOS respeitando a unidade.
#' SIH-RD: `idade` + `cod_idade` (unidade). SIA-PA: `pa_idade` já costuma vir em anos.
#' ⚠️ [VERIFICAR] mapeamento de cod_idade na versão do layout/microdatasus usado:
#'    convenção comum SIH → 2=dias, 3=meses, 4=anos (confirmar no dicionário/competência).
#' Se o process_*() já entregar idade em anos, usar a coluna diretamente.
idade_em_anos <- function(idade, cod_idade = NULL) {
  idade <- suppressWarnings(as.numeric(idade))
  if (is.null(cod_idade)) return(idade)            # SIA: já em anos
  cod <- as.character(cod_idade)
  dplyr::case_when(
    cod == "4" ~ idade,                            # anos
    cod == "3" ~ idade / 12,                       # meses
    cod == "2" ~ idade / 365.25,                   # dias
    TRUE       ~ idade                             # [VERIFICAR] demais códigos
  )
}

#' Decodifica o campo IDADE bruto do SIM (3 dígitos: 1º = unidade, 2º-3º = valor)
#' para ANOS. Unidades: 0=min, 1=hora, 2=dia, 3=mês, 4=anos(<100), 5=anos(100+).
#' Usar quando o process_sim não decodificou (ex.: prévia 2025 do opendatasus).
decode_idade_sim <- function(idade_cod) {
  s <- stringr::str_pad(as.character(idade_cod), 3, pad = "0")
  u <- stringr::str_sub(s, 1, 1)
  v <- suppressWarnings(as.numeric(stringr::str_sub(s, 2, 3)))
  dplyr::case_when(
    u == "5" ~ 100 + v,          # anos, 100 e mais
    u == "4" ~ v,                # anos
    u == "3" ~ v / 12,           # meses
    u == "2" ~ v / 365.25,       # dias
    u %in% c("0","1") ~ 0,       # minutos/horas (recém-nascido)
    TRUE ~ NA_real_
  )
}

#' Aplica a grade canônica FAIXAS_BR a uma idade em anos. MESMA função no
#' numerador (paciente) e no denominador (IBGE) — pré-requisito da padronização.
harmonizar_faixa <- function(idade_anos, breaks = FAIXAS_BR) {
  lb <- head(breaks, -1); ub <- breaks[-1]
  labs <- ifelse(is.infinite(ub), paste0(lb, "+"), paste0(lb, "-", ub - 1))
  cut(idade_anos, breaks = breaks, right = FALSE, labels = labs, include.lowest = TRUE)
}

# -----------------------------------------------------------------------------
# 4. Geografia (UF a partir do código de município IBGE)
# -----------------------------------------------------------------------------

# Tabela código IBGE (2 díg.) -> sigla UF
.UF_COD <- tibble::tribble(
  ~cod, ~uf,
  "11","RO","12","AC","13","AM","14","RR","15","PA","16","AP","17","TO",
  "21","MA","22","PI","23","CE","24","RN","25","PB","26","PE","27","AL","28","SE","29","BA",
  "31","MG","32","ES","33","RJ","35","SP",
  "41","PR","42","SC","43","RS",
  "50","MS","51","MT","52","GO","53","DF"
)

#' Extrai a sigla da UF dos 2 primeiros dígitos de um código de município (6 ou 7 díg.).
#' Decidir residência vs atendimento conforme o eixo (CLAUDE.md §5).
uf_from_mun <- function(cod_mun) {
  cod2 <- stringr::str_sub(as.character(cod_mun), 1, 2)
  .UF_COD$uf[match(cod2, .UF_COD$cod)]
}

#' Mapeia UF -> macrorregião.
mapear_uf_regiao <- function(uf) {
  regioes <- list(
    Norte        = c("RO","AC","AM","RR","PA","AP","TO"),
    Nordeste     = c("MA","PI","CE","RN","PB","PE","AL","SE","BA"),
    Sudeste      = c("MG","ES","RJ","SP"),
    Sul          = c("PR","SC","RS"),
    `Centro-Oeste` = c("MS","MT","GO","DF")
  )
  reg <- rep(NA_character_, length(uf))
  for (nm in names(regioes)) reg[uf %in% regioes[[nm]]] <- nm
  reg
}

# -----------------------------------------------------------------------------
# 5. Logging e validação de grade
# -----------------------------------------------------------------------------

#' Anexa uma linha ao log de execução (schema fixo p/ auditoria — CLAUDE.md §4).
#' @param base "sia"|"sih"|"sim"
#' @param status "ok"|"skip"|"erro"
log_run <- function(base, uf, competencia, status,
                    n_lidas = NA_integer_, n_hs = NA_integer_, msg = "") {
  fp <- here::here("logs", paste0("run_log_", base, ".csv"))
  linha <- tibble::tibble(
    ts = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    base = base, uf = uf, competencia = as.character(competencia),
    status = status, n_lidas = n_lidas, n_hs = n_hs, msg = msg
  )
  readr::write_csv(linha, fp, append = file.exists(fp))
  invisible(linha)
}

#' Valida a grade de brutos presentes vs esperada.
#' @param base "sia"|"sih" (mensal: UF×ano×mês) ou "sim" (anual: UF×ano)
#' @param dir  diretório dos brutos
#' @param pattern_fun função(uf, ano, mes) -> nome de arquivo esperado
#' @param stop_se_faltar se TRUE, para o pipeline quando há faltantes
#' @return tibble de competências esperadas × presença, com atributo n_faltantes
validar_grade_completa <- function(base, dir, pattern_fun,
                                   anos = ANOS, ufs = UFS, meses = MESES,
                                   stop_se_faltar = TRUE) {
  grade <- if (base %in% c("sia","sih")) {
    tidyr::expand_grid(uf = ufs, ano = anos, mes = meses)
  } else {                                  # sim: anual
    tidyr::expand_grid(uf = ufs, ano = anos, mes = NA_integer_)
  }
  grade <- grade |>
    dplyr::mutate(
      arquivo = purrr::pmap_chr(list(uf, ano, mes), pattern_fun),
      caminho = file.path(dir, arquivo),
      tamanho = file.info(caminho)$size,
      # presença robusta: arquivo existe E tem tamanho > 0 (descarta truncados)
      presente = !is.na(tamanho) & tamanho > 0
    )
  n_faltantes <- sum(!grade$presente)
  attr(grade, "n_faltantes") <- n_faltantes
  message(sprintf("[%s] grade: %d esperados, %d presentes, %d faltantes.",
                  toupper(base), nrow(grade), sum(grade$presente), n_faltantes))
  if (stop_se_faltar && n_faltantes > 0)
    stop(sprintf("validar_grade_completa(%s): %d competências faltantes — rodar download ou reconciliar nomes (CLAUDE.md §7).",
                 base, n_faltantes))
  grade
}

# -----------------------------------------------------------------------------
# 6. QC básico
# -----------------------------------------------------------------------------

#' Resumo rápido de qualidade: nº de linhas, completude por coluna-chave,
#' proporção de CID válido. Para painel de indicadores (datasus_hs.md §6.8).
#' @param cols_cid colunas de CID a checar validade
qc_basico <- function(df, cols_cid = character()) {
  cols_cid <- intersect(cols_cid, names(df))
  compl <- df |>
    dplyr::summarise(dplyr::across(dplyr::everything(),
                                   ~ mean(!is.na(.x) & .x != ""))) |>
    tidyr::pivot_longer(dplyr::everything(),
                        names_to = "coluna", values_to = "completude")
  cid_ok <- if (length(cols_cid)) {
    df |>
      dplyr::summarise(dplyr::across(dplyr::all_of(cols_cid),
                                     ~ mean(cid_valido(.x), na.rm = TRUE))) |>
      tidyr::pivot_longer(dplyr::everything(),
                          names_to = "coluna", values_to = "prop_cid_valido")
  } else tibble::tibble(coluna = character(), prop_cid_valido = double())
  list(n_linhas = nrow(df), completude = compl, cid_valido = cid_ok)
}

#' Supressão LGPD: oculta contagens de células pequenas na divulgação.
suprimir_pequenas <- function(df, col_n, limiar = N_SUPRESSAO) {
  df |> dplyr::mutate("{{col_n}}" := ifelse({{ col_n }} < limiar, NA_integer_, {{ col_n }}))
}

#' Coage as colunas comuns de `df` para a classe das colunas homônimas em `ref`,
#' tornando dois data.frames empilháveis por bind_rows (ex.: 2025 lido como
#' character vs anos anteriores já tipados). Coerções que falharem são mantidas.
casar_tipos <- function(df, ref) {
  comuns <- intersect(names(df), names(ref))
  for (cn in comuns) {
    cls_ref <- class(ref[[cn]])[1]
    if (class(df[[cn]])[1] == cls_ref) next
    df[[cn]] <- tryCatch(
      switch(cls_ref,
        numeric   = as.numeric(df[[cn]]),
        double    = as.numeric(df[[cn]]),
        integer   = as.integer(df[[cn]]),
        character = as.character(df[[cn]]),
        factor    = factor(df[[cn]]),
        Date      = lubridate::as_date(df[[cn]]),
        logical   = as.logical(df[[cn]]),
        df[[cn]]),
      error = function(e) df[[cn]], warning = function(w) df[[cn]])
  }
  df
}
