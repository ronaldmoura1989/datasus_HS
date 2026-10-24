#!/usr/bin/env bash
# =============================================================================
# rodar_pipeline_hs.sh — Consolidação → pseudo-ID → completude → taxas (HS v2, R550-2)
# Molde: datasus_EIM/scripts/r550/rodar_pipeline.sh. Depois da filtragem
# (orquestrar_filtro_hs.sh) e do download do CNES-PF (baixar_cnes_pf.py).
# Para no primeiro erro; log por etapa em logs/pipeline_<etapa>.log.
#
# Uso (NO R550-2, em tmux): bash scripts/r550/rodar_pipeline_hs.sh [--de NN]
#   01 SIA · 02 SIH · 03 SIM · 04 CNES · 05 pseudo-ID · 06 completude · 07 taxas
# =============================================================================
set -uo pipefail
RSCRIPT=${RSCRIPT:-$HOME/miniconda3/envs/datasus/bin/Rscript}
PROJ=$(cd "$(dirname "$0")/../.." && pwd)
DE=1; [[ ${1:-} == --de ]] && DE=$((10#$2))
ETAPAS=(get_hs_data_from_SIA get_hs_data_from_SIH get_hs_data_from_SIM get_dermatologistas_cnes
        feature_eng_pacientes_SIA completude_campos_hs taxas_tendencias_hs)
mkdir -p "$PROJ/logs"; cd "$PROJ" || exit 1
for i in "${!ETAPAS[@]}"; do
  n=$((i + 1)); [[ $n -lt $DE ]] && continue
  e=${ETAPAS[$i]}; log=$PROJ/logs/pipeline_$(printf %02d "$n")_$e.log
  echo "[$(date '+%F %T')] $n $e"
  if ! nice -n 5 "$RSCRIPT" "scripts/$e.R" > "$log" 2>&1; then
    echo "[$(date '+%F %T')] FALHOU em $e — ver $log"; exit 1
  fi
done
echo "[$(date '+%F %T')] pipeline HS concluído"
