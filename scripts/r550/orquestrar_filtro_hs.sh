#!/usr/bin/env bash
# =============================================================================
# orquestrar_filtro_hs.sh — Roda filtrar_um_hs.R sobre os DBC 2010+, em paralelo
# Adaptado de datasus_EIM/scripts/r550/orquestrar_filtro.sh. Seleciona do manifesto
# só arquivos íntegros (tamanho == manifesto), ordena do MAIOR para o menor e roda um
# processo R por arquivo. filtrar_um_hs.R pula o que já tem .ok com o mesmo tamanho →
# rodar de novo é seguro e retoma.
#
# Uso (NO R550-2, dentro de tmux):
#   bash orquestrar_filtro_hs.sh [--base SIA-PA|SIH-RD|SIM-DO|todas] [--jobs 24]
#                                [--uf PE] [--ano-min 2010] [--ano-max 2026] [--dry-run]
#   (todas = SIA-PA, SIH-RD e SIM-DO; o HS não usa SINASC)
# Saída: ~/Documentos/ronald/datasus_filtrado_hs/<BASE>/{filtrado,denominador,agregado_*,ok}/
# =============================================================================
set -uo pipefail
RAIZ=${RAIZ:-$HOME/Documentos/ronald/datasus_raw}
OUT=${OUT:-$HOME/Documentos/ronald/datasus_filtrado_hs}
RSCRIPT=${RSCRIPT:-$HOME/miniconda3/envs/datasus/bin/Rscript}
DIR=$(cd "$(dirname "$0")" && pwd)
BASE=todas; JOBS=24; UF=""; ANO_MIN=2010; ANO_MAX=2100; DRY=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --base) BASE=$2; shift 2 ;; --jobs) JOBS=$2; shift 2 ;; --uf) UF=$2; shift 2 ;;
    --ano-min) ANO_MIN=$2; shift 2 ;; --ano-max) ANO_MAX=$2; shift 2 ;;
    --dry-run) DRY=1; shift ;; *) echo "opção inválida: $1"; exit 2 ;;
  esac
done
[[ $(basename "$OUT") == "datasus_filtrado" ]] && { echo "OUT aponta para os filtrados do EIM — abortado"; exit 2; }
[[ $BASE == todas ]] && BASE="SIA-PA,SIH-RD,SIM-DO"
mkdir -p "$OUT"
LOG=$OUT/filtro_$(date +%Y%m%d_%H%M).log

# base \t caminho_dbc  — só os completos, do maior para o menor
LISTA=$(awk -F'\t' -v b=",$BASE," -v uf="$UF" -v a0="$ANO_MIN" -v a1="$ANO_MAX" -v raiz="$RAIZ" \
  'NR>1 && index(b, ","$1",") && (uf=="" || $4==uf) && $3>=a0 && $3<=a1 {print $8"\t"$1"\t"raiz"/"$2"/"$6}' \
  "$RAIZ/manifest/manifesto_atual.tsv" |
  while IFS=$'\t' read -r tam b fp; do [[ -f $fp && $(stat -c%s "$fp") -eq $tam ]] && printf "%s\t%s\t%s\n" "$tam" "$b" "$fp"; done |
  sort -t$'\t' -k1,1nr | cut -f2,3)
N=$(printf "%s\n" "$LISTA" | grep -c . || true)
echo "[$(date '+%F %T')] base=$BASE uf=${UF:-todas} anos=$ANO_MIN-$ANO_MAX → $N DBC completos, jobs=$JOBS" | tee -a "$LOG"
if [[ $DRY -eq 1 ]]; then printf "%s\n" "$LISTA" | cut -f1 | sort | uniq -c; printf "%s\n" "$LISTA" | head -5; exit 0; fi

printf "%s\n" "$LISTA" | grep . |
  xargs -d '\n' -P "$JOBS" -I{} bash -c 'IFS=$'"'"'\t'"'"' read -r b fp <<< "$1"; nice -n 5 "$2" "$3/filtrar_um_hs.R" --base="$b" --dbc="$fp" --out="$4" || echo "[falha] $fp"' _ {} "$RSCRIPT" "$DIR" "$OUT" >> "$LOG" 2>&1

echo "[$(date '+%F %T')] fim. Status:" | tee -a "$LOG"
awk -F'\t' 'NR>1{c[$3" "$2]++} END{for(k in c) print "  "k": "c[k]}' "$OUT/status_filtro.tsv" | tee -a "$LOG"
