# =============================================================================
# feature_eng_pacientes_SIA.R — Pseudo-ID de paciente no SIA-PA (HS, L732)
# Sem CNS no SIA público → record linkage por quase-identificadores.
# PRINCÍPIO: o pseudo-ID AGRUPA registros compatíveis, NÃO identifica pessoas.
#   Nº de pacientes = INTERVALO [estrita, frouxa], nunca número pontual.
# Desenho: determinístico (blocking sexo×munpcn + janela ano_nasc±1) +
#   resolução de entidade por componentes conexos (igraph). reclin2 = sensibilidade
#   opcional. Ver datasus_hs.md §5.1.
# Saídas: data/parquet/sia_hs_pacientes/ (+ id_paciente) e
#         manifest/sia_pseudo_pacientes_sensibilidade.csv
# Rodar (após get_hs_data_from_SIA.R): Rscript scripts/feature_eng_pacientes_SIA.R
# =============================================================================

source(here::here("scripts", "00_setup.R"))
suppressPackageStartupMessages({ library(data.table); library(igraph) })

# -----------------------------------------------------------------------------
# 1. Carregar + normalizar quase-identificadores
# -----------------------------------------------------------------------------
sia <- arrow::open_dataset(here::here("data/parquet/sia_hs")) |>
  dplyr::select(pa_sexo, pa_idade, pa_racacor, pa_munpcn, pa_cmp, ano) |>
  dplyr::collect()

sia <- sia |>
  dplyr::mutate(
    rid    = dplyr::row_number(),                            # âncora estável
    sexo_n = dplyr::case_when(toupper(stringr::str_trim(pa_sexo)) %in% c("M","1") ~ "M",
                              toupper(stringr::str_trim(pa_sexo)) %in% c("F","2","3") ~ "F",
                              TRUE ~ NA_character_),
    raca_n = { r <- stringr::str_pad(stringr::str_trim(as.character(pa_racacor)), 2, pad="0")
               dplyr::if_else(r %in% c("01","02","03","04","05"), r, NA_character_) },  # 99/00 -> NA
    mun_n  = { m <- stringr::str_pad(stringr::str_trim(as.character(pa_munpcn)), 6, pad="0")
               dplyr::if_else(stringr::str_detect(m, "^0+$") | m == "999999", NA_character_, m) },
    idade_i = suppressWarnings(as.integer(pa_idade)),        # SIA-PA: idade em anos
    idade_i = dplyr::if_else(idade_i >= 0 & idade_i <= 110, idade_i, NA_integer_),
    ano_cmp = suppressWarnings(as.integer(stringr::str_sub(pa_cmp, 1, 4))),
    ano_nasc_proxy = ano_cmp - idade_i,
    chave_completa = !is.na(sexo_n) & !is.na(raca_n) & !is.na(mun_n) & !is.na(ano_nasc_proxy)
  )

n_total <- nrow(sia)
message(sprintf("SIA: %d registros | chave completa: %d (%.1f%%)",
                n_total, sum(sia$chave_completa), 100*mean(sia$chave_completa)))

# -----------------------------------------------------------------------------
# 2. Geração de pares por blocking + janela ±1 (equi-join expandido; sem cartesiano global)
# -----------------------------------------------------------------------------
# Janela de aniversário via expansão de UM lado em offsets {-j..+j} → equi-join puro.
construir_pares <- function(el, usar_raca, janela) {
  bloco <- if (usar_raca) c("sexo_n","mun_n","raca_n") else c("sexo_n","mun_n")
  a <- el[, c("rid", bloco, "ano_nasc_proxy"), with = FALSE]
  b <- el[, c("rid", bloco, "ano_nasc_proxy"), with = FALSE]
  data.table::setnames(b, "rid", "rid_b")
  offs <- if (janela == 0) 0L else seq(-janela, janela)
  b_exp <- data.table::rbindlist(lapply(offs, function(o) {
    bb <- data.table::copy(b); bb[, ano_nasc_proxy := ano_nasc_proxy + o]; bb
  }))
  on_cols <- c(bloco, "ano_nasc_proxy")
  pr <- a[b_exp, on = on_cols, nomatch = 0L, allow.cartesian = TRUE,
          .(x = rid, y = rid_b)]
  pr <- pr[x < y]
  unique(pr)
}

# Resolução de entidade: componentes conexos sobre TODOS os rids elegíveis
atribuir_componentes <- function(rids, pares) {
  g <- igraph::graph_from_data_frame(
    as.data.frame(pares[, .(x, y)]), directed = FALSE,
    vertices = data.frame(name = as.character(rids)))
  comp <- igraph::components(g)
  list(membership = comp$membership, n = comp$no, csize = comp$csize)
}

# Conta pacientes p/ um nível de chave, COM cap de span ≤ 1 anos.
# A janela ±1 via componentes conexos ENCADEIA transitivamente em municípios densos
# (A~B~C…), fundindo pessoas de anos de nascimento muito distintos. Mitigação
# (datasus_hs.md §5.1): componentes cujo span de ano_nasc > 1 voltam a exato por ano.
# Assim todo cluster final tem span ∈ {0,1}; some o "encadeamento-rio".
contar_pacientes <- function(el, usar_raca, janela) {
  pares <- construir_pares(el, usar_raca, janela)
  comp  <- atribuir_componentes(el$rid, pares)
  dt <- data.table::copy(el)
  dt[, comp := comp$membership[as.character(rid)]]
  dt[, span := max(ano_nasc_proxy) - min(ano_nasc_proxy), by = comp]
  dt[, id_final := data.table::fifelse(span <= 1L, paste0("C", comp),
                                       paste0("C", comp, "_", ano_nasc_proxy))]
  list(n          = data.table::uniqueN(dt$id_final),
       id         = setNames(dt$id_final, as.character(dt$rid)),  # capped, por rid
       csize      = as.integer(table(dt$id_final)),
       raw_csize  = comp$csize,                                   # antes do cap (diagnóstico)
       n_encadeados = sum(dt$span > 1L),
       n_pares    = nrow(pares))
}

elig <- data.table::as.data.table(
  dplyr::filter(sia, chave_completa)[, c("rid","sexo_n","mun_n","raca_n","ano_nasc_proxy")]
)
n_singletons_incompletos <- sum(!sia$chave_completa)  # forçados a paciente próprio

# -----------------------------------------------------------------------------
# 3. Gradiente de chaves (intervalo de pacientes) — datasus_hs.md §5.1
# -----------------------------------------------------------------------------
message("== Linkage: gradiente de chaves ==")
estrita       <- contar_pacientes(elig, usar_raca = TRUE,  janela = 0L)
intermediaria <- contar_pacientes(elig, usar_raca = TRUE,  janela = 1L)
frouxa        <- contar_pacientes(elig, usar_raca = FALSE, janela = 1L)

# nº de pacientes = componentes (elegíveis) + singletons de chave incompleta
sens <- tibble::tibble(
  nivel       = c("registro_evento","estrita","intermediaria","frouxa"),
  regra       = c("sem de-dup",
                  "sexo+raça+município+ano_nasc exato",
                  "estrita + janela ano_nasc ±1 (CENTRAL)",
                  "sexo+município+ano_nasc±1 (sem raça)"),
  n_pacientes = c(n_total,
                  estrita$n       + n_singletons_incompletos,
                  intermediaria$n + n_singletons_incompletos,
                  frouxa$n        + n_singletons_incompletos),
  n_registros = n_total
) |> dplyr::mutate(reg_por_paciente = round(n_registros / n_pacientes, 2))
cat("\n"); print(sens)

# Diagnóstico do cap anti-encadeamento (chave central)
cat(sprintf("\n• cap de span: %d registros estavam em componentes encadeados (span>1) e voltaram a exato.\n",
            intermediaria$n_encadeados))
cat("• maior cluster ANTES do cap:", max(intermediaria$raw_csize),
    "→ DEPOIS do cap:", max(intermediaria$csize), "registros\n")
cat("• distribuição de tamanho de cluster (após cap), top:\n")
print(sort(table(intermediaria$csize), decreasing = TRUE)[1:6])

# -----------------------------------------------------------------------------
# 4. Atribuir id_paciente CENTRAL (intermediária) ao dado e checagens
# -----------------------------------------------------------------------------
memb <- intermediaria$id                               # capped, named por rid (só elegíveis)
sia <- sia |>
  dplyr::mutate(
    id_componente = unname(memb[as.character(rid)]),     # NA p/ chave incompleta
    id_paciente   = dplyr::if_else(is.na(id_componente),
                                   paste0("S", rid),                 # singleton próprio
                                   paste0("P", id_componente))
  ) |>
  dplyr::group_by(id_paciente) |>
  dplyr::mutate(n_registros_paciente = dplyr::n()) |>
  dplyr::ungroup() |>
  dplyr::mutate(
    chave_estrita = dplyr::if_else(chave_completa,
                      paste(sexo_n, raca_n, mun_n, ano_nasc_proxy, sep = "_"), NA_character_),
    chave_frouxa  = dplyr::if_else(!is.na(sexo_n) & !is.na(mun_n) & !is.na(ano_nasc_proxy),
                      paste(sexo_n, mun_n, ano_nasc_proxy, sep = "_"), NA_character_)
  )

# Sanity: dispersão de ano_nasc dentro do paciente (esperado 0/1; >1 = encadeamento)
span <- sia |> dplyr::filter(!is.na(id_componente)) |>
  dplyr::group_by(id_paciente) |>
  dplyr::summarise(span = max(ano_nasc_proxy) - min(ano_nasc_proxy), .groups = "drop")
cat("\n• span de ano_nasc dentro do paciente (esperado 0/1):\n")
print(dplyr::count(span, span))

# Proxy de fragmentação por migração: pseudo-pacientes com >1 município
# (raros aqui pois mun entra na chave — mede colisão residual de blocking, não migração)
cat("• registros por pseudo-paciente (intermediária): média",
    round(mean(sia$n_registros_paciente), 2),
    "| máx", max(sia$n_registros_paciente), "\n")

# -----------------------------------------------------------------------------
# 5. Persistir
# -----------------------------------------------------------------------------
dir.create(here::here("manifest"), showWarnings = FALSE)
readr::write_csv(sens, here::here("manifest","sia_pseudo_pacientes_sensibilidade.csv"))

saida <- arrow::open_dataset(here::here("data/parquet/sia_hs")) |>
  dplyr::collect() |>
  dplyr::mutate(rid = dplyr::row_number()) |>
  dplyr::left_join(
    dplyr::select(sia, rid, id_paciente, ano_nasc_proxy, n_registros_paciente,
                  chave_completa, chave_estrita, chave_frouxa, sexo_n, raca_n, mun_n),
    by = "rid")
arrow::write_dataset(saida, path = here::here("data/parquet/sia_hs_pacientes"),
                     partitioning = c("ano","uf"), format = "parquet")

message(sprintf(
  "\n✓ Pseudo-ID atribuído. Intervalo de pacientes: [%d (frouxa) ; %d (estrita)], central %d.",
  sens$n_pacientes[sens$nivel=="frouxa"],
  sens$n_pacientes[sens$nivel=="estrita"],
  sens$n_pacientes[sens$nivel=="intermediaria"]))
message("→ data/parquet/sia_hs_pacientes/ + manifest/sia_pseudo_pacientes_sensibilidade.csv")
