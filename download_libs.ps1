param (
	[string]$oseRuntimeFolder = $env:OSE_DEPLOY_BACKGROUND_FOLDER

)

try {
	while ([string]::IsNullOrWhiteSpace($oseRuntimeFolder)) {
		$oseRuntimeFolder = Read-Host -Prompt "Por favor, ingrese la ruta del directorio ose_deploy_background donde descomprimio el fichero incluyendo la carpeta ose_deploy_background ose_deploy_background.zip"
		$env:OSE_DEPLOY_BACKGROUND_FOLDER = $oseRuntimeFolder
	}
	
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

	# Descarga el cliente de OpenShift CLI
	[Console]::Title = "Descargando el cliente de OpenShift CLI"
	Invoke-WebRequest -Uri "https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-windows.zip" -OutFile "$oseRuntimeFolder\oc.zip"

	# Extrae el archivo descargado
	[Console]::Title = "Extrayendo el cliente de OpenShift CLI"
	Expand-Archive -Path "$oseRuntimeFolder\oc.zip" -DestinationPath "$oseRuntimeFolder"

	# Elimina el archivo zip después de extraerlo
	Remove-Item -Path "$oseRuntimeFolder\oc.zip"
	Remove-Item -Path "$oseRuntimeFolder\README.md"

	[Console]::Title = "Descargando nuget.exe para instalar HtmlAgilityPack"
	Invoke-WebRequest -Uri "https://dist.nuget.org/win-x86-commandline/latest/nuget.exe" -OutFile "$oseRuntimeFolder\nuget.exe"
	$nuget = "$oseRuntimeFolder\nuget.exe"


	# Instala HtmlAgilityPack
	[Console]::Title = "Instalando HtmlAgilityPack con nuget.exe para	poder parsear tokens de acceso"
	& $nuget install HtmlAgilityPack  -OutputDirectory $oseRuntimeFolder -Source https://api.nuget.org/v3/index.json

	# Elimina nuget.exe después de usarlo
	Remove-Item -Path $nuget

	[Console]::Title = "Descarga de librerias realizada con exito"
	Write-Host "***** Descarga de librerias realizada con exito *****"
}
catch {
	Write-Host "Error: $_"
}
# Restaurar la política de certificados original
[System.Net.ServicePointManager]::CertificatePolicy = $originalPolicy
