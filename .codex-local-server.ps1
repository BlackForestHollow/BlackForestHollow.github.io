param([string]$Root, [int]$Port)
Add-Type -AssemblyName System.Web
$listener = [System.Net.HttpListener]::new()
$prefix = "http://localhost:$Port/"
$listener.Prefixes.Add($prefix)
$listener.Start()
Write-Output "Serving $Root at $prefix"
while ($listener.IsListening) {
  try {
    $context = $listener.GetContext()
    $requestPath = [System.Web.HttpUtility]::UrlDecode($context.Request.Url.AbsolutePath)
    $localPath = if ($requestPath -eq '/') { 'index.html' } else { $requestPath.TrimStart('/') }
    $candidate = Join-Path $Root $localPath
    if (Test-Path $candidate -PathType Container) {
      $candidate = Join-Path $candidate 'index.html'
    }
    if (-not (Test-Path $candidate -PathType Leaf)) {
      $context.Response.StatusCode = 404
      $bytes = [System.Text.Encoding]::UTF8.GetBytes('Not Found')
      $context.Response.OutputStream.Write($bytes, 0, $bytes.Length)
      $context.Response.Close()
      continue
    }
    $ext = [System.IO.Path]::GetExtension($candidate).ToLowerInvariant()
    $contentType = switch ($ext) {
      '.html' { 'text/html; charset=utf-8' }
      '.css'  { 'text/css; charset=utf-8' }
      '.js'   { 'application/javascript; charset=utf-8' }
      '.png'  { 'image/png' }
      '.jpg'  { 'image/jpeg' }
      '.jpeg' { 'image/jpeg' }
      '.gif'  { 'image/gif' }
      default { 'application/octet-stream' }
    }
    $bytes = [System.IO.File]::ReadAllBytes($candidate)
    $context.Response.ContentType = $contentType
    $context.Response.ContentLength64 = $bytes.Length
    $context.Response.OutputStream.Write($bytes, 0, $bytes.Length)
    $context.Response.Close()
  } catch {
    if ($listener.IsListening) {
      try { $context.Response.StatusCode = 500; $context.Response.Close() } catch {}
    }
  }
}
