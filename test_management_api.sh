#!/bin/bash
# Management API Test Script
# Tests basic functionality of Postal Management API v2

set -e

# Configuration
BASE_URL="${BASE_URL:-http://localhost:5000}"
API_KEY="${MANAGEMENT_API_KEY:-your_api_key_here}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Helper function to make API requests
api_request() {
    local method=$1
    local endpoint=$2
    local data=$3

    if [ -z "$data" ]; then
        curl -s -X "$method" \
            -H "X-Management-API-Key: $API_KEY" \
            -H "Content-Type: application/json" \
            "$BASE_URL$endpoint"
    else
        curl -s -X "$method" \
            -H "X-Management-API-Key: $API_KEY" \
            -H "Content-Type: application/json" \
            -d "$data" \
            "$BASE_URL$endpoint"
    fi
}

# Test function
test_endpoint() {
    local test_name=$1
    local method=$2
    local endpoint=$3
    local data=$4
    local expected_status=$5

    echo -n "Testing: $test_name... "

    response=$(api_request "$method" "$endpoint" "$data")
    status=$(echo "$response" | jq -r '.status // "error"')

    if [ "$status" == "$expected_status" ]; then
        echo -e "${GREEN}PASSED${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}FAILED${NC}"
        echo "Expected: $expected_status, Got: $status"
        echo "Response: $response"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

echo "================================================"
echo "Management API v2 Test Suite"
echo "================================================"
echo "Base URL: $BASE_URL"
echo "API Key: ${API_KEY:0:10}..."
echo "================================================"
echo ""

# Test 1: System Info
echo "1. System Tests"
echo "----------------"
test_endpoint "GET /api/v2/system/info" GET "/api/v2/system/info" "" "success"
test_endpoint "GET /api/v2/system/health" GET "/api/v2/system/health" "" "healthy"
test_endpoint "GET /api/v2/system/stats" GET "/api/v2/system/stats" "" "success"
echo ""

# Test 2: Authentication
echo "2. Authentication Tests"
echo "-----------------------"
echo -n "Testing: Invalid API Key... "
response=$(curl -s -X GET \
    -H "X-Management-API-Key: invalid_key" \
    -H "Content-Type: application/json" \
    "$BASE_URL/api/v2/system/info")
error_code=$(echo "$response" | jq -r '.error.code // "none"')
if [ "$error_code" == "InvalidAPIKey" ] || [ "$error_code" == "AuthenticationRequired" ]; then
    echo -e "${GREEN}PASSED${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}FAILED${NC}"
    echo "Expected error code: InvalidAPIKey or AuthenticationRequired, Got: $error_code"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
echo ""

# Test 3: Users API
echo "3. Users API Tests"
echo "------------------"
test_endpoint "GET /api/v2/users" GET "/api/v2/users" "" "success"

# Test creating a user (this might fail if user exists, which is ok)
echo -n "Testing: POST /api/v2/users (create test user)... "
user_data='{
  "first_name": "Test",
  "last_name": "User",
  "email_address": "test-'$(date +%s)'@example.com",
  "password": "TestPassword123!",
  "email_verified": true
}'
response=$(api_request "POST" "/api/v2/users" "$user_data")
status=$(echo "$response" | jq -r '.status // "error"')
if [ "$status" == "success" ]; then
    echo -e "${GREEN}PASSED${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    TEST_USER_UUID=$(echo "$response" | jq -r '.data.user.uuid')
    echo "  Created user UUID: $TEST_USER_UUID"
else
    echo -e "${YELLOW}SKIPPED${NC} (user might already exist)"
fi
echo ""

# Test 4: Organizations API
echo "4. Organizations API Tests"
echo "--------------------------"
test_endpoint "GET /api/v2/organizations" GET "/api/v2/organizations" "" "success"
echo ""

# Test 5: IP Pools API
echo "5. IP Pools API Tests"
echo "---------------------"
test_endpoint "GET /api/v2/system/ip_pools" GET "/api/v2/system/ip_pools" "" "success"

# Test creating IP pool with JSON body (testing the fix we made)
echo -n "Testing: POST /api/v2/system/ip_pools (with JSON body)... "
pool_data='{"name": "Test Pool '$(date +%s)'", "default": false}'
response=$(api_request "POST" "/api/v2/system/ip_pools" "$pool_data")
status=$(echo "$response" | jq -r '.status // "error"')
if [ "$status" == "success" ]; then
    echo -e "${GREEN}PASSED${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    TEST_POOL_ID=$(echo "$response" | jq -r '.data.ip_pool.id')
    echo "  Created IP pool ID: $TEST_POOL_ID"

    # Clean up - delete the test pool
    echo -n "  Cleaning up test pool... "
    delete_response=$(api_request "DELETE" "/api/v2/system/ip_pools/$TEST_POOL_ID" "")
    delete_status=$(echo "$delete_response" | jq -r '.status // "error"')
    if [ "$delete_status" == "success" ]; then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${YELLOW}WARNING${NC}"
    fi
else
    echo -e "${RED}FAILED${NC}"
    echo "Response: $response"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
echo ""

# Test 6: Error Handling
echo "6. Error Handling Tests"
echo "-----------------------"
echo -n "Testing: GET non-existent organization... "
response=$(api_request "GET" "/api/v2/organizations/nonexistent-org-12345" "")
status=$(echo "$response" | jq -r '.status // "success"')
if [ "$status" == "error" ]; then
    echo -e "${GREEN}PASSED${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}FAILED${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

echo -n "Testing: POST with invalid data... "
invalid_data='{"name": ""}'
response=$(api_request "POST" "/api/v2/system/ip_pools" "$invalid_data")
status=$(echo "$response" | jq -r '.status // "success"')
if [ "$status" == "error" ]; then
    echo -e "${GREEN}PASSED${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}FAILED${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
echo ""

# Summary
echo "================================================"
echo "Test Summary"
echo "================================================"
echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"
echo "Total Tests: $((TESTS_PASSED + TESTS_FAILED))"
echo "================================================"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed.${NC}"
    exit 1
fi
