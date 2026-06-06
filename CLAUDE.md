# CLAUDE.md — Projeto DATASUS Hidradenite Supurativa (HS)

Guia operacional para o Claude Code e para colaboradores neste projeto. Replica a
abordagem do projeto de autismo (`../autismo/`), adaptada às particularidades
clínico-epidemiológicas da Hidradenite Supurativa.

> Documento de metodologia/plano analítico: ver **`datasus_hs.md`**.

---

## 1. Visão geral

- **Objetivo:** caracterizar a HS no SUS a partir dos microdados do DATASUS —
  acesso, perfil epidemiológico, peso cirúrgico, custos (incl. biológico de alto
  custo) e inequidades regionais. **Atraso diagnóstico** entra apenas como
  **discussão qualitativa/contextual** (as proxies administrativas não o sustentam —
  ver `datasus_hs.md` §6.7), não como entregável quantitativo.
- **Desenho:** estudo **ecológico/descritivo** de dados secundários; **unidade =
  registro/atendimento, não indivíduo** (sem ID longitudinal). Sem inferência
  individual ou causal; bases reportadas **em paralelo, nunca somadas**.
- **Doença / CID-10 alvo:** **L73.2 — Hidradenite supurativa** (acne inversa). No
  DATASUS o CID é armazenado **sem ponto = `L732`**.
- **Bases DATASUS:** **SIA-PA** (ambulatorial + APAC/alto custo), **SIH-RD**
  (internações — foco cirúrgico e comorbidades), **SIM-DO** (mortalidade — exploratório).
- **Período:** **2020–2025** (`ANOS <- 2020:2025`). ⚠️ Os brutos de SIM-DO vão
  apenas **até 2024**; verificar disponibilidade de **SIM-DO 2025** no DATASUS.
- **Captura de casos:** **Restrito + sensibilidade**.
  - **Primária (restrita):** apenas `L732` — alta especificidade.
  - **Sensibilidade (ampliada, em camadas):** `L732` → `+L73x` → `+L02x`
    (abscessos cutâneos), reportada separadamente.
- **Dados brutos:** o usuário **já baixou** SIA/SIH/SIM e **irá transferi-los**
  para `data/raw/`. Os scripts usam *skip-if-exists* — com os brutos presentes, a
  etapa de download é pulada e o pipeline segue para filtro/consolidação.
  Reconciliar o padrão de nomes dos arquivos transferidos (ver §7).

---

## 2. Stack e setup

**Princípio geral: priorizar `tidyverse` em vez de R base.** Use `dplyr`, `tidyr`,
`purrr`, `stringr`, `forcats`, `lubridate` para manipulação e iteração; evite
loops/`apply`/subsetting de R base quando houver equivalente legível em
`purrr`/`dplyr`.

| Finalidade | Pacotes a usar (preferenciais) |
|---|---|
| Manipulação / iteração | **`tidyverse`** (`dplyr`, `tidyr`, `purrr`, `stringr`, `forcats`, `lubridate`); `data.table` apenas onde o volume exigir (bind/agregação pesada) |
| Limpeza de nomes | `janitor::clean_names()` (sempre após carregar dados) |
| Download DATASUS | `microdatasus` (`fetch_datasus`, `process_sia/sih/sim`, `fetch_sigtab`, `tabMun`) |
| Colunar / lazy | `arrow` (`write_dataset`, `open_dataset`) |
| **Estatística** | **`rstatix`** (testes em pipe, `group_by`-friendly), `broom`; **`epitools`** (padronização direta de taxas com IC — `ageadjust.direct()`) |
| **Gráficos** | **`ggplot2` + `ggpubr`** (`stat_compare_means`, `ggarrange`); `patchwork`/`cowplot` p/ composição; `scales` |
| **Tabelas** | **`flextable` + `officer`** (relatório/Word); `gt` quando útil em HTML |
| Mapas | `geobr` (malhas UF/município) + `ggplot2`/`geom_sf` |
| Denominador populacional | `sidrar` (API SIDRA/IBGE) |
| QC de missing | `naniar` |
| Reprodutibilidade | `renv`, `yaml`, `digest`, `here` |

### Helper de instalação (`ensure_pkg`) — topo de `scripts/00_setup.R`

```r
ensure_pkg <- function(pkgs, github = list()) {
  cran <- "https://cloud.r-project.org"
  for (p in pkgs) {
    if (requireNamespace(p, quietly = TRUE)) next
    try(install.packages(p, repos = cran), silent = TRUE)
    if (requireNamespace(p, quietly = TRUE)) next
    if (!requireNamespace("BiocManager", quietly = TRUE))
      install.packages("BiocManager", repos = cran)
    try(BiocManager::install(p, update = FALSE, ask = FALSE), silent = TRUE)
    if (requireNamespace(p, quietly = TRUE)) next
    if (!is.null(github[[p]])) {
      if (!requireNamespace("remotes", quietly = TRUE))
        install.packages("remotes", repos = cran)
      remotes::install_github(github[[p]], upgrade = "never")
    }
    if (!requireNamespace(p, quietly = TRUE))
      stop(sprintf("Falha ao instalar '%s'", p))
  }
  invisible(NULL)
}

pkgs_cran <- c("tidyverse","data.table","arrow","janitor","naniar","rstatix",
               "broom","epitools","ggplot2","scales","patchwork","cowplot","ggpubr",
               "flextable","officer","gt","geobr","sidrar","renv","yaml",
               "digest","here")
# Pinar ref/SHA (ex.: "rfsaldanha/microdatasus@<sha>") p/ o lockfile reproduzir a
# MESMA versão de process_sia/sih/sim — argumentos variam entre versões (§7.4).
pkgs_github <- list(microdatasus = "rfsaldanha/microdatasus",
                    read.dbc     = "danicat/read.dbc")
ensure_pkg(pkgs_cran, github = pkgs_github)
```

> **`renv` (novo vs autismo):** rodar `renv::init()` uma vez; `renv::snapshot()`
> após instalar pacotes; `renv::restore()` para reproduzir. Versionar `renv.lock`,
> **não** `renv/library/`. Em projeto com `renv` ativo, `ensure_pkg()` fica
> redundante mas é mantido como fallback.

> **`set.seed(42)`** em `00_setup.R` para qualquer amostragem/bootstrap/jitter.

---

## 3. Parâmetros globais (`scripts/00_setup.R`)

```r
set.seed(42)

ANOS  <- 2020:2025
MESES <- 1:12                 # SIA/SIH são MENSAIS → unidade de iteração = UF×ano×mês
UFS   <- c("AC","AL","AP","AM","BA","CE","DF","ES","GO","MA","MT","MS","MG",
           "PA","PB","PR","PE","PI","RJ","RN","RS","RO","RR","SC","SP","SE","TO")
# ⚠️ TRIMESTRES é SÓ p/ AGREGAÇÃO temporal em relatórios — NÃO é chave de iteração
# nem de nome de arquivo (SIA/SIH iteram por mês; SIM por ano — ver §7).
TRIMESTRES <- list(T1 = c(1,3), T2 = c(4,6), T3 = c(7,9), T4 = c(10,12))

# CID alvo — Hidradenite Supurativa
CID_ALVO     <- "L732"        # representação DATASUS (sem ponto)
MODO_CAPTURA <- "restrito"    # "restrito" | "ampliado"

# Faixas etárias CANÔNICAS — mesma grade no numerador (paciente) e no denominador
# (IBGE), senão a taxa padronizada é inválida (ver utils.R::harmonizar_faixa()).
FAIXAS_BR <- c(0,5,10,15,20,25,30,35,40,45,50,55,60,65,70,75,80,Inf)
POP_PADRAO   <- "censo2022"   # "censo2022" (comparações internas) | "oms" (internac.)
N_SUPRESSAO  <- 5             # LGPD: suprimir células com N < 5 na divulgação

# Paleta visual do projeto (ver §8)
PAL_HS <- c("#5C3F6C", "#816095", "#E9CDC9", "#A87FA8", "#D8B4C4", "#6E4E82", "#3E2A4D")
```

Diretórios (criados em `00_setup.R` com `dir.create(recursive = TRUE)`): ver §4.

---

## 4. Estrutura de diretórios

```
datasus_HS/
├── CLAUDE.md                     # este guia
├── datasus_hs.md                 # plano consolidado / metodologia
├── _quarto.yml                   # website Quarto → output-dir: docs
├── .gitignore
├── renv.lock
├── scripts/
│   ├── 00_setup.R                # ensure_pkg(), params, seed, paleta, dirs
│   ├── utils.R                   # camada_cid(), normalizar_cid_sim(), cid_valido(), idade_em_anos(), decode_idade_sim(), harmonizar_faixa(), uf_from_mun(), corrigir_encoding(), coagir_tipos(), casar_tipos(), mapear_uf_regiao(), log_run(), validar_grade_completa(), qc_basico(), suprimir_pequenas()
│   ├── 01_validar_brutos.R       # valida grade + conteúdo dos brutos (SIA/SIH/SIM)
│   ├── get_hs_data_from_SIA.R    # consolida SIA-PA → parquet/sia_hs (ano+uf)
│   ├── feature_eng_pacientes_SIA.R # pseudo-ID de paciente (record linkage) → sia_hs_pacientes
│   ├── get_hs_data_from_SIH.R    # consolida SIH-RD (cirúrgico/comorbidades) → parquet/sih_hs
│   ├── get_hs_data_from_SIM.R    # filtra/consolida SIM-DO (+2025 preliminar opendatasus)
│   ├── get_denominadores_ibge.R  # população IBGE Censo 2022 via sidrar → denominators/pop_ibge
│   ├── get_dermatologistas_cnes.R # nº de dermatologistas por UF×ano (CNES-PF, CBO) → oferta/acesso
│   └── calcular_taxas.R          # taxas brutas/padronizadas (direta idade×sexo, IC gama) — lib p/ .qmd
├── qmd/
│   ├── index.qmd                 # portal KPIs
│   ├── sia_hs.qmd                # ambulatorial
│   ├── sih_hs.qmd                # internações
│   └── sim_hs.qmd                # mortalidade
├── data/
│   ├── raw/{sia_files_hs,SIH_files,SIM_DO}/      # brutos (transferidos pelo usuário)
│   ├── filtered/{sia_hs,sih_hs,sim_hs}/          # *_hs.RData filtrados por CID
│   ├── denominators/{sia,sih,sim}/               # totais agregados na ingestão (denominador de uso) + pop_ibge.parquet
│   ├── parquet/{sia_hs,sih_hs,sim_hs}/           # Parquet particionado por ano + uf
│   └── consolidated/{sia,sih,sim}_hs_nacional.RData
├── logs/run_log_{sia,sih,sim}.csv
├── manifest/                     # params_run_*.yaml, checksums
└── docs/                         # website renderizado (versionado) + .nojekyll
```

`.gitignore` deve excluir: `data/`, `logs/`, `*.RData`, `*.rds`, `*_cache/`,
`*_files/` (cache Quarto), `.Rhistory`, `.RData`, `.Rproj.user/`,
`renv/library/`, `renv/staging/`, `.DS_Store`. **Versionar:** `scripts/`,
`qmd/`, `docs/`, `manifest/`, `renv.lock`, `*.md`, `_quarto.yml`.

---

## 5. Convenções de código

- **`janitor::clean_names()`** sempre após carregar/baixar — nomes em snake_case.
- **Encoding latin1 → UTF-8 SEMPRE** após carregar (o DATASUS é ISO-8859-1): se o
  `process_*()` da versão instalada não tratar, aplicar
  `mutate(across(where(is.character), ~ iconv(.x, "latin1", "UTF-8")))`. Crítico para
  o CID do SIM (marcadores `†`/`*`) e nomes de município — **sempre juntar por
  CÓDIGO IBGE, nunca por nome**.
- **Coerção de tipos** logo após `clean_names()`: monetários (`pa_valapr`, `val_tot`,
  `val_sh`, `val_sp`) com `readr::parse_number()`; datas (`dt_inter`, `dt_saida`,
  `dt_obito`, `AAAAMMDD`) com `lubridate::ymd()`; códigos com zero-padding preservados
  como `character` (CIDs, `pa_proc_id`, `co_uf`). **Confirmar** o que o `process_*()`
  já converte para não reconverter.
- **Granularidade real:** SIA/SIH iteram por **UF × ano × mês** (`MESES`); SIM por
  **UF × ano** (anual, nacional). Não usar `TRIMESTRES` como chave (§3, §7).
- **Namespaces:** se algum script carregar Bioconductor junto do tidyverse,
  declarar override no topo (`select <- dplyr::select`, `filter <- dplyr::filter`,
  `rename <- dplyr::rename`, `slice <- dplyr::slice`, `count <- dplyr::count`).
- **Loops de download/filtro:** sempre com `tryCatch` (alguns meses/UF falham),
  *skip-if-exists* (verificar `file.exists() && file.info()$size > 0`, idealmente
  checksum) e `gc()` ao final de cada iteração. Usar `purrr::walk()` (filtra/grava/
  descarta arquivo a arquivo), **nunca `map_dfr()` sobre todos os brutos** (estoura RAM).
- **Denominador de utilização = AGREGAR na ingestão.** O SIA-PA total não cabe em RAM:
  por competência, logo após carregar e antes de descartar, agregar
  (`count(uf, ano, mes, sexo, faixa)`) e gravar incrementalmente em
  `data/denominators/sia` — **nunca materializar o bruto inteiro**.
- **SIA é volumoso** → consolidar o SIA-HS (já reduzido pelo CID) em **Parquet
  particionado por `ano` e `uf`** (`arrow::write_dataset(partitioning = c("ano","uf"))`)
  e consultar com `arrow::open_dataset() |> filter() |> group_by() |> summarise() |>
  collect()` (lazy). **Fixar `schema()` explícito** em `open_dataset()` para campos
  críticos (monetários `double`, códigos `character`) — senão tipos divergentes entre
  meses quebram o `collect()`.
- **Deduplicação:** SIH conta **AIH distinta** (não linha — há AIH de continuação);
  SIA conta **soma de `pa_qtdapr`** (não `nrow()` — o PA é produção agregada). Define a
  métrica de "atendimentos/internações".
- **UF e residência vs atendimento:** UF = 2 primeiros dígitos do código de município
  (`uf_from_mun()`); **fixar a convenção** — residência (`munic_res`/`pa_munpcn`) para
  epidemiologia, atendimento para oferta (vazios assistenciais).
- **Joins entre bases apenas AGREGADOS** (UF × ano × sexo × faixa) — nunca por linha
  (sem ID longitudinal). Chave canônica de UF uniforme entre as três bases.
- **Supressão LGPD:** suprimir células com `N < N_SUPRESSAO` (§3) na divulgação.
- **Não inventar** CID, procedimento SIGTAP, CBO, portaria ou prevalência.
  Marcar pendências com `[VERIFICAR]` / `[CONFIRMAR via fetch_sigtab()]`.

### `camada_cid()` — rotula a camada de captura por registro (em `utils.R`)

Substitui o antigo `detectar_cid()` booleano: gera as **3 camadas numa única passada**
(em vez de reprocessar o bruto 3×) e alinha-se ao desenho restrito→ampliado de
`datasus_hs.md` §2. **Atenção:** não existem subcódigos oficiais `L7320`/`L7321` — a
categoria L73.2 tem 4 caracteres; normalizar para 4 chars e comparar por igualdade
evita regex aberta.

```r
camada_cid <- function(campo) {
  x <- stringr::str_sub(stringr::str_trim(toupper(as.character(campo))), 1, 4)
  dplyr::case_when(
    x == "L732"                    ~ "L732",   # caso-índice (restrito)
    stringr::str_detect(x, "^L73") ~ "L73x",   # demais foliculares
    stringr::str_detect(x, "^L02") ~ "L02x",   # ENVELOPE de subcodificação (teto, não caso)
    TRUE                           ~ NA_character_
  )
}
# Restrito  → camada == "L732"
# Ampliado  → camada %in% c("L732","L73x","L02x"), reportadas em camadas separadas

cid_valido <- function(campo)   # marca CID malformado ANTES de filtrar (indicador de qualidade, §6.8)
  stringr::str_detect(stringr::str_trim(toupper(as.character(campo))), "^[A-Z][0-9]{2}")
```

**Campos de CID por base** (após `clean_names()`):
- **SIA-PA:** `pa_cidpri` (principal), `pa_cidsec`, `pa_cidcas`. ⚠️ **Não há `pa_cidpec`**
  nesta extração (SIA-PA de produção); rastrear adalimumabe/APAC exige a base **SIA-AM/AP
  (APAC)** ou código de procedimento, não disponível aqui — ver §7. Os brutos atuais já
  vêm **filtrados por `pa_cidpri == L732`** (só CID principal).
- **SIH-RD:** `diag_princ` + `diag_secun` + `diagsec1`…`diagsec9` (11 campos no layout
  atual). **Detecção dinâmica** das colunas presentes e `any_of` (não `all_of`):
  ```r
  cols_diag <- names(df) |> stringr::str_subset("^diag(_?princ|sec)")
  cols_diag <- union("diag_princ", cols_diag) |> intersect(names(df))
  # Reportar DOIS sabores (datasus_hs.md §2):
  #   (a) principal: detectar só em diag_princ
  #   (b) qualquer:  dplyr::if_any(any_of(cols_diag), ~ camada_cid(.x) == "L732")
  ```
- **SIM-DO:** `causabas` + `linhaa`/`linhab`/`linhac`/`linhad` + `linhaii`. Cada célula
  pode ter **vários CIDs** e marcadores `†`/`*` → `normalizar_cid_sim()` extrai a lista
  de códigos (após corrigir encoding) e testa HS em qualquer um:
  ```r
  normalizar_cid_sim <- function(x) {
    x |> toupper() |>
      stringr::str_remove_all("[†*]") |>     # daga (†) e asterisco da notação CID
      stringr::str_extract_all("[A-Z][0-9]{2,3}")   # lista de códigos por célula
  }
  ```

### Funções de denominador/idade (em `utils.R`)

```r
idade_em_anos <- function(idade, cod_idade)   # respeita unidade do SIH (anos/meses/dias) e pa_idade do SIA
harmonizar_faixa <- function(idade_anos)      # MESMA grade FAIXAS_BR no numerador e no denominador IBGE
```

---

## 6. Runbook (ordem de execução)

```
Fase 0 — Ambiente
  renv::restore()                              # 1ª vez: instala do lock
  source("scripts/00_setup.R")                 # params, dirs, paleta, seed

Fase 1 — Dados brutos
  # Os brutos serão transferidos pelo usuário para data/raw/.
  # Reconciliar nomes (§7). Verificar disponibilidade de SIM-DO 2025.
  # Grade esperada: SIA/SIH = 27 UF × 6 anos × 12 meses (= 1944/base); SIM = 27 UF × anos.
  # Se faltarem competências: rodar a Etapa 2 (download) do script correspondente.
  # validar_grade_completa(base) deve retornar 0 faltantes antes de avançar (stop() se >0).

Fase 1.5 — Validação dos brutos
  Rscript scripts/01_validar_brutos.R          # grade + conteúdo (0 faltantes p/ avançar)

Fase 2 — Filtro + consolidação
  Rscript scripts/get_hs_data_from_SIA.R       # → parquet/sia_hs + consolidated
  Rscript scripts/feature_eng_pacientes_SIA.R  # → sia_hs_pacientes (pseudo-ID; datasus_hs.md §5.1)
  Rscript scripts/get_hs_data_from_SIH.R       # → parquet/sih_hs + consolidated
  Rscript scripts/get_hs_data_from_SIM.R       # → consolidated/sim_hs_nacional (+2025 preliminar)
  Rscript scripts/get_denominadores_ibge.R     # → denominators/pop_ibge (Censo 2022 via sidrar)

Fase 3 — Relatórios
  quarto render                                # qmd/ → docs/ (self-contained)

Fase 4 — Publicação
  # criar .nojekyll em docs/; repositório GitHub; GitHub Pages servindo /docs
  git add scripts/ qmd/ docs/ manifest/ renv.lock *.md _quarto.yml
```

---

## 7. Pontos de atenção (confirmar antes de rodar)

1. **Granularidade temporal** — SIA-PA/SIH-RD são **mensais** (`PAUF AAMM`, `RDUF AAMM`);
   `fetch_datasus()` baixa por `month_start`/`month_end`. SIM-DO é **anual por UF**
   (`DOUF AAAA`), com `year_start`/`year_end` — loop e naming distintos dos demais.
2. **SIM-DO 2025** — provavelmente ainda não publicado; verificar no DATASUS/`fetch_datasus`.
3. **`information_system` do SIM** no `microdatasus` instalado (`?fetch_datasus` — pode ser `"SIM-DO"`).
4. **SIA-AM (APAC)** — confirmar disponibilidade no microdatasus para rastrear adalimumabe; alternativamente usar `pa_cidpec`/procedimento APAC no SIA-PA.
5. **Argumentos de `process_sia()`/`process_sih()`/`process_sim()`** variam entre versões (`?process_*`). **Validar pós-carga** as colunas-chave (ex.: `stopifnot(all(c("pa_cidpec","pa_valapr","pa_qtdapr","pa_proc_id","pa_cbocod") %in% names(df)))`) — o eixo do adalimumabe depende de `pa_cidpec`, que alguns defaults de `process_sia()` não trazem.
6. **`fetch_sigtab()` pode não existir** nesta versão — checar `"fetch_sigtab" %in% getNamespaceExports("microdatasus")`; fallback: download manual do SIGTAP/TabWin.
7. **Nomes das colunas `diagsec*`** após `clean_names()` mudam entre anos do SIH — detectar dinamicamente (§5, `any_of`).
8. **Reconciliação dos brutos transferidos** — alinhar o padrão de nomes ao esperado, **com a competência no nome**: `{base}_{uf}_{ano}_{mes2}.RData` (SIA/SIH) e `{base}_{uf}_{ano}.RData` (SIM) — senão `validar_grade_completa()` não detecta faltantes. Conferir também se o objeto salvo é `x` (bruto) como no projeto de autismo.
9. **Códigos SIGTAP/CBO** — validar via `fetch_sigtab()` na competência correta antes de citar (não fixar códigos sem confirmação).
10. **Efeito COVID-19 (2020–2021)** — queda de produção eletiva/dermatológica afeta toda série temporal; ressalva obrigatória nos relatórios (`datasus_hs.md` §6, §9.11).
11. **Descontinuidade do denominador em 2022 (Censo)** — harmonizar a série populacional (retrointerpolar a partir do Censo 2022) e fixar `POP_PADRAO` (`datasus_hs.md` §5).

### 7.1 Reconciliação CONFIRMADA dos brutos (validado em 2026-06 — `01_validar_brutos.R`)

O usuário transferiu e **pré-filtrou** os brutos. Layout real (sobrepõe-se à premissa
mensal acima — os brutos vêm consolidados por **trimestre**):

| Base | Diretório | Nome do arquivo | Objeto | Caso/colunas | Grade | Filtro aplicado |
|---|---|---|---|---|---|---|
| **SIA** | `data/raw/SIA/` | `sia_{uf}_{ano}_{tri}_hs.RData` | `x_hs` | 62 cols, **MAIÚSCULAS** | UF×ano×**tri(1–4)** = 648 ✓ | `PA_CIDPRI == L732` (só principal) |
| **SIH** | `data/raw/SIH/` | `sih_{uf}_{ano}_{tri}_hs.RData` | `x_hs` | 113 cols (2020–24) / **114 em 2025** (`+FONTE_ORC`) | 648 ✓ | `DIAG_PRINC == L732` (só principal) |
| **SIM** | `data/raw/SIM/` | `sim_do_{UF}_{ano}.RData` | `x` | 97 cols, **minúsculas** (já processado) | UF×ano(2020–24) = 135 ✓ | **NÃO filtrado** (filtrar por `causabas`+linhas) |

Implicações confirmadas:
- **`uf` minúsculo** (SIA/SIH) e **MAIÚSCULO** (SIM) no nome; objeto `x_hs` vs `x`.
- **SIA/SIH em MAIÚSCULAS** → aplicar `janitor::clean_names()` ao carregar; SIM já minúsculo.
- **Filtro só por diagnóstico PRINCIPAL** em ambos → o **sabor "qualquer campo"** do SIH
  (datasus_hs.md §2) **não é recuperável** deste conjunto (internações com HS apenas em
  `diagsec*` foram excluídas na extração do usuário). Reportar apenas o sabor principal,
  ou re-extrair do RD completo se o sabor "qualquer campo" for necessário.
- **Sem `pa_cidpec`** no SIA-PA → eixo do **adalimumabe/APAC inviável** com estes brutos;
  requer SIA-AM/AP (APAC). Sinalizar em §6.4 e §8 do plano.
- **Schema SIH 2025** é superset (`+FONTE_ORC`) → `bind_rows()` preenche `NA`; ao gravar
  Parquet, fixar schema com a união das colunas.
- **Arquivos com 0 linhas** são esperados (SIA: 33; SIH: 452 — HS hospitalar é rara);
  ao bindar, garantir classes de coluna idênticas (coagir tipos antes do bind).
- **SIM 2025**: ausente no DATASUS; usar **prévia do opendatasus** (CSV nacional) —
  `Mortalidade_Geral_2025` — processada à parte e harmonizada ao schema do SIM-DO.

Contagens HS validadas (captura restrita `L732`): **SIA 158.850** registros
(2020→2025: 4.388 → 52.678); **SIH 632** internações; **SIM 65** óbitos com HS em
qualquer campo (só **1** como causa básica) — confirma a quase invisibilidade no SIM.

---

## 8. Tema visual (gráficos e site)

Paleta principal (espectro rosé → roxo):

- **`#E9CDC9`** (rosé claro) · **`#5C3F6C`** (roxo escuro) · **`#816095`** (roxo médio).
- Extensão sugerida para mais categorias (manter harmonia no espectro):
  `#D8B4C4`, `#A87FA8`, `#6E4E82`, `#3E2A4D`.

Uso:
- Constante `PAL_HS` em `00_setup.R`; aplicar com `scale_fill_manual(values = PAL_HS)`
  / `scale_color_manual(values = PAL_HS)`.
- Escalas **contínuas**: gradiente `scale_*_gradient(low = "#E9CDC9", high = "#5C3F6C")`.
- Tema base `ggpubr::theme_pubr()` (ou `theme_minimal()`), alinhado às cores acima.
- Alinhar o tema do site no `_quarto.yml` à mesma paleta.

---

## 9. Relatórios e publicação

- **`.qmd` self-contained:** preferir `format: html: embed-resources: true` para
  que cada HTML funcione isolado.
- **`_quarto.yml`:** `project: type: website`, `output-dir: docs`, tema alinhado à
  paleta, `execute: echo: false, warning: false, message: false, cache: true`,
  `lang: pt`.
- **GitHub Pages:** criar repositório, adicionar **`.nojekyll`** em `docs/`
  (impede o Jekyll de quebrar `site_libs/`), e configurar Pages para servir a
  pasta `/docs`.

---

## 10. Limitações (resumo — detalhe em `datasus_hs.md`)

Subdiagnóstico/subcodificação (HS frequentemente codificada como abscesso `L02x`);
ausência de denominador censitário (taxas são de **detecção/uso**, não prevalência);
**sem identificador longitudinal** no DATASUS público (conta registros, não
pessoas; recidiva e atraso diagnóstico só aproximáveis); SIA tem 1 só CID;
procedimento ≠ doença; mortalidade quase invisível no SIM; APAC sujeita a
judicialização não distinguível; heterogeneidade de codificação entre UFs/tempo;
viés de gravidade; mudanças de versão do SIGTAP no período.
