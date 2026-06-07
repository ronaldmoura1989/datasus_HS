# Adalimumabe e biossimilares no SUS: por que a migração e a heterogeneidade entre estados

> Pesquisa de contexto para o relatório DATASUS sobre Hidradenite Supurativa (HS).
> Motivação: nos microdados do SIA-PA (2020–2025), as dispensações de adalimumabe
> aparecem em três procedimentos SIGTAP — **referência** (`0604380062`),
> **Biossimilar A** (`0604380127`) e **Biossimilar B** (`0604380135`) — com migração
> rápida do referência para os biossimilares (2022→2025) e heterogeneidade entre UFs.
>
> Princípio do projeto: **não inventar números**. Itens não confirmados em fonte
> oficial estão marcados com `[VERIFICAR]`.

## Síntese executiva

O achado do relatório reflete uma **decisão administrativa nacional, não clínica**. A
partir do **3º trimestre de 2022**, o Ministério da Saúde passou a abastecer o SUS com
adalimumabe oriundo de **duas Parcerias para o Desenvolvimento Produtivo (PDP)** —
**Bio-Manguinhos/Fiocruz** (tecnologia Fresenius Kabi, produto **Idacio®**) e
**Instituto Butantan** (PDP com Sandoz, produto **Hyrimoz®**) — mantendo o referência
**Humira®** (AbbVie) como cota minoritária. As cotas anunciadas foram **~40%
Bio-Manguinhos / ~30% Butantan / ~30% referência**, com economia esperada por
biológicos de até ~70%. A heterogeneidade entre estados (ex.: MA/RN com mais
"Biossimilar B") é **logística/de distribuição** — qual lote/cota chegou a cada
Secretaria Estadual — e **não** uma escolha terapêutica do prescritor. Os códigos
SIGTAP "A/B" são **genéricos**: não há, nas fontes públicas, mapeamento oficial de qual
código corresponde a Idacio ou Hyrimoz — qualquer atribuição A↔fabricante é inferência
`[VERIFICAR]`.

---

## 1. Por que o SUS migrou do referência para biossimilares

A migração foi **deliberada e estrutural**, ancorada em três mecanismos:

- **Compra centralizada via CEAF (Grupo 1A).** O adalimumabe 40 mg é adquirido de forma
  **centralizada pelo Ministério da Saúde** e repassado às Secretarias Estaduais, que
  distribuem às farmácias de alto custo. Por ser compra nacional, a troca do mix de
  produtos altera simultaneamente o que é dispensado em todo o país — o que explica a
  **rapidez** da migração observada nos microdados.
- **Parcerias para o Desenvolvimento Produtivo (PDP).** A entrada dos biossimilares, no
  **3º trimestre de 2022**, decorre de PDPs com **Bio-Manguinhos/Fiocruz** (Fresenius
  Kabi) e **Instituto Butantan** (Sandoz, PDP assinada em dez/2021), visando
  nacionalização da produção e redução de dependência de importação.
- **Economia esperada.** A política é justificada por reduções de custo expressivas —
  narrativas oficiais e do setor citam **até ~50%** de redução no custo de tratamento e,
  para biológicos, economia de até **~71%**. `[VERIFICAR valores exatos]`

A cota do **referência (Humira®)** é adquirida por **pregão eletrônico**; há registro de
**pregões recentes desertos** para o referência, o que reforça a participação dos
biossimilares e ajuda a explicar a queda do referência para ~1.500 dispensações em 2025.

## 2. Por que alguns estados usam mais o "Biossimilar A" e outros o "B"

**A escolha entre biossimilares no SUS é, predominantemente, de compra pública e
logística — não clínica.** Mecanismo provável:

- O MS compra de **dois fornecedores PDP** com cotas nacionais (~40% Bio-Manguinhos,
  ~30% Butantan) e distribui por **lotes/remessas** às Secretarias Estaduais.
- A **distribuição não é homogênea no tempo nem no território**: cada remessa contém o
  produto disponível naquele ciclo. Estados acabam dispensando majoritariamente o
  fabricante que receberam — MA e RN podem concentrar o "Biossimilar B" simplesmente por
  terem recebido aquele lote.
- **Faltas/descontinuidades** (houve desabastecimento de adalimumabe no SUS em 2024)
  forçam substituições por disponibilidade, ampliando a heterogeneidade regional.
- A **ANVISA não atribui intercambiabilidade automática** no registro; na prática do
  SUS, o paciente recebe o produto que a farmácia de alto custo tem em estoque.

**Conclusão para o relatório:** a heterogeneidade estadual A vs B é **assinatura
logística da distribuição federal**, e **não** preferência clínica regional.

## 3. Diferença de custo (A vs B vs referência)

Não há, nas fontes públicas, **valores unitários oficiais de aquisição** do MS por
código/fabricante. O que se pode afirmar:

- **Direção e magnitude:** biossimilares são sistematicamente mais baratos. A **CMED
  (Resolução 3/2025)** limita o preço de biossimilar a **no máximo 80%** do preço do
  referência e prevê redução de ~20% no preço do originador após o primeiro biossimilar.
  Narrativas citam economia de **até ~50%** no tratamento e **~71%** no gasto com
  biológicos. `[VERIFICAR]`
- **A vs B:** não há diferença de preço pública confiável **entre** os dois
  biossimilares. Como ambos entram por PDP (preço negociado), o diferencial A↔B
  provavelmente é pequeno e **não é o driver da escolha** — o driver é cota/disponibilidade.
  `[VERIFICAR]`
- **Referência (varejo, só ordem de grandeza):** o Humira® aparece no varejo a partir de
  ~R$ 15.762 por embalagem de 2 unidades (preço de consumidor, **não** o valor de
  aquisição do governo, muito menor). Serve apenas para dimensionar — **não** para
  inferir custo SUS. `[VERIFICAR]`

> **Nota metodológica (importante para este projeto):** os campos de valor do SIA-PA
> (`pa_valapr`, `pa_valpro`, etc.) vêm **zerados** para os procedimentos de adalimumabe
> (quirk do CEAF/alto custo — o valor financeiro não é registrado no SIA-PA). Logo, o
> **custo real não é recuperável** desta extração; exigiria a base de **APAC de
> medicamentos** ou as **atas/preços de aquisição do MS**. A `pa_qtdapr` (≈4 seringas de
> 40 mg por registro) permite medir **volume/doses dispensadas**, não R$.

## 4. Eficácia e segurança: biossimilaridade, intercambiabilidade e switching

**Marco regulatório (ANVISA).** Um biossimilar é aprovado por **exercício de
comparabilidade** (qualidade, não-clínica e clínica) que demonstra **ausência de
diferenças clinicamente significativas** frente ao referência. A ANVISA **não confere
status de "intercambiável"** no registro e **mantém a decisão de troca na prática
clínica**, com participação do prescritor e farmacovigilância. Estudos específicos de
intercambiabilidade **não são exigidos** para registro.

**Evidência de equivalência.** Para a maioria das indicações (com dados robustos em
**psoríase** e artrite reumatoide), os biossimilares de adalimumabe mostram eficácia e
segurança comparáveis, e o **switching referência→biossimilar** é, em geral, bem tolerado.

**Ressalva específica para HS (relevante para este relatório).** A literatura de
**mundo real em hidradenite supurativa** é menos tranquilizadora:
- Análise multicêntrica real-world (HS) reportou **resposta superior do originador** em
  pacientes naïve na semana 52 (HiSCR-50 51% vs 24%; p=0,0001) e **maior chance de perda
  de resposta com biossimilar** (HR ~2,73).
- **Switching originador→biossimilar** associou-se a maior perda de resposta (HR ~2,4).
- Esses achados **contrastam** com a equivalência em psoríase e devem ser lidos com
  cautela (estudos observacionais; confundimento por indicação/gravidade; efeito nocebo).
  Há também séries em HS mostrando manutenção de resposta após a troca.

**A vs B (biossimilar↔biossimilar).** Sem evidência de superioridade de um sobre o outro
no Brasil. Estudos prospectivos (ex.: Doença de Crohn) sugerem múltiplos switches
biossimilar→biossimilar viáveis, mas faltam dados específicos para HS. `[VERIFICAR para HS]`

**Implicação para o relatório:** registrar que a troca foi **conduzida por gestão de
abastecimento**, e que a evidência de equivalência é forte em psoríase/AR porém **mais
heterogênea em HS** — limitação clínica a sinalizar, sem afirmar superioridade do
referência como verdade definitiva.

## 5. Biossimilares no Brasil e correspondência com os códigos SIGTAP

**Registrados na ANVISA** (lista não exaustiva): **Humira®** (referência, AbbVie),
**Amgevita®** (Amgen), **Hyrimoz®/Halimatoz®** (Sandoz), **Idacio®** (Fresenius Kabi),
**Hadlima®** (Organon), **Hulio®** (Viatris/Mylan), **Yuflyma®**, **Xilbrilada®**, entre
outros.

**Os dois biossimilares que abastecem o SUS via PDP (2022→):**
- **Bio-Manguinhos/Fiocruz** → **Idacio®** (tecnologia Fresenius Kabi). Cota ~**40%**.
- **Instituto Butantan** → **Hyrimoz®** (Sandoz). Cota ~**30%**. Há nota oficial sobre
  **embalagem do Hyrimoz® atualizada com o nome do Butantan** no SUS.
- **Referência Humira®** (AbbVie), via pregão → cota ~**30%**.

**Mapeamento A/B ↔ fabricante — limitação honesta:** os procedimentos `0604380127`
("BIOSSIMILAR A") e `0604380135` ("BIOSSIMILAR B") são **rótulos genéricos e
fabricante-agnósticos**. **Não há documento oficial declarando qual código corresponde a
Idacio ou Hyrimoz.** É *plausível* (por cota/volume) que **A = Idacio** (maior volume
nacional) e **B = Hyrimoz**, coerente com as cotas ~40%/30% e com a predominância de A —
mas é **inferência, não fato** `[VERIFICAR]`. Poderia ser checado cruzando as
**competências de entrada de cada código no SIGTAP** (`fetch_sigtab()`) com as datas de
início das PDPs (Bio-Manguinhos: ago/2022; Butantan: nov–dez/2022).

---

## Checklist do que confirmar antes de publicar (`[VERIFICAR]`)

1. **Mapeamento A↔Idacio / B↔Hyrimoz** — não documentado publicamente; confirmar via
   competências do SIGTAP e datas das PDPs, ou tratar como rótulos genéricos.
2. **Valores de aquisição** A vs B vs referência — o SIA-PA vem **zerado**; usar APAC de
   medicamentos ou atas/preços do MS.
3. **Cotas 40/30/30** — anunciadas em 2022; podem ter mudado em 2023–2025 (inclusive por
   pregões desertos do referência).
4. **Eficácia em HS** — equivalência sólida em psoríase/AR, mas sinais de menor
   resposta/maior perda com biossimilar em séries real-world de HS (observacional).

---

## Referências

1. InfoSUS / SES-SC — Adalimumabe (compra centralizada, cotas, distribuição às SES).
   <http://infosus.saude.sc.gov.br/index.php/Adalimumabe>
2. Bio-Manguinhos / Fiocruz — Início do fornecimento de adalimumabe biossimilar ao SUS.
   <https://www.bio.fiocruz.br/index.php/br/noticias/3039-bio-manguinhos-fiocruz-inicia-o-fornecimento-de-adalimumabe-biossimilar-ao-sistema-unico-de-saude>
3. Instituto Butantan — Transferência tecnológica com Sandoz / entrega ao SUS.
   <https://butantan.gov.br/noticias/butantan-e-sandoz-iniciam-transferencia-tecnologica-com-entrega-de-400-mil-unidades-de-medicamento-para-artrite-reumatoide-ao-sus>
4. Instituto Butantan — Hyrimoz® (adalimumabe) com embalagem atualizada no SUS.
   <https://butantan.gov.br/noticias/medicamento-hyrimoz%C2%AE-adalimumabe-tera-embalagem-atualizada-no-sus-com-nome-do-butantan--entenda>
5. SBD — Bio-Manguinhos/Fiocruz produzirá Idacio® no Brasil.
   <https://www.sbd.org.br/sbd-informa-bio-manguinhos-fiocruz-afirma-acordo-para-produzir-adalimumabe-biossimilar-idacio%EF%B8%8F-no-brasil/>
6. Laes & Haes — 1º biossimilar Sandoz/Butantan (Hyrimoz) chega ao SUS.
   <https://laes-haes.com.br/noticias/chega-ao-sus-primeiro-medicamento-biossimilar-da-parceria-entre-sandoz-e-instituto-butantan/>
7. Organon — Biossimilares e reduções de custo > 70%.
   <https://www.organon.com/brazil/news/medicamentos-biossimilares-entram-na-pauta-do-governo-com-reducoes-de-custos-de-mais-de-70/>
8. Biored Brasil — Falta de adalimumabe nas farmácias de alto custo do SUS (jul/2024).
   <https://www.bioredbrasil.com.br/falta-de-adalimumabe-nas-farmacias-de-alto-custo-do-sus-julho-de-2024/>
9. ANVISA — Biossimilares são intercambiáveis? (substituição não automática).
   <https://www.gov.br/anvisa/pt-br/assuntos/noticias-anvisa/2018/biossimilares-sao-intercambiaveis>
10. ANVISA — Nota Técnica 23/2018 GGMED (intercambialidade).
    <https://www.gov.br/anvisa/pt-br/centraisdeconteudo/publicacoes/medicamentos/publicacoes-sobre-medicamentos/nota-tecnica-no-23-2018-ggmed-intercambialidade.pdf/view>
11. ANVISA / CMED — Atualização da precificação (teto de 80% para biossimilares).
    <https://www.gov.br/anvisa/pt-br/assuntos/noticias-anvisa/2026/cmed-atualiza-e-aprimora-a-precificacao-de-novos-medicamentos-no-pais>
12. Originador vs biossimilar de adalimumabe em HS (real-world, multicêntrico).
    <https://pmc.ncbi.nlm.nih.gov/articles/PMC12615301/>
13. Switching originador→biossimilar em HS (experiência clínica).
    <https://www.ncbi.nlm.nih.gov/pmc/articles/PMC8879480/>
14. Switching biossimilar→biossimilar (Doença de Crohn, prospectivo).
    <https://www.ncbi.nlm.nih.gov/pmc/articles/PMC8348781/>
15. ConsultaRemedios — Preço de referência do Humira (varejo).
    <https://consultaremedios.com.br/adalimumabe/pa>

*Pesquisa conduzida com apoio do agente epidemiologista (revisão e curadoria de fontes).
Datas e valores marcados `[VERIFICAR]` devem ser confirmados em fonte primária antes de
uso oficial.*
