# Mis Prompts

Aplicación nativa para macOS que guarda prompts en tarjetas, junto con la IA, el modelo y el esfuerzo que quieras recordar.

## Funciones

- Crear, editar, abrir y copiar prompts.
- Arrastrar las tarjetas sobre otras para cambiar su orden, o usar el menú ⋯ para moverlas antes, después, al principio o al final.
- Anotar varias configuraciones de IA en una tarjeta.
- Buscar por título, contenido, categoría, IA o modelo.
- Mover prompts a una papelera y restaurarlos.
- Guardar automáticamente en el Mac.
- Exportar e importar respaldos JSON, conservando los registros existentes.
- Iniciar con siete prompts reutilizables, incluido el copiloto de reuniones en inglés.

Los campos de IA, modelo y esfuerzo son recordatorios. La aplicación no ejecuta modelos ni cambia la configuración de otras aplicaciones. No requiere cuenta ni conexión a Internet.

## Instalar

Descarga el ZIP de la sección **Releases**, descomprímelo y mueve **Mis Prompts.app** a Aplicaciones.

La versión 1.1 requiere **macOS 14 o posterior y Apple Silicon**. Tiene una firma local ad hoc; no está notarizada por Apple. En otro Mac, Gatekeeper puede pedir autorización para abrirla. También puedes compilarla desde el código fuente.

## Compilar

Requiere macOS, las herramientas de línea de comandos de Xcode, Swift 6.2 o posterior.

```bash
bash scripts/test.sh
bash scripts/build.sh
open ".build/App.noindex/Mis Prompts.app"
```

El script compila para la arquitectura del Mac actual, genera el icono, firma el paquete localmente y crea un ZIP en `dist/`. No modifica las credenciales ni las preferencias del sistema.

## Datos y recuperación

La biblioteca se guarda fuera de la aplicación, en:

```text
~/Library/Application Support/Mis Prompts/library.json
```

Antes de guardar un cambio, se conserva la versión anterior en `library.previous.json`. Los prompts de la papelera permanecen dentro de la biblioteca. Los respaldos exportados incluyen la papelera.

El orden de las tarjetas se guarda automáticamente y se conserva en los respaldos. Al reordenar resultados de búsqueda, las tarjetas ocultas y la papelera mantienen sus posiciones. Para probar la interfaz con una biblioteca temporal, abre la aplicación con `--args --demo`.

Si ya usabas la versión 1.0, puedes importar `Resources/Seed.json` desde **Importar respaldo** para añadir el prompt de copiloto de reuniones. Las fases PREPARA, INICIA y DETENTE incluyen recordatorios de modelo y esfuerzo.

La importación agrega los identificadores que no existen; no sobrescribe prompts ya presentes. Cambiar de versión o mover la aplicación no elimina la biblioteca. Si el archivo existente no es válido, la aplicación informa el error y evita reemplazarlo.

Los archivos JSON contienen texto legible. Los respaldos y la biblioteca personal no se incluyen en el repositorio.

## Estructura

```text
Sources/App.swift       Interfaz SwiftUI, portapapeles y operaciones de biblioteca
Sources/Core.swift      Modelo de datos, persistencia y validación de archivos
Resources/Seed.json     Prompts iniciales
Resources/Info.plist    Configuración del paquete de macOS
Tests/Tests.swift       Pruebas de persistencia, papelera, importación y recuperación
scripts/Icon.swift     Generación del icono
scripts/build.sh       Compilación y empaquetado
scripts/test.sh        Ejecución de pruebas en un directorio aislado
```

Los identificadores de modelos que aparecen como campos por completar deben elegirse y verificarse antes de utilizar los prompts.
