#!/bin/bash
set -euo pipefail
shopt -s nullglob

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
test_dir="$(mktemp -d)"
cleanup() {
    local status=$?
    if [[ "$status" -ne 0 && -f "$test_dir/run.log" ]]; then
        printf '\nInstaller output:\n' >&2
        while IFS= read -r line || [[ -n "$line" ]]; do
            printf '%s\n' "$line" >&2
        done < "$test_dir/run.log"
    fi
    rm -rf "$test_dir"
    exit "$status"
}
trap cleanup EXIT
fixture="$test_dir/repo with spaces"
target_dir="$test_dir/targets"
mock_bin="$test_dir/bin"
test_home="$test_dir/home"
mkdir -p "$fixture/dotfiles/test/directory" "$target_dir" "$mock_bin" "$test_home"
cp "$repo_dir/symlink.sh" "$fixture/symlink.sh"
env HOME="$test_home" git -C "$fixture" init -q
printf 'managed\n' > "$fixture/dotfiles/test/file"
printf 'original\n' > "$test_dir/original"
printf 'older backup\n' > "$test_dir/older"

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

run_links() {
    env HOME="$test_home" CLEAN_BROKEN_LINKS=0 bash "$fixture/symlink.sh" > "$test_dir/run.log" 2>&1
}

assert_link() {
    [[ -L "$1" ]] && [[ "$(readlink "$1")" == "$2" ]] || fail "wrong link: $1"
}

assert_backup() {
    local target="$1"
    local backups=("$target".bak.*)
    [[ ${#backups[@]} -eq 1 ]] || fail "expected one backup for $target"
    cmp -s "$test_dir/original" "${backups[0]}" || fail "original content lost: $target"
}

printf 'test/directory\t%s\n' "$target_dir/directory" > "$fixture/symlink.conf"
printf 'test/file\t%s\n' "$target_dir/file" >> "$fixture/symlink.conf"
cp "$test_dir/original" "$target_dir/directory"
cp "$test_dir/original" "$target_dir/file"
run_links
assert_link "$target_dir/directory" "$fixture/dotfiles/test/directory"
assert_link "$target_dir/file" "$fixture/dotfiles/test/file"
assert_backup "$target_dir/directory"
assert_backup "$target_dir/file"
run_links
assert_backup "$target_dir/directory"
assert_backup "$target_dir/file"
printf 'PASS: file backups for both source types and repeated runs\n'

mkdir "$target_dir/existing-directory"
cp "$test_dir/original" "$target_dir/existing-directory/content"
cp "$test_dir/original" "$target_dir/skipped"
printf 'test/directory\t%s\n' "$target_dir/existing-directory" > "$fixture/symlink.conf"
printf 'test/directory\t%s\tflag:skip-existing\n' "$target_dir/skipped" >> "$fixture/symlink.conf"
run_links
[[ ! -L "$target_dir/existing-directory" ]] || fail 'existing directory was replaced'
cmp -s "$test_dir/original" "$target_dir/existing-directory/content" || fail 'directory content changed'
[[ ! -L "$target_dir/skipped" ]] || fail 'skip-existing file was replaced'
cmp -s "$test_dir/original" "$target_dir/skipped" || fail 'skip-existing content changed'
printf 'PASS: existing directories and skip-existing files preserved\n'

mkdir -p "$fixture/dotfiles/test/parent"
cp "$test_dir/original" "$fixture/dotfiles/test/parent/file"
git -C "$fixture" add dotfiles/test/parent/file
printf 'test/parent\t%s\n' "$target_dir/alias" > "$fixture/symlink.conf"
run_links
printf 'test/parent/file\t%s\n' "$target_dir/alias/file" > "$fixture/symlink.conf"
run_links
[[ ! -L "$fixture/dotfiles/test/parent/file" ]] || fail 'source file replaced through linked parent'
cmp -s "$test_dir/original" "$fixture/dotfiles/test/parent/file" || fail 'source content changed through linked parent'
source_backups=("$fixture/dotfiles/test/parent/file".bak.*)
[[ ${#source_backups[@]} -eq 0 ]] || fail 'source file was backed up through linked parent'
git -C "$fixture" diff --exit-code -- dotfiles/test/parent/file || fail 'source working tree changed'
assert_link "$target_dir/alias" "$fixture/dotfiles/test/parent"
printf 'PASS: target resolving to source leaves repository content intact\n'

printf '#!/bin/bash\nprintf "20000101-000000\\n"\n' > "$mock_bin/date"
chmod +x "$mock_bin/date"
cp "$test_dir/original" "$target_dir/collision"
cp "$test_dir/older" "$target_dir/collision.bak.20000101-000000"
printf 'test/directory\t%s\n' "$target_dir/collision" > "$fixture/symlink.conf"
PATH="$mock_bin:$PATH" run_links
cmp -s "$test_dir/older" "$target_dir/collision.bak.20000101-000000" || fail 'older backup overwritten'
cmp -s "$test_dir/original" "$target_dir/collision.bak.20000101-000000.1" || fail 'numbered backup missing'
assert_link "$target_dir/collision" "$fixture/dotfiles/test/directory"
printf 'PASS: backup name collisions preserve both versions\n'

printf '#!/bin/bash\nexit 1\n' > "$mock_bin/mv"
chmod +x "$mock_bin/mv"
for source in directory file; do
    cp "$test_dir/original" "$target_dir/failed-$source"
    printf 'test/%s\t%s\n' "$source" "$target_dir/failed-$source" > "$fixture/symlink.conf"
    if PATH="$mock_bin:$PATH" run_links; then
        fail "backup failure reported success: $source"
    fi
    grep -Fq 'refusing to replace' "$test_dir/run.log" || fail "backup refusal missing: $source"
    [[ ! -L "$target_dir/failed-$source" ]] || fail "backup failure replaced original: $source"
    cmp -s "$test_dir/original" "$target_dir/failed-$source" || fail "backup failure lost content: $source"
done
printf 'PASS: failed backups stop before replacing either source type\n'
