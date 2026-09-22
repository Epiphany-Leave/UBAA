param(
    [Parameter(Mandatory = $true)][string]$Apk,
    [Parameter(Mandatory = $true)][string]$BuildTools,
    [string]$Abi = 'arm64-v8a'
)
$ErrorActionPreference = 'Stop'
$Apk = (Resolve-Path -LiteralPath $Apk).Path
$badging = & (Join-Path $BuildTools 'aapt.exe') dump badging $Apk
if ($LASTEXITCODE -ne 0) { throw 'Cannot read APK manifest' }
if (-not ($badging -match "uses-permission: name='android.permission.INTERNET'")) { throw 'APK lacks INTERNET permission' }
if ($badging -match 'application-debuggable') { throw 'Expected a release APK' }
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::OpenRead($Apk)
try {
    foreach ($library in @('libflutter.so', 'libapp.so', 'libubaa_flutter_bridge.so')) {
        if (-not $zip.GetEntry("lib/$Abi/$library")) { throw "Missing $Abi/$library" }
    }
    $dexText = foreach ($entry in $zip.Entries | Where-Object { $_.FullName -match '^classes\d*\.dex$' }) {
        $reader = [IO.StreamReader]::new($entry.Open(), [Text.Encoding]::ASCII)
        try { $reader.ReadToEnd() } finally { $reader.Dispose() }
    }
    foreach ($class in @('CertificateVerifier', 'VerificationResult', 'StatusCode')) {
        if (-not ($dexText -cmatch "Lorg/rustls/platformverifier/$class;")) { throw "TLS JNI class missing: $class" }
    }
} finally { $zip.Dispose() }
& (Join-Path $BuildTools 'apksigner.bat') verify --verbose $Apk
if ($LASTEXITCODE -ne 0) { throw 'APK signature verification failed' }
& (Join-Path $BuildTools 'zipalign.exe') -c -P 16 4 $Apk
if ($LASTEXITCODE -ne 0) { throw 'APK ZIP alignment verification failed' }
Write-Output "PASS: release manifest, $Abi libraries, TLS JNI classes, signature. Device login still requires manual verification."
