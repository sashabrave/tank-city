#!/bin/zsh
# Прогон бота tests/balance_pacing по набору состояний меты. Вывод: tmp/pacing/<label>_c<ch>_<route>_s<seed>.log
# Использование: tools/balance/run_pacing.sh <параллельно=4> < список строк "label hp dmg mob press class ch seed route [wlvl]"
# Сохранения не трогаются: тест сам выключает Game.save_enabled и Settings.persistence_enabled.
cd "$(dirname "$0")/../.."
export G=${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}
mkdir -p tmp/pacing
grep -v '^#' | grep -v '^$' | xargs -P ${1:-4} -L 1 zsh -c '
  out=tmp/pacing/$0_c$6_$8_s$7.log
  [ -s $out ] && grep -q PACE_RUN $out && exit 0
  $G --headless --fixed-fps 60 --path . tests/balance_pacing.tscn -- $1 $2 $3 $4 $5 $6 $7 $8 ${9:-0} --test-timeout=2400 > $out.raw 2>&1
  grep -E "^PACE" $out.raw > $out; rm -f $out.raw'
