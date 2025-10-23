Add-Type -AssemblyName System.Drawing

function Resize-Image {
    param(
        [string]$InputPath,
        [string]$OutputPath,
        [int]$Width,
        [int]$Height,
        [int]$Quality = 85
    )
    
    $image = [System.Drawing.Image]::FromFile($InputPath)
    $resized = New-Object System.Drawing.Bitmap($Width, $Height)
    $graphics = [System.Drawing.Graphics]::FromImage($resized)
    
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.CompositingHint = [System.Drawing.Drawing2D.CompositingHint]::AssumeLinear
    
    $graphics.DrawImage($image, 0, 0, $Width, $Height)
    
    # JPEG encoder with quality
    $codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq "image/jpeg" }
    $encoderParams = New-Object System.Drawing.Imaging.EncoderParameters(1)
    $encoderParams.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, $Quality)
    
    $resized.Save($OutputPath, $codec, $encoderParams)
    
    $graphics.Dispose()
    $resized.Dispose()
    $image.Dispose()
}

Write-Host "📱 Optimizujem screenshots za Play Store..."

# Screenshot 1 - Phone format (1080 x 1920)
Resize-Image -InputPath "assets\store_images\IMG_20251020_023531.jpg" -OutputPath "assets\store_images\screenshot_01_phone.jpg" -Width 1080 -Height 1920 -Quality 90
Write-Host "✅ Screenshot 1: 1080 x 1920 px"

# Screenshot 2 - Phone format (1080 x 1920) 
Resize-Image -InputPath "assets\store_images\IMG_20251020_023540.jpg" -OutputPath "assets\store_images\screenshot_02_phone.jpg" -Width 1080 -Height 1920 -Quality 90
Write-Host "✅ Screenshot 2: 1080 x 1920 px"

# Feature Graphic - Landscape format (1024 x 500)
Resize-Image -InputPath "assets\store_images\IMG_20251023_010922.jpg" -OutputPath "assets\store_images\feature_graphic.jpg" -Width 1024 -Height 500 -Quality 95
Write-Host "✅ Feature Graphic: 1024 x 500 px"

Write-Host ""
Write-Host "🎉 Optimizacija završena!"
