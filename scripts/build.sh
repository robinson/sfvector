#!/bin/bash
#
# sfvector - SQL Server Vector Search with FAISS
# Copyright (c) 2026 sfvector contributors
#
#


# =============================================
# Build script for SQL Server Vector Search
# =============================================

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}SQL Server Vector Search Build Script${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/build"
NATIVE_BUILD_DIR="$BUILD_DIR/native"
DEPLOYMENT_DIR="$PROJECT_ROOT/deployment"

# Parse arguments
BUILD_TYPE="Release"
BUILD_TESTS="OFF"
USE_GPU="OFF"

while [[ $# -gt 0 ]]; do
    case $1 in
        --debug)
            BUILD_TYPE="Debug"
            shift
            ;;
        --tests)
            BUILD_TESTS="ON"
            shift
            ;;
        --gpu)
            USE_GPU="ON"
            shift
            ;;
        --clean)
            echo -e "${YELLOW}Cleaning build directories...${NC}"
            rm -rf "$BUILD_DIR"
            rm -rf "$DEPLOYMENT_DIR"
            echo -e "${GREEN}Clean complete${NC}"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--debug] [--tests] [--gpu] [--clean]"
            exit 1
            ;;
    esac
done

echo "Build configuration:"
echo "  Build type: $BUILD_TYPE"
echo "  Build tests: $BUILD_TESTS"
echo "  GPU support: $USE_GPU"
echo ""

# =============================================
# Step 1: Check prerequisites
# =============================================

echo -e "${YELLOW}Checking prerequisites...${NC}"

# Check for CMake
if ! command -v cmake &> /dev/null; then
    echo -e "${RED}Error: CMake not found. Please install CMake 3.15+${NC}"
    exit 1
fi

# Check for dotnet
if ! command -v dotnet &> /dev/null; then
    echo -e "${RED}Error: .NET SDK not found. Please install .NET 6.0+${NC}"
    exit 1
fi

# Check for FAISS (this is a simple check, may need adjustment)
if ! ldconfig -p | grep -q libfaiss &> /dev/null && [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo -e "${YELLOW}Warning: FAISS library may not be installed${NC}"
    echo "  Install FAISS from: https://github.com/facebookresearch/faiss"
fi

echo -e "${GREEN}Prerequisites OK${NC}"
echo ""

# =============================================
# Step 2: Build native library
# =============================================

echo -e "${YELLOW}Building native library...${NC}"

mkdir -p "$NATIVE_BUILD_DIR"
cd "$NATIVE_BUILD_DIR"

cmake "$PROJECT_ROOT/src/SqlServer.VectorSearch.Native" \
    -DCMAKE_BUILD_TYPE=$BUILD_TYPE \
    -DBUILD_SHARED_LIBS=ON \
    -DBUILD_TESTS=$BUILD_TESTS \
    -DUSE_GPU=$USE_GPU

cmake --build . --config $BUILD_TYPE -j$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Native library build successful${NC}"
else
    echo -e "${RED}Native library build failed${NC}"
    exit 1
fi

echo ""

# =============================================
# Step 3: Build C# assembly
# =============================================

echo -e "${YELLOW}Building C# CLR assembly...${NC}"

cd "$PROJECT_ROOT/src/SqlServer.VectorSearch"

dotnet restore
dotnet build --configuration $BUILD_TYPE

if [ $? -eq 0 ]; then
    echo -e "${GREEN}C# assembly build successful${NC}"
else
    echo -e "${RED}C# assembly build failed${NC}"
    exit 1
fi

echo ""

# =============================================
# Step 4: Copy to deployment folder
# =============================================

echo -e "${YELLOW}Preparing deployment package...${NC}"

mkdir -p "$DEPLOYMENT_DIR"

# Copy native library
if [[ "$OSTYPE" == "darwin"* ]]; then
    cp "$NATIVE_BUILD_DIR/libSqlServer.VectorSearch.Native.dylib" "$DEPLOYMENT_DIR/" 2>/dev/null || true
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    cp "$NATIVE_BUILD_DIR/libSqlServer.VectorSearch.Native.so" "$DEPLOYMENT_DIR/" 2>/dev/null || true
else
    cp "$NATIVE_BUILD_DIR/$BUILD_TYPE/SqlServer.VectorSearch.Native.dll" "$DEPLOYMENT_DIR/" 2>/dev/null || true
fi

# Copy C# assembly
cp "$PROJECT_ROOT/src/SqlServer.VectorSearch/bin/$BUILD_TYPE/net6.0/SqlServer.VectorSearch.dll" "$DEPLOYMENT_DIR/"
cp "$PROJECT_ROOT/src/SqlServer.VectorSearch/bin/$BUILD_TYPE/net6.0/SqlServer.VectorSearch.pdb" "$DEPLOYMENT_DIR/" 2>/dev/null || true

# Copy deployment scripts
cp "$PROJECT_ROOT/scripts/deploy.sql" "$DEPLOYMENT_DIR/"
cp "$PROJECT_ROOT/examples/"*.sql "$DEPLOYMENT_DIR/" 2>/dev/null || true

# Copy documentation
cp "$PROJECT_ROOT/README.md" "$DEPLOYMENT_DIR/"
cp "$PROJECT_ROOT/docs/"*.md "$DEPLOYMENT_DIR/" 2>/dev/null || true

echo -e "${GREEN}Deployment package ready in: $DEPLOYMENT_DIR${NC}"
echo ""

# =============================================
# Step 5: Summary
# =============================================

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Build Summary${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Build type: $BUILD_TYPE"
echo "Output directory: $DEPLOYMENT_DIR"
echo ""
echo "Files created:"
ls -lh "$DEPLOYMENT_DIR" | tail -n +2 | awk '{print "  " $9 " (" $5 ")"}'
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Copy files from $DEPLOYMENT_DIR to your SQL Server machine"
echo "  2. Update the assembly path in deploy.sql"
echo "  3. Run deploy.sql in SQL Server Management Studio"
echo "  4. Test with examples from semantic_search_example.sql"
echo ""

# =============================================
# Optional: Run tests
# =============================================

if [ "$BUILD_TESTS" == "ON" ]; then
    echo -e "${YELLOW}Running tests...${NC}"
    cd "$NATIVE_BUILD_DIR"
    ctest --output-on-failure
    
    cd "$PROJECT_ROOT/src/SqlServer.VectorSearch.Tests"
    dotnet test --configuration $BUILD_TYPE
    
    echo ""
fi

echo -e "${GREEN}Build complete!${NC}"
