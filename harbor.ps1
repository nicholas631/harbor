# Harbor Native Wrapper for Windows
# This script provides a Harbor-like CLI experience for native Ollama/App setups.

function Show-Help {
    Write-Host "Harbor Native CLI (Shim)" -ForegroundColor Cyan
    Write-Host "Usage: .\harbor.ps1 <command>"
    Write-Host ""
    Write-Host "Commands:"
    Write-Host "  ls, list    - List available models"
    Write-Host "  up, start   - Ensure Ollama backend is running"
    Write-Host "  pull <model>- Pull a new model from Ollama library"
    Write-Host "  run <model> - Start a chat with a model"
    Write-Host "  smi         - Show NVIDIA GPU status"
    Write-Host "  app         - Open the Harbor Desktop App"
}

$OLLAMA_PATH = "C:\Users\nickd\AppData\Local\Microsoft\WinGet\Packages\Ollama.Ollama.Portable_Microsoft.WinGet.Source_8wekyb3d8bbwe\ollama.exe"

switch ($args[0]) {
    "ls"      { & $OLLAMA_PATH list }
    "list"    { & $OLLAMA_PATH list }
    "pull"    { & $OLLAMA_PATH pull $args[1] }
    "run"     { & $OLLAMA_PATH run $args[1] }
    "smi"     { nvidia-smi }
    "up"      { 
        if (Get-Process -Name ollama -ErrorAction SilentlyContinue) {
            Write-Host "Ollama is already running." -ForegroundColor Green
        } else {
            Start-Process -FilePath $OLLAMA_PATH -ArgumentList "serve" -WindowStyle Hidden
            Write-Host "Ollama started in the background." -ForegroundColor Green
        }
    }
    "app"     {
        # Try to find Harbor App
        $harborApp = Get-ChildItem -Path "C:\Program Files\Harbor" -Filter Harbor.exe -Recurse -ErrorAction SilentlyContinue
        if ($harborApp) {
            Start-Process $harborApp.FullName
        } else {
            Write-Host "Harbor App not found in C:\Program Files\Harbor. Please launch it from the Start Menu." -ForegroundColor Red
        }
    }
    default   { Show-Help }
}
