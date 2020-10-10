
<#PSScriptInfo

.VERSION 0.1.0

.GUID a026b58f-10ab-439e-af42-763969d67cbc

.AUTHOR HP-97

.COMPANYNAME

.COPYRIGHT

.TAGS

.LICENSEURI

.PROJECTURI

.ICONURI

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.PRIVATEDATA

#>

<# 
.NOTES
TODO:
- Need to figure out a more consistent formula tao calculate the required average bitrate to stay below the file size threshold.

.DESCRIPTION 
Compress a given video clip using FFmpeg and the Two-Pass method 

#> 
Param()

Function Compress-VideoClip {
    Param (
        # The path to the video you want to compress
        [string] $VideoPath,
        # The file size threshold we wish to compress the given video to (in MB).
        [int] $Threshold = 7
    )

    begin {
        # Initialisation
        $FFmpegPath = ".\bin\ffmpeg.exe"
        $FFprobePath = ".\bin\ffprobe.exe"
        if (-not (Test-Path -Path $VideoPath)) {
            Write-Error "Video path <$VideoPath> could not be found. Exiting" -ErrorAction Stop
        }
        # Order of precedence for ffmpeg.exe and ffprobe.exe:
        # 1. Local
        # 2. PATH
        if (-not (Test-Path $FFmpegPath -ErrorAction SilentlyContinue)) {
            $FFmpegPath = "ffmpeg.exe"
            if (-not (Get-Command $FFmpegPath -ErrorAction SilentlyContinue)) {
                Write-Error "FFmpeg was not found in PATH. Please add FFmpeg to PATH before proceeding." -ErrorAction Stop
            }
        }
        if (-not (Test-Path $FFprobePath -ErrorAction SilentlyContinue)) {
            $FFprobePath = "ffprobe.exe"
            if (-not (Get-Command $FFprobePath -ErrorAction SilentlyContinue)) {
                Write-Error "FFprobe was not found in PATH. Please add FFmpeg to PATH before proceeding." -ErrorAction Stop
            }
        }
        Write-Host "Using FFmpeg: ${FFmpegPath}"
        Write-Host "Using FFprobe: ${FFprobePath}"
        
        # List of items to remove post compression
        $RemoveArray = @('.\ffmpeg2pass-0.log', '.\ffmpeg2pass-0.log.mbtree')
        $ResolvedPath = Resolve-Path -Path $VideoPath
        Write-Host "Target video is ${ResolvedPath}"
        # Write-Host "Removing special characters from Video Path to sanitize inputs"
        # $VideoPath = $VideoPath -replace '();', ''
        # $VideoPath = $VideoPath -replace "'", "'"
    }

    process {
        # Get the video metadata of target video
        $FfprobeOutput = (Invoke-Expression "${FFprobePath} -v error -show_entries format=duration:stream=width,height,r_frame_rate -of default=noprint_wrappers=1 -print_format json `"${VideoPath}`"") | Out-String

        $Metadata = ConvertFrom-Json $FfprobeOutput
        $Duration = $Metadata.format.duration

        [int] $CurrentFileSize = (Get-Item $ResolvedPath).length / 1MB
        $OriginalSizeRatio = (($CurrentFileSize * 8192) / $Duration) - 128

        $AverageBitrate = (($Threshold * 8192) / $Duration) - 128

        # Round down to whole number
        $AverageBitrate = [Math]::Floor($AverageBitrate)

        $Basename = (Get-Item $VideoPath).BaseName
        $Directory = (Get-Item $VideoPath).DirectoryName
        $BasenameFinal = "${Basename}_compressed.mp4"
        $PathFinal = "${Directory}\${BasenameFinal}"

        Write-Host "File destination: ${PathFinal}"
        Write-Host "Original calculated bitrate ratio is ${OriginalSizeRatio}"
        Write-Host "Calculated average bitrate required: ${AverageBitrate}"

        # Pass 1
        Write-Host "Starting pass 1"
        Invoke-Expression("${FFmpegPath} -v quiet -stats -y -i `"${VideoPath}`" -c:v libx264 -preset slow -b:v ${AverageBitrate}k -pass 1 -an -f mp4 NUL") -ErrorAction Stop

        # Pass 2
        Write-Host "Starting pass 2"
        Invoke-Expression("${FFmpegPath} -v quiet -stats -y -i `"${VideoPath}`" -c:v libx264 -preset slow -b:v ${AverageBitrate}k -pass 2 -c:a aac -b:a 128k `"${PathFinal}`"") -ErrorAction Stop
    }

    end {
        Foreach ($Item in $RemoveArray) {
            Write-Host "Removing file ${Item}"
            Remove-Item $Item
        }
        
        Write-Host "Compression complete!"
    }
}


