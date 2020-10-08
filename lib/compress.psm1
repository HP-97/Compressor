
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

.RELEASENOTES Compress script now uses the Floor function rather than Round to prevent scenarios where the final filesize is too large.

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

        if (-not (Test-Path -Path $VideoPath)) {
            Write-Error "Video path <$VideoPath> could not be found. Exiting" -ErrorAction Stop
        }
        if (-not (Get-Command "ffmpeg.exe" -ErrorAction SilentlyContinue)) {
            Write-Error "FFmpeg was not found in PATH. Please add FFmpeg to PATH before proceeding." -ErrorAction Stop
        }
        if (-not (Get-Command "ffprobe.exe" -ErrorAction SilentlyContinue)) {
            Write-Error "FFprobe was not found in PATH. Please add FFmpeg to PATH before proceeding." -ErrorAction Stop
        }

        # List of items to remove post compression
        $RemoveArray = @('.\ffmpeg2pass-0.log', '.\ffmpeg2pass-0.log.mbtree')
        $ResolvedPath = Resolve-Path -Path $VideoPath
        Write-Host "Target video is ${ResolvedPath}"
        # Write-Host "Removing special characters from Video Path to sanitize inputs"
        # $VideoPath = $VideoPath -replace '();', ''
        # $VideoPath = [Management.Automation.WildcardPattern]::Escape("${VideoPath}")
        # $VideoPath = $VideoPath -replace "'", "'"
        Write-Host $VideoPath

    }

    process {
        # Get the video metadata of target video
        $FfprobeOutput = (Invoke-Expression "ffprobe -v error -show_entries format=duration:stream=width,height,r_frame_rate -of default=noprint_wrappers=1 -print_format json `"${VideoPath}`"") | Out-String

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
        Invoke-Expression("ffmpeg -v quiet -stats -y -i `"${VideoPath}`" -c:v libx264 -preset slow -b:v ${AverageBitrate}k -pass 1 -an -f mp4 NUL")

        # Pass 2
        Write-Host "Starting pass 2"
        Invoke-Expression("ffmpeg -v quiet -stats -y -i `"${VideoPath}`" -c:v libx264 -preset slow -b:v ${AverageBitrate}k -pass 2 -c:a aac -b:a 128k `"${PathFinal}`"")
    }

    end {
        Foreach ($Item in $RemoveArray) {
            Write-Host "Removing file ${Item}"
            Remove-Item $Item
        }
        
        Write-Host "Compression complete!"
    }
}


