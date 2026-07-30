#!/bin/bash
# CI/CD Pre-flight Check for Anchor Info Discovery
# Simulates GitHub Actions checks locally

set -e

echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║                    CI/CD PRE-FLIGHT CHECK                                    ║"
echo "║                  Anchor Info Discovery Service                               ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Track failures
FAILURES=0

check_pass() {
    echo -e "${GREEN}✓${NC} $1"
}

check_fail() {
    echo -e "${RED}✗${NC} $1"
    FAILURES=$((FAILURES + 1))
}

check_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1. FILE STRUCTURE CHECKS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check required files exist
if [ -f "src/contract.rs" ]; then
    check_pass "src/contract.rs exists"
else
    check_fail "src/contract.rs missing"
fi

if [ -f "src/types.rs" ]; then
    check_pass "src/types.rs exists"
else
    check_fail "src/types.rs missing"
fi

# Keep a check for legacy test file (may still exist)
if [ -f "src/anchor_info_discovery_tests.rs" ]; then
    check_pass "src/anchor_info_discovery_tests.rs exists"
else
    check_warn "src/anchor_info_discovery_tests.rs missing (ok if moved)"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "2. MODULE DECLARATION CHECKS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check module is declared in lib.rs
# Check contract module declared in lib.rs
if grep -q "^mod contract;" src/lib.rs; then
    check_pass "Module 'contract' declared in lib.rs"
else
    check_fail "Module 'contract' NOT declared in lib.rs"
fi

# Check test module is declared
if grep -q "^#\[cfg(test)\]" src/lib.rs && grep -A1 "^#\[cfg(test)\]" src/lib.rs | grep -q "^mod anchor_info_discovery_tests;"; then
    check_pass "Test module declared with #[cfg(test)]"
else
    check_fail "Test module NOT properly declared"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "3. IMPORT CHECKS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check imports in contract.rs and types.rs
if grep -q "use soroban_sdk::" src/contract.rs; then
    check_pass "Soroban SDK imported in src/contract.rs"
else
    check_fail "Soroban SDK NOT imported in src/contract.rs"
fi

if grep -q "ErrorCode" src/contract.rs || grep -q "Error" src/errors.rs; then
    check_pass "Error types referenced"
else
    check_warn "Error types not obviously referenced (verify manually)"
fi

# Check imports in test file (if present)
if [ -f "src/anchor_info_discovery_tests.rs" ] && grep -q "use crate::contract::" src/anchor_info_discovery_tests.rs; then
    check_pass "Tests import contract types from crate::contract"
else
    check_warn "Test file does not import from crate::contract (or test file missing)"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "4. DATA STRUCTURE CHECKS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check for required data structures in src/types.rs
if grep -q "pub struct StellarToml" src/types.rs; then
    check_pass "StellarToml struct defined in src/types.rs"
else
    check_fail "StellarToml struct NOT defined in src/types.rs"
fi

if grep -q "pub struct AssetInfo" src/types.rs; then
    check_pass "AssetInfo struct defined in src/types.rs"
else
    check_fail "AssetInfo struct NOT defined in src/types.rs"
fi

if grep -q "pub struct CachedToml" src/types.rs; then
    check_pass "CachedToml struct defined in src/types.rs"
else
    check_warn "CachedToml struct NOT found in src/types.rs (verify)"
fi

# Check for #[contracttype] attribute
if grep -q "#\[contracttype\]" src/types.rs; then
    check_pass "#\[contracttype\] attribute present in src/types.rs"
else
    check_warn "#\[contracttype\] attribute missing in src/types.rs"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "5. PUBLIC API CHECKS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Count public methods in lib.rs
PUBLIC_METHODS=(
    "fetch_anchor_info"
    "get_anchor_toml"
    "refresh_anchor_info"
    "get_anchor_assets"
    "get_anchor_asset_info"
    "get_anchor_deposit_limits"
    "get_anchor_withdrawal_limits"
    "get_anchor_deposit_fees"
    "get_anchor_withdrawal_fees"
    "anchor_supports_deposits"
    "anchor_supports_withdrawals"
)

for method in "${PUBLIC_METHODS[@]}"; do
    if grep -q "pub fn $method" src/lib.rs; then
        check_pass "Method $method exposed in contract"
    else
        check_fail "Method $method NOT exposed"
    fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "6. TEST CHECKS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Count test functions (basic sanity checks)
UNIT_TESTS=$(grep -Rc "fn test_" src | awk -F: '{sum += $2} END {print sum+0}')
INTEGRATION_TESTS=$(grep -c "fn test_" src/anchor_info_discovery_tests.rs || echo "0")
TOTAL_TESTS=$((UNIT_TESTS + INTEGRATION_TESTS))

if [ "$UNIT_TESTS" -ge 1 ]; then
    check_pass "Unit tests found: $UNIT_TESTS"
else
    check_warn "No unit tests detected in src/ (verify manually)"
fi

if [ "$INTEGRATION_TESTS" -ge 1 ]; then
    check_pass "Integration tests in anchor_info_discovery_tests.rs: $INTEGRATION_TESTS"
else
    check_warn "No integration tests in anchor_info_discovery_tests.rs (or file missing)"
fi

if [ "$TOTAL_TESTS" -ge 1 ]; then
    check_pass "Total tests: $TOTAL_TESTS"
else
    check_warn "No tests found in repository (verify)"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "7. CODE QUALITY CHECKS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check for proper error handling (no unwrap in non-test code)
NON_TEST_UNWRAPS=$(grep -n "\.unwrap()" src/anchor_info_discovery.rs | grep -v "fn test_" | grep -v "mod tests" | wc -l || echo "0")
if [ "$NON_TEST_UNWRAPS" -eq 0 ]; then
    check_pass "No unwrap() in production code"
else
    check_warn "Found $NON_TEST_UNWRAPS unwrap() calls in production code"
fi

# Check for TODO/FIXME comments
TODOS=$(grep -c "TODO\|FIXME" src/anchor_info_discovery.rs || echo "0")
if [ "$TODOS" -eq 0 ]; then
    check_pass "No TODO/FIXME comments"
else
    check_warn "Found $TODOS TODO/FIXME comments"
fi

# Check for proper documentation
if grep -q "/// " src/anchor_info_discovery.rs; then
    check_pass "Documentation comments present"
else
    check_warn "No documentation comments found"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "8. CARGO.TOML CHECKS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -f "Cargo.toml" ]; then
    check_pass "Cargo.toml exists"
    
    if grep -q "soroban-sdk" Cargo.toml; then
        check_pass "soroban-sdk dependency present"
    else
        check_fail "soroban-sdk dependency missing"
    fi
    
    if grep -q "\[features\]" Cargo.toml; then
        check_pass "Feature flags defined"
    else
        check_warn "No feature flags defined"
    fi
else
    check_fail "Cargo.toml missing"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "9. DOCUMENTATION CHECKS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check README updated
if grep -q "Anchor Info Discovery" README.md; then
    check_pass "README.md mentions Anchor Info Discovery"
else
    check_fail "README.md NOT updated"
fi

if grep -q "ANCHOR_INFO_DISCOVERY.md" README.md; then
    check_pass "README.md links to documentation"
else
    check_fail "README.md missing documentation link"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "10. SUMMARY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ $FAILURES -eq 0 ]; then
    echo -e "${GREEN}✓ ALL CHECKS PASSED${NC}"
    echo ""
    echo "The implementation is ready for CI/CD pipeline."
    echo ""
    echo "Next steps:"
    echo "  1. Run: cargo check"
    echo "  2. Run: cargo build"
    echo "  3. Run: cargo test anchor_info_discovery"
    echo "  4. Run: cargo clippy -- -D warnings"
    echo ""
    exit 0
else
    echo -e "${RED}✗ $FAILURES CHECK(S) FAILED${NC}"
    echo ""
    echo "Please fix the issues above before proceeding."
    echo ""
    exit 1
fi
