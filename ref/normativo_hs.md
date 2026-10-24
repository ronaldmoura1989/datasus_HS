# Arcabouço normativo da Hidradenite Supurativa (L73.2) no SUS — 2010 a 2025

Produto da etapa **E1** de `plano_expansao_2010.md`. Pesquisa feita em 23/10/2026.
Regra seguida: nenhum número, data ou código foi tirado de memória. Cada ato abaixo foi lido
nesta sessão, no **DOU** (in.gov.br), no **gov.br/conitec** ou nos **arquivos SIGTAP por
competência** do FTP do DATASUS. Quando não consegui confirmar algo na fonte primária, está
marcado `[VERIFICAR]`, com o que achei e onde.

Arquivo complementar: `ref/sigtap_hs.csv` (códigos, vigência, instrumento, compatibilidade com L73.2).

---

## 0. Resumo

| # | Ato | Data do ato | Publicação (DOU) | O que muda no dado |
|---|---|---|---|---|
| 1 | Portaria GM/MS nº 2.981/2009 (cria o CEAF) | 26/11/2009 | `[VERIFICAR]` (republicada com `(*)`) | Medicamentos saem do grupo 06.01 e passam ao 06.04; adalimumabe 06.01.01.001-9 vai até 05/2010, e 06.04.38.001-1 existe desde 03/2010 |
| 2 | Portaria SCTIE/MS nº 48/2018 (incorpora adalimumabe para HS) | 16/10/2018 | 17/10/2018, ed. 200, s. 1, p. 44 | Nada no dado: é decisão de incorporar. Prazo legal de oferta de 180 dias, até cerca de 15/04/2019 |
| 3 | Portarias SCTIE/MS nº 28, 29 e 30/2019 (antibióticos para HS) | 11/06/2019 | 12/06/2019, ed. 112, s. 1, p. 126 | Nada no SIA: clindamicina e rifampicina estão no CBAF (Componente Básico), sem APAC |
| 4 | Portaria Conjunta SAES/SCTIE nº 14/2019 (PCDT HS) | 11/09/2019 | 16/09/2019, ed. 179, s. 1, p. 95 | Define critérios clínicos e CID L73.2. Sozinha não abre a APAC |
| 5 | **Portaria SAES/MS nº 1.217/2019** (L73.2 no 06.04.38.006-2) | 18/10/2019 | 31/10/2019, ed. 211, s. 1, p. 72 (republicada 27/01/2020 e 29/01/2020) | **A partir da competência 11/2019, a APAC 06.04.38.006-2 com CID L73.2 passa a ser aceita**. Também: quantidade máxima de 7 |
| 6 | Portaria SAES/MS nº 211/2022 (biossimilar A) | 29/06/2022 | 30/06/2022, ed. 122, s. 1, p. 142 (republicada 05/07/2022, ed. 125, p. 212) | Cria 06.04.38.012-7 (biossimilar A) com L73.2, a partir de 07/2022 |
| 7 | Portaria SAES/MS nº 442/2022 (biossimilar B) | 17/08/2022 | 31/08/2022, ed. 166, s. 1, p. 197 | Cria 06.04.38.013-5 (biossimilar B) com L73.2, na competência seguinte: 09/2022 |
| 8 | Portaria Conjunta SAES/SCTIE nº 40/2026 (biossimilar C) | 24/02/2026 | 10/03/2026, ed. 46, s. 1, p. 120 | Cria 06.04.38.014-3 com L73.2, a partir de 03/2026. **Fora da série** |

---

## 1. Incorporação do adalimumabe para HS

### 1.1 Portaria SCTIE/MS nº 48, de 16 de outubro de 2018 — CONFIRMADO no DOU

- **Órgão:** Ministério da Saúde / Secretaria de Ciência, Tecnologia e Insumos Estratégicos (SCTIE).
  Signatário: Marco Antonio de Araujo Fireman.
- **Publicação:** DOU de **17/10/2018**, edição 200, seção 1, página 44.
- **Link (DOU):** <https://www.in.gov.br/web/dou/-/portaria-n-48-de-16-de-outubro-de-2018-45574592>
- **Ementa:** "Torna pública a decisão de incorporar o adalimumabe para o tratamento da hidradenite
  supurativa ativa moderada a grave no âmbito do Sistema Único de Saúde - SUS."
- **Art. 1º:** incorpora "mediante Protocolo Clínico e Diretrizes Terapêuticas do Ministério da Saúde".
- **Art. 2º:** "o prazo máximo para efetivar a oferta ao SUS é de cento e oitenta dias" (art. 25 do
  Decreto 7.646/2011). Contando da publicação (17/10/2018), o prazo vence por volta de
  **15/04/2019**. Fiz a conta de dias corridos; a contagem formal é `[VERIFICAR]`. A oferta
  efetiva só veio em 11/2019 (§3), cerca de 7 meses depois do prazo.
- **O que muda no dado:** nada de imediato. Em 10/2018 o SIGTAP ainda não aceitava L73.2 em nenhum
  código de adalimumabe (§3 e `sigtap_hs.csv`).

**Relatório Conitec que embasa o ato (não confundir com a portaria):**
- Relatório de Recomendação **nº 395**, outubro/2018. "Adalimumabe para o tratamento da hidradenite
  supurativa ativa moderada a grave". Recomendação final na 71ª reunião ordinária (03/10/2018),
  **Registro de Deliberação nº 382/2018**. Demandante: AbbVie.
  <https://www.gov.br/conitec/pt-br/midias/relatorios/2018/relatorio_adalimumabe_hidradenitesupurativa.pdf>
- Consulta pública: o DOU traz a **Consulta Pública SCTIE nº 40, de 1º/08/2018** (DOU 03/08/2018),
  sobre "adalimumabe para pacientes com hidradenite supurativa ativa moderada a grave".
  <https://www.in.gov.br/web/dou/-/consulta-publica-n-40-de-1-de-agosto-de-2018-35314801>

**Erros encontrados nas fontes secundárias (prevalece o DOU):**
- O sumário do próprio Relatório 395 diz "Portaria nº 48, de 16 de outubro de **2017**" e "DOU nº **210**,
  página **40**". A página "Decisão" do mesmo relatório e o DOU dizem **2018**, com publicação na
  **ed. 200, p. 44**.
- O Relatório 395 fala em "Consulta Pública nº **39**/2018 (04/08 a 23/08/2018)". O DOU publica o tema
  como **CP nº 40/2018**. Uso o número do DOU.
- Uma decisão do TJRS citada em buscas atribui a incorporação à "Portaria 211/2022". Isso está **errado**:
  a Portaria SAES 211/2022 só cria o código do biossimilar A (§4).
- O "nº 473/2019" citado em `datasus_hs.md` §8 é o **Relatório de Recomendação do PCDT** (§2), e não
  a portaria de incorporação.

### 1.2 Incorporações acessórias (antibióticos) — CONFIRMADO no DOU

Todas da SCTIE/MS, datadas de 11/06/2019 e publicadas no DOU de 12/06/2019 (ed. 112, s. 1, p. 126):
- **nº 28/2019:** clindamicina 1% tópica, para lesões superficiais. <https://www.in.gov.br/web/dou/-/portaria-n-28-de-11-de-junho-de-2019-163114622>
- **nº 29/2019:** tetraciclina 500 mg, para HS leve. <https://www.in.gov.br/web/dou/-/portaria-n-29-de-11-de-junho-de-2019-163114645>
- **nº 30/2019:** clindamicina 300 mg com rifampicina 300 mg, para HS moderada. <https://www.in.gov.br/web/dou/-/portaria-n-30-de-11-de-junho-de-2019-163114826>

**O que muda no dado:** nada visível no SIA-PA. A Portaria GM/MS nº 6.212/2024 (DOU 20/12/2024) lista
"clindamicina 300 mg e rifampicina 300 mg, exclusivamente para tratamento de hidradenite supurativa
moderada" entre os itens do **CBAF**, o Componente Básico, que não usa APAC.
<https://www.in.gov.br/web/dou/-/portaria-gm/ms-n-6.212-de-19-de-dezembro-de-2024-603278949>.
Consequência: a etapa de antibiótico do PCDT **não é observável** no DATASUS.

---

## 2. PCDT de Hidradenite Supurativa

### 2.1 Portaria Conjunta SAES/SCTIE nº 14, de 11 de setembro de 2019 — CONFIRMADO no DOU

- **Órgãos:** Secretaria de Atenção Especializada à Saúde (SAES) e Secretaria de Ciência, Tecnologia,
  Inovação e Insumos Estratégicos em Saúde (SCTIE). Signatários: Francisco de Assis Figueiredo e
  Denizar Vianna.
- **Publicação:** DOU de **16/09/2019**, edição 179, seção 1, página 95. Vigência na data da publicação (art. 4º).
- **Link (DOU):** <https://www.in.gov.br/web/dou/-/portaria-conjunta-n-14-de-11-de-setembro-de-2019-216322855>
- **Fac-símile no Conitec:** <https://www.gov.br/conitec/pt-br/midias/relatorios/portaria/2019/portariasctie_14_b_2019.pdf>
- **Base:** Registro de Deliberação nº 462/2019 e **Relatório de Recomendação nº 473** (agosto/2019) da Conitec.
  Consulta pública do PCDT: **CP SCTIE nº 35, de 18/06/2019** (DOU 19/06/2019).
  <https://www.in.gov.br/web/dou/-/consulta-publica-n-35-de-18-de-junho-de-2019-164322672>.
  O PDF do Relatório 473 não foi localizado `[VERIFICAR link]`.
- **CID do PCDT:** só "L73.2 – Hidradenite supurativa".
- **Medicamentos:** fosfato de clindamicina 1% gel, cloridrato de tetraciclina 500 mg, cloridrato de
  clindamicina 300 mg, rifampicina 300 mg e **adalimumabe 40 mg** solução injetável.
- **O que muda no dado:** a portaria sozinha não muda nada no SIA. A Portaria SAES 1.217/2019 (§3)
  cita esta como fundamento para incluir L73.2 no SIGTAP.

### 2.2 Edições e atualizações

- **Edição em livro (MS, 2020, ISBN 978-85-334-2814-0):** "compreende o conteúdo da Portaria Conjunta
  SAES/SCTIE nº 14, de 11 de setembro de 2019". Não é ato novo.
  <https://www.gov.br/conitec/pt-br/midias/protocolos/publicacoes_ms/pcdt_hidradenite-supurativa_isbn_21-08-2020.pdf>
- **Reedição de maio/2025, sem nova portaria:** o PDF vigente no Conitec ("ajusteMaio2025") tem um
  Apêndice 1, "Alteração pós publicação". Ele atualiza só o item de monitoramento de tuberculose
  (ILTB), para harmonizar com os demais PCDT de MMCD biológicos. O tema foi levado como informe à
  125ª reunião da Subcomissão de PCDT (20/05/2025) e à 141ª Reunião Ordinária da Conitec (06/2025).
  <https://www.gov.br/conitec/pt-br/midias/protocolos/site-de-portaria-conjunta-14_pcdthidradernite-supurativa.pdf>
- **PCDT anterior:** não há. A Portaria Conjunta 14/2019 é o primeiro e único PCDT de HS. A busca no DOU
  por "hidradenite supurativa" (todas as datas) não trouxe nenhum PCDT anterior nem posterior.
- **Atualização em curso?** Pareceres do NatJus/TJRJ de 2025 dizem que o PCDT "encontra-se em
  atualização" (fonte secundária). Não achei o tema na página "PCDT em elaboração" do Conitec
  (modificada em 23/09/2026) nem no DOU até 23/10/2026 `[VERIFICAR]`.

---

## 3. Início efetivo da dispensação no CEAF

### 3.1 Portaria SAES/MS nº 1.217, de 18 de outubro de 2019 — CONFIRMADO no DOU e no SIGTAP

- **Órgão:** Secretaria de Atenção Especializada à Saúde (SAES/MS). Signatário: Francisco de Assis Figueiredo.
- **Publicação:** DOU de **31/10/2019**, edição 211, seção 1, página 72. A data de 18/10/2019 é a da
  assinatura, e não a da publicação; o Relatório de Reavaliação Conitec confunde as duas.
  - Republicada no DOU de **27/01/2020** (ed. 18, p. 121) e de **29/01/2020** (ed. 20, p. 43), "por ter
    saído com incorreções". As correções foram só na linha da azatioprina. A linha do adalimumabe e o
    art. 3º não mudaram.
- **Links (DOU):**
  - original: <https://www.in.gov.br/web/dou/-/portaria-n-1.217-de-18-de-outubro-de-2019-224671168>
  - republicação 1: <https://www.in.gov.br/web/dou/-/portaria-n-1.217-de-18-de-outubro-de-2019-%2A-239864296>
  - republicação 2: <https://www.in.gov.br/web/dou/-/portaria-n-1.217-de-18-de-outubro-de-2019-%2A-240332608>
- **Texto relevante:** "06.04.38.006-2 ADALIMUMABE 40 MG INJETÁVEL (POR SERINGA PREENCHIDA) — CID: H15.0,
  H20.1, H30.1, H30.2, H30.8, **L73.2 (inclusão)** QUANTIDADE MÁXIMA: 7". Art. 3º: "entra em vigor na
  data de sua publicação com **efeitos operacionais a partir da competência novembro de 2019**".
- **Confirmação no SIGTAP (arquivos por competência):** L73.2 aparece em `rl_procedimento_cid` do
  0604380062 a partir de **201911**, sem lacunas até 202610. A quantidade máxima passa a 7 na mesma
  competência. Até 201910 nenhum procedimento do SIGTAP tinha L73.2 entre os CID de medicamento.
- **O que muda no dado:** **a partir da competência 11/2019, a APAC 06.04.38.006-2 com CID principal
  L73.2 passa a ser aceita no SIA**. Antes disso, uma APAC de adalimumabe com L73.2 seria rejeitada
  pela crítica do SIA. Se aparecer APAC L732 antes de 201911 na série longa, é anomalia a descrever
  (ver `plano_expansao_2010.md` §4.2).
- **Corroboração empírica (Conitec):** o Relatório de Reavaliação nº 01, de outubro/2021, "Adalimumabe
  para hidradenite supurativa", usa a SABEIS com os códigos 06.04.38.001-1, 06.04.38.006-2 e
  06.04.38.009-7 e CID L73.2. Ele registra que "a implementação da tecnologia foi iniciada em
  **novembro de 2019**", com 15 usuários e 54 unidades aprovadas em 11/2019, chegando a 588 usuários
  em 02/2021. Cita o intervalo de 12 meses entre incorporação e oferta.
  <https://www.gov.br/conitec/pt-br/midias/radar/2021/20220714_Relatorio_Reavaliacao_01_Adalimumabe_Hidradenite_supurativa.pdf>

### 3.2 Inclusão de L73.2 em grupo do CEAF (anexos da PRC)

Não localizei um ato separado que inclua L73.2 ou adalimumabe para HS num grupo de financiamento do CEAF
(Grupo 1A/1B), por exemplo uma alteração nos anexos do CEAF na Portaria de Consolidação. A Portaria
1.217/2019 é o ato que habilita o registro no SIA `[VERIFICAR grupo de financiamento do adalimumabe para
L73.2 na RENAME/anexos do CEAF]`.

---

## 4. Biossimilares de adalimumabe — CONFIRMADO no DOU e no SIGTAP

Motivo dos atos: "diferenciação administrativa dos medicamentos biológicos - originador e biossimilar,
no caso adalimumabe 40 mg injetável", a pedido das secretarias estaduais.

| Código | Nome SIGTAP | Ato | DOU | Efeito no SIA | 1ª competência com L73.2 no SIGTAP |
|---|---|---|---|---|---|
| 06.04.38.012-7 | ADALIMUMABE 40 MG INJETÁVEL (POR SERINGA PREENCHIDA) (BIOSSIMILAR A) | Portaria SAES/MS nº 211, de 29/06/2022 | 30/06/2022, ed. 122, p. 142; republicada 05/07/2022, ed. 125, p. 212 | "a partir da competência Julho/2022" | 202207 |
| 06.04.38.013-5 | ADALIMUMABE 40 MG INJETÁVEL (POR SERINGA PREENCHIDA) (BIOSSIMILAR B) | Portaria SAES/MS nº 442, de 17/08/2022 | 31/08/2022, ed. 166, p. 197 | "a partir da competência seguinte à data de sua publicação" | 202209 |
| 06.04.38.014-3 | ADALIMUMABE 40 MG INJETÁVEL (POR SERINGA PREENCHIDA) (BIOSSIMILAR C) | Portaria Conjunta SAES/SCTIE nº 40, de 24/02/2026 | 10/03/2026, ed. 46, p. 120 | "a partir da competência de março de 2026" | 202603 |

Links:
- 211/2022: <https://www.in.gov.br/web/dou/-/portaria-n-211-de-29-de-junho-de-2022-411392465> (republicação: <https://www.in.gov.br/web/dou/-/portaria-n-211-de-29-de-junho-de-2022-%2A-412880652>)
- 442/2022: <https://www.in.gov.br/web/dou/-/portaria-n-442-de-17-de-agosto-de-2022-425750297>
- Conjunta 40/2026: <https://www.in.gov.br/web/dou/-/portaria-conjunta-saes/sctie-n-40-de-24-de-fevereiro-de-2026-691477534>

Todos os três códigos são APAC (proc. principal), alta complexidade, financiamento Assistência
Farmacêutica, quantidade máxima 7. A descrição permite registrar mais de 3 seringas para "Hidradenite
supurativa (CID-10: L73.2)".

**O que muda no dado:** desde 07/2022 o canal medicamento se divide entre o originador (0604380062) e o
biossimilar A, e desde 09/2022 também o B. Para contar dispensação de adalimumabe para HS é preciso
**somar os códigos**. A troca de código não é mudança de demanda, e a quebra no 0604380062 depois de
07/2022 é administrativa. O biossimilar C só entra em 2026 e não afeta a série 2010–2025.

---

## 5. Outros marcos que afetam a série 2010–2025

### 5.1 Criação do CEAF e migração dos códigos de medicamento (2010)

- **Portaria GM/MS nº 2.981, de 26/11/2009** ("Aprova o Componente Especializado da Assistência
  Farmacêutica"). O art. 77 diz que ela "entrará em vigor após noventa (90) dias da sua publicação". Li o
  texto numa cópia da SES-MT (fonte secundária):
  <https://www.saude.mt.gov.br/storage/old/files/2981-%5B3050-120110-SES-MT%5D.pdf>. A busca do CONASS
  indica publicação original no DOU nº 229 de 1º/12/2009, p. 71; o cabeçalho tem "(*)", sinal de
  republicação. `[VERIFICAR link DOU/saudelegis; bvsms.saude.gov.br respondeu 503 nesta sessão]`.
- **O que o SIGTAP mostra (CONFIRMADO):** a forma de organização 06.04.38 ("Inibidores do fator de
  necrose tumoral alfa (TNF-a)") existe desde 201002. O 0604380011 existe desde **201003**, e
  `rl_procedimento_origem` o liga ao antigo **0601010019** ("ADALIMUMABE (A) 40 MG ... POR TRATAMENTO
  MENSAL", APAC), que vigora de 200801 a **201005**. Houve sobreposição de 201003 a 201005.
- **Relevância para HS:** nenhuma no canal medicamento, porque nenhum desses códigos aceitava L73.2
  (`sigtap_hs.csv`). Mas a mudança de unidade, de "por tratamento mensal" para "por seringa", e de
  código em 2010 afeta qualquer série de adalimumabe total, para todas as indicações, usada como
  comparação ou denominador.

### 5.2 Novos códigos de adalimumabe sem L73.2

- **0604380062** (seringa, 40 mg) existe desde **201101**, ou seja, antes da HS. Só ganha L73.2 em 201911.
- **0604380097** (frasco-ampola) existe desde **201907** e nunca teve L73.2.
- **0604380011** (seringa) existe desde 201003, é ainda vigente e nunca teve L73.2.
- Uma APAC L732 com 0604380011 ou 0604380097 seria incompatível com o SIGTAP.

### 5.3 Mudança de instrumento de registro no SIA: o canal clínico só passa a ter CID a partir de 2011–2014

Este é o marco **mais importante para o canal clínico** em 2010–2019, e não é específico de HS. O
SIA-PA só tem CID útil em registros **BPA-I** e **APAC**; o **BPA-C** (consolidado) não leva CID. Os
arquivos SIGTAP (`rl_procedimento_registro`) mostram:

| Código | Procedimento | Instrumento ao longo do tempo |
|---|---|---|
| 0301010072 | Consulta médica em atenção especializada (o principal código do canal clínico HS na v1) | só BPA-C até **201312**; BPA-C ou BPA-I a partir de **201401** |
| 0301060096 | Atendimento médico em UPA | só BPA-C até 201312; BPA-C ou BPA-I a partir de 201401 |
| 0203020030 | Anatomopatológico | BPA-C até 201012; **BPA-I a partir de 201101** |
| 0401010058 | Excisão de lesão de pele | BPA-C até 201012; **BPA-I a partir de 201101** |
| 0401010104 | Incisão e drenagem de abscesso | BPA-C até 201012; **BPA-I a partir de 201101** |

**O que muda no dado:** antes de **01/2014**, consultas especializadas com L73.2 não podem aparecer no
SIA-PA com CID. Entre 2010 e 2013 o canal clínico L732 fica perto de zero **por construção**, e não por
ausência de doença. Mesmo depois de 2014 o BPA-I é opcional para a consulta, porque o BPA-C continua
permitido. Por isso a cobertura do CID depende da adesão de cada UF ao BPA-I. Isso pesa na série
interrompida: o período antes da incorporação, 2010–2019, tem uma descontinuidade interna em 201101 e
201401. **Os atos normativos dessas mudanças não foram identificados** `[VERIFICAR: portarias SAS de
2010 e 2013 que alteram o instrumento de registro; a busca do DOU no in.gov.br não cobre esse período]`.

### 5.4 Compatibilidade de L73.2 com exames anatomopatológico e citológico (2019)

- O SIGTAP mostra L73.2 compatível com **0203020030** (anatomopatológico) a partir de **201906** e com
  **0203010035** (citologia) a partir de **201908**. É CONFIRMADO no arquivo.
- Atos prováveis: **Portaria SAS/MS nº 202, de 08/02/2019** (DOU 15/02/2019, ed. 33, p. 54), que
  "compatibiliza códigos da CID-10 com o procedimento 02.03.02.003-0" e inclui L73.0–L73.2 na lista.
  <https://www.in.gov.br/web/dou/-/portaria-n-202-de-8-de-fevereiro-de-2019-63578044>. O art. 3º põe
  vigência na publicação, mas o SIGTAP só reflete em 201906 `[VERIFICAR defasagem]`. E **Portaria
  SAES/MS nº 815, de 02/07/2019** (DOU 10/07/2019, ed. 131, p. 64), que altera atributos e
  compatibilidades do 02.03.01.003-5, com efeito na competência seguinte (201908).
  <https://www.in.gov.br/web/dou/-/portaria-n-815-de-2-de-julho-de-2019-191451091> `[VERIFICAR a que
  procedimento se liga a lista com L73.2 no texto]`.
- **O que muda no dado:** a partir de 2019, biópsias e anatomopatológicos com CID L73.2 passam a ser
  aceitos sem incompatibilidade. Isso pode aumentar o L732 no canal clínico do SIA perto da incorporação,
  sem ligação causal com o adalimumabe. É um **confundidor de calendário** para o marco 201911.

### 5.5 Procedimentos cirúrgicos e SIH

- Nenhum procedimento cirúrgico ou clínico de AIH tem L73.2 na lista de CID compatível do SIGTAP, em
  nenhuma competência de 200801 a 202610. Mesmo assim, a v1 (2020–2025) tem 632 AIH com DIAG_PRINC
  L732, sobretudo em 0401020053, 0401020100 e 0303080094 (`sigtap_hs.csv`, status VERIFICAR). Como a
  crítica do SIH trata o CID principal fora da lista não está documentado aqui
  `[VERIFICAR regra de compatibilidade CID x procedimento no SIH/SISAIH01]`.
- Não há procedimento com "hidrosadenite", "hidradenite" ou "sudorípara" no nome, em nenhuma
  competência de 200801 a 202610.

### 5.6 Mudanças de código SIGTAP

Fora o que está em §5.1, §4 e §5.3, não encontrei mudança de código dos procedimentos listados em
`sigtap_hs.csv` entre 2010 e 2025. Todos os códigos cirúrgicos e de exame existem sem interrupção de
200801 a 202610. Para os medicamentos, só houve as criações e encerramentos já descritos.

---

## 6. Marco pré-especificado para a série interrompida

**Proposta primária: `201911`.**

Justificativa:
1. É a **primeira competência em que o sistema aceita** a APAC de adalimumabe com CID L73.2. A
   Portaria SAES/MS 1.217/2019 diz "efeitos operacionais a partir da competência novembro de 2019", e
   o SIGTAP tem L73.2 no 0604380062 desde 201911. É a data em que o dado pode mudar, e não só a norma.
2. Coincide com o início real da dispensação segundo o próprio MS: o Relatório de Reavaliação Conitec
   nº 01/2021 registra 15 usuários em 11/2019. A data normativa e a data operacional caem na mesma
   competência, o que reduz a ambiguidade de pré-especificação.
3. Fica depois de todos os atos que preparam a oferta: incorporação em 10/2018, PCDT em 09/2019 e
   compatibilização dos anatomopatológicos em 06 a 08/2019. Fica antes do choque da COVID (03/2020),
   que entra como covariável separada.

**Alternativa: `201811`** (primeira competência completa depois da Portaria SCTIE/MS 48/2018, DOU 17/10/2018).
Ela testa se houve efeito de anúncio ou de difusão da informação sobre a codificação clínica de
L73.2, antes da dispensação. São 12 meses antes do marco primário, o bastante para separar os dois
numa série mensal.

**Notas de uso:**
- O PCDT (16/09/2019, primeira competência completa 201910) fica a só um mês do marco primário. Não dá
  para separá-lo de 201911. Como sensibilidade, tratar **201909–201910 como janela de transição**,
  excluindo ou modelando com indicadora própria.
- No canal medicamento, o marco é por construção o início da série. A entrada dos biossimilares
  (**202207**, e **202209** para o B) é o segundo evento, como covariável (ver `plano_expansao_2010.md`
  §4.2). Somar os códigos 0604380062, 0604380127 e 0604380135.
- O canal clínico do SIA antes da incorporação tem quebras estruturais próprias em **201101** e
  **201401** (§5.3). O período antes do marco deve começar em **201401**, ou o modelo deve incluir
  indicadoras nesses pontos. Senão a inclinação antes do marco reflete a migração BPA-C → BPA-I, e não
  a codificação de HS.

---

## 7. Pendências `[VERIFICAR]`

1. Link do DOU ou do saudelegis da Portaria GM/MS 2.981/2009 e data exata da publicação e da republicação. O texto foi lido numa cópia da SES-MT.
2. Contagem formal do prazo de 180 dias da Portaria SCTIE 48/2018; a minha conta dá cerca de 15/04/2019.
3. PDF do Relatório de Recomendação Conitec nº 473/2019 (PCDT). Só é citado na portaria.
4. Se o PCDT está em atualização formal em 2025–2026. A informação vem só de pareceres NatJus/TJRJ.
5. Grupo de financiamento do CEAF do adalimumabe para L73.2 (1A ou 1B) e o ato que o fixa.
6. Atos normativos das mudanças de instrumento BPA-C → BPA-I em 201101 e 201401.
7. Defasagem entre a Portaria SAS 202/2019 (DOU 02/2019) e o aparecimento de L73.2 no 0203020030 (201906). Também o vínculo exato da Portaria SAES 815/2019 com o 0203010035.
8. Regra da crítica CID x procedimento no SIH para L73.2 em procedimentos cuja lista não inclui o código.

## 8. Método de reprodução (SIGTAP)

Usei as 226 tabelas mensais `TabelaUnificada_AAAAMM_*.zip` (200801 a 202610), baixadas de
`ftp://ftp2.datasus.gov.br/pub/sistemas/tup/downloads/`. Cada arquivo foi lido com o seu próprio
`*_layout.txt`, porque as larguras mudam entre versões (ex.: `VL_SH`). Tabelas usadas: `tb_procedimento`
(presença e nome por competência), `rl_procedimento_registro` (instrumento), `rl_procedimento_cid`
(`CO_CID == "L732"`), `rl_procedimento_origem` e `tb_forma_organizacao`. "Competência inicial 200801"
em `sigtap_hs.csv` quer dizer "presente desde o primeiro arquivo da Tabela Unificada". "vigente" quer
dizer presente até o último arquivo consultado, 202610. A E2 (`hs_lookup.R`) deve reimplementar essa
leitura em R para versionar a lookup.
