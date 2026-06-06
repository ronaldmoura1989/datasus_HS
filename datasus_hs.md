# Análise de dados do DATASUS sobre Hidradenite Supurativa no Brasil: plano consolidado

**A Hidradenite Supurativa (HS), ou acne inversa, é uma doença inflamatória crônica
da pele subdiagnosticada, com anos de atraso entre o início dos sintomas e o
diagnóstico, forte impacto na qualidade de vida e custo crescente para o SUS — em
especial após a incorporação do adalimumabe.** Este documento adapta, para a HS, a
metodologia de análise dos microdados do DATASUS já validada no projeto de autismo
(`../autismo/`), triangulando as bases **SIA-PA** (ambulatorial), **SIH-RD**
(internações) e **SIM-DO** (mortalidade) no período **2020–2025**. Diferentemente do
autismo — que ganhou um denominador populacional com o Censo 2022 — a HS **não tem
fonte censitária**, o que muda a construção de taxas e exige cautela interpretativa.

> **Convenções de marcação:** `[VERIFICAR]` = afirmação que exige confirmação
> documental na fonte oficial; `[CONFIRMAR via fetch_sigtab()]` = código de
> procedimento/CBO a validar na competência correta do SIGTAP. Princípio do
> projeto: **nunca inventar** CID, procedimento, CBO, portaria ou número de
> prevalência.

> Guia operacional (stack, runbook, convenções de código): ver **`CLAUDE.md`**.

---

## 1. Resumo executivo

A HS é uma dermatose folicular crônica que acomete predominantemente **mulheres
adultas jovens (pico 20–40 anos)**, com razão de sexo em torno de **~3:1 (F:M)**
`[VERIFICAR magnitude para o Brasil]` e prevalência mundial estimada em **~0,1–1%**
(valor citado para o Brasil em torno de ~0,4% provém de fontes secundárias e
`[VERIFICAR]`). Está associada a obesidade, tabagismo, síndrome metabólica e doença
inflamatória intestinal, e cursa com lesões recorrentes (nódulos, abscessos,
fístulas) de manejo clínico e **cirúrgico**.

O cruzamento das três bases do DATASUS permite caracterizar: **acesso e cobertura
dermatológica** (SIA), **carga cirúrgica e internações** (SIH), **gasto** — incluindo
o **biológico de alto custo** (adalimumabe via APAC) — e, de forma exploratória, a
**mortalidade** (SIM). A análise primária usa captura **restrita** (`L732`) e uma
análise de **sensibilidade ampliada** em camadas para dimensionar a subcodificação.

### Desenho do estudo e unidade de análise

Trata-se de um **estudo ecológico/descritivo de séries temporais sobre dados
secundários administrativos**, cuja **unidade de análise é o registro/atendimento,
não o indivíduo** (não há identificador longitudinal no DATASUS público — §9). Toda
associação observada (HS × região, HS × comorbidade) está sujeita à **falácia
ecológica** e **não autoriza inferência individual ou causal**. As três bases têm
unidades e denominadores distintos e **não são somáveis** — um mesmo paciente gera N
registros SIA + 1 AIH; somar "casos" entre bases é dupla contagem. Cada base responde
a uma pergunta própria (acesso ambulatorial / carga hospitalar / mortalidade) e é
reportada **em paralelo**, nunca consolidada num "total de casos HS".

| **Legitimamente inferível** | **NÃO inferível com este desenho** |
|---|---|
| Carga de uso de serviço (intensidade ambulatorial/hospitalar) | Prevalência / incidência verdadeiras |
| Padrões de codificação e qualidade do dado | Risco individual; causalidade |
| Gasto atribuível por codificação | Trajetória do paciente; recidiva real |
| Distribuição espacial da **detecção** | Atraso diagnóstico individual (§6.7) |
| Perfil demográfico **dos registros** (≠ da doença na população) | Perfil da HS na população (viés de gravidade — §2) |

> **Princípio interpretativo único, repetido em cada eixo (§6) e em cada `.qmd`:** o
> que se mede são **taxas de detecção/uso de serviço**, não prevalência. Reforçar
> nominal e visualmente (rótulos de eixo, títulos, nota de rodapé em toda tabela).

---

## 2. Códigos CID-10 da HS e como localizá-los nas três bases

**Código principal:** **L73.2 — Hidradenite supurativa** (sinônimo: acne inversa).
No DATASUS, **sem ponto = `L732`**. O PCDT e a padronização do adalimumabe no CEAF
referenciam explicitamente o CID **L73.2**.

### Correlatos e diferenciais (captura ampliada) — todos sem ponto no DATASUS

| CID-10 | Descrição | Papel |
|---|---|---|
| `L732` | Hidradenite supurativa | **Caso-índice (captura restrita)** |
| `L730` | Acne queloideana | Diferencial L73.x |
| `L731` | Pseudofoliculite da barba | Diferencial L73.x |
| `L738` | Outras afecções foliculares especificadas | Possível miscodificação de HS |
| `L739` | Afecção folicular não especificada | Possível subcodificação de HS |
| `L020`–`L024`, `L028`, `L029` | Abscesso cutâneo, furúnculo e antraz (por topografia) | Captura ampliada / diferencial |

> Topografias **axilar, inguinal, perineal/glútea e inframamária** (`L022` tronco,
> `L023` nádega) são as mais sugestivas de HS subjacente quando recorrentes. A
> ausência de granularidade topográfica no CID limita a separação automática.

### Onde o CID aparece em cada base

| Base | Campo(s) de diagnóstico | Observação |
|---|---|---|
| **SIA-PA** | `pa_cidpri` (CID principal) + `pa_cidpec` (CID especial APAC) | Um CID por registro; sem secundários. Preenchimento opcional/inconsistente em baixa complexidade → subcaptura; APAC (biológico) tende a ter CID melhor preenchido. |
| **SIH-RD** | `diag_princ` + `diagsec1`…`diagsec9` | Os secundários permitem captar HS como comorbidade e cruzar comorbidades (§4). |
| **SIM-DO** | `causabas` + `linhaa`–`linhad` + `linhaii` | HS quase nunca é causa básica; buscar também nas linhas e Parte II. Cada linha pode conter **vários CIDs** e marcadores `†`/`*` (dagger-asterisk) → normalizar e extrair todos os códigos (§11). |

> **Assimetria de definição de caso entre bases (não comparável trivialmente).** O
> SIA capta caso por **1 CID** (`pa_cidpri`) = diagnóstico principal; o SIH pode captar
> por **principal OU qualquer um dos 9 secundários**. Logo a "taxa SIH" e a "taxa SIA"
> não medem o mesmo conceito de caso. **Decisão:** reportar o SIH em **dois sabores
> separados** — (a) HS como `diag_princ` (estritamente comparável ao SIA, motivo
> principal da internação) e (b) HS em **qualquer campo** (`if_any` sobre os `diagsec*`
> presentes). Nunca misturar os dois nem somar com o SIA.

### Subnotificação / subcodificação esperada
- **SIA:** moderada a alta — HS leve manejada como "abscesso", "consulta
  dermatológica" ou "curativo" sem CID específico.
- **SIH:** codificação relativamente melhor (exige AIH), mas pode entrar como
  `L02x` (abscesso a drenar).
- **SIM:** subnotificação quase total da HS como entidade.
- **Viés de gravidade:** o que chega com `L732` tende a ser HS moderada/grave
  (Hurley II–III); casos leves ficam invisíveis.

### Estratégia de captura: RESTRITA vs AMPLIADA

| | **RESTRITA** (`L732`) | **AMPLIADA** (`L73x` + `L02x`) |
|---|---|---|
| Definição | Diagnóstico = `L732` | Acrescenta `L730–L739` e `L020–L029` |
| Prós | Alta especificidade; comparável à literatura; numerador limpo | Maior sensibilidade; capta HS miscodificada; dimensiona carga de abscessos recorrentes |
| Contras | Subestima a carga real | Baixa especificidade (L02x inclui muito abscesso não-HS); superestima |

**Recomendação (decisão do projeto):** **análise primária RESTRITA (`L732`)**;
**análise de sensibilidade AMPLIADA em camadas** — reportar separadamente
`L732` → `+L73x` → `+L02x` para mostrar o efeito de cada inclusão.

> **A camada `+L02x` é um ENVELOPE de subcodificação, não um cenário de caso.** O
> código `L02` (abscesso/furúnculo/antraz cutâneo) é uma das causas mais comuns de
> pequena cirurgia ambulatorial no SUS; a esmagadora maioria dos `L02x` **não é HS**.
> A razão sinal:ruído é desfavorável em várias ordens de grandeza. Portanto a camada
> `+L02x` deve ser lida como **limite superior absoluto de subcodificação possível**
> (*bracketing*), **nunca** como estimativa reportável de carga de HS. Nos relatórios,
> nomear "**envelope de subcodificação**", não "casos ampliados". Refinamento opcional:
> estratificar `L02x` por **topografia sugestiva** (tronco/nádega — ver acima) para um
> teto intermediário mais defensável, em vez de bloco único `^L02`.
>
> **Camadas implementadas numa única passada** com rótulo por registro (função
> `camada_cid()` retornando `"L732" | "L73x" | "L02x" | NA`), não com filtro booleano
> reprocessado 3× — ver `CLAUDE.md` §5.
>
> **Viés de gravidade (consequência analítica).** O que chega como `L732` é
> seletivamente HS **moderada/grave** (Hurley II–III) — a que motiva especialista,
> cirurgia ou biológico. Logo o **perfil demográfico capturado (sexo, idade) é o da HS
> grave detectada, não o da HS na população**. Se o DATASUS não reproduzir a razão
> ~3:1 F:M ou o pico 20–40, isso pode refletir **viés de gravidade/acesso diferencial
> por sexo**, e não um achado epidemiológico real nem erro do dado (ressalva embutida
> em §6.2).

---

## 3. Procedimentos SIGTAP relevantes

> O SIGTAP é organizado por **procedimento**, não por doença — raramente há item
> nominalmente "hidradenite". A identificação da HS depende do **CID associado**
> (`pa_cidpri`/`diag_princ`), não do código do procedimento. Estratégia: filtrar
> por CID (§2) e **caracterizar os procedimentos predominantes** dentro desse
> universo. Todos os códigos abaixo são **orientativos** e devem ser
> `[CONFIRMAR via fetch_sigtab()]` na(s) competência(s) de 2020–2025.

| Procedimento (grupo funcional) | Onde buscar | Observação |
|---|---|---|
| Drenagem de abscesso | SIA-PA / SIH | Manejo agudo recorrente |
| Exérese / excisão de lesão de pele e subcutâneo | SIA-PA / SIH | Tratamento definitivo de lesões |
| Retalhos / enxertos (reconstrução pós-excisão ampla) | SIH | Cirurgia plástica reparadora |
| Curativos (grau I/II) | SIA-PA | Pós-operatório / lesões abertas |
| Consulta médica em atenção especializada (dermatologia) | SIA-PA | Acesso ambulatorial |
| **Adalimumabe (biológico)** | SIA — **APAC / CEAF** | Alto custo; ver §6 e §8 |

**CBOs relevantes** (`pa_cbocod` no SIA): dermatologista, cirurgião geral,
cirurgião plástico, clínico/generalista (APS) — **`[CONFIRMAR código]`**. O
cruzamento procedimento × CBO indica **quem maneja a HS** (dermatologia vs cirurgia
vs APS), útil ao eixo de acesso/vazios assistenciais.

---

## 4. Comorbidades / CIDs secundários para cruzamento

Buscar nos campos **`diagsec1`…`diagsec9` do SIH-RD** (única base com diagnósticos
secundários estruturados). Todos sem ponto no DATASUS:

| Comorbidade | CID-10 | Racional |
|---|---|---|
| Obesidade | `E66` | Forte associação; fator de gravidade |
| Transtornos por uso de tabaco | `F17` | Fator de risco/gravidade clássico |
| Doença de Crohn | `K50` | Espectro inflamatório intestinal |
| Retocolite ulcerativa | `K51` | idem |
| Diabetes mellitus tipo 2 | `E11` | Síndrome metabólica |
| Depressão | `F32`, `F33` | Carga psíquica / qualidade de vida |
| Ansiedade | `F41` | idem |
| Espondiloartropatias / artrite | `M07`, `M45`, `M46` `[CONFIRMAR]` | Associação espondiloartrítica |
| Dislipidemia | `E78` | Contexto metabólico |

**Procedimento:** para cada AIH com HS (`diag_princ = L732` **ou** qualquer
`diagsec = L732`), montar matriz binária de presença de cada comorbidade nos 9
campos `diagsec*`; reportar prevalência entre internados com HS.
**Ressalva:** `diagsec` reflete o relevante *para aquela internação*, não a
comorbidade real da pessoa → subestima; e sem identificador longitudinal não há
como consolidar comorbidades por indivíduo (§9).
**⚠️ Magnitude confirmada no dado (2020–2025):** apenas **16% das 632 AIH-HS têm
qualquer diagnóstico secundário preenchido** (84% não têm nenhum), com completude
fortemente heterogênea por UF (SP ~32%, vários estados 0%). Logo a prevalência de
comorbidade observada (obesidade ~1,4%, tabaco ~0,8% etc.) é **piso subestimado e
enviesado para as UFs que codificam secundários**, não estimativa de prevalência real.
Reportar como "comorbidade **registrada na AIH**", nunca "prevalência em pacientes HS".

---

## 5. Denominador populacional

**Problema central:** a HS **não tem fonte censitária** (diferente do TEA no Censo
2022) — não há contagem populacional direta de pessoas com HS.

**Solução — denominador = população geral IBGE:**
- População residente por **UF × sexo × faixa etária** via **`sidrar`** (API SIDRA)
  e Censo 2022; usar a **população do ano-calendário** correspondente a cada
  numerador. Para 2020–2025, combinar estimativas intercensitárias + Censo 2022
  `[VERIFICAR disponibilidade da série por UF/sexo/idade no SIDRA]`.
- **Taxas por 100.000 habitantes:** detecção/registro ambulatorial (SIA),
  internação (SIH) e mortalidade (SIM).
- **Estes são índices de DETECÇÃO/USO DE SERVIÇO, não prevalência.** Reportar como
  "casos registrados/atendidos por 100 mil", não "prevalência".

> **⚠️ Descontinuidade do denominador em 2022 (Censo).** A série 2020–2025 combina
> metodologias diferentes: **2020–2021** = estimativas pós-Censo 2010 (projeções
> antigas); **2022** = Censo 2022; **2023–2025** = estimativas pós-Censo 2022. O Censo
> 2022 **revisou a população brasileira para baixo** frente às projeções antigas →
> taxas calculadas com denominadores de metodologias distintas exibem um **degrau
> artificial em 2022** que pode ser confundido com mudança real de detecção.
> **Decisão:** usar **projeções retrointerpoladas a partir do Censo 2022 para toda a
> série** (mais coerente) e/ou sinalizar explicitamente a quebra. `[VERIFICAR]` qual
> tabela SIDRA fornece UF × sexo × **idade** para todos os anos — as estimativas
> municipais anuais costumam ser **totais** (sem desagregação sexo/idade); a
> desagregação vem das **Projeções da População por UF**, em **grupos etários
> próprios** que precisam ser harmonizados (abaixo).

> **⚠️ Numerador (registros) ÷ denominador (pessoas) — vira regra de cálculo, não só
> ressalva.** HS é crônica e recorrente: uma mesma pessoa gera múltiplos registros/ano
> (consultas, curativos, drenagens). A taxa "registros SIA por 100 mil" tem numerador
> **inflado** e mede **intensidade de uso**, não prevalência nem incidência.
> **Regra:** no SIA reportar **dois numeradores distintos** — (a) **volume de
> procedimentos/registros** (intensidade de uso — somar `pa_qtdapr`, não `nrow()`); e,
> quando viável, (b) **proxy de pacientes-únicos** por deduplicação aproximada
> (chave `cns`/munic.+sexo+idade dentro do ano, sob LGPD — §9), claramente rotulada
> como aproximação. No SIH, a **AIH** aproxima melhor o episódio, mas reinternação
> ainda dupla-conta a pessoa (deduplicar por AIH distinta — `CLAUDE.md` §5).

**Harmonização de faixas etárias (pré-requisito da padronização).** Definir **faixas
canônicas únicas** (ex.: quinquenais 0-4 … 80+) e aplicar a **mesma** função de
faixa ao **numerador** (idade do paciente derivada com cuidado da unidade `cod_idade`
do SIH / `pa_idade` do SIA) **e** ao **denominador** (grupos etários do IBGE). Faixas
não-idênticas invalidam a taxa padronizada.

**Padronização:** **padronização direta por idade e sexo** ao comparar UFs/regiões.
**Fixar UMA população-padrão por finalidade:** (i) comparações **internas**
(UF×UF, série temporal) → **população brasileira do Censo 2022**; (ii) comparabilidade
**internacional** → **padrão OMS (World Standard)**. Declarar qual foi usada em cada
tabela. Reportar **taxas brutas e padronizadas lado a lado, com intervalo de
confiança** (método gamma p/ taxas, p.ex. `epitools::ageadjust.direct()`) — essencial
porque UFs pequenas (AC, RR, AP) terão N baixo e taxas instáveis. Considerar a taxa
específica do **estrato-alvo (mulheres 18–40)** como indicador mais sensível (com
denominador também restrito a mulheres 18–40 e supressão de células pequenas — §9).

**Prevalência da literatura — só como contexto:** moldura de plausibilidade (faixa
~0,1–1%; razão ~3:1 F:M; pico 20–40 anos), com `[VERIFICAR]`. Uso: comparar a carga
esperada (prevalência × população) com o nº de casos capturados no DATASUS →
**quantificar o gap de captação/subdiagnóstico** (nunca usar 0,4% como denominador).

---

## 5.1 Pseudo-individualização do SIA (registros → pessoas-aproximadas)

> Plano consolidado a partir das revisões **epidemiológica** e **bioinformática**
> (ambas Opus). O SIA-PA público **não tem identificador de paciente (CNS)**; os
> 158.850 registros de HS são individualizados (BPAI/APAC, com `pa_sexo`/`pa_idade`/
> `pa_racacor`/`pa_munpcn` ~100% preenchidos). Construímos um **pseudo-ID** por
> *record linkage* sobre quase-identificadores. Implementação: `feature_eng_pacientes_SIA.R`.

**Princípio inegociável:** o pseudo-ID é um **AGRUPADOR de registros compatíveis, não
um identificador de pessoas**. O nº de pacientes é reportado como **INTERVALO**, nunca
como número pontual. As taxas continuam sendo de **detecção/uso**, não de prevalência.

**Construção da chave** (derivar `ano_nasc_proxy = ano(pa_cmp) − pa_idade`):
- A idade **incrementa no tempo**; `ano_nasc_proxy` neutraliza isso por construção. O
  resíduo é o **±1 ano** do aniversário não-feito → tratar com **janela de tolerância
  ±1 na geração de pares** (não `group_by` exato).
- **Núcleo da chave:** `pa_sexo` + `ano_nasc_proxy(±1)` + `pa_munpcn` + `pa_racacor`.
- **Fora da chave (atributos do evento, não da pessoa):** `pa_coduni`, `pa_proc_id`,
  `pa_cbocod`, `pa_valapr`/`pa_qtdapr`. Incluí-los liga "quem vai ao mesmo serviço",
  não "a mesma pessoa" — e fragmenta sistematicamente o trajeto UBS→especializado.

**Algoritmo (decisão de desenho):** **determinístico primário** — *blocking* por
`sexo × munpcn`, pares candidatos com janela `|Δano_nasc|≤1` (via `data.table`),
resolução de entidade por **componentes conexos** (`igraph::components`). A abordagem
**probabilística (`reclin2`, EM/Fellegi-Sunter)** entra **só como sensibilidade** — os
campos são categóricos limpos de baixa entropia; o problema é **ambiguidade estrutural
(colisões reais)**, que um score não resolve, apenas mascara. (Não usar `fastLink`.)

**Dois erros de sinais opostos — por isso intervalo, não ponto:**
- **Colisão** (falso vínculo → *subestima* pessoas): duas pessoas distintas, mesmo
  sexo/ano/município/raça. Cresce em **municípios grandes** e na **faixa modal 20–40**.
- **Fragmentação** (falsa separação → *superestima* pessoas): mesma pessoa partida por
  migração de `pa_munpcn`, re-declaração de raça, atendimento em outra UF (TFD), erro
  de idade. **Pior na cauda crônica/grave** → viés **diferencial por gravidade**.

**Gradiente de chaves (intervalo + sensibilidade):**

| Nível | Regra | Papel |
|---|---|---|
| Registro = pessoa | sem de-dup | limite inferior absoluto de pessoas (= 158.850 registros) |
| **Estrita** | sexo+raça+município+`ano_nasc` **exato** | **limite superior** de pacientes (mais fragmenta) |
| **Intermediária** | estrita + janela `ano_nasc ±1` | **estimativa central** |
| **Frouxa** | sexo+município+`ano_nasc±1` (sem raça) | **limite inferior** de pacientes (mais funde) |

**Validação/robustez a reportar:** amplitude do intervalo estrita↔frouxa (principal
indicador); **capture-recapture** (Lincoln-Petersen/Chao) p/ estimar fragmentação
(com ressalva de não-independência das capturas); distribuição do tamanho dos clusters
(`csize` — componentes gigantes = *over-merge* por encadeamento transitivo em capital);
% de pseudo-pacientes que mudam de `pa_munpcn` (proxy de fragmentação); razão
registros/pseudo-paciente por nível.

**O que muda nas análises:**
- **Vira defensável:** contagem como **intervalo [registros ; pseudo-pacientes]** e
  **razão registros/paciente** (intensidade de uso) — entrega principal do pseudo-ID.
- **Parcialmente defensável:** "idade ao 1º registro **na janela**" (com left-truncation
  e viés de fragmentação que a empurra para cima); recidiva como "frequência de
  atendimentos/procedimentos cirúrgicos por pseudo-paciente" (proxy **grosseiro**,
  ancorar em `pa_proc_id` cirúrgicos, não contagem bruta).
- **Continua inviável:** nº "oficial" de pacientes; incidência; atraso diagnóstico
  clínico; recidiva clínica; trajetória individual de quem migra.

**LGPD (linha vermelha):** o objetivo é **agregar, não identificar**. Pseudo-ID é
instrumento interno; só saem **agregados**; **supressão de células `N < 5`**; nunca
publicar a chave nem `município × ano_nasc × raça` em nível fino; granularidade de
divulgação em **UF/região**. Qualquer passo que vise *aumentar a unicidade* até apontar
uma pessoa real está **fora do escopo**.

---

## 6. Eixos de análise acionáveis (adaptados à HS)

> **Ressalva COVID-19 transversal a todo eixo de série temporal.** Em **2020–2021**
> houve colapso da produção ambulatorial e de procedimentos eletivos/dermatológicos no
> SUS. Qualquer série 2020–2025 de HS mostrará **depressão 2020–2021 + recuperação que
> é artefato de oferta pandêmica, não tendência da doença**. Tratar 2020–2021 como
> **período anômalo** na narrativa e, idealmente, na modelagem (ver §9).

1. **Acesso/cobertura dermatológica** — consultas e procedimentos com `L732` por
   UF/região; razão consulta dermatológica/população; quem maneja (CBO §3).
2. **Perfil epidemiológico** — ênfase em **sexo feminino** e **adultos jovens
   (18–40)**; pirâmide sexo × idade; raça/cor; verificar se o DATASUS reproduz a
   razão ~3:1 e o pico 20–40, ou se há desvios. **Ressalva embutida:** desvios podem
   refletir **viés de gravidade/acesso diferencial** (o capturado é a HS grave
   detectada, não a HS populacional — §2), não necessariamente achado real. Para a
   série, usar **teste de tendência** (regressão de Poisson/quasi-Poisson `n ~ ano`,
   offset `log(população)`) com IC, em vez de só descrever a curva (`rstatix`/`broom`).
3. **Peso cirúrgico / internações** — proporção de casos com procedimento cirúrgico
   (drenagem, exérese, retalho); taxa de internação; permanência (`dias_perm`);
   reinternação como proxy de gravidade/recidiva (limitado — §9).
4. **Custos** — `pa_valapr` (SIA) e `val_tot`/`val_sh`/`val_sp` (SIH); **destaque
   para o custo do adalimumabe (APAC)** vs cirúrgico vs ambulatorial; custo médio
   por internação; participação dos biológicos no gasto atribuível à HS.
   **Ressalva:** manter **componentes separados** (APAC alto custo · cirúrgico SIH ·
   ambulatorial SIA) — só somar como "gasto total atribuível" **com ressalva
   explícita** de que cada base sub/superconta de forma diferente e por codificação.
5. **Vazios assistenciais em dermatologia** — UFs/regiões com baixa/nula produção
   `L732` apesar de população esperada → subdiagnóstico ou ausência de oferta;
   cruzar com **CNES**. **Confundimento dominante por oferta:** a "taxa de detecção de
   HS por UF" e a "densidade de serviços/dermatologistas" (CNES) estão tão entrelaçadas
   que a variação geográfica mede majoritariamente **acesso, não doença**. Reportar
   **dois mapas lado a lado (detecção × oferta)** e, se possível, taxa **condicionada à
   oferta** (casos por dermatologista / razão detecção:cobertura).
6. **Inequidades regionais** — taxas padronizadas por região/UF (com IC); razão de
   taxas; concentração da dispensação de biológico (provável em capitais/Sul-Sudeste —
   `[VERIFICAR no dado]`).
7. **Atraso diagnóstico — REBAIXADO a discussão qualitativa/contextual, NÃO entregável
   quantitativo.** As proxies disponíveis **não sustentam inferência** sobre atraso:
   - *Razão `L02x`/`L732` por UF* confunde subcodificação de HS-como-abscesso com a
     **incidência real de abscessos banais** (varia por clima/perfil/acesso); mede, no
     máximo, **propensão local a codificar abscesso** → reportar como **indicador de
     padrão de codificação**, não atraso.
   - *Idade ao "primeiro registro `L732`"* sofre **censura à esquerda (left-truncation)**
     massiva: sem identificador longitudinal nem janela de observação prévia, o
     "primeiro registro" é apenas o primeiro **dentro de 2020–2025** (um caso prevalente
     desde 2010 aparece como "novo"). Idade no 1º registro observado ≠ idade ao
     diagnóstico ≠ idade ao início dos sintomas. **Renomear para "idade na primeira
     detecção na janela", sem inferência sobre atraso.**
   - A medição direta do atraso é **inviável** sem coorte individual — manter o tema
     apenas como discussão contextual da literatura, sem prometê-lo como resultado.
8. **Indicadores de qualidade do dado** — completude de `pa_cidpri`/`diagsec`/
   raça-cor; proporção de CID válido; consistência sexo × CID; oportunidade;
   duplicidade.

---

## 7. Particularidades HS vs Autismo (que mudam o desenho)

| Dimensão | Autismo (TEA) | Hidradenite Supurativa | Implicação |
|---|---|---|---|
| Faixa etária | Pediátrica/infanto-juvenil | **Adulta jovem (20–40)** | Cortes etários adultos |
| Razão de sexo | Predomínio masculino (~3–4:1 M:F) | **Predomínio feminino (~3:1 F:M)** | Estrato-alvo: mulheres adultas |
| Base mais relevante | SIA (terapias) | **SIH ganha peso** (cirurgia) + SIA/APAC | Mais ênfase no SIH |
| Alto custo | — | **Adalimumabe via CEAF/APAC** (L732, ≥18 anos, ≤160 mg/mês) | Eixo de custo/judicialização |
| Denominador | **Censo 2022 mediu TEA** | **Sem fonte censitária** | População geral IBGE; taxas de uso |
| Mortalidade (SIM) | Pouco específica | **Ainda mais invisível** | SIM exploratório, N baixo |
| Miscodificação | F84 específico | **L02x compete com L732** | Restrito vs ampliado crítico |

---

## 8. Arcabouço normativo e contexto (a verificar)

> **⚠️ Reconciliar números antes de publicar — há mistura de atos distintos.** O
> texto abaixo confunde **número de relatório Conitec**, **número de portaria SCTIE de
> incorporação** e **portaria de aprovação do PCDT** — que são atos **diferentes**,
> com números/datas próprios (o "nº 473/2019" das fontes consultadas parece ser
> **relatório de recomendação**, não a portaria). **Não publicar nenhum desses números
> sem confirmar na fonte primária** (DOU + gov.br/Conitec). Antes da redação final,
> **buscar e fixar três atos**: (1) portaria Conitec/SCTIE de **incorporação do
> adalimumabe** para HS; (2) portaria que **aprova/atualiza o PCDT** de HS **vigente**
> (checar atualização pós-2020); (3) a entrada no **CEAF** e seus critérios — sempre
> via PCDT nacional vigente, **não** por cartilha estadual (CEAF/SP não é fonte
> normativa nacional).

- **PCDT de Hidradenite Supurativa — existe.** Primeiro PCDT específico da doença no
  SUS; consulta pública CP 35/2019 e publicação posterior (2020).
  `[VERIFICAR número/data da portaria vigente e versão atual]`. Contempla
  antibioticoterapia (clindamicina tópica; clindamicina + rifampicina; tetraciclina),
  cirurgia, e **adalimumabe para casos moderados/graves refratários**.
- **Adalimumabe no SUS — incorporado** para HS moderada a grave (Portaria SCTIE
  **nº 48, de 16/10/2018** `[VERIFICAR — possível confusão com nº do relatório
  Conitec 473/2019; confirmar número/data exatos da portaria de incorporação no
  DOU]`). Dispensação pelo **CEAF, Grupo 1A**, apresentação 40 mg, **idade mínima 18
  anos**, máximo **160 mg/mês**, mediante **LME/APAC**, CID L73.2
  `[CONFIRMAR critérios na versão vigente do PCDT]`.
- **SBD (Sociedade Brasileira de Dermatologia)** — participou da consulta pública do
  PCDT; referência para diretrizes clínicas complementares.
- **PCDaS/Fiocruz** — fonte alternativa de microdados harmonizados para validação
  cruzada da extração via `microdatasus`.

> Antes da redação final dos relatórios, baixar e citar a portaria de incorporação
> e o PCDT vigente (gov.br/conitec) para fixar números, critérios e CID oficiais.

**Fontes consultadas (epidemiologista):** Conitec — relatório PCDT HS nº 473/2019 e
publicação MS 2020; SBD — consulta pública e incorporação do adalimumabe; CEAF/SP —
cartilha do adalimumabe para HS; Agência Brasil — fatores de risco.

---

## 9. Limitações específicas da análise de HS no DATASUS

1. **Subdiagnóstico e subcodificação** — muitos casos como `L02x` (abscesso) ou
   `L739` (folicular inespecífico) → numerador subestimado e dependente de captura
   ampliada (com perda de especificidade).
2. **Ausência de denominador específico** — taxas de **detecção/uso**, não de
   prevalência verdadeira.
3. **Sem identificador longitudinal** no DATASUS público (SIA/SIH) → conta
   **registros/atendimentos, não pessoas**; recidiva, atraso diagnóstico individual
   e consolidação de comorbidades por indivíduo são inviáveis ou só aproximáveis.
4. **SIA com 1 só CID** — cruzamento de comorbidade restrito ao SIH (`diagsec`),
   enviesado para casos internados (mais graves).
5. **Procedimento ≠ doença** — SIGTAP não nomeia HS; identificação depende do CID,
   sujeito a má codificação.
6. **Mortalidade quase invisível** — N muito baixo no SIM; análise limitada a
   exploração de causas contribuintes.
7. **Adalimumabe/APAC** — dispensação concentrada e sujeita a **judicialização** que
   o dado administrativo não distingue; granularidade do procedimento APAC a confirmar.
8. **Heterogeneidade de codificação** entre UFs e ao longo do tempo — mitigar com
   indicadores de qualidade (§6.8) e análises de sensibilidade.
9. **Viés de gravidade** — o capturado com `L732` tende a ser HS moderada/grave; o
   perfil demográfico capturado é o da **HS grave detectada**, não o da HS populacional.
10. **Mudanças de versão do SIGTAP** (2020–2025) — consolidar com mapeamento por
    competência.
11. **Efeito da pandemia COVID-19 (2020–2021)** — colapso da produção ambulatorial e
    de procedimentos eletivos/dermatológicos no SUS deprime artificialmente a série
    nesses anos; a recuperação posterior **não é tendência da HS**. Tratar 2020–2021
    como período anômalo na narrativa e na modelagem.
12. **Descontinuidade do denominador em 2022 (Censo)** — série populacional combina
    estimativas pós-Censo 2010 (2020–2021), Censo 2022 e estimativas pós-2022; risco de
    **degrau artificial** nas taxas (§5). Mitigar com retrointerpolação a partir do
    Censo 2022.
13. **Censura à esquerda (left-truncation)** — sem identificador longitudinal nem
    janela prévia, não se distingue **caso novo de caso prevalente** entrando em
    2020–2025; invalida "atraso diagnóstico" e "idade ao primeiro registro" (§6.7).
14. **Não-comparabilidade SIA vs SIH** — a definição de caso difere por construção
    (1 CID no SIA vs principal+9 secundários no SIH); taxas das duas bases **não medem
    o mesmo conceito** e não devem ser somadas (§2).
15. **Completude heterogênea no espaço/tempo** — preenchimento de raça/cor, CID e
    outros campos varia entre UFs e anos, confundindo comparações de **qualidade** com
    comparações de **carga** (§6.8).
16. **Privacidade / LGPD** — embora os microdados sejam desidentificados, estratos
    finos (UF × sexo × faixa 18–40 em RR/AP/AC) podem gerar **células pequenas
    reidentificáveis**. **Aplicar supressão de células com N pequeno** (limiar
    declarado, p.ex. `< 5`) em toda divulgação; não tentar reidentificação; tratar
    qualquer deduplicação por chave (CNS/munic.+sexo+idade) sob princípio de
    minimização.

---

## 10. Plano analítico em 5 fases

**Fase 1 — Extração e preparação.** Transferir/validar os brutos para `data/raw/`
(reconciliar nomes; granularidade **mensal** em SIA/SIH e **anual** em SIM — `CLAUDE.md`
§7); **verificar disponibilidade do SIM-DO 2025**; corrigir **encoding latin1→UTF-8** e
coagir tipos (valores monetários/datas — `CLAUDE.md` §5); rotular as camadas por
registro com `camada_cid()` (`L732`/`L73x`/`L02x` numa só passada); **agregar os
denominadores de utilização durante a ingestão** (o SIA total não cabe em RAM);
consolidar nacional; converter o SIA-HS para **Parquet particionado por `ano` e `uf`**;
baixar população IBGE por UF/sexo/idade via `sidrar` (cache) e **harmonizar as faixas
etárias** numerador↔denominador (§5).

**Fase 2 — Diagnóstico da rede.** Mapear estabelecimentos/CNES que registram HS;
calcular cobertura territorial dermatológica; identificar vazios assistenciais
(geoespacial com `geobr`).

**Fase 3 — Perfil epidemiológico e de utilização.** Séries temporais 2020–2025
(SIA/SIH) com **ressalva COVID em 2020–2021** (§9.11) e **teste de tendência** (Poisson
com offset); decompor por sexo, faixa etária, raça/cor e subtipo; **taxas por 100 mil
padronizadas** por idade/sexo com **IC** e população-padrão declarada (§5);
caracterizar o **peso cirúrgico** (SIH: procedimentos, caráter eletivo/urgência,
permanência). Reportar o SIH nos **dois sabores** (`diag_princ` vs qualquer campo —
§2) e **não somar** com o SIA.

**Fase 4 — Custos e inequidades.** Gasto ambulatorial vs hospitalar vs **biológico
(APAC)**; custo por internação; inequidades regionais (taxas padronizadas);
**análise de sensibilidade** restrito ↔ ampliado.

**Fase 5 — Painel de indicadores e publicação.** `index.qmd` com KPIs, mapas
(`geobr`) e tendências; recomendações acionáveis (expansão de oferta dermatológica,
qualificação diagnóstica, manejo do alto custo); render do website Quarto
(self-contained) e publicação via **GitHub Pages** (`docs/` + `.nojekyll`).

---

## 11. Convenções analíticas e tema visual

- **Ferramentas (ver `CLAUDE.md`):** priorizar **`tidyverse`**; estatística com
  **`rstatix`**; gráficos com **`ggplot2` + `ggpubr`**; tabelas com **`flextable` +
  `officer`** (e `gt` em HTML); mapas com **`geobr`**.
- **Relatórios `.qmd` self-contained** (`embed-resources: true`).
- **Paleta de cores** (espectro rosé → roxo): **`#E9CDC9`**, **`#5C3F6C`**,
  **`#816095`**; extensão `#D8B4C4`, `#A87FA8`, `#6E4E82`, `#3E2A4D`. Constante
  `PAL_HS` em `00_setup.R`; `scale_*_manual()` para discretas e gradiente
  `#E9CDC9`→`#5C3F6C` para contínuas.
