#!/bin/bash
sudo apt install -y z3 libz3-dev zlib1g zlib1g-dev libzstd-dev zstd libzstd1

# Display all commands before executing them.
set -o errexit
set -o errtrace

LLVM_BRANCH=$1
LLVM_REPO_URL=${2:-https://github.com/llvm/llvm-project.git}
LLVM_CROSS="$3"

if [[ -z "$LLVM_REPO_URL" || -z "$LLVM_BRANCH" ]]
then
  echo "Usage: $0 <branch> <llvm-repository-url> [aarch64/riscv64]"
  echo
  echo "# Arguments"
  echo "  branch               The name of a LLVM release branch (or main for currently 22.0.0git)"
  echo "  llvm-repository-url  The URL used to clone LLVM sources (default: https://github.com/llvm/llvm-project.git)"
  echo "  aarch64 / riscv64    To cross-compile an aarch64/riscv64 version of LLVM"

  exit 1
fi

# Clone the LLVM project.
if [ ! -d llvm-project ]
then
	git clone -b $LLVM_BRANCH --single-branch --depth=1 "$LLVM_REPO_URL" llvm-project
fi


cd llvm-project
git fetch origin
git checkout $LLVM_BRANCH
git reset --hard origin/$LLVM_BRANCH

# Create a directory to build the project.
mkdir -p build
cd build

# Create a directory to receive the complete installation.
mkdir -p install

# Adjust compilation based on the OS.
CMAKE_ARGUMENTS=""

case "${OSTYPE}" in
    darwin*) ;;
    linux*) ;;
    *) ;;
esac

# Adjust cross compilation
CROSS_COMPILE=""

case "${LLVM_CROSS}" in
    aarch64*) CROSS_COMPILE="-DLLVM_HOST_TRIPLE=aarch64-linux-gnu" ;;
    riscv64*) CROSS_COMPILE="-DLLVM_HOST_TRIPLE=riscv64-linux-gnu" ;;
    *) ;;
esac

# Run `cmake` to configure the project.
cmake \
  -G Ninja \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DCMAKE_INSTALL_PREFIX="/" \
  -DLLVM_ENABLE_PROJECTS=all \
  -DLLVM_ENABLE_RUNTIMES=all \
  -DLLVM_ENABLE_ZLIB=ON \
  -DLLVM_ENABLE_ZSTD=ON \
  -DLLVM_ENABLE_Z3_SOLVER=ON \
  -DLLVM_INCLUDE_DOCS=OFF \
  -DLLVM_INCLUDE_EXAMPLES=OFF \
  -DLLVM_INCLUDE_TESTS=OFF \
  -DLLVM_INCLUDE_TOOLS=ON \
  -DLLVM_INCLUDE_UTILS=ON \
  -DLLVM_OPTIMIZED_TABLEGEN=ON \
  "${CROSS_COMPILE}" \
  "${CMAKE_ARGUMENTS}" \
  ../llvm

# Showtime!
cmake --build . --config RelWithDebInfo
DESTDIR=destdir cmake --install . --strip --config RelWithDebInfo

# move usr/bin/* to bin/ or llvm-config will be broken
if [ ! -d destdir/bin ];then
 mkdir destdir/bin
fi
mv destdir/usr/bin/* destdir/bin/
