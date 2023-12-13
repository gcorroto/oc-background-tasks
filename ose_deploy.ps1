param (
    [string]$oseRuntimeFolder = $env:OSE_DEPLOY_BACKGROUND_FOLDER,
    [string]$user,
				[SecureString]$securePassword

)
do {
	try {
	
# main vars
$server = "https://api.ocp.mutua.es:6443"
$hostOauth = "https://oauth-openshift.clouddes.mutua.es"

try {
	while ([string]::IsNullOrWhiteSpace($oseRuntimeFolder)) {
		$oseRuntimeFolder = Read-Host -Prompt "Por favor, ingrese la ruta del directorio ose_deploy_background donde descomprimio el fichero incluyendo la carpeta ose_deploy_background ose_deploy_background.zip"
		$env:OSE_DEPLOY_BACKGROUND_FOLDER = $oseRuntimeFolder
	}
	$nuget = "$oseRuntimeFolder\nuget.exe"
	$oc = "$oseRuntimeFolder\oc.exe"
	while ([string]::IsNullOrWhiteSpace($user)) {
		$user = Read-Host -Prompt "Por favor, ingrese el nombre de usuario"
	}

	while ([string]::IsNullOrWhiteSpace($securePassword)) {
		$securePassword = Read-Host -Prompt "Por favor, ingrese la password" -AsSecureString
	}

	# $cadenaBasic = "$user`:$password"
	# $decodedPassword = ConvertFrom-SecureString $password
	$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
	$password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
	$cadenaBasic = "{0}:{1}" -f $user, $password
	$ose_client_id = "openshift-browser-client"
	$ose_response_type = "code"


	$idp = "LDAP"
	$redirect_uri = "https://oauth-openshift.clouddes.mutua.es/oauth/token/display"
	$replicas = "--replicas=1"
	$namespace = "-n"
	$command = "scale"
	$deployment = "deployment"
	# Agregar la política de certificados
	add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
	$originalPolicy = [System.Net.ServicePointManager]::CertificatePolicy
	[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy

	# Convierte la cadena a bytes en UTF-8
	$bytes = [System.Text.Encoding]::UTF8.GetBytes($cadenaBasic)
	$base64 = [Convert]::ToBase64String($bytes)

	# Log headers using Write-Host
	$uriCode = "$hostOauth/oauth/authorize?client_id=$ose_client_id&idp=$idp&redirec_uri=$redirect_uri&response_type=$ose_response_type"

	Write-Host " uri oauth $uriCode"
	Write-Host " Basic oauth $base64"
	$webClient = New-Object System.Net.WebClient


	# Carga el módulo HtmlAgilityPack
	Write-Host "add type $oseRuntimeFolder\HtmlAgilityPack.1.11.54\lib\Net40\HtmlAgilityPack.dll"
	Add-Type -Path  "$oseRuntimeFolder\HtmlAgilityPack.1.11.54\lib\Net40\HtmlAgilityPack.dll"

	try {
		$webClient.Headers.Add("Authorization", "Basic $base64")
		# $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers
		$response = $webClient.DownloadString($uriCode)
	}
 catch {
		Write-Host "Error: $_"
	}



	# Crea un nuevo objeto HtmlDocument
	$html = New-Object HtmlAgilityPack.HtmlDocument


	# Carga el HTML en el objeto HtmlDocument
	$html.LoadHtml($response)

	# Encuentra el input con name="code" y lee su valor
	$inputCode = $html.DocumentNode.SelectSingleNode("//input[@type='hidden' and @name='code']")
	$inputCsrf = $html.DocumentNode.SelectSingleNode("//input[@type='hidden' and @name='csrf']")
	if ($null -ne $inputCode -and $null -ne $inputCsrf) {
		$codeOse = $inputCode.GetAttributeValue("value", "")
		$csrfOse = $inputCsrf.GetAttributeValue("value", "")
		# Write-Host "authorzation code ose generado $codeOse"
		# Write-Host "csrf ose generado $csrfOse"

		$uriToken = "$hostOauth/oauth/token/display"
		$data = "code=$codeOse&csrf=$csrfOse"
		$webClient.Headers.Remove("Authorization")
		$webClient.Headers.Add("Content-Type", "application/x-www-form-urlencoded")
		# Crea un nuevo objeto CookieContainer
		$cookieContainer = New-Object System.Net.CookieContainer

		# Crea una nueva cookie
		$cookie = New-Object System.Net.Cookie
		$cookie.Name = "csrf"
		$cookie.Value = $csrfOse
		$cookie.Domain = "oauth-openshift.clouddes.mutua.es" # Reemplaza esto con tu dominio

		# Agrega la cookie al contenedor de cookies
		$cookieContainer.Add($cookie)

		# Asigna el contenedor de cookies al WebClient
		$webClient.Headers["Cookie"] = $cookie.ToString()

		try {
			$responsePost = $webClient.UploadString($uriToken, $data)
		}
		catch {
			Write-Host "Error: $_"
			if ($null -ne $_.Exception.Response) {
				$responseStream = $_.Exception.Response.GetResponseStream()
				$streamReader = New-Object System.IO.StreamReader($responseStream)
				$errorResponse = $streamReader.ReadToEnd()
				Write-Host "Server response: $errorResponse"
			}
		}
		# Write-Host $responsePost

		$htmlPost = New-Object HtmlAgilityPack.HtmlDocument
		$htmlPost.LoadHtml($responsePost)

		$codeTag = $htmlPost.DocumentNode.SelectSingleNode("//code")
		if ($null -ne $codeTag) {
			$tokenOse = $codeTag.InnerText
			# Write-Host "Token: $token"
			# HACEMOS LOGIN
			& $oc login --token=$tokenOse --server=$server

			# LEEMOS FICHERO DE APLICACIONES
			$envs = $envs -split " "

			
			# Inicializa $commandExecArray como un array vacío
			$commandExecArray = @()
			
			# $namespaceName = "$area-$env"
			# Get the list of projects
			$projects = & $oc "projects" "--short"

			# Let the user select a project
			$selectedProject = $projects | Out-GridView -PassThru

			# Use the selected project
			$namespaceName = $selectedProject
			Write-Host "for area-env ... $namespaceName"
			$deployments = & $oc -n $namespaceName "get" "deployments"
			$deploymentList = $deployments -split "`n" | Select-Object -Skip 1 | ForEach-Object {
							$columns = $_ -split '\s+', 5
							[PSCustomObject]@{
											Name = $columns[0]
											Ready = $columns[1]
											UpToDate = $columns[2]
											Available = $columns[3]
											Age = $columns[4]
							}
			}
			$filteredDeployments = $deploymentList | Where-Object {
							$ready = $_.Ready -split '/'
							([int]$ready[0] -lt [int]$ready[1]) -or ($_.Ready -eq '0/0')
			}
			$selectedDeployments = $filteredDeployments | Out-GridView -PassThru -Title "Selecciona uno o más aplicaciones para desplegar (filtrado por pods availables)"
			$deploymentList | Out-GridView -OutputMode None -Title "Lista de todos deployments"

			foreach ($lineDeployment in $selectedDeployments) {
				$deploymentName = $lineDeployment.Name
				[Console]::Title = "deploy $deploymentName $namespaceName"
				$commandExecArray += [String]::Join(" ", @($command, $deployment, $deploymentName, $replicas, $namespace, $namespaceName))
			}

			# PINTAMOS LLAMADAs
			foreach ($appCurrent in $commandExecArray) {
				Write-Host "CALLING OCP WITH ... $appCurrent"
				$appCurrentArgs = $appCurrent -split ' '
				& $oc $appCurrentArgs
			}
			Write-Host "FIN PROCESO OCP"


		}
		else {
			Write-Host "Etiqueta <code> no encontrada"
		}

	}
}
catch {
	Write-Host "Error: $_"
}
# Restaurar la política de certificados original
[System.Net.ServicePointManager]::CertificatePolicy = $originalPolicy

} finally {
	$userInput = @( "si", "no" ) | Out-GridView -Title "¿Quieres volver a desplegar aplicaciones en Openshift?" -OutputMode Single
}
} while ($userInput -eq 'si')