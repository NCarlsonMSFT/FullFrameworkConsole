Param(
    [Parameter(ParameterSetName = "Build", Position = 0, Mandatory = $True)]
    [switch]$Build,
    [Parameter(ParameterSetName = "Clean", Position = 0, Mandatory = $True)]
    [switch]$Clean,
    [Parameter(ParameterSetName = "Run", Position = 0, Mandatory = $True)]
    [switch]$Run,
    [Parameter(ParameterSetName = "GetUrl", Position = 0, Mandatory = $True)]
    [switch]$GetUrl,
    [Parameter(ParameterSetName = "WaitForUrl", Position = 0, Mandatory = $True)]
    [switch]$WaitForUrl,
    [parameter(ParameterSetName = "Clean", Position = 1, Mandatory = $True)]
    [parameter(ParameterSetName = "Build", Position = 1, Mandatory = $True)]
    [parameter(ParameterSetName = "Run", Position = 1, Mandatory = $True)]
    [ValidateNotNullOrEmpty()]
    [String]$Environment,
    [parameter(ParameterSetName = "Clean", Position = 3, Mandatory = $False)]
    [parameter(ParameterSetName = "Build", Position = 3, Mandatory = $False)]
    [parameter(ParameterSetName = "Run", Position = 3, Mandatory = $False)]
    [ValidateNotNullOrEmpty()]
    [String]$ProjectFolder = (Split-Path -Path $MyInvocation.MyCommand.Definition),
    [parameter(ParameterSetName = "Build", Position = 5, Mandatory = $False)]
    [switch]$NoCache
)

$ErrorActionPreference = "Stop"

# Turns VERBOSE output ON
$VerbosePreference = "Continue"

# The name of the image created by the compose file
$ImageName = "username/consoleapplication1"

# Kills all containers using an image, removes all containers using an image, and removes the image.
function Clean () {

    docker rm -f $(docker ps -a)

    # If $ImageName exists remove it
    $ImageNameRegEx = "\b$ImageName\b"
    docker images | select-string -pattern $ImageNameRegEx | foreach {
        $imageName = $_.Line.split(" ", [System.StringSplitOptions]::RemoveEmptyEntries)[0];
        $tag = $_.Line.split(" ", [System.StringSplitOptions]::RemoveEmptyEntries)[1];
        $shellCommand = "docker rmi -f ${imageName}:$tag"
        Write-Verbose "Executing: $shellCommand";
        Invoke-Expression "cmd /c $shellCommand `"2>&1`""
    }

    # Remove any dangling images (from previous builds)
    $shellCommand = "docker images -q --filter 'dangling=true'"
    Write-Verbose "Executing: $shellCommand"
    $danglingImages = $(Invoke-Expression "cmd /c $shellCommand `"2>&1`"")
    if (-not [String]::IsNullOrWhiteSpace($danglingImages)) {
        $shellCommand = "docker rmi -f $danglingImages"
        Write-Verbose "Executing: $shellCommand"
        Invoke-Expression "cmd /c $shellCommand `"2>&1`""
    }

    # If the folder for publishing exists, delete it
    if (Test-Path $pubPath) {
        Remove-Item $pubPath -Force -Recurse
    }
}

# Runs docker build.
function Build () {
    # Publish the project
    PublishProject

    $dockerFilePath = GetDockerFilePath($pubPath)

    $buildArgs = ""
    if ($NoCache)
    {
        $buildArgs = "--no-cache"
    }

    $taggedImageName = $ImageName
    if ($Environment -ne "Release") {
        $taggedImageName = "${ImageName}:$Environment"
    }

    # Call docker build on the published project to build the images
    $shellCommand = "docker build -f '$dockerFilePath' -t $taggedImageName $buildArgs '$pubPath'"
    Write-Verbose "Executing: $shellCommand"
    Invoke-Expression "cmd /c $shellCommand `"2>&1`""
    if ($LastExitCode -ne 0) {
        Write-Error "Failed to build the image"
    }
}

# Runs docker run
function Run () {
    $dockerFilePath = GetDockerFilePath($pubPath)

    $conflictingContainerIds = $(docker ps | select-string -pattern ":80->" | foreach { Write-Output $_.Line.split()[0] })

    if ($conflictingContainerIds) {
        $conflictingContainerIds = $conflictingContainerIds -Join ' '
        Write-Host "Stopping conflicting containers using port 80"
        $stopCommand = "docker stop $conflictingContainerIds"
        Write-Verbose "Executing: $stopCommand"
        Invoke-Expression "cmd /c $stopCommand `"2>&1`""
        if ($LastExitCode -ne 0) {
            Write-Error "Failed to stop the container(s)"
        }
    }

    $taggedImageName = $ImageName
    if ($Environment -ne "Release") {
        $taggedImageName = "${ImageName}:$Environment"
    }

    $shellCommand = "docker run $taggedImageName"
    Write-Verbose "Executing: $shellCommand"
    Invoke-Expression "cmd /c $shellCommand `"2>&1`""
    if ($LastExitCode -ne 0) {
        Write-Error "Failed to start the container(s)"
    }
}

# Publishes the project
function PublishProject () {
    try {
        Push-Location $ProjectFolder

        # Publish the project
        Write-Output "msbuild /p:OutputPath=`"$pubPath`" /p:DockerBuild=False"
        msbuild /p:OutputPath="$pubPath" /p:DockerBuild=False
    }
    finally {
        Pop-Location
    }
}

function GetDockerFilePath([string]$folder) {
    $dockerFileName = $Null
    if ($Environment -eq "Release") {
        $dockerFileName = "dockerfile"
    } else {
        $dockerFileName = "dockerfile.$Environment"
    }
    $dockerFileName = Join-Path $folder $dockerFileName

    if (Test-Path $dockerFileName) {
        return $dockerFileName
    } else {
        Write-Error -Message "$Environment is not a valid parameter. File '$dockerFileName' does not exist." -Category InvalidArgument
    }
}

# Our working directory in bin
$dockerBinFolder = Join-Path $ProjectFolder (Join-Path "bin" "Docker")
# The folder to publish the app to
$pubPath = Join-Path $dockerBinFolder "app"

# Call the correct functions for the parameters that were used
if ($Clean) {
    Clean
}
if ($Build) {
    Build
}
if ($Run) {
    Run
}
if ($GetUrl) {
    GetUrl
}
if ($WaitForUrl) {
    WaitForUrl (GetUrl)
}
