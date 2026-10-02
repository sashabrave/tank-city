#!/bin/zsh
# Запуск тестов War Cats.
#   tools/run_tests.sh quick            — быстрый набор (tests/suites/quick.txt)
#   tools/run_tests.sh full             — все тесты, кроме оконных и зондов
#   tools/run_tests.sh name1 name2 ...  — выбранные тесты
# Тесты идут по одному (параллельные Godot в одной папке мешают друг другу через кэш .godot).
# Упавший тест завершается сразу (scripts/test_guard.gd), зависший — по --test-timeout.
# Итог: tmp/test_runs/<время>/summary.txt и по логу на тест. Код выхода 0, только если всё зелёное.
cd "$(dirname "$0")/.."
G=${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}
mode=${1:-quick}
if [ "$mode" = quick ]; then names=($(grep -v '^#' tests/suites/quick.txt | grep -v '^$'))
elif [ "$mode" = full ]; then names=($(ls tests/*.tscn | xargs -n1 basename | sed 's/\.tscn$//' | grep -vE '_visual$|^capture$|^chaos_monkey$|probe'))
else names=("$@"); fi
out=tmp/test_runs/$(date +%Y%m%d-%H%M%S); mkdir -p $out
start=$(date +%s); pass=0; fail=()
for n in $names; do
  t0=$(date +%s)
  if [ ! -f tests/$n.tscn ]; then echo "FAIL $n (нет такого теста)"; continue; fi
  # A long test declares its own limit with a line "## test-timeout: <seconds>" in its .gd.
  limit=$(grep -m1 -o 'test-timeout: *[0-9]*' tests/$n.gd 2>/dev/null | grep -o '[0-9]*$'); limit=${limit:-${TEST_TIMEOUT:-180}}
  $G --headless --path . tests/$n.tscn -- --test-timeout=$limit > $out/$n.log 2>&1; code=$?
  dt=$(( $(date +%s)-t0 ))
  if [ $code -eq 0 ]; then pass=$((pass+1)); echo "ok   $n (${dt}s)"
  else fail+=($n); echo "FAIL $n (код $code, ${dt}s): $(grep -m1 -E 'TEST ABORTED|TEST TIMEOUT|FAIL' $out/$n.log | cut -c1-140)"; fi
done | tee $out/summary.txt
total=$(( $(date +%s)-start ))
failed=$(grep -c '^FAIL' $out/summary.txt)
echo "Итог: $(grep -c '^ok' $out/summary.txt) прошло, $failed упало, $((total/60)) мин $((total%60)) с. Логи: $out" | tee -a $out/summary.txt
[ $failed -eq 0 ]
