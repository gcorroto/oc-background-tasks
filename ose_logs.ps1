param (
	[string]$oseRuntimeFolder = $env:OSE_DEPLOY_BACKGROUND_FOLDER,
	[string]$user,
	[SecureString]$securePassword,
	[string]$scrapperInstalled = $env:OSE_DEPLOY_BACKGROUND_SCRAPPER_INSTALLED

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

	# Pregunta al usuario si desea descargar el cliente de OpenShift CLI
	$oc = "$oseRuntimeFolder\oc.exe"

	while ([string]::IsNullOrWhiteSpace($user)) {
		$user = Read-Host -Prompt "Por favor, ingrese el nombre de usuario"
	}

	while ([string]::IsNullOrWhiteSpace($securePassword)) {
		$securePassword = Read-Host -Prompt "Por favor, ingrese la password" -AsSecureString
	}

	$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
	$password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
	$cadenaBasic = "{0}:{1}" -f $user, $password
	$ose_client_id = "openshift-browser-client"
	$ose_response_type = "code"

	
	$env:OSE_FILE_APPS = "$oseRuntimeFolder\$file"
	$file = $env:OSE_FILE_APPS

	$idp = "LDAP"
	$redirect_uri = "https://oauth-openshift.clouddes.mutua.es/oauth/token/display"
	
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

			& $oc login --token=$tokenOse --server=$server

			$outputProjects = & $oc "projects"
			$linesProjects = $outputProjects -split "`n"
			$projects = @()

			foreach ($line in $linesProjects) {
				# Write-Host "have permission for unformat [$line]"
				if ($line -match '^\s*\*\s*([a-z0-9\-]+)\s*$') {
					$currentProject = $Matches[1].Trim()
					$currentProject = $currentProject.Replace('*', '').Trim()
					$projects += $currentProject;
					# Write-Host "have permission and current default [$currentProject]"
				} 
				if ($line -match '^\s*([a-z0-9\-\*]+)\s*$') {
					$currentProject = $Matches[1].Trim()
					$projects += $currentProject;
					# Write-Host "have permission for [$currentProject]"
				}
			}
			
			# $namespaceName = "$area-$env"
			# Get the list of projects
			$projects = & $oc "projects" "--short"

			# Let the user select a project
			$selectedProject = $projects | Out-GridView -PassThru

			# Use the selected project
			$namespaceName = $selectedProject
			Write-Host "for area-env ... $namespaceName"

			# DEPRECATED
			# $pods = & $oc -n $namespaceName "get" "pods"
			#  Write-Host "PODS payload ... $pods"
			# # $podNames = $pods -split "`n" | ForEach-Object { if ($_ -match '^(.*?)\s' -and $_ -notmatch 'NAME') { $Matches[1] } }
			# $podNames = & $oc -n $namespaceName get pods -o jsonpath="{.items[*].metadata.name}"
			# $podNames = $podNames -split " "
			# # Write-Host "pods $podNames"
			# $selectedDeployment = $podNames | Out-GridView -PassThru -Title "Selecciona el pod para consultar el log"

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
	
			$selectedDeployment = $deploymentList | Out-GridView -OutputMode Single -Title "Selecciona una aplicación para consultar el log"

			Write-Host "deployment selected [$selectedDeployment]"
   if($selectedDeployment) {
			$nameDeployment = $selectedDeployment.Name
			Write-Host "deployment target [$nameDeployment]"
			$podNames = & $oc "-n" $namespaceName "get" "pods" "-l" "app=$nameDeployment" "-o" "jsonpath={.items[*].metadata.name}"
			$podNames = $podNames -split " "
			write-host "podNames $podNames"
			# foreach ($podName in $podNames) {
			# 	   write-host "podName $podName"
			# 				$containerNames += & $oc -n $namespaceName get pod $podName -o jsonpath="{.spec.containers[*].name}"
			# 				write-host "containerNames to add $containerNames"
			# }
			if ($podNames -and $podNames.Count -and $podNames.Count -gt 1) {
				write-host "podNames $podNames"
				$selectedPod = $podNames | Out-GridView -Title 'Por favor, selecciona un pod' -OutputMode Single
			}
			else {
				if (!$podNames[0]) {
					throw "No se encontraron pods"
				} else {
					write-host "podNames $podNames"
					$selectedPod = $podNames[0]
				}
			}
			$containerNames = & $oc -n $namespaceName get pod $selectedPod -o jsonpath="{.spec.containers[*].name}"
			$containerNames	= $containerNames -split " "
			Write-Host "final containerNames [$containerNames]"
			# $containerNames	= $containerNames -split " "
			if ($containerNames.Count -gt 1) {
				$selectedContainer = $containerNames | Out-GridView -Title 'Por favor, selecciona un contenedor' -OutputMode Single
			}
			else {
				if (!$containerNames[0]) {
					throw "No se encontraron contenedores"
				} else {
								$selectedContainer = $containerNames[0]
				}
			}
			Write-Host "selectedContainer $selectedContainer"
			# & $oc "-n" $namespaceName "logs" "-f" $selectedDeployment "-c" $selectedContainer
			$userInputStream = @( "si", "no" ) | Out-GridView -Title "¿Quieres mantener el log en stream ?" -OutputMode Single
			
			if($userInputStream -eq 'si'){
				[Console]::Title = "streaming namespace=$namespaceName deployment=$selectedDeployment container=$selectedContainer"
				& $oc "-n" $namespaceName "logs" "-f" $selectedPod "-c" $selectedContainer
			} else {
				[Console]::Title = "single block log namespace=$namespaceName deployment=$selectedDeployment container=$selectedContainer"
				& $oc "-n" $namespaceName "logs" $selectedPod "-c" $selectedContainer
			}
			
		}
					

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
# Ask the user if they want to continue

} finally {
	$userInput = @( "si", "no" ) | Out-GridView -Title "¿Quieres volver a consultar un log de Openshift?" -OutputMode Single
}
} while ($userInput -eq 'si')