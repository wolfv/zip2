#!/bin/bash
set -euxo pipefail
ncpus=$(nproc || getconf NPROCESSORS_ONLN)
ncpus=$(( ncpus / ( 1 + $(cat /sys/devices/system/cpu/smt/active))))
NORMAL_RESTARTS=10
rm -rf "fuzz/corpus/fuzz_$1_pre_fresh_blood" || true
mkdir "fuzz/corpus/fuzz_$1_pre_fresh_blood"
mv "fuzz/corpus/fuzz_$1"/* "fuzz/corpus/fuzz_$1_pre_fresh_blood" || true
for i in $(seq 1 $NORMAL_RESTARTS); do
  mv "fuzz/corpus/fuzz_$1_restart_${i}"/* "fuzz/corpus/fuzz_$1_pre_fresh_blood" || true
  echo "$(date): RESTART ${i}"
  mkdir "fuzz/corpus/fuzz_$1" || true
  cargo fuzz run --all-features "fuzz_$1" "fuzz/corpus/fuzz_$1" -- \
    -dict=fuzz/fuzz.dict -max_len="$2" -fork="$ncpus" \
    -max_total_time=5100 -runs=100000000
  mkdir "fuzz/corpus/fuzz_$1_restart_${i}" || true
  mv "fuzz/corpus/fuzz_$1"/* "fuzz/corpus/fuzz_$1_restart_${i}"
done

mv "fuzz/corpus/fuzz_$1_restart_dictionaryless"/* "fuzz/corpus/fuzz_$1_pre_fresh_blood" || true
rm -rf "fuzz/corpus/fuzz_$1_restart_dictionaryless" || true
mkdir "fuzz/corpus/fuzz_$1_restart_dictionaryless" || true
echo "$(date): DICTIONARY-LESS RESTART"
cargo fuzz run --all-features "fuzz_$1" "fuzz/corpus/fuzz_$1" -- \
  -max_len="$2" -fork="$ncpus" -max_total_time=5100 -runs=100000000

mv "fuzz/corpus/fuzz_$1_restart_dictionaryless_012byte"/* "fuzz/corpus/fuzz_$1_pre_fresh_blood" || true
rm -rf "fuzz/corpus/fuzz_$1_restart_dictionaryless_012byte" || true
mkdir "fuzz/corpus/fuzz_$1_restart_dictionaryless_012byte" || true
echo "$(date): DICTIONARY-LESS RESTART WITH 0-2 BYTE CORPUS"
tar -xvzf "fuzz/012byte.tar.gz" -C "fuzz/corpus/fuzz_$1"
cargo fuzz run --all-features "fuzz_$1" "fuzz/corpus/fuzz_$1" -- \
  -max_len="$2" -fork="$ncpus" -max_total_time=5100 -runs=100000000

mv "fuzz/corpus/fuzz_$1_restart_012byte"/* "fuzz/corpus/fuzz_$1_pre_fresh_blood" || true
rm -rf "fuzz/corpus/fuzz_$1_restart_012byte" || true
mkdir "fuzz/corpus/fuzz_$1_restart_012byte" || true
echo "$(date): RESTART WITH DICTIONARY AND 0-2 BYTE CORPUS"
tar -xvzf "fuzz/012byte.tar.gz" -C "fuzz/corpus/fuzz_$1"
cargo fuzz run --all-features "fuzz_$1" "fuzz/corpus/fuzz_$1" -- \
  -dict=fuzz/fuzz.dict -max_len="$2" -fork="$ncpus" -max_total_time=5100 -runs=100000000

echo "$(date): MERGING CORPORA"
for i in $(seq 1 $NORMAL_RESTARTS); do
  mv "fuzz/corpus/fuzz_$1_restart_${i}"/* "fuzz/corpus/fuzz_$1"
  rm -rf "fuzz/corpus/fuzz_$1_restart_${i}"
done
SPECIAL_RESTARTS=("012byte" "dictionaryless_012byte" "dictionaryless")
for i in "${SPECIAL_RESTARTS[@]}"; do
  mv "fuzz/corpus/fuzz_$1_restart_${i}"/* "fuzz/corpus/fuzz_$1"
  rm -rf "fuzz/corpus/fuzz_$1_restart_${i}"
done
echo "$(date): RUNNING WITH MERGED CORPUS"
./fuzz-until-converged.sh "$1" "$2"
echo "$(date): DONE BUILDING FUZZ CORPUS AT SIZE $2"