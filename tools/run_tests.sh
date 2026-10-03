#!/bin/zsh
# Запуск тестов War Cats.
#   tools/run_tests.sh quick            — быстрый набор (tests/suites/quick.txt)
#   tools/run_tests.sh full             — все тесты, кроме оконных и зондов (параллельно, см. JOBS)
#   tools/run_tests.sh name1 name2 ...  — выбранные тесты
# Параллельные Godot в одной папке мешают друг другу через кэш .godot, поэтому полный набор идёт в JOBS
# потоков (по умолчанию 4), каждый в своей мгновенной APFS-копии проекта (cp -c, ~2 с, место не занимает).
# Долгие тесты стартуют первыми. JOBS=1 — по одному, в самой папке проекта.
# Упавший тест завершается сразу (scripts/test_guard.gd), зависший — по --test-timeout.
# Итог: tmp/test_runs/<время>/summary.txt и по логу на тест. Код выхода 0, только если всё зелёное.
cd "$(dirname "$0")/.."
root=$PWD
G=${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}
mode=${1:-quick}
if [ "$mode" = quick ]; then names=($(grep -v '^#' tests/suites/quick.txt | grep -v '^$'))
elif [ "$mode" = full ]; then names=($(ls tests/*.tscn | xargs -n1 basename | sed 's/\.tscn$//' | grep -vE '_visual$|capture|^chaos_monkey$|probe'))
else names=("$@"); fi
jobs=1; [ "$mode" = full ] && jobs=${JOBS:-4}
out=$root/tmp/test_runs/$(date +%Y%m%d-%H%M%S); mkdir -p $out
start=$(date +%s)

# One test in a given project folder; prints the summary line.
run_one() {
  local dir=$1 n=$2 t0=$(date +%s)
  if [ ! -f $dir/tests/$n.tscn ]; then echo "FAIL $n (нет такого теста)"; return; fi
  # A long test declares its own limit with a line "## test-timeout: <seconds>" in its .gd.
  local limit=$(grep -m1 -o 'test-timeout: *[0-9]*' $dir/tests/$n.gd 2>/dev/null | grep -o '[0-9]*$'); limit=${limit:-${TEST_TIMEOUT:-180}}
  $G --headless --path $dir tests/$n.tscn -- --test-timeout=$limit > $out/$n.log 2>&1; local code=$?
  local dt=$(( $(date +%s)-t0 ))
  if [ $code -eq 0 ]; then echo "ok   $n (${dt}s)"
  else echo "FAIL $n (код $code, ${dt}s): $(grep -m1 -E 'TEST ABORTED|TEST TIMEOUT|FAIL' $out/$n.log | cut -c1-140)"; fi
}

if [ $jobs -le 1 ]; then
  for n in $names; do run_one $root $n; done | tee $out/summary.txt
else
  # Slow tests first, so no worker is left alone with a 3-minute test at the end.
  slow=(extreme_builds balance_v09 playthrough hq_arrival_revision balance_v08 active_battle_revision balance hub_performance)
  ordered=()
  for n in $slow; do (( ${names[(Ie)$n]} )) && ordered+=($n); done
  for n in $names; do (( ${slow[(Ie)$n]} )) || ordered+=($n); done
  clones=${TMPDIR:-/tmp}/warcats_test_clones
  rm -rf $clones; mkdir -p $clones/claims
  for j in $(seq 1 $jobs); do
    w=$clones/w$j; mkdir -p $w
    # Everything the game reads; no git history, builds, worktrees or temp files.
    for item in ${(f)"$(ls -A | grep -vxE '\.git|tmp|build|\.claude|landing|site|\.DS_Store')"}; do cp -cR "$item" $w/; done
    mkdir -p $w/tmp
  done
  for j in $(seq 1 $jobs); do
    (
      # Each worker claims the next free test (mkdir is atomic), so the load balances itself.
      for n in $ordered; do
        mkdir $clones/claims/$n 2>/dev/null && run_one $clones/w$j $n
      done > $out/summary_w$j.txt
    ) &
  done
  wait
  cat $out/summary_w*.txt | tee $out/summary.txt
  rm -f $out/summary_w*.txt
  rm -rf $clones
fi
total=$(( $(date +%s)-start ))
failed=$(grep -c '^FAIL' $out/summary.txt)
echo "Итог: $(grep -c '^ok' $out/summary.txt) прошло, $failed упало, $((total/60)) мин $((total%60)) с. Логи: ${out#$root/}" | tee -a $out/summary.txt
[ $failed -eq 0 ]
