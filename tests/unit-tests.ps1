# Unit Tests for Akamai Object Storage (PowerShell version)
$ErrorActionPreference = "Stop"

# Configuration
$ENDPOINT = if ($env:ENDPOINT) { $env:ENDPOINT } else { "https://sg-sin-2.linodeobjects.com" }
$REGION = if ($env:REGION) { $env:REGION } else { "sg-sin-2" }
$INGEST_BUCKET = if ($env:INGEST_BUCKET) { $env:INGEST_BUCKET } else { "we11-ingest-raw" }

# Counters
$PASS = 0
$FAIL = 0

function Test-Pass($msg) {
    $script:PASS++
    Write-Host " ✅ PASS: $msg" -ForegroundColor Green
}

function Test-Fail($msg) {
    $script:FAIL++
    Write-Host " ❌ FAIL: $msg" -ForegroundColor Red
}

# Check Environment Variables
foreach ($var in @("NESTJS_ACCESS_KEY", "NESTJS_SECRET_KEY", "WORKER_ACCESS_KEY", "WORKER_SECRET_KEY")) {
    if (-not (Get-ChildItem -Path "Env:$var" -ErrorAction SilentlyContinue)) {
        Write-Error "ERROR: Environment variable $var is not set"
        exit 1
    }
}

$TEST_PREFIX = "test-$(Get-Date -UFormat %s)"
$TEMP_FILE = "test-1mb.bin"

# Create a 1MB test file
$data = New-Object Byte[] 1048576
(New-Object Random).NextBytes($data)
[IO.File]::WriteAllBytes("$PSScriptRoot/$TEMP_FILE", $data)

Write-Host "`n--- Test 1: Authorized PUT (NestJS key -> ingest-raw) ---"
$env:AWS_ACCESS_KEY_ID = $env:NESTJS_ACCESS_KEY
$env:AWS_SECRET_ACCESS_KEY = $env:NESTJS_SECRET_KEY

try {
    aws --endpoint-url $ENDPOINT --region $REGION s3api put-object `
        --bucket $INGEST_BUCKET `
        --key "$TEST_PREFIX/test-auth.bin" `
        --body "$PSScriptRoot/$TEMP_FILE" `
        --content-type "application/octet-stream" | Out-Null
    Test-Pass "NestJS key can write to ingest-raw"
} catch {
    Test-Fail "NestJS key should be able to write to ingest-raw"
}

Write-Host "`n--- Test 2: Unauthorized PUT (Worker key -> ingest-raw) ---"
$env:AWS_ACCESS_KEY_ID = $env:WORKER_ACCESS_KEY
$env:AWS_SECRET_ACCESS_KEY = $env:WORKER_SECRET_KEY

try {
    aws --endpoint-url $ENDPOINT --region $REGION s3api put-object `
        --bucket $INGEST_BUCKET `
        --key "$TEST_PREFIX/test-unauth.bin" `
        --body "$PSScriptRoot/$TEMP_FILE" `
        --content-type "application/octet-stream" 2>$null | Out-Null
    Test-Fail "Worker key should NOT be able to write to ingest-raw"
} catch {
    Test-Pass "Worker key correctly denied write to ingest-raw (403 Forbidden)"
}

Write-Host "`n--- Test 3: Public Read Deny (Anonymous GET -> ingest-raw) ---"
$OBJECT_URL = "$ENDPOINT/$INGEST_BUCKET/$TEST_PREFIX/test-auth.bin"
try {
    $response = Invoke-WebRequest -Uri $OBJECT_URL -Method Get -ErrorAction SilentlyContinue
    Test-Fail "Anonymous GET returned HTTP $($response.StatusCode) (expected 403)"
} catch {
    if ($_.Exception.Response.StatusCode.value__ -eq 403 -or $_.Exception.Response.StatusCode.value__ -eq 401) {
        Test-Pass "Anonymous GET blocked (HTTP $($_.Exception.Response.StatusCode.value__))"
    } else {
        Test-Fail "Anonymous GET returned unintended error: $($_.Exception.Response.StatusCode)"
    }
}

Write-Host "`n--- Test 4: Tenant Isolation ---"
$env:AWS_ACCESS_KEY_ID = $env:NESTJS_ACCESS_KEY
$env:AWS_SECRET_ACCESS_KEY = $env:NESTJS_SECRET_KEY

# Upload for Tenant A and B
aws --endpoint-url $ENDPOINT --region $REGION s3api put-object --bucket $INGEST_BUCKET --key "$TEST_PREFIX/tenant_A/file-a.bin" --body "$PSScriptRoot/$TEMP_FILE" | Out-Null
aws --endpoint-url $ENDPOINT --region $REGION s3api put-object --bucket $INGEST_BUCKET --key "$TEST_PREFIX/tenant_B/file-b.bin" --body "$PSScriptRoot/$TEMP_FILE" | Out-Null

$LIST_A = aws --endpoint-url $ENDPOINT --region $REGION s3api list-objects-v2 --bucket $INGEST_BUCKET --prefix "$TEST_PREFIX/tenant_A/" --query "Contents[].Key" --output text
$LIST_B = aws --endpoint-url $ENDPOINT --region $REGION s3api list-objects-v2 --bucket $INGEST_BUCKET --prefix "$TEST_PREFIX/tenant_B/" --query "Contents[].Key" --output text

if ($LIST_A -like "*tenant_A*" -and $LIST_A -notlike "*tenant_B*" -and $LIST_B -like "*tenant_B*" -and $LIST_B -notlike "*tenant_A*") {
    Test-Pass "Tenant prefixes are isolated"
} else {
    Test-Fail "Tenant data leaked across prefixes"
}

Write-Host "`n--- Cleanup ---"
aws --endpoint-url $ENDPOINT --region $REGION s3 rm "s3://$INGEST_BUCKET/$TEST_PREFIX/" --recursive | Out-Null
Remove-Item "$PSScriptRoot/$TEMP_FILE" -Force

Write-Host "`n=== Results: $PASS passed, $FAIL failed ===" -ForegroundColor Yellow
if ($FAIL -gt 0) { exit 1 }
