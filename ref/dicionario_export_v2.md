# Dicionário do export v2 (`data/export/`)

Gerado no R550-2 por `scripts/exportar_agregados_hs.R` e copiado para o local por `rsync`.
É o **único insumo** do site (`qmd/`), da apresentação e do manuscrito. Contém só agregados
nacionais, por região ou por UF; nenhum microdado, chave de pseudo-ID ou município.
`hs_v2_agregados.rds` é uma lista R com as mesmas tabelas de `csv/`, mais `tot` (totais
nacionais) e `meta` (data, hash da lookup, marco, versão do R).

## Regras de supressão (LGPD)

- **Contagem de evento entre 1 e 4 → `NA`.** "Evento" é registro, quantidade aprovada, AIH,
  óbito ou paciente. **`0` é zero de fato** (sem evento), nunca supressão.
- **Tabelas de taxa** (`taxas`, `uf_clinico_2014`, `sih_uf`, `br_pool`): o numerador
  (`eventos`) é suprimido **junto** com a taxa e o IC, e `motivo_supressao` diz por que a taxa
  é `NA`: `"N < 5"` (suprimida) ou `"sem evento"` (eventos = 0).
- **Totais em `tot`** que sejam contagens pequenas também são `NA` (ex.: `sim_cb_def`, o
  óbito com HS como causa básica; `sih_obitos`). Texto e figuras escrevem "<5".
- **Sem subtotais que permitam recuperar célula por diferença:** `sih_comorb` só tem o período
  inteiro; `completude` usa `pct_hs = NA` quando `n_hs` é suprimido.
- O export **falha** (`verificar_supressao()`) se qualquer coluna de contagem tiver valor
  entre 1 e 4. Única exceção: `derm_uf` (profissionais no CNES, cadastro público; ver abaixo).

## Fontes canônicas (uma por quantidade)

| Quantidade | Use | Não derive de |
|---|---|---|
| Totais nacionais (registros, AIH, óbitos, % feminino, idades, permanência, % urgência) | `tot` | somas de tabelas estratificadas (perdem as células suprimidas) |
| Gasto do SIH | `sih_custo` (soma `VAL_TOT` de **todas** as linhas da AIH; igual a `tot$sih_gasto_nominal`); deflator em `data/denominators/ipca_anual.parquet` | — |
| Participação nacional por código de adalimumabe | `biossimilar_br` | `biossimilar_uf` (20 células suprimidas) |
| Caráter da internação, nacional | `sih_carater_br` | `sih_carater` (por ano, com supressão) |
| Permanência no SIH | `sih_perm_resumo` (p25, mediana, p75, p90) | `sih_perm` (histograma; cauda suprimida) |
| Série anual do SIH (observado) | `serie_ano$sih_principal` | `its_ajuste` (o observado mensal do SIH não é publicado) |

## Tabelas

| Tabela | Conteúdo | Notas |
|---|---|---|
| `serie_ano` | ano × séries nacionais: SIA clínico (linhas, Σ qtd), SIA adalimumabe (linhas, seringas, pacientes/mês), SIH (principal, qualquer campo), SIM (qualquer campo, causa básica) | `status_sim` = DEFINITIVO/PRELIM; 2025 do SIM é preliminar |
| `taxas` | taxas padronizadas/brutas por `serie` × `nivel` (BR, região, `uf_pool` = UF em pessoa-anos) | `sia_tratamento`: `eventos` = mediana mensal de pacientes |
| `br_pool` | referência nacional em pessoa-anos (clínico 2014–2025; SIH 2010–2025) | taxa direta do país, não média das UFs |
| `uf_clinico_2014` | taxa clínica padronizada por UF (2014–2025) + `derm_100k` | **`derm_100k` = média aritmética das densidades anuais 2014–2025**, não o valor de 2025. AP e RR têm taxa `NA` por N < 5: a correlação com dermatologistas usa 25 UFs |
| `tendencias` | variação anual % (quasi-Poisson), com e sem 2020–2022 e só até 2019 | IC que cruza 0 = "sem tendência" |
| `its` | série interrompida: nível, inclinação antes/depois, por cenário | SIH: estimado na série mensal completa no R550-2; não reproduzível a partir do export (ver `its_ajuste`) |
| `its_ajuste` | mensal: observado, ajustado e contrafactual | **SIH: `eventos` = NA em todos os meses** (o observado mensal cairia quase todo em 1–4 AIH); publicar só ajustado/contrafactual e o observado anual (`serie_ano`). A ITS do SIH é análise secundária |
| `derm_producao` | produção dos dermatologistas (CBO 223117/225135), BPA-I e com L73.2 | normalização do canal clínico |
| `cobertura_cid` | % do volume do SIA-PA em instrumento com CID | |
| `piramide` | faixa × sexo por base | estratos extremos suprimidos; totais em `tot` |
| `raca` | canal × período × raça/cor | preenchimento varia no tempo (`completude`) |
| `completude` | % de preenchimento por campo × ano, nos registros HS (`pct_hs`) e no total da base (`pct_total`) | SIA/SIH 2010–2025; SIM só 2010–2024 |
| `heatmap` | canal × ano × UF | |
| `derm_uf` | dermatologistas por UF × ano (CNES-PF, junho), por 100 mil | **fora da regra de supressão** (cadastro público de profissionais, não evento de saúde); `n_por_cbo` decompõe por CBO |
| `trat_uf` | pacientes/mês em adalimumabe por UF × ano | |
| `fluxo` | canal × UF × local de atendimento | categorias suprimidas somem do denominador da proporção |
| `proc` | canal × período × procedimento SIGTAP | |
| `biossimilar_uf`, `biossimilar_br` | dispensações de adalimumabe para HS por código (UF × ano; Brasil × ano) | use `biossimilar_br` para o nacional |
| `adalimumabe_todos_cid` | todas as linhas de adalimumabe do SIA-PA, `l732` = é HS | |
| `envelope` | L02 no CID principal, por ano × subcódigo | teto de subcodificação, nunca caso |
| `camadas_sia` | registros L73 por ano × camada | |
| `pseudo` | pseudo-pacientes por janela × recorte | intervalo [frouxa; estrita]; método determinístico |
| `sih_*`, `sim_*` | perfil do SIH e do SIM | ver fontes canônicas acima |

## Canais do SIA (`canal`, nos registros do núcleo L732)

| Canal | Regra |
|---|---|
| `medicamento` | APAC (`PA_DOCORIG` P/S) de adalimumabe |
| `clinico_apac` | APAC sem medicamento |
| `clinico_bpai` | BPA-I (`PA_DOCORIG` I) |
| `outro` | demais instrumentos com CID: **6 registros** (2014: 4; 2015: 2), todos `PA_DOCORIG = "A"` (RAAS `[VERIFICAR no dicionário do SIA]`), procedimentos 0101030010, 0301010137, 0301050082 e 0301050147. Ficam fora dos dois canais; por isso clínico + medicamento = 168.135 e o núcleo = 168.141 |

BPA consolidado (`C`) não tem CID e não entra em nenhum canal.

## Reprodutibilidade

- Versões do R e dos pacotes da rodada do R550-2: `manifest/sessioninfo_v2_r550.txt`.
  Do render local do site: `manifest/sessioninfo_v2_local.txt`.
- Definição de caso: `scripts/hs_lookup.R` (hash em `meta$lookup_hash` e
  `manifest/hs_lookup_versao.csv`).
