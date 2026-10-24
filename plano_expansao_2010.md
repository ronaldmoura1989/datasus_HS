# Plano de expansão da série HS para 2010 até o último ano completo

**Para quem:** Ronald e colaboradores que vão executar.
**Base:** `ref/guia_processamento_datasus.md` (guia EIM, citado como "guia §n"), `CLAUDE.md`,
`datasus_hs.md` e o código atual em `scripts/` e `qmd/`.
**Status:** plano. Nada foi executado. Toda afirmação normativa ou de código SIGTAP marcada
`[VERIFICAR]` precisa ser confirmada na fonte primária antes de entrar em texto publicado.

---

## Status de execução (23/10/2026)

| Etapa | Status | Onde |
|---|---|---|
| E0 | feita: tag local `v1-2020-2025`, `manifest/v1_checksums.csv` (brutos só com tamanho: estão só na nuvem do OneDrive), `manifest/v1_contagens_referencia.csv` | local |
| E1 | feita: `ref/normativo_hs.md`, `ref/sigtap_hs.csv`; marco **201911** (alternativo 201811); canal clínico a partir de **201401** | local |
| E2 | feita: `scripts/hs_lookup.R` (hash em `manifest/hs_lookup_versao.csv`) | local |
| E3 | feita: piloto aprovado (SIA PE 2021 idêntico, `anti_join` vazio; SIH PE+SP 2021 = 29 AIH; SIM 2020–2025 igual à v1) | R550-2 |
| E4 | feita: 11.663 DBC, 0 erros → `~/Documentos/ronald/datasus_filtrado_hs/` | R550-2 |
| E5–E12 | feitas (`scripts/r550/rodar_pipeline_hs.sh`), resultados em `~/Documentos/ronald/datasus_HS/{data,manifest,logs}`; revisões 1–3 abaixo incorporadas no export (normalização pela produção dermatológica; ITS com COVID até 2022, sem 2020–2021 e sem anatomopatológico) | R550-2 |
| E13 site | feito, opção (a): `scripts/exportar_agregados_hs.R` → `data/export/` (só agregados suprimidos) → `qmd/` reescritos (números por R inline em `qmd/_numeros.R`) + `notas_lancamento.qmd`; renderizado em `docs/` | local |
| E13 docs | `CLAUDE.md` (§1, §3, §4, §5, §6, nota em §7) e quadro "Atualização v2" no topo de `datasus_hs.md` | local |
| E13 apresentação | feita: figuras de `scripts/figuras_apresentacao.R` (só agregados) trocadas dentro do `.pptx` editado à mão, números e notas atualizados; versão manual anterior preservada no commit 0780a1e | local |
| E13 manuscrito | fora desta linha de trabalho: será editado em sessão separada (Claude Science) a partir de `data/export/` e do site | — |
| E14 | branch `v2-serie-2010-2025` publicado, PR #1 aberto; o site sai ao integrar na `main` | GitHub |

**Bug corrigido na cópia HS do filtro:** no `filtrar_um.R` do EIM, as medidas do denominador
usam `g("COL")`, que devolve a coluna inteira do arquivo; cada estrato recebia a soma do
arquivo todo (Σ`PA_QTDAPR`/Σ`PA_VALAPR` no SIA; óbitos/diárias no SIH). Contagens de linhas e
de AIH não são afetadas. O EIM não foi alterado.

**Pontos a revisar antes da E13:** (1) o canal clínico cresce junto com a fração do volume
SIA em instrumento com CID (23% em 2010 → 50% em 2025): normalizar pela produção
dermatológica (`sia_derm_agg`) ou pela fração BPA-I; (2) a ITS mostra queda de nível no marco
201911 a 4 meses da COVID — testar indicadora COVID até 2022 e exclusão de 2020–2021; (3)
confundidor de calendário em 2019 (L73.2 no anatomopatológico em 201906); (4) SIM: N muito
pequeno e `LINHAII` mais preenchida — tendência só descritiva.

---

## 0. Resumo em uma página

| | Hoje (v1) | Depois da expansão (v2) |
|---|---|---|
| Período | 2020–2025 | SIA/SIH **2010–2025**; SIM definitivo **2010–2024** + 2025 preliminar à parte |
| Brutos | RData pré-filtrados pelo usuário (SIA só `PA_CIDPRI == L732`; SIH só `DIAG_PRINC == L732`; SIM processado pelo microdatasus) | DBC originais do R550-2, filtrados por um escopo novo `hit_hs` para `datasus_filtrado_hs/` (parquet todo-texto) |
| Definição de caso | `camada_cid()` codificada à mão em `utils.R` | `scripts/hs_lookup.R` (tabela versionada com hash, guia §7); `camada_cid()` vira wrapper |
| Unidade SIA | linhas (`nrow`), das quais cerca de 88% são APAC de adalimumabe | três canais separados: detecção clínica (BPA-I e APAC sem medicamento), tratamento com adalimumabe (APAC 06.04) e envelope L02x agregado |
| SIH | só principal | principal (série primária) + "qualquer campo" (teto, cresce por preenchimento) |
| SIM | `str_detect("L732")` sobre o SIM processado | regex de causas múltiplas sobre o DBC bruto; causa básica × qualquer linha |
| Denominador | Censo 2022 repetido como constante em todos os anos | IBGE Projeções Revisão 2024, anual, mesma grade 0–4 … 80+ |
| Tendência | descritiva | quasi-Poisson com offset, série interrompida no marco de incorporação do adalimumabe, sensibilidade sem 2020–2022 |
| Números no texto | vários escritos à mão (qmd, manuscrito, apresentação) | só R inline (guia §12) |

A principal razão epidemiológica para a série longa está na última linha da seção 4.6: com
2010–2019 dá para separar o efeito da **incorporação do adalimumabe** (que obriga APAC com
CID L73.2 e cria um canal de registro novo) da **detecção clínica** da HS. Na janela
2020–2025 esses dois efeitos estão confundidos, e o crescimento de cerca de 10 vezes no SIA
foi lido como "intensificação de uso e recuperação pós-COVID" (manuscrito, Results), quando é
majoritariamente dispensação mensal de medicamento.

---

## 1. Diagnóstico do que existe e do que muda

Conferido diretamente no código e no parquet atual (`data/parquet/sia_hs`, leitura apenas):

| Item | Situação atual | Consequência para a v2 |
|---|---|---|
| Composição do SIA-HS | `PA_DOCORIG`: P = 136.797, I = 19.518, S = 2.535 linhas; grupo `0604` = 139.332 linhas (88%). Σ`PA_QTDAPR` em P = 489.604 | A série "registros SIA" é, na prática, a série de APAC de adalimumabe. Separar canais é obrigatório (seção 4.1) |
| Ano no SIA | `ano`/`mes` já coincidem com `PA_CMP` (zero divergências); há linhas com `PA_MVM` no ano seguinte (8 a 62 por ano) | A regra "ano = `PA_CMP`" já vale de fato. A v2 a formaliza e precisa ler os arquivos de 2026 para fechar 2025 (atrasos de até 3 meses observados) |
| `PA_CIDSEC`/`PA_CIDCAS` | 0% preenchido / sempre `0000` em 2020–2025 | Série longa usa só `PA_CIDPRI` (guia §5); o secundário de 2010–2014 entra só como auditoria |
| Raça/cor SIA | 99 em 14.097 linhas (8,9%) | O pseudo-ID atual força paciente próprio para chave incompleta (erro descrito no guia §11). Corrigir na v2 |
| Pseudo-ID | não usa `PA_AUTORIZ` | Ligação certa por número de APAC (guia §11) resolve boa parte do SIA, que é 88% APAC |
| SIH | 632 linhas, 631 AIH distintas, 1 `IDENT == 5` | Regras corretas; a v2 só amplia período e sabores |
| SIM | 2020–2024: 65 óbitos com L732 em qualquer campo, 1 como causa básica; 2025 preliminar (opendatasus): 31 | O 2025 preliminar quase dobra 2024 (16). Auditar antes de exibir (seção 6, item 9) |
| Denominador | `get_denominadores_ibge.R` replica o Censo 2022 em todos os anos | Exatamente o erro descrito no guia §9. Substituir |
| Taxas | `contar_estrato()` descarta linhas sem aviso; `taxas_padronizadas()` faz `left_join` a partir da população e preenche `n = 0` | Risco de anos-fantasma com `ANOS = 2010:2025` e SIM até 2024 (guia §10). Portar a versão EIM |
| COVID | `ANOS_COVID <- c(2020, 2021)` | Guia usa 2020–2022 na sensibilidade. Harmonizar (seção 4.3) |

---

## 2. Princípios herdados (não negociáveis)

1. Os DBC do R550-2 não se tocam; o projeto HS escreve só em `datasus_filtrado_hs/` (guia §1, §4.4).
2. Denominador de utilização vem do arquivo inteiro, antes do filtro (guia §4.1).
3. A definição de caso é a lookup com hash (guia §7). Mudou a lookup, mudou a versão.
4. Camadas: núcleo `L732` é o número primário; limítrofe e envelope nunca entram nele.
5. Bases em paralelo, nunca somadas. Taxas são de detecção/uso.
6. Nenhum número digitado à mão em texto publicado (guia §12).
7. Supressão N < 5 em contagens **e** taxas, inclusive em CSV/TSV de apoio.
8. Jobs longos em tmux, retomáveis, com checkpoint `.ok`.

---

## 3. Etapas

Cada etapa traz objetivo, entradas, saídas, scripts, critério de aceite e riscos. "Molde EIM"
refere-se a `datasus_EIM/scripts/` (não há cópia local neste computador; os nomes vêm do
guia §15). Esforço em dias-pessoa, sem contar tempo de máquina.

### E0. Congelar a v1 e decidir o ambiente (0,5 d)

- **Objetivo:** ter um ponto de retorno e uma referência para validar a v2.
- **Entradas:** repositório atual, `data/` local.
- **Saídas:** tag git `v1-2020-2025`; `manifest/v1_checksums.csv` (sha256 dos brutos
  `data/raw/{SIA,SIH,SIM}` e dos consolidados); `manifest/v1_contagens_referencia.csv` com
  as contagens de referência da seção E3 (por UF × `PA_MVM` no SIA, `N_AIH` no SIH,
  óbitos por ano no SIM).
- **Scripts:** `scripts/v1_congelar_referencia.R` (novo, curto: lê o parquet v1 e grava as
  contagens).
- **Aceite:** tag criada; CSV de referência versionado.
- **Riscos:** OneDrive sincronizando `data/` durante a cópia; fazer com o sync pausado.

### E1. Fixar o arcabouço normativo e os códigos SIGTAP (1,5 d)

- **Objetivo:** saber, antes de modelar, **quando** cada código existe e **quando** a HS
  passou a ter adalimumabe no SUS.
- **Entradas:** DOU, gov.br/conitec, SIGTAP por competência, `microdatasus::sigtab`.
- **Saídas:** `ref/normativo_hs.md` com três atos fixados (guia não cobre; `datasus_hs.md` §8):
  1. portaria SCTIE de incorporação do adalimumabe para HS `[VERIFICAR número e data no DOU;
     datasus_hs.md cita "nº 48, 16/10/2018" com dúvida e relatório Conitec 473/2019]`;
  2. portaria que aprova o PCDT de HS e eventuais atualizações `[VERIFICAR]`;
  3. data de início efetivo da dispensação no CEAF `[VERIFICAR]`.
  E `ref/sigtap_hs.csv`: código, nome, competência inicial e final, instrumento de registro
  (BPA-C, BPA-I, APAC, AIH), fonte.
- **Como achar os códigos sem inventar:**
  - Adalimumabe: os três códigos usados hoje (`0604380062` referência, `0604380127`
    biossimilar A, `0604380135` biossimilar B) estão confirmados no dado 2020–2025. Para
    2010–2019, `[VERIFICAR via sigtab]` se houve código anterior. Método empírico: depois da
    E4, listar todos os `PA_PROC_ID` com `PA_CIDPRI == L732` e `PA_DOCORIG` P/S por
    competência, e todos os procedimentos cujo nome contenha `ADALIMUMABE` em qualquer
    versão do SIGTAP.
  - Cirúrgicos: buscar no SIGTAP por nome (`HIDROSADENITE`, `HIDRADENITE`, `SUDORIPARA`,
    `ABSCESSO`, `EXERESE`, `RETALHO`, `ENXERTO`) e registrar os códigos achados como
    `[VERIFICAR via sigtab]` até conferir nome e vigência. Não fixar código de memória.
  - `microdatasus::sigtab` é um retrato único; para nomes e vigências históricas, baixar as
    tabelas SIGTAP por competência `[VERIFICAR caminho no FTP do DATASUS]`.
- **Aceite:** os três atos com número, data e link; cada código usado no pipeline com nome e
  vigência; nenhum código sem fonte.
- **Riscos:** confundir número de relatório Conitec com número de portaria; códigos de
  medicamento reorganizados no CEAF ao longo de 2010–2025; data normativa diferente da data
  em que a APAC aparece no dado (usar as duas, seção 4.2).

### E2. Lookup versionada `hs_lookup.R` (1 d)

- **Objetivo:** substituir a lista à mão de `camada_cid()` por uma tabela (guia §7).
- **Entradas:** `datasus_hs.md` §2 e §4, `ref/sigtap_hs.csv` (E1).
- **Saídas:** `scripts/hs_lookup.R` com `HS_LOOKUP` (tibble) e
  `manifest/hs_lookup_versao.csv` (data, hash `digest::digest(HS_LOOKUP, "sha256")`, n de
  linhas, autor).
- **Molde EIM:** `eim_lookup.R`.
- **Estrutura proposta:**

| `tipo` | `prefixo` | `camada` | `escopo` | Observação |
|---|---|---|---|---|
| cid | `L732` | nucleo | hs | caso-índice; número primário |
| cid | `L738`, `L739` | limitrofe | hs | afecção folicular especificada/não especificada: possível subcodificação |
| cid | `L730`, `L731` | diferencial | contexto | acne queloideana e pseudofoliculite são outras doenças; hoje entram em "L73x" junto com L738/L739. Separar |
| cid | `L02` (e, se desejado, `L022`, `L023` como subcamada topográfica) | envelope | contexto | teto de subcodificação, nunca caso |
| proc | 3 códigos de adalimumabe + eventuais históricos (E1) | medicamento | hs_proc | captura **em qualquer CID**, para auditar vigência e uso fora de L732 |
| proc | procedimentos nominalmente de hidrosadenite, se existirem (E1) | procedimento_especifico | hs_proc | `[VERIFICAR via sigtab]`; canal de captura independente do CID |
| cid | `E66`, `F17`, `K50`, `K51`, `E11`, `F32`, `F33`, `F41`, `M07`, `M45`, `M46`, `E78` | comorbidade | comorb | usado só para classificar secundários dentro das AIH-HS; não entra no filtro (seção E3) |

- **Regras:** ordenar por `nchar(prefixo)` decrescente, primeiro match vence; função
  `classificar_hs(cid)` devolve `camada`; `camada_cid()` passa a chamar
  `classificar_hs()` e mapear para os rótulos antigos, só para os `.qmd` da v1 continuarem
  rodando até a E12.
- **Aceite:** teste unitário com casos conhecidos (`L732` → nucleo; `L739` → limitrofe;
  `L731` → diferencial; `L020` → envelope; `L03` → NA; espaços e minúsculas normalizados);
  hash gravado.
- **Riscos:** `M07`/`M45`/`M46` como espondiloartrite estão marcados `[CONFIRMAR]` em
  `datasus_hs.md` §4; manter a marca.

### E3. Escopo `hit_hs` no filtro e piloto de validação (1,5 d + cerca de 1 h de máquina)

- **Objetivo:** criar o escopo e provar, numa UF × ano, que a filtragem 2010+ reproduz os
  brutos atuais.
- **Entradas:** `HS_LOOKUP`; `config_filtro.R`, `filtrar_um.R`, `orquestrar_filtro.sh`
  (R550-2); `manifest/v1_contagens_referencia.csv` (E0).
- **Mudanças em `config_filtro.R`** (guia §4.4):
  - `ESCOPO_CID$hs` lido de `HS_LOOKUP` (camadas nucleo, limitrofe, diferencial, envelope),
    nunca copiado à mão;
  - `ESCOPO_PROC$hs_proc` com os códigos `tipo == "proc"`;
  - campos testados: SIA `PA_CIDPRI`, `PA_CIDSEC`, `PA_CIDCAS`; SIH `DIAG_PRINC`,
    `DIAG_SECUN`, `DIAGSEC1`…`9`, `CID_ASSO`, `CID_MORTE`; SIM `CAUSABAS`, `CAUSABAS_O`,
    `LINHAA`…`LINHAD`, `LINHAII` com regex `(^|\*)(L73|L02)` (a camada sai depois, pela lookup).
  - `[CONFIRMAR no config_filtro.R]` se há forma de ativar **só** os escopos HS. Sem isso, a
    saída em `datasus_filtrado_hs/` repetiria os 65,7 milhões de linhas do EIM. Se não
    houver, acrescentar `ESCOPOS_ATIVOS` (variável de ambiente) ao `filtrar_um.R`.
- **Envelope L02 no SIA vira agregado na leitura** (guia §6.1): o L02 em BPA-I/APAC é
  volumoso e inespecífico. Em vez de gravar linhas, `filtrar_um.R` grava
  `agregado_hs_env/<ARQ>.parquet` com contagem de linhas e Σ`PA_QTDAPR` por `PA_CMP` × UF
  de residência × sexo × faixa × subcódigo L02 × grupo do procedimento × `PA_DOCORIG`. No
  SIH, manter linhas de L02 (volume moderado), mas decidir com o número do piloto.
- **Comorbidades:** não criar escopo de linhas para E66, F17 etc. Elas já vêm nas colunas
  secundárias da própria AIH-HS. Opcional: um agregado de referência (AIH com cada
  comorbidade em qualquer secundário, por UF × ano × sexo × faixa, sobre **todas** as AIH)
  para comparar a proporção nas AIH-HS com a do conjunto (seção 4.4).
- **Denominador HS extra (opcional, recomendado):** Σ`PA_QTDAPR` por competência × UF ×
  `PA_DOCORIG` para CBO de dermatologista (`225135`; `223117` está em uso no script CNES,
  `[VERIFICAR]` se é código CBO válido no período). Permite "proporção da produção
  dermatológica com L732", mesmo sabendo que o BPA-C não tem CID.
- **Piloto:** `OUT=~/Documentos/ronald/datasus_filtrado_hs bash scripts/r550/orquestrar_filtro.sh --base todas --uf PE --ano-min 2021 --ano-max 2021`,
  mais `--uf SP --ano-min 2021 --ano-max 2021` só para SIH (PE 2021 tem só 2 AIH-HS, pouco
  para validar), e a passada inteira do SIM (459 arquivos, rápida).
- **Critérios de aceite** (comparar por **mês de processamento**, porque o piloto lê
  arquivos de 2021, e não por `PA_CMP`):

| Base | Chave de comparação | Referência v1 | Aceite |
|---|---|---|---|
| SIA PE | linhas e Σ`PA_QTDAPR` por `PA_MVM` 202101–202112, `PA_CIDPRI == L732` | v1: 268 linhas e 832 unidades em `PA_CMP` 2021 (a recalcular por `PA_MVM` na E0) | idêntico; `anti_join` por (`PA_CODUNI`, `PA_CMP`, `PA_PROC_ID`, `PA_AUTORIZ`, `PA_IDADE`, `PA_SEXO`, `PA_QTDAPR`) vazio nos dois sentidos |
| SIH SP e PE | `N_AIH` distintas com `DIAG_PRINC == L732` | v1 (PE 2021: 2 AIH) | idêntico |
| SIM 2020–2024 | óbitos com L732 em qualquer campo, por ano | v1: 8, 8, 9, 24, 16 | igual, ou diferença explicada caso a caso (regex de causas múltiplas pode achar mais, nunca menos) |

- **Riscos:** UFs com arquivos em partes (`a`, `b`…); diferença por republicação do DATASUS
  entre o download do usuário e o do R550-2 (conferir tamanho no manifesto); acentos
  (não reconverter latin1).

### E4. Passada completa para `datasus_filtrado_hs/` (0,5 d + cerca de 3 h de máquina)

- **Objetivo:** filtrados HS 2010+ de SIA, SIH, SIM (SINASC não é necessário).
- **Entradas:** E3 aprovado.
- **Saídas:** `~/Documentos/ronald/datasus_filtrado_hs/<BASE>/{filtrado,denominador,agregado_hs_env,ok}/`,
  `status_filtro.tsv`.
- **Execução:** em tmux, `--dry-run` primeiro; `--base SIA-PA,SIH-RD,SIM-DO` se o
  orquestrador aceitar lista `[CONFIRMAR]`; incluir os mensais de 2026 (fecham as
  competências de 2025) e `SIM-DO/PRELIM` (2025).
- **Aceite:** zero arquivos com erro em `status_filtro.tsv`; número de arquivos igual ao
  manifesto (SIA 5.806, SIH 5.398, SIM 459, ou o que o manifesto atual disser); linhas lidas
  iguais às da passada EIM (6,74 bilhões no SIA etc.), porque o denominador é o mesmo.
- **Riscos:** reaproveitar `datasus_filtrado/` por engano (o `.ok` pularia tudo); memória em
  SIA-SP (pico de 4,2 GB por processo no EIM; com 24 jobs cabe).

### E5. Catálogo de schema e completude dos campos HS (0,5 d)

- **Objetivo:** saber, por base × ano, se cada campo usado existe e é preenchido (guia §5).
- **Entradas:** `schema_resumo.tsv`, filtrados HS.
- **Saídas:** `manifest/completude_hs_por_ano.csv`: `PA_CIDPRI` válido, `PA_RACACOR`,
  `PA_MUNPCN`, `PA_AUTORIZ`, `PA_CBOCOD`; SIH secundários preenchidos **nas AIH-HS** e no
  total; SIM `LINHAII`.
- **Aceite:** tabela usada como nota obrigatória nas figuras de série por raça/cor, por
  comorbidade e por "qualquer campo".
- **Riscos:** interpretar ganho de preenchimento como tendência (raça/cor de 36% para 94%
  no SIA total; secundários do SIH de 8% para 29%).

### E6. Denominador IBGE Projeções Revisão 2024 (0,5 d)

- **Objetivo:** população anual UF × sexo × faixa 2010–2025 de série única.
- **Entradas:** `projecoes_2024_tab2_grupo_quinquenal.xlsx` (URL no guia §9).
- **Saídas:** `data/denominators/pop_ibge.parquet` (mesmo nome, `base_pop = "proj2024"`),
  população-padrão Brasil 2022 da própria projeção.
- **Scripts:** substituir `get_denominadores_ibge.R` pelo do EIM (guia diz que serve sem
  mudanças). Remover `sidrar` das dependências se nada mais o usar.
- **Aceite:** 27 × 16 anos × 2 × 17 = 14.688 linhas, zero faixa NA; níveis de `faixa`
  idênticos a `harmonizar_faixa()`; total Brasil por ano impresso; `POP_PADRAO` renomeado
  para `"proj2024_br2022"`.
- **Riscos:** a padronização muda um pouco porque a população-padrão deixa de ser o Censo e
  passa a ser a projeção de 2022 (diferença pequena, mas os números da v1 não se
  reproduzem exatamente; registrar nas notas de lançamento).

### E7. Consolidação SIA (2 d)

- **Objetivo:** substituir `get_hs_data_from_SIA.R` por versão que lê os filtrados.
- **Molde EIM:** `get_eim_data_from_SIA.R`.
- **Entradas:** filtrados SIA com `hit_hs`/`hit_hs_proc`, `HS_LOOKUP`.
- **Saídas:** `data/parquet/sia_hs/` (ano + uf), com colunas novas `camada`, `canal`,
  `status_dado`; `data/consolidated/sia_hs_agregado_env.parquet`;
  `data/consolidated/sia_adalimumabe_todos_cid.parquet` (agregado, para auditoria de CID).
- **Regras novas:**
  - ano analítico = ano de `PA_CMP`; descartar `PA_CMP` fora de 201001–202512;
  - `as.numeric()` em `PA_QTDAPR`, `PA_VALAPR`, `PA_VALPRO` antes de somar; não chamar
    `corrigir_encoding()`;
  - `canal`: `medicamento` (`PA_PROC_ID` 06.04 em APAC), `clinico_apac` (APAC sem
    medicamento), `clinico_bpai` (`I`); BPA-C (`C`) não tem CID e não entra no numerador;
    reportar a fração do volume total que I/P/S representam (do denominador agregado);
  - métricas separadas: linhas, Σ`PA_QTDAPR` e APAC distintas (`PA_AUTORIZ`) por mês;
  - residência = `PA_MUNPCN`; estabelecimento = `PA_UFMUN`; partição por UF de residência,
    não `uf_arquivo` (hoje a partição usa a UF do arquivo).
- **Aceite:** recorte 2020–2025 com `PA_CIDPRI == L732` igual à v1 por `PA_CMP`, exceto
  competências de 2025 processadas em 2026 (a v2 deve ter **mais**, nunca menos);
  auditoria: 25 procedimentos mais frequentes por canal e período, idade mediana, % feminino.
- **Riscos:** município da APAC do CEAF pouco confiável (guia §8.2, PE quase tudo Recife):
  mapas de medicamento por UF, não por município.

### E8. Consolidação SIH (1,5 d)

- **Objetivo:** série 2010–2025 com dois sabores.
- **Molde EIM:** `get_eim_data_from_SIH.R`.
- **Saídas:** `data/parquet/sih_hs/` com `sabor_principal` (lógico), `sabor_qualquer`,
  `camada_principal`, matriz `com_*` das comorbidades a partir da lookup.
- **Regras:** unidade = `N_AIH` distinta; `IDENT == 5` como continuação `[CONFIRMAR no
  dicionário]`; ano = `ANO_CMPT`; idade por `IDADE` + `COD_IDADE` (4 anos, 3 meses, 2 dias,
  1 horas, 0 minutos; completar `idade_em_anos()`, que hoje trata só 2–4); sexo 1 = M,
  3 = F (o código atual também aceita 2, manter e contar quantos); residência `MUNIC_RES`,
  hospital `MUNIC_MOV`; `as.numeric()` em `VAL_TOT`, `VAL_SH`, `VAL_SP`, `DIAS_PERM`.
- **Série primária** = sabor principal. "Qualquer campo" só como teto, com a completude da
  E5 ao lado. Comorbidade "registrada na AIH", nunca prevalência.
- **Aceite:** 2020–2025 sabor principal igual à v1 (631 AIH distintas); procedimentos
  `PROC_REA` mais frequentes por período; idade mediana coerente com adulto jovem.
- **Riscos:** valores monetários nominais em 16 anos; para comparar gasto ao longo do
  tempo, deflacionar (IPCA) e declarar o ano-base `[DECIDIR]`.

### E9. Consolidação SIM (1 d)

- **Objetivo:** óbitos com HS 2010–2024 definitivos e 2025 preliminar separado.
- **Molde EIM:** `get_eim_data_from_SIM.R`.
- **Saídas:** `data/consolidated/sim_hs.parquet` com `hs_causa_basica` (núcleo),
  `hs_cb_ampliado` (inclui limítrofe), `hs_qualquer`, `status_dado`.
- **Regras:** regex `(^|\*)(prefixos)` em todas as linhas; idade por
  `decode_idade_sim()` sobre o `IDADE` bruto (o código atual depende de `idade_decode` do
  microdatasus, que no bruto não existe); sexo 1/2; residência `CODMUNRES`; 2025 vem de
  `SIM-DO/PRELIM` do R550-2 em vez do CSV do opendatasus (mesmo schema), com o opendatasus
  só como conferência.
- **Aceite:** 2020–2024 em qualquer campo ≥ v1, diferenças listadas; composição do
  numerador (25 CIDs mais frequentes na causa básica dos óbitos com HS em qualquer linha).
- **Riscos:** N muito pequeno; sem taxa de mortalidade por HS (contagens e proporções,
  supressão N < 5).

### E10. CNES: dermatologistas 2010–2025 (1 d + download)

- **Objetivo:** oferta especialista ao longo de toda a série.
- **Entradas:** CNES-PF, um mês de referência por ano (hoje junho).
- **Saídas:** `data/denominators/dermatologistas_uf.parquet` 2010–2025, densidade sobre a
  população projetada **do mesmo ano** (hoje divide pelo Censo 2022 fixo).
- **Scripts:** adaptar `get_dermatologistas_cnes.R`. O CNES-PF não está entre as bases já
  baixadas no R550-2 (guia §2); o guia desaconselha `fetch_datasus` para download. Opção:
  incluir `CNES/PF` no manifesto do `gerar_manifesto.py` `[VERIFICAR diretório FTP]` e ler
  com `read.dbc`.
- **Aceite:** 27 × 16 pares sem faltante; mesma regra de profissional único (`CNS_PROF`).
- **Riscos:** códigos CBO de dermatologista mudam de uso no período `[VERIFICAR 223117]`.

### E11. Pseudo-ID na série longa e pacientes em tratamento (2 d)

- **Objetivo:** intervalo de pessoas e indicador de tratamento.
- **Molde EIM:** `pseudo_id_motor.R` (substitui `feature_eng_pacientes_SIA.R`).
- **Mudanças em relação ao atual:**
  - ligação certa por `PA_AUTORIZ` + sexo nas APAC (P/S) antes da ligação por
    quase-identificadores;
  - raça/cor ausente vira categoria "NI", não paciente próprio (hoje 14.097 linhas viram
    "pacientes" isolados e inflam o limite superior);
  - rodar por janela: (a) 2020–2025, para comparar com a v1; (b) janelas anuais;
    (c) 2010–2025 inteiro só como sensibilidade, porque migração e mudança de raça/cor em
    16 anos aumentam a fragmentação;
  - corrigir o texto do manuscrito: o método é determinístico, não probabilístico.
- **Indicador novo:** pacientes em tratamento com adalimumabe = mediana mensal de
  `PA_AUTORIZ` distintas com o medicamento, por ano e UF (guia §8.2).
- **Aceite:** intervalo frouxa–estrita publicado; tamanho máximo de cluster depois do cap;
  razão registros/pseudo-paciente por canal.
- **Riscos:** LGPD; nenhuma chave sai do servidor; só agregados por UF/região.

### E12. Taxas, tendência e série interrompida (3 d)

- **Objetivo:** séries padronizadas 2010–2025 e teste do marco de incorporação.
- **Molde EIM:** `calcular_taxas.R` + `utils.R` (`contar_estrato()` com aviso de perda,
  `taxas_padronizadas()` restrita aos anos do numerador, `suprimir_taxa()`,
  `tendencia_poisson(excluir_covid = TRUE)`).
- **Saídas:** `data/consolidated/taxas_hs.parquet`, `data/consolidated/tendencias_hs.csv`,
  `data/consolidated/its_hs.csv`; todos já com supressão.
- **Modelos:** ver seção 4.2.
- **Aceite:** nenhum ano no resultado sem numerador; IC que cruza zero rotulado "sem
  tendência"; sensibilidade sem 2020–2022 sempre ao lado.
- **Riscos:** sobreajuste ao escolher o ponto de quebra olhando o dado (pré-especificar).

### E13. Produtos (site, manuscrito, apresentação, documentação) (5 a 8 d)

Ver seção 5.

### E14. Publicação e notas de lançamento (0,5 d)

- `qmd/notas_lancamento.qmd`: o que mudou da v1 para a v2 (período, fonte dos brutos,
  canais do SIA, denominador, população-padrão, regex do SIM, pseudo-ID).
- Varredura do HTML: `NA` solto, código R vazado, "2020–2025" fora das notas (guia §12).

---

## 4. Questões epidemiológicas específicas da série longa

### 4.1 O SIA precisa ser lido em canais

O numerador atual mistura três fenômenos com dinâmicas próprias:

| Canal | O que mede | Unidade recomendada | Comportamento esperado |
|---|---|---|---|
| Medicamento (APAC 06.04, adalimumabe) | pessoas em tratamento de alto custo | APAC distintas por mês (mediana anual); seringas (Σ`PA_QTDAPR`) | inexistente ou quase zero antes da incorporação; cresce depois; substituição por biossimilar a partir de 2022 (já visto na v1) |
| Clínico (BPA-I e APAC sem medicamento) | detecção clínica com CID registrado | Σ`PA_QTDAPR` e linhas | depende de quais procedimentos exigem BPA-I em cada versão do SIGTAP |
| Envelope L02 | abscessos (teto de subcodificação) | agregado | dominado por abscesso banal; serve para razão L02/L732 como **indicador de padrão de codificação**, não de atraso diagnóstico |

Taxa "de detecção" passa a ser a do canal clínico. A do canal medicamento é taxa de
tratamento. Não somar.

**Atenção:** mudança de instrumento de registro de um procedimento (BPA-C para BPA-I, ou o
contrário) cria degrau artificial no canal clínico. Conferir pelo denominador agregado
(`PA_DOCORIG` × grupo do procedimento) e pela tabela de vigência da E1.

### 4.2 Quebra estrutural pré/pós incorporação

- **Marco:** duas datas, ambas registradas: a normativa (E1, `[VERIFICAR]`) e a empírica
  (primeira competência com APAC de adalimumabe e `PA_CIDPRI == L732` acima de um limiar
  nacional, por exemplo 10 APAC/mês). A análise primária usa a data normativa
  pré-especificada; a empírica entra como sensibilidade. Se houver APAC L732 antes da
  incorporação, é sinal de judicialização ou de uso por outra via e deve ser descrito, não
  descartado.
- **Modelo primário (série interrompida, mensal por `PA_CMP`):** quasi-Poisson ou binomial
  negativa, `eventos ~ t + pos + t_pos + harmônicos(mês) + covid + offset(log(pop))`, com
  `pos` = mudança de nível e `t_pos` = mudança de inclinação. População mensal por
  interpolação linear da projeção anual (ou anual/12; declarar). Reportar razão de taxas de
  nível e variação anual antes e depois, com IC 95%.
- **Aplicar a três séries, separadamente:** canal clínico do SIA (a pergunta central:
  a incorporação aumentou a **codificação** de L73.2 fora da dispensação?), SIH sabor
  principal (a incorporação mudou a carga cirúrgica e de internação?) e, para descrição,
  o canal medicamento (que por construção nasce no marco).
- **Exploratório:** joinpoint (`segmented` em R, ou o Joinpoint do NCI) sobre a série anual
  padronizada, para ver se os pontos de quebra achados coincidem com o marco. Não usar o
  joinpoint para escolher o marco.
- **Segundo evento:** a entrada dos biossimilares (2022 em diante, visto na v1) afeta o
  canal medicamento; covariável nesse canal, não nos demais.
- **Variação por UF:** modelo com efeito de UF (ou estratificado por região) para ver se o
  efeito da incorporação depende da oferta de dermatologistas (E10). Leitura ecológica.

### 4.3 COVID como sensibilidade

- Período anômalo padrão: 2020–2022 (guia §10), não 2020–2021 como em `00_setup.R`.
  Mudar `ANOS_COVID` para `2020:2022` e manter 2020–2021 como segunda sensibilidade, se
  quiser comparar com a v1.
- No modelo mensal: indicadora para março de 2020 a dezembro de 2021 (ou 2022) em vez de
  excluir; nas tendências anuais, `excluir_covid = TRUE`.
- Na série longa a pergunta deixa de ser "quanto cresceu desde 2020" e passa a ser "a
  pandemia interrompeu uma tendência que já existia?". A frase do manuscrito sobre
  "recuperação de demanda reprimida" precisa ser testada contra a tendência 2010–2019.

### 4.4 Mudanças de preenchimento

| Campo | Efeito | Tratamento |
|---|---|---|
| `PA_RACACOR` | de 36% (2010) para 94% preenchido no SIA total (guia §5) | distribuição por raça/cor só a partir do ano em que a completude nas linhas HS passar de um limiar (por exemplo 80%), com a completude impressa |
| `PA_CIDSEC` | 7–8% até 2014, depois quase 0 | não usar na série; auditoria apenas |
| SIH secundários | `DIAG_SECUN` até 2014, `DIAGSEC1–9` depois; preenchimento de 8% para 29% | "qualquer campo" e comorbidade sempre com a completude ao lado; comparar a proporção de comorbidade nas AIH-HS com a de todas as AIH do mesmo estrato (agregado opcional da E3) |
| SIM `LINHAII` | 37% para 51% | "qualquer linha" cresce um pouco só por isso |

### 4.5 Pseudo-ID na série longa

- A censura à esquerda diminui: com 2010–2019 como período de observação prévia, a "idade
  na primeira detecção" a partir de 2020 tem dez anos de histórico. Continua sendo primeira
  detecção na janela, não diagnóstico.
- A fragmentação cresce com a janela (mudança de município, de raça/cor, de faixa de idade
  declarada). Por isso a contagem de pessoas em 16 anos é só sensibilidade; o número
  publicado é por ano ou por janela de até 6 anos.
- Com `PA_AUTORIZ`, o canal medicamento tem ligação quase certa dentro da mesma APAC; o
  canal clínico continua dependendo de quase-identificadores.

### 4.6 O que 2010–2019 permite responder e 2020–2025 não permitia

1. Linha de base pré-incorporação da detecção clínica de L73.2 no SUS.
2. Se a incorporação do adalimumabe mudou a codificação (efeito "o CID passa a ser exigido")
   ou só abriu um canal de registro novo.
3. Tendência pré-pandemia, para separar choque COVID de tendência.
4. Carga cirúrgica e de internação por 16 anos (SIH), incluindo se ela caiu depois da oferta
   do biológico. Leitura ecológica, sem inferência de efeito do tratamento.
5. Evolução das desigualdades regionais e da oferta de dermatologistas (convergência ou
   não), que hoje é afirmada no manuscrito ("no convergence") com seis anos de dado.
6. Mais óbitos acumulados no SIM (ainda descritivo).
7. Menos censura à esquerda no pseudo-ID.

O que continua impossível: prevalência, incidência, atraso diagnóstico individual, efeito
causal do adalimumabe.

---

## 5. Impacto nos produtos

**Regra geral:** todo número, ano, razão ("~250×", "seis vezes", "88%", "r = 0,71"),
título e subtítulo de figura sai de R inline ou de uma função de acesso
(`qmd/_numeros.R`, molde `qmd/_discussao_numeros.R` do EIM). Textos longos em `ref/*.md` com
`{{< include >}}`. Render de uma página por comando.

| Produto | O que muda | Esforço |
|---|---|---|
| `qmd/_common.R` | carregar os novos parquet e o `pop_ibge` da projeção; trocar `D$sens`; carregar `_numeros.R` | 0,5 d |
| `qmd/index.qmd` | KPIs por canal; figura de tendência 2010–2025 com marco de incorporação e faixa COVID; tirar o "~250×" escrito à mão | 0,5 d |
| `qmd/sia_hs.qmd` | reorganizar em canais (clínico, medicamento, envelope); taxas sobre o canal clínico; seção nova de série interrompida; seção do adalimumabe 2010–2025 com pacientes em tratamento; o callout de padronização passa a citar a projeção 2022 | 1,5 d |
| `qmd/sih_hs.qmd` | dois sabores; comorbidade com completude por ano; gasto deflacionado; trocar "~16%" e "SP ~32%" por inline | 1 d |
| `qmd/sim_hs.qmd` | causa básica × qualquer linha 2010–2024; 2025 preliminar em quadro à parte | 0,5 d |
| `qmd/consideracoes_finais.qmd` | reescrever: hoje tem números à mão (88%, 16.401, 1.496, 35.112, 25–31 mil, seis vezes, 11/100 mil) e a leitura de "uso de serviço" precisa incorporar os canais | 1 d |
| `qmd/notas_lancamento.qmd` | nova | 0,3 d |
| `_quarto.yml` | descrição e rodapé ("Censo 2022", "2020–2025") | 0,1 d |
| `manuscript/` | o desenho muda (série interrompida, 2010–2025). Reescrever Methods (fonte dos brutos, denominador, pseudo-ID determinístico) e Results; refazer `figures/*.R` e `tables/*.R` a partir dos novos consolidados; `CONTEXT.md` atualizado primeiro, porque é a fonte dos agentes de redação. Ideal: converter `manuscript.md` em `.qmd` para ter números inline | 3 a 5 d |
| Apresentação (`apresentacao_HS_15min.*`, `scripts/gerar_apresentacao.R`, `doses_adalimumabe.R`, `mapa_biossimilares.R`) | figuras com o novo período; o mapa "2020 vs 2025" vira "primeiro ano pós-incorporação vs 2025"; regenerar o pptx | 1 d |
| `CLAUDE.md` | reescrever §1 (período), §3 (parâmetros: `ANOS`, `ANOS_SIM`, `DIR_FILTRADO`, `ANOS_COVID`, `POP_PADRAO`), §4 (estrutura), §5 (lookup, canais, sem latin1, texto → número), §6 (runbook R550-2), §7/§7.1 (os brutos pré-filtrados passam a ser legado); corrigir a afirmação de que o eixo do adalimumabe é inviável | 0,5 d |
| `datasus_hs.md` | §2 (camadas com diferencial separado), §5 (denominador), §6 (canais, série interrompida), §8 (atos fixados na E1), §9.11–12 (COVID 2020–2022, sem degrau de Censo), §10 (fases) | 0,5 d |

---

## 6. Decisões pendentes

| # | Decisão | Opções | Recomendação |
|---|---|---|---|
| 1 | Onde rodar | R550-2 × local | Filtragem, consolidação e pseudo-ID no **R550-2** (os 209 GB de DBC estão lá; o pseudo-ID não deve sair do servidor). Copiar para o local só os consolidados e agregados já suprimidos. Render pode ser local, se o ambiente local reproduzir o `renv` |
| 2 | Ano final SIA/SIH | 2025 × incluir 2026 parcial | **2025**, lendo os arquivos de 2026 para fechar competências de 2025. Sem 2026 parcial nas taxas |
| 3 | Ano inicial | 2010 × 2008 | **2010**, porque é o que existe no R550-2 e já dá quase uma década antes do marco. Reavaliar 2008 só se o marco empírico cair antes de 2013 |
| 4 | SIM 2025 | opendatasus CSV × `SIM-DO/PRELIM` | **PRELIM do R550-2** como fonte, opendatasus como conferência; nunca nas taxas |
| 5 | Brutos 2020–2025 atuais | apagar × manter | **Manter congelados** (checksum na E0) até a v2 passar na E3 e ser publicada; depois arquivar fora do OneDrive. Não apagar: são a referência de validação |
| 6 | Envelope L02 | linhas × agregado | **Agregado no SIA**; linhas no SIH se o piloto mostrar volume administrável (definir limiar, por exemplo < 2 milhões de linhas em 16 anos) |
| 7 | L730/L731 | dentro de "L73x" × separados | **Separados** como diferencial; limítrofe = L738/L739 |
| 8 | Comorbidades | escopo de linhas × só dentro da AIH-HS | **Só dentro da AIH-HS**, com o agregado de referência opcional |
| 9 | Marco da série interrompida | normativo × empírico | **Normativo pré-especificado**, empírico como sensibilidade; fixar antes de olhar o modelo |
| 10 | Período COVID | 2020–2021 × 2020–2022 | **2020–2022** na sensibilidade principal (alinhado ao guia) |
| 11 | Unidade do SIA | linhas × Σ`PA_QTDAPR` × APAC distintas | Σ`PA_QTDAPR` no canal clínico; APAC distintas por mês no canal medicamento; linhas só como auditoria |
| 12 | Valores monetários | nominal × deflacionado | **Deflacionar pelo IPCA** com ano-base declarado nas séries de gasto |
| 13 | Manuscrito | atualizar o atual × novo artigo | O desenho muda; tratar como **nova versão com título novo** (2010–2025, série interrompida). Se o artigo 2020–2025 já estiver submetido, não misturar |
| 14 | Site publicado | substituir × manter v1 | Substituir, com notas de lançamento e link para a tag v1 |

---

## 7. Sequência, dependências e esforço

```
E0 ──► E1 ──► E2 ──► E3 (piloto) ──► E4 (passada) ──► E5
                                      │
E6 (independente; pode rodar já) ─────┤
E10 (precisa só de E6) ───────────────┤
                                      ├─► E7 SIA ──► E11 pseudo-ID ─┐
                                      ├─► E8 SIH ───────────────────┤
                                      └─► E9 SIM ───────────────────┴─► E12 taxas/ITS ──► E13 produtos ──► E14
```

| Etapa | Depende de | Esforço (d-pessoa) | Máquina |
|---|---|---|---|
| E0 congelar v1 | — | 0,5 | — |
| E1 normativo e SIGTAP | E0 | 1,5 | — |
| E2 lookup | E1 | 1 | — |
| E3 escopo e piloto | E2 | 1,5 | cerca de 1 h |
| E4 passada completa | E3 | 0,5 | cerca de 3 h |
| E5 completude | E4 | 0,5 | — |
| E6 denominador | — | 0,5 | minutos |
| E7 SIA | E4, E6 | 2 | — |
| E8 SIH | E4, E6 | 1,5 | — |
| E9 SIM | E4, E6 | 1 | — |
| E10 CNES | E6 | 1 | download |
| E11 pseudo-ID | E7 | 2 | — |
| E12 taxas e ITS | E5, E7–E11 | 3 | — |
| E13 produtos | E12 | 5 a 8 | — |
| E14 publicação | E13 | 0,5 | — |
| **Total** | | **cerca de 22 a 25** | |

E6 e E10 podem andar em paralelo com E1–E4. E1 pode começar já, porque não depende de dado.

---

## 8. Inconsistências encontradas entre o guia EIM e o código HS atual

1. **Denominador constante.** `get_denominadores_ibge.R` replica o Censo 2022 em todos os
   anos (decisão documentada no script), que o guia §9 lista como erro. `datasus_hs.md` §5
   também pede retrointerpolação, contradizendo o script.
2. **Unidade do SIA.** `CLAUDE.md` §5 manda somar `PA_QTDAPR`; `contar_estrato()` e os
   `.qmd` contam linhas. Como 88% das linhas são APAC de adalimumabe, a "taxa de detecção"
   publicada é sobretudo taxa de dispensação.
3. **Anos-fantasma.** `taxas_padronizadas()` parte da população e preenche `n = 0`; com
   `ANOS = 2010:2025` e SIM até 2024, criaria 2025 com zero óbitos (guia §10).
   `contar_estrato()` descarta linhas sem UF/sexo/faixa sem avisar.
4. **Pseudo-ID.** Registros sem raça/cor viram pacientes próprios (guia §11: "erro que já
   cometemos"); não usa `PA_AUTORIZ`. O manuscrito e `manuscript/CONTEXT.md` chamam o
   método de "probabilistic record linkage", mas o código é determinístico.
5. **Adalimumabe.** `CLAUDE.md` §7.1 e `datasus_hs.md` §2 dizem que o eixo do adalimumabe é
   inviável por falta de `pa_cidpec`, mas `doses_adalimumabe.R` e `sia_hs.qmd` o analisam
   pelos códigos `0604380062`, `0604380127` e `0604380135`. A documentação está
   desatualizada.
6. **Camada L73x.** `camada_cid()` junta L730 (acne queloideana) e L731 (pseudofoliculite)
   com L738/L739. Pelo guia §7, os dois primeiros são diferenciais, não subcodificação.
7. **COVID.** `ANOS_COVID <- c(2020, 2021)` em `00_setup.R`; o guia usa 2020–2022.
8. **Idade no SIH.** `idade_em_anos()` trata só `COD_IDADE` 2–4; o guia lista também 1
   (horas) e 0 (minutos). Irrelevante para HS na prática, mas a função é compartilhada.
9. **SIM 2025 preliminar.** 31 óbitos com L732 contra 16 em 2024 e 8–24 nos anos
   anteriores. Pode ser real ou artefato da leitura do CSV opendatasus processado com
   `process_sim()`; auditar antes de exibir.
10. **Densidade de dermatologistas.** `get_dermatologistas_cnes.R` divide pelo Censo 2022
    em todos os anos, o que repete o problema do item 1.
11. **Partição do SIA por UF do arquivo** (`uf_arquivo`, UF do estabelecimento) enquanto as
    taxas usam UF de residência (`uf_pcn`). Não é erro, mas confunde quem consulta o
    parquet; a v2 deve particionar por residência e guardar as duas.
12. **Números à mão.** `consideracoes_finais.qmd` (88%, 16.401, 1.496, 35.112, 25–31 mil,
    seis vezes, 11/100 mil), `index.qmd` ("~250×"), `sih_hs.qmd` ("~16%", "SP ~32%") e o
    manuscrito (158.850, 4.388 → 52.678, 25.325–30.675, r = 0,71) violam o guia §12 e vão
    ficar errados com a nova série.
13. **Encoding.** `utils.R` mantém `corrigir_encoding()`; nos filtrados 2010+ ele não pode
    ser chamado (guia §6.5). Hoje não é chamado nos `get_*`, mas convém remover ou proteger
    a função para evitar uso acidental.
