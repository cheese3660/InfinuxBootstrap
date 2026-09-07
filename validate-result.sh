rm -rf ./.validate
mkdir -p ./.validate
tar  -xzf ./dist/bootstrap.tar.gz -C ./.validate

WORK_DIR=$(pwd)/.build

TARGET="x86_64-linux-musl"
echo "HARDCODED STRINGS (should be zero)"
strings ./.validate/bin/gcc | grep -E "(/nix/store|/home/|$WORK_DIR)"
strings "./.validate/libexec/gcc/$TARGET/"*"/cc1" | grep -E "(/nix/store|/home/|$WORK_DIR)"

echo "SEARCH DIRS"
./.validate/bin/gcc -print-search-dirs

echo "LINKAGE"
readelf -l ./.validate/bin/gcc | grep interpreter