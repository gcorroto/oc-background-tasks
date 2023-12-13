# Acceso directo a los scripts de PowerShell
PONER LA EJECUCION DEL SCRIPT EN EL DESTINO DE UN ACCESO DIRECTO PASANDOLE LOS PARAMETROS OPCIONALES TALES COMO	EL USUARIO Y LA RUTA DE EJECUCION DEL SCRIPT
````POWERSHELL
C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -File "RUTAABSOLUTA_DESCOMPRIMIDO\ose_logs.ps1" -oseRuntimeFolder "RUTAABSOLUTA_DESCOMPRIMIDO" -user "hmaja9q"
````

# PowerShell Script: download_libs.ps1 (se requiere	ejecutar antes	de los otros dos)

Este script de PowerShell está diseñado para descargar e instalar las bibliotecas necesarias para la ejecucuión y propia descarga de la Opensifht CLI. 
Realiza las siguientes tareas:

1. **Establecer Carpeta de Ejecución**: El script primero establece la carpeta de ejecución a partir de una variable de entorno `OSE_DEPLOY_BACKGROUND_FOLDER`. Si esta variable no está establecida, solicita al usuario que introduzca la ruta manualmente esta ruta es donde has descomprimimido el zip inicial.

2. **Confiar en Todos los Certificados**: Para evitar problemas de certificados de seguridad SSL/TLS durante el proceso de descarga, el script cambia temporalmente la política de certificados para confiar en todos los certificados.

3. **Descargar y Extraer OpenShift CLI**: El script descarga el cliente de OpenShift CLI desde el sitio espejo de OpenShift, extrae el archivo zip descargado en la carpeta de ejecución y luego elimina el archivo zip.

4. **Descargar NuGet**: NuGet, un gestor de paquetes para .NET, se descarga en la carpeta de ejecución.

5. **Instalar HtmlAgilityPack**: El script utiliza NuGet para instalar HtmlAgilityPack, una biblioteca para analizar documentos HTML. Después de la instalación, el script elimina el ejecutable de NuGet.
6. **Restaurar la Política de Certificados Original**: Al final del script, se restaura la política de certificados original para mantener la seguridad del sistema.

# PowerShell Script: ose_logs.ps1

Este script de PowerShell está diseñado para interactuar con OpenShift, permitiendo al usuario consultar los logs de las aplicaciones desplegadas. Realiza las siguientes tareas:

1. **Establecer Variables**: El script establece varias variables, incluyendo la carpeta de ejecución, el usuario, la contraseña y si el "scrapper" está instalado.

2. **Solicitar Información al Usuario**: Si ciertas variables no están establecidas, el script solicita al usuario que las introduzca.

3. **Confiar en Todos los Certificados**: Para evitar problemas de certificados de seguridad SSL/TLS durante el proceso de descarga, el script cambia temporalmente la política de certificados para confiar en todos los certificados.

4. **Autenticación**: El script se autentica con el servidor OpenShift utilizando las credenciales proporcionadas por el usuario.

5. **Interacción con OpenShift**: El script interactúa con OpenShift para obtener información sobre los proyectos y pods disponibles, permitiendo al usuario seleccionar un proyecto y un pod para consultar los logs.

6. **Consulta de Logs**: Finalmente, el script consulta los logs del pod seleccionado y los muestra en la consola.


# PowerShell Script: ose_deploy.ps1

Este script de PowerShell está diseñado para interactuar con OpenShift, permitiendo al usuario desplegar	una aplicación en un proyecto. Realiza las siguientes tareas:

1. **Establecer Variables**: El script establece varias variables, incluyendo la carpeta de ejecución, el usuario, la contraseña y si el "scrapper" está instalado.

2. **Solicitar Información al Usuario**: Si ciertas variables no están establecidas, el script solicita al usuario que las introduzca.

3. **Confiar en Todos los Certificados**: Para evitar problemas de certificados de seguridad SSL/TLS durante el proceso de descarga, el script cambia temporalmente la política de certificados para confiar en todos los certificados.

4. **Autenticación**: El script se autentica con el servidor OpenShift utilizando las credenciales proporcionadas por el usuario.

5. **Interacción con OpenShift**: El script interactúa con OpenShift para obtener información sobre los proyectos, pods disponibles, y containers disponibles, permitiendo al usuario seleccionar un proyecto, un pod y un container para desplegar la aplicación siempre	que el pod seleccionado tenga un pod libre.

6. **Deploys**: Finalmente, el script ejecuta el despliegue de la aplicación en el pod seleccionado y muestra los logs de ejecución en la consola.

