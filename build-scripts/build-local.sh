#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Matrix Crypto Bridge - Local Build & Link Script         ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Build all platforms
echo -e "${YELLOW}Building and packaging for all platforms...${NC}"
bash "$SCRIPT_DIR/build-and-package.sh" all

# Build TypeScript
echo ""
echo -e "${YELLOW}Building TypeScript...${NC}"
cd "$PROJECT_ROOT/react-native-matrix-crypto"
npm install
npm run build

# Create npm link
echo ""
echo -e "${YELLOW}Creating npm link...${NC}"
npm link

# Instructions
echo ""
echo -e "${GREEN}✓ Build complete!${NC}"
echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Next Steps                                                ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}To use in your Fortress app:${NC}"
echo ""
echo "1. Link the package in your app:"
echo "   cd /path/to/fortress"
echo "   npm link @k9o/react-native-matrix-crypto"
echo ""
echo "2. For iOS, install pods:"
echo "   cd ios"
echo "   pod install"
echo ""
echo "3. Build and run:"
echo "   npm run dev:ios"
echo "   # or"
echo "   npm run dev:android"
echo ""
echo -e "${YELLOW}To unlink when done:${NC}"
echo "   npm unlink @k9o/react-native-matrix-crypto"
echo "   cd $PROJECT_ROOT/react-native-matrix-crypto"
echo "   npm unlink"
echo ""
