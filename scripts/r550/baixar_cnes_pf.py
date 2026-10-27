#!/usr/bin/env python3
# =============================================================================
# baixar_cnes_pf.py — Baixa o CNES-PF (profissionais) de UM mês por ano, retomável
# Para a E10 do plano_expansao_2010.md (dermatologistas por UF × ano, 2010–2025).
# O CNES não está entre as bases já baixadas no R550-2 (guia §2); mesma regra do
# baixar_brutos.sh do EIM: baixa para .part e só renomeia quando o tamanho bate
# EXATAMENTE com o do FTP; arquivo completo é pulado; tamanho diferente = republicado,
# baixa de novo. Grava também o manifesto (arquivo, url, tamanho).
#
# FTP: ftp.datasus.gov.br/dissemin/publicos/CNES/200508_/Dados/PF/PF{UF}{AA}{MM}[parte].dbc
# Uso (NO R550-2, em tmux): python3 baixar_cnes_pf.py [--mes 6] [--ano-min 2010] [--ano-max 2025]
# Saída: ~/Documentos/ronald/datasus_raw/CNES-PF/ + manifest/manifesto_cnes_pf.tsv
# =============================================================================
import argparse, ftplib, os, re, sys, time

HOST, DIR = "ftp.datasus.gov.br", "/dissemin/publicos/CNES/200508_/Dados/PF"
RAIZ = os.path.expanduser("~/Documentos/ronald/datasus_raw")

ap = argparse.ArgumentParser()
ap.add_argument("--mes", type=int, default=6)
ap.add_argument("--ano-min", type=int, default=2010)
ap.add_argument("--ano-max", type=int, default=2025)
a = ap.parse_args()

dest_dir = os.path.join(RAIZ, "CNES-PF"); os.makedirs(dest_dir, exist_ok=True)
os.makedirs(os.path.join(RAIZ, "manifest"), exist_ok=True)

def conectar():
    f = ftplib.FTP(HOST, timeout=120); f.login(); f.cwd(DIR); f.voidcmd("TYPE I"); return f

ftp = conectar()
rx = re.compile(r"^PF([A-Z]{2})(\d{2})(\d{2})([a-z]?)\.dbc$", re.I)
alvo = []
for nome in ftp.nlst():
    m = rx.match(nome)
    if not m: continue
    ano, mes = 2000 + int(m.group(2)), int(m.group(3))
    if mes == a.mes and a.ano_min <= ano <= a.ano_max:
        alvo.append((nome, m.group(1).upper(), ano, m.group(4).lower()))
alvo.sort()
print(f"{len(alvo)} arquivos PF no mês {a.mes:02d}, {a.ano_min}–{a.ano_max}", flush=True)

man = os.path.join(RAIZ, "manifest", "manifesto_cnes_pf.tsv")
with open(man, "w") as fm:
    fm.write("base\tdestino\tano\tuf\tperiodo\tarquivo\turl\ttamanho\n")
    for nome, uf, ano, parte in alvo:
        tam = ftp.size(nome)
        fm.write(f"CNES-PF\tCNES-PF\t{ano}\t{uf}\t{ano}{a.mes:02d}{parte}\t{nome}\tftp://{HOST}{DIR}/{nome}\t{tam}\n")
        dest = os.path.join(dest_dir, nome)
        if os.path.exists(dest) and os.path.getsize(dest) == tam: continue
        if os.path.exists(dest): os.remove(dest)               # republicado
        part = dest + ".part"
        for tent in range(3):
            try:
                with open(part, "wb") as fp: ftp.retrbinary(f"RETR {nome}", fp.write)
                break
            except (ftplib.all_errors) as e:
                print(f"  [retry {tent + 1}] {nome}: {e}", flush=True); time.sleep(10); ftp = conectar()
        if os.path.getsize(part) == tam:
            os.rename(part, dest); print(f"  OK {nome} ({tam} B)", flush=True)
        else:
            print(f"  [FALHA] {nome}: {os.path.getsize(part)} != {tam}", flush=True)
ftp.quit()
print("fim", flush=True)
