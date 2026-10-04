#!/bin/zsh
# Запуск тестов War Cats (политика — guides/02_development/04_testing.md).
#   tools/run_tests.sh core             — CORE: tests/suites/core.txt, перед каждой сборкой (~1–2 мин). quick = core.
#   tools/run_tests.sh long             — LONG: tests/suites/long.txt, перед релизом (боты, долгие прогоны).
#   tools/run_tests.sh full             — core + long.
#   tools/run_tests.sh name1 name2 ...  — выбранные тесты (по одному, в папке проекта).
# Строка набора: «имя [аргументы теста]», # — комментарий. Аргументы уходят тесту после «--».
# В .gd теста: «## test-timeout: <секунды>» — свой лимит (по умолчанию 180), «## test-flags: <флаги>» — флаги движка.
# Наборы идут в JOBS потоков (по умолчанию 4; JOBS=1 — по одному): каждый поток — в своей мгновенной APFS-копии
# проекта (cp -c, ~2 с, место не занимает), потому что несколько Godot в одной папке дерутся за кэш .godot.
# У каждого запуска свой временный HOME: user:// (профили, настройки) никогда не авторский.
# Упавший тест завершается сразу (scripts/test_guard.gd), зависший — по --test-timeout.
# Итог: tmp/test_runs/<время>/summary.txt и по логу на тест. Код выхода 0, только если всё зелёное.
cd "$(dirname "$0")/.."
root=$PWD
G=${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}
mode=${1:-core}
suite() { grep -v '^#' tests/suites/$1.txt | grep -v '^[[:space:]]*$' }
lines=()
case $mode in
  quick|core) lines=(${(f)"$(suite core)"});;
  long) lines=(${(f)"$(suite long)"});;
  full) lines=(${(f)"$(suite core)"} ${(f)"$(suite long)"});;
  *) lines=("$@"); mode=выбранные;;
esac
jobs=1; [[ $mode != выбранные ]] && jobs=${JOBS:-4}
out=$root/tmp/test_runs/$(date +%Y%m%d-%H%M%S); mkdir -p $out
homes=${TMPDIR:-/tmp}/warcats_test_homes_$$; mkdir -p $homes
start=$(date +%s)

# One test line ("name [args]") in a given project folder with a given HOME; prints the summary line.
run_one() {
  local dir=$1 home=$2 line=$3 t0=$(date +%s)
  local words=(${=line}); local n=$words[1]; local args=(${words[2,-1]})
  if [ ! -f $dir/tests/$n.tscn ]; then echo "FAIL $n (нет такого теста)"; return; fi
  local limit=$(grep -m1 -o 'test-timeout: *[0-9]*' $dir/tests/$n.gd 2>/dev/null | grep -o '[0-9]*$'); limit=${limit:-${TEST_TIMEOUT:-180}}
  local flags=($(grep -m1 '^## test-flags:' $dir/tests/$n.gd 2>/dev/null | sed 's/^## test-flags://'))
  mkdir -p $home
  HOME=$home $G --headless $flags --path $dir tests/$n.tscn -- $args --test-timeout=$limit > $out/$n.log 2>&1; local code=$?
  local dt=$(( $(date +%s)-t0 ))
  if [ $code -eq 0 ]; then echo "ok   $n (${dt}s)"
  else echo "FAIL $n (код $code, ${dt}s): $(grep -m1 -E 'TEST ABORTED|TEST TIMEOUT|FAIL|SCRIPT ERROR' $out/$n.log | cut -c1-140)"; fi
}

if [ $jobs -le 1 ]; then
  for line in $lines; do run_one $root $homes/seq "$line"; done | tee $out/summary.txt
else
  # Slow tests first, so no worker is left alone with a long test at the end.
  slow=(balance_pacing extreme_builds balance_v09 playthrough chaos_monkey replay_v09 route_alternation_revision author_rooms_revision)
  ordered=()
  for s in $slow; do for line in $lines; do [[ ${line%% *} == $s ]] && ordered+=("$line"); done; done
  for line in $lines; do (( ${slow[(Ie)${line%% *}]} )) || ordered+=("$line"); done
  clones=${TMPDIR:-/tmp}/warcats_test_clones_$$
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
      for line in $ordered; do
        mkdir $clones/claims/${line%% *} 2>/dev/null && run_one $clones/w$j $homes/w$j "$line"
      done > $out/summary_w$j.txt
    ) &
  done
  wait
  cat $out/summary_w*.txt | tee $out/summary.txt
  rm -f $out/summary_w*.txt
  rm -rf $clones
fi
rm -rf $homes
total=$(( $(date +%s)-start ))
failed=$(grep -c '^FAIL' $out/summary.txt)
echo "Итог ($mode): $(grep -c '^ok' $out/summary.txt) прошло, $failed упало, $((total/60)) мин $((total%60)) с. Логи: ${out#$root/}" | tee -a $out/summary.txt
[ $failed -eq 0 ]
