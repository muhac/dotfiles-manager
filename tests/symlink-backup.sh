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
    env HOME="${links_home:-$test_home}" CLEAN_BROKEN_LINKS=0 bash "$fixture/symlink.sh" > "$test_dir/run.log" 2>&1
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

original_dir="$test_dir/original-directory"
mkdir -p "$original_dir/nested/empty"
cp "$test_dir/original" "$original_dir/content"
cp "$test_dir/original" "$original_dir/nested/.hidden"
for source in directory file; do
    target="$target_dir/existing-directory-$source"
    cp -R "$original_dir" "$target"
    printf 'test/%s\t%s\n' "$source" "$target" > "$fixture/symlink.conf"
    run_links
    assert_link "$target" "$fixture/dotfiles/test/$source"
    backups=("$target".bak.*)
    [[ ${#backups[@]} -eq 1 && -d "${backups[0]}" && ! -L "${backups[0]}" ]] || fail 'directory backup missing'
    diff -r "$original_dir" "${backups[0]}" || fail 'directory backup content changed'
    run_links
    backups=("$target".bak.*)
    [[ ${#backups[@]} -eq 1 ]] || fail 'repeated run created another directory backup'
    diff -r "$original_dir" "${backups[0]}" || fail 'repeated run changed directory backup'
done
printf 'PASS: both source types back up real directories intact, including on repeated runs\n'

cp -R "$original_dir" "$target_dir/skipped-directory"
cp "$test_dir/original" "$target_dir/skipped"
printf 'test/directory\t%s\tflag:skip-existing\n' "$target_dir/skipped-directory" > "$fixture/symlink.conf"
printf 'test/directory\t%s\tflag:skip-existing\n' "$target_dir/skipped" >> "$fixture/symlink.conf"
run_links
[[ ! -L "$target_dir/skipped-directory" ]] || fail 'skip-existing directory was replaced'
diff -r "$original_dir" "$target_dir/skipped-directory" || fail 'skip-existing directory content changed'
[[ ! -L "$target_dir/skipped" ]] || fail 'skip-existing file was replaced'
cmp -s "$test_dir/original" "$target_dir/skipped" || fail 'skip-existing content changed'
printf 'PASS: skip-existing files and directories preserved\n'

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
    printf 'test/file\t%s\n' "$target_dir/after-failed-$source" >> "$fixture/symlink.conf"
    if PATH="$mock_bin:$PATH" run_links; then
        fail "backup failure reported success: $source"
    fi
    grep -Fq 'refusing to replace' "$test_dir/run.log" || fail "backup refusal missing: $source"
    [[ ! -L "$target_dir/failed-$source" ]] || fail "backup failure replaced original: $source"
    cmp -s "$test_dir/original" "$target_dir/failed-$source" || fail "backup failure lost content: $source"
    assert_link "$target_dir/after-failed-$source" "$fixture/dotfiles/test/file"
done
printf 'PASS: failed backups preserve originals, allow later links, and return failure\n'

rm "$mock_bin/mv"
export TEST_REAL_LN
TEST_REAL_LN="$(command -v ln)"
# The mock expands these variables when the installer invokes it.
# shellcheck disable=SC2016
printf '%s\n' '#!/bin/bash' \
    'target="${!#}"' \
    'case "$target" in' \
    '    */link-failure-*) exit 1 ;;' \
    '    */raced-*) printf "competing file\n" > "$target" ;;' \
    'esac' \
    'exec "$TEST_REAL_LN" "$@"' > "$mock_bin/ln"
chmod +x "$mock_bin/ln"
for source in directory file; do
    cp "$test_dir/original" "$target_dir/link-failure-$source"
    printf 'test/%s\t%s\n' "$source" "$target_dir/link-failure-$source" > "$fixture/symlink.conf"
    printf 'test/file\t%s\n' "$target_dir/after-link-failure-$source" >> "$fixture/symlink.conf"
    if PATH="$mock_bin:$PATH" run_links; then
        fail "link failure reported success: $source"
    fi
    grep -Fq "Error: failed to link $target_dir/link-failure-$source" "$test_dir/run.log" || fail 'link error missing'
    if grep -F 'Linked:' "$test_dir/run.log" | grep -Fq "$target_dir/link-failure-$source"; then
        fail 'failed link logged as successful'
    fi
    assert_backup "$target_dir/link-failure-$source"
    assert_link "$target_dir/after-link-failure-$source" "$fixture/dotfiles/test/file"

    printf 'test/%s\t%s\n' "$source" "$target_dir/raced-$source" > "$fixture/symlink.conf"
    if PATH="$mock_bin:$PATH" run_links; then
        fail "concurrent target creation reported success: $source"
    fi
    [[ ! -L "$target_dir/raced-$source" ]] || fail 'concurrent target overwritten'
    [[ "$(< "$target_dir/raced-$source")" == 'competing file' ]] || fail 'concurrent content lost'
done
printf 'PASS: failed links retain backups, allow later links, and never force replacement\n'

alias_home="$test_dir/home with spaces"
sibling_dir="$fixture with sibling"
mkdir -p "$alias_home" "$fixture/dotfiles/test/aliased" "$sibling_dir"
printf 'repo owned\n' > "$fixture/dotfiles/test/aliased/existing"
printf 'repo owned\n' > "$fixture/dotfiles/test/aliased/same"
ln -s "$fixture/dotfiles/test/aliased" "$alias_home/.config"
ln -s "$sibling_dir" "$alias_home/.sibling"
{
    printf 'test/file\t%s\n' "$alias_home/.config/ghostty/config"
    printf 'test/file\t%s\n' "$alias_home/.config/ghostty"
    printf 'test/file\t%s\n' "$alias_home/.config/existing"
    printf 'test/file\t%s\n' "$alias_home/.sibling/nested/file"
    printf 'test/file\t%s\n' "$alias_home/after-alias"
} > "$fixture/symlink.conf"
links_home="$alias_home"
if run_links; then
    fail 'target aliased into repository reported success'
fi
for target in ghostty/config ghostty existing; do
    grep -Fq "Error: $alias_home/.config/$target resolves inside the repository; refusing." "$test_dir/run.log" || fail "aliased target error missing: $target"
done
[[ ! -e "$fixture/dotfiles/test/aliased/ghostty" ]] || fail 'aliased target created inside repository'
aliased_entries=("$fixture/dotfiles/test/aliased"/* "$fixture/dotfiles/test/aliased"/.[!.]*)
[[ ${#aliased_entries[@]} -eq 2 ]] || fail 'unexpected entries created inside repository'
[[ ! -L "$fixture/dotfiles/test/aliased/existing" ]] || fail 'repository file replaced through aliased parent'
[[ "$(< "$fixture/dotfiles/test/aliased/existing")" == 'repo owned' ]] || fail 'repository file content changed through aliased parent'
repo_backups=("$fixture/dotfiles/test/aliased"/*.bak.*)
[[ ${#repo_backups[@]} -eq 0 ]] || fail 'repository file backed up through aliased parent'
assert_link "$alias_home/.sibling/nested/file" "$fixture/dotfiles/test/file"
assert_link "$alias_home/after-alias" "$fixture/dotfiles/test/file"
printf 'PASS: targets aliased into the repository are refused while later and sibling-prefix targets link\n'

printf 'test/aliased/same\t%s\n' "$alias_home/.config/same" > "$fixture/symlink.conf"
run_links
grep -Fq 'already points to source' "$test_dir/run.log" || fail 'correct existing alias was not skipped'
if grep -Fq 'resolves inside the repository' "$test_dir/run.log"; then
    fail 'correct existing alias reported as error'
fi
[[ ! -L "$fixture/dotfiles/test/aliased/same" ]] || fail 'source replaced through correct alias'
unset links_home
printf 'PASS: targets already resolving to source are skipped without error\n'
