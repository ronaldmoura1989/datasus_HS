# =============================================================================
# gerar_apresentacao.R — Monta a apresentação (.pptx) sobre HS para pacientes
# Esqueleto fiel: gráficos reais (docs/), paleta do projeto, notas do apresentador.
# Segue o roteiro de apresentacao_HS_15min.md. Editar o visual depois no PowerPoint.
# Saída: apresentacao_HS_15min.pptx (raiz). Rodar: Rscript scripts/gerar_apresentacao.R
# =============================================================================
suppressPackageStartupMessages({ library(officer); library(here) })
here::i_am("scripts/gerar_apresentacao.R")

# Paleta -----------------------------------------------------------------------
ROXO_PROF <- "#3E2A4D"; ROXO_ESC <- "#5C3F6C"; ROXO_MED <- "#816095"
ROXO_CLA  <- "#A87FA8"; ROSE_MED <- "#D8B4C4"; ROSE_CLA <- "#E9CDC9"
FONTE <- "Calibri"
W <- 10; H <- 7.5                      # template 4:3 (trocável p/ widescreen no PPT)

doc_path <- function(...) here::here("docs", ...)

# Fundo sólido (PNG) p/ slides coloridos --------------------------------------
bg_solido <- function(cor) {
  fp <- tempfile(fileext = ".png")
  grDevices::png(fp, width = 2000, height = 1500, bg = cor); plot.new(); grDevices::dev.off()
  fp
}
BG_ROXO <- bg_solido(ROXO_ESC)

# Helpers de formatação --------------------------------------------------------
txt   <- function(t, size, cor = ROXO_PROF, bold = FALSE)
  fpar(ftext(t, fp_text(font.size = size, color = cor, bold = bold, font.family = FONTE)))
bullets <- function(itens, size = 22, cor = ROXO_PROF)
  do.call(block_list, lapply(itens, function(b)
    fpar(ftext(paste0("•  ", b), fp_text(font.size = size, color = cor, font.family = FONTE)),
         fp_p = fp_par(padding.bottom = 10))))

# Ajusta imagem a uma caixa preservando proporção
fit_img <- function(path, maxw = 8.6, maxh = 5.1) {
  d <- dim(png::readPNG(path)); asp <- d[2] / d[1]   # w/h
  w <- maxw; h <- w / asp
  if (h > maxh) { h <- maxh; w <- h * asp }
  list(img = external_img(path, width = w, height = h),
       left = (W - w) / 2, top = 1.55, width = w, height = h)
}

# Adiciona um slide de TEXTO (título + bullets) + notas
slide_texto <- function(doc, titulo, itens, notas) {
  doc <- add_slide(doc, layout = "Blank", master = "Office Theme")
  doc <- ph_with(doc, block_list(txt(titulo, 30, ROXO_PROF, TRUE)),
                 location = ph_location(left = 0.5, top = 0.4, width = 9, height = 1))
  doc <- ph_with(doc, bullets(itens),
                 location = ph_location(left = 0.7, top = 1.7, width = 8.6, height = 5.2))
  set_notes(doc, notas, location = notes_location_type("body"))
}

# Adiciona um slide de IMAGEM (título + gráfico) + notas
slide_imagem <- function(doc, titulo, img_path, notas, legenda = NULL) {
  doc <- add_slide(doc, layout = "Blank", master = "Office Theme")
  doc <- ph_with(doc, block_list(txt(titulo, 30, ROXO_PROF, TRUE)),
                 location = ph_location(left = 0.5, top = 0.4, width = 9, height = 1))
  f <- fit_img(img_path)
  doc <- ph_with(doc, f$img,
                 location = ph_location(left = f$left, top = f$top, width = f$width, height = f$height))
  if (!is.null(legenda))
    doc <- ph_with(doc, block_list(txt(legenda, 16, ROXO_MED)),
                   location = ph_location(left = 0.7, top = 6.9, width = 8.6, height = 0.5))
  set_notes(doc, notas, location = notes_location_type("body"))
}

# Slide de FUNDO COLORIDO (capa / clímax) + notas
slide_cor <- function(doc, titulo, subtitulo, notas, size_titulo = 40) {
  doc <- add_slide(doc, layout = "Blank", master = "Office Theme")
  doc <- ph_with(doc, external_img(BG_ROXO, width = W, height = H),
                 location = ph_location(left = 0, top = 0, width = W, height = H))
  doc <- ph_with(doc, block_list(txt(titulo, size_titulo, "#FFFFFF", TRUE)),
                 location = ph_location(left = 0.8, top = 2.6, width = 8.4, height = 2))
  if (nzchar(subtitulo))
    doc <- ph_with(doc, block_list(txt(subtitulo, 22, ROSE_CLA)),
                   location = ph_location(left = 0.8, top = 4.6, width = 8.4, height = 1.5))
  set_notes(doc, notas, location = notes_location_type("body"))
}

# =============================================================================
# Construção
# =============================================================================
doc <- read_pptx()
# remove o slide inicial em branco do template, se houver
if (length(doc) > 0) doc <- remove_slide(doc, 1)

## 1 — Capa
doc <- slide_cor(doc,
  "Hidradenite Supurativa: o que os dados do SUS contam sobre o nosso cuidado",
  "Uma conversa sobre números — e sobre pessoas",
  "Hoje eu trouxe muitos gráficos. Mas quero combinar uma coisa logo no começo: cada ponto, cada barra desses gráficos é uma pessoa como você.",
  size_titulo = 32)

## 2 — O que é a HS
doc <- slide_texto(doc, "O que é a Hidradenite Supurativa?",
  c("Doença crônica, inflamatória e dolorosa da pele.",
    "Costuma começar jovem e atinge mais mulheres.",
    "Não é falta de higiene e não é contagiosa.",
    "Impacta muito a qualidade de vida: dor, recidiva, trabalho, sono, autoestima."),
  "Valide a experiência da plateia. Quem vive com HS sabe: não é 'só um caroço'. É dor, é recidiva, é impacto profundo na vida.")

## 3 — De onde vêm os dados
doc <- slide_texto(doc, "De onde vêm estes números",
  c("Cada atendimento no SUS gera um registro — sem nome, protegido.",
    "Olhamos milhões desses registros, de 2020 a 2025.",
    "Três sistemas: atendimento ambulatorial, internações e mortalidade.",
    "Ninguém foi identificado: é como contar quem passou por uma porta."),
  "Desmistifique: são dados anônimos e protegidos. É como contar quantas pessoas passaram por uma porta, sem saber quem são.")

## 4 — O que os números NÃO dizem
doc <- slide_texto(doc, "O que os números não dizem",
  c("Eles contam QUEM é atendido — não quantos TÊM a doença.",
    "Muita gente com HS ainda não chegou ao sistema.",
    "Poucos casos em um lugar pode significar pouco ACESSO, não pouca doença.",
    "[Sugestão de arte: metáfora do iceberg — ponta visível x base submersa]"),
  "Se os dados mostram poucos casos em um lugar, isso pode não significar 'pouca doença'. Pode significar 'pouca gente conseguindo ser atendida'.")

## 5 — Crescimento dos atendimentos
doc <- slide_imagem(doc, "Cada vez mais pessoas sendo atendidas",
  doc_path("index_files","figure-html","trend-1.png"),
  "É uma boa notícia: mais pessoas estão sendo vistas. Mas a pergunta é: todas as regiões cresceram igual? Já já a gente descobre que não. (Dica: na arte final, simplifique para mostrar só a linha do atendimento ambulatorial subindo.)",
  legenda = "Atendimentos por HS ao longo dos anos.")

## 6 — Quem é o paciente
doc <- slide_imagem(doc, "Quem é o paciente",
  doc_path("sia_hs_files","figure-html","piramide-1.png"),
  "Esse perfil provavelmente se parece com muitos de vocês aqui. É uma doença que atinge pessoas no auge da vida produtiva e pessoal — sobretudo mulheres jovens.",
  legenda = "A maioria são mulheres adultas jovens.")

## 7 — O biológico e os biossimilares
doc <- slide_imagem(doc, "O tratamento que mudou o jogo: o biológico",
  doc_path("sia_hs_files","figure-html","ada-tipos-1.png"),
  "A maior parte dos atendimentos hoje é a entrega do medicamento biológico (adalimumabe). Biossimilar não é remédio de segunda linha: é equivalente, com mesma eficácia e segurança, custando menos. Cada real economizado pode virar acesso para outra pessoa.",
  legenda = "O SUS migrou do medicamento de referência para versões biossimilares (equivalentes e mais econômicas).")

## 8 — Onde você mora muda o acesso (mapa)
doc <- slide_imagem(doc, "Onde você mora muda o seu acesso",
  doc_path("index_files","figure-html","mapa-1.png"),
  "Não é que a HS não exista no Norte e no Nordeste. É que, em muitos lugares, não há quem diagnostique. Onde há mais dermatologistas, encontra-se mais HS — a diferença de oferta chega a 6 vezes entre estados. Uma doença que ninguém vê é uma doença que ninguém trata.",
  legenda = "Quanto mais escuro, mais HS é encontrada. O cuidado não está distribuído de forma justa.")

## 9 — O paciente invisível (heatmap)
doc <- slide_imagem(doc, "O paciente invisível",
  doc_path("sia_hs_files","figure-html","heatmap-1.png"),
  "Atrás de cada espaço claro nesse mapa há gente convivendo com dor sem diagnóstico. Muitos são confundidos com 'abscesso' e demoram anos para descobrir o que têm. Eles existem mesmo quando o dado não os mostra.",
  legenda = "Cada espaço vazio ou claro representa pessoas que ainda não estão sendo alcançadas.")

## 10 — Peso real da doença
doc <- slide_texto(doc, "A doença pesa pelo dia a dia",
  c("A HS quase não aparece como causa de morte.",
    "Ela pesa pelo sofrimento crônico, pelo custo e pela qualidade de vida.",
    "A complexidade do paciente (outras condições) muitas vezes nem é registrada.",
    "Sua história completa nem sempre é anotada pelo sistema."),
  "A HS raramente mata — mas afeta profundamente o viver. E o sistema ainda registra mal tudo o que vem junto com ela.")

## 11 — O que pode melhorar
doc <- slide_texto(doc, "O que pode (e precisa) melhorar",
  c("Mais diagnóstico na porta de entrada (capacitar a atenção básica).",
    "Teledermatologia para levar o especialista a quem está longe.",
    "Acesso justo ao medicamento em todas as regiões.",
    "Ouvir o paciente e registrar sua história por completo."),
  "Enquadre como direito e esperança: essas não são ideias soltas — saem diretamente do que os dados mostraram. São pedidos legítimos de quem usa o SUS.")

## 12 — Mensagem central (clímax)
doc <- slide_cor(doc, "Vocês não são números.",
  "Por trás de cada gráfico há cidadãos com direito à atenção do sistema de saúde.",
  "Pausa. Eu mostrei muitos números hoje. Mas o mais importante é este: cada um deles é uma pessoa que merece ser vista, diagnosticada e cuidada. Vocês não são dados. São cidadãos.",
  size_titulo = 44)

## 13 — Encerramento
doc <- slide_texto(doc, "Onde buscar cuidado e apoio",
  c("Serviço de referência em dermatologia da sua região.",
    "Associações de pacientes com HS (apoio e informação).",
    "Canais de informação confiáveis sobre a doença e o tratamento.",
    "Obrigado por confiarem a mim a tarefa de contar a história de vocês com respeito."),
  "Procurem cuidado, procurem apoio, não se isolem. E obrigado pela presença e pela confiança.")

# Salvar e validar -------------------------------------------------------------
out <- here::here("apresentacao_HS_15min.pptx")
print(doc, target = out)

chk <- read_pptx(out)
message(sprintf("✓ Apresentação criada: %s (%d slides)", basename(out), length(chk)))
