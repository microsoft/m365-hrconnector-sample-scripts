param
(   
    [Parameter(mandatory = $true)]
    [string] $tenantId,
    [Parameter(mandatory = $true)]
    [string] $appId,
    [Parameter(mandatory = $true)]
    [string] $appSecret,
    [Parameter(mandatory = $true)]
    [string] $jobId,
    [Parameter(mandatory = $true)]
    [string] $csvFilePath
)
# Access Token Config
$oAuthTokenEndpoint = "https://login.microsoftonline.us/$tenantId/oauth2/token"
$resource = 'https://gsgotrs.onmicrosoft.com/66ace435-1e6f-4305-8abc-96f365388077'

# Csv upload config
$eventApiURl = "https://webhook-itarl4.ingestion.office365.us"
$eventApiEndpoint = "api/signals/hr/termination/csv"

function GetAccessToken () {
    # Token Authorization URI
    $uri = "$($oAuthTokenEndpoint)?api-version=1.0"

    # Access Token Body
    $formData = 
    @{
        client_id     = $appId;
        client_secret = $appSecret;
        grant_type    = 'client_credentials';
        resource      = $resource;
        tenant_id     = $tenantId;
    }

    # Parameters for Access Token call
    $params = 
    @{
        URI         = $uri
        Method      = 'Post'
        ContentType = 'application/x-www-form-urlencoded'
        Body        = $formData
    }

    $response = Invoke-RestMethod @params -ErrorAction Stop
    return $response.access_token
}

function RetryCommand {
    [CmdletBinding()]
    Param(
        [Parameter(Position = 0, Mandatory = $true)]
        [scriptblock]$ScriptBlock,

        [Parameter(Position = 1, Mandatory = $false)]
        [int]$Maximum = 15
    )

    Begin {
        $cnt = 0
    }

    Process {
        do {
            $cnt++
            try {
                $ScriptBlock.Invoke()
                return
            }
            catch {
                Write-Error $_.Exception.InnerException.Message -ErrorAction Continue
                Start-Sleep 60
                if ($cnt -lt $Maximum) {
                    Write-Output "Retrying"
                }
            }
            
        } while ($cnt -lt $Maximum)

        throw 'Execution failed.'
    }
}

function WriteErrorMessage($errorMessage) {
    $Exception = [Exception]::new($errorMessage)
    $ErrorRecord = [System.Management.Automation.ErrorRecord]::new(
        $Exception,
        "errorID",
        [System.Management.Automation.ErrorCategory]::NotSpecified,
        $TargetObject
    )
    $PSCmdlet.WriteError($ErrorRecord)
}

function UploadCsvData ($access_token) {
    $nvCollection = [System.Web.HttpUtility]::ParseQueryString([String]::Empty) 
    $nvCollection.Add('jobid', $jobId)
    $uriRequest = [System.UriBuilder]"$eventApiURl/$eventApiEndpoint"
    $uriRequest.Query = $nvCollection.ToString()

    $fieldName = 'file'
    $url = $uriRequest.Uri.OriginalString

    Add-Type -AssemblyName 'System.Net.Http'

    $client = New-Object System.Net.Http.HttpClient
    $content = New-Object System.Net.Http.MultipartFormDataContent
    try{
        $fileStream = [System.IO.File]::OpenRead($csvFilePath)
        $fileName = [System.IO.Path]::GetFileName($csvFilePath)
        $fileContent = New-Object System.Net.Http.StreamContent($fileStream)
        $content.Add($fileContent, $fieldName, $fileName)
    }catch{
        WriteErrorMessage("Error reading from file. Please check if path is correct")
        return
    }
    $client.DefaultRequestHeaders.Add("Authorization", "Bearer $access_token");
    $client.Timeout = New-Object System.TimeSpan(0, 0, 150)
    
    try {
        $result = $client.PostAsync($url, $content).Result
    }
    catch {
        WriteErrorMessage("Unknown failure while uploading.")
        return
    }
    $status_code = [int]$result.StatusCode
    if ($result.IsSuccessStatusCode) {
        Write-Output "Upload Successful"
        $responseStr = $result.Content.ReadAsStringAsync().Result
        if (! [string]::IsNullOrWhiteSpace($responseStr)) {
            Write-Output("Body : {0}" -f $responseStr)
        }
    }
    elseif ($status_code -eq 0 -or $status_code -eq 501 -or $status_code -eq 503) {
        throw "Service unavailable."
    }
    else {
        WriteErrorMessage("Failure with StatusCode [{0}] and ReasonPhrase [{1}]" -f $result.StatusCode, $result.ReasonPhrase)
        WriteErrorMessage("Error body : {0}" -f $result.Content.ReadAsStringAsync().Result)
    }
}

RetryCommand -ScriptBlock {
    $access_token = GetAccessToken
    UploadCsvData($access_token)
}