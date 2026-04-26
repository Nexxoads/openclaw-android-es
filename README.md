# OpenClaw Gateway Android (Español)

Versión mejorada y traducida del gateway OpenClaw para Android. Convierte un teléfono en servidor de IA con interfaz en español, sin usar la terminal manualmente.

## Características de esta versión

- **Interfaz en español:** textos de la app, notificaciones y asistente de instalación.
- **Acceso remoto:** `localtunnel` se instala en el entorno Ubuntu (proot); desde el panel puedes **Habilitar acceso remoto** y obtener una URL pública hacia el puerto `18789`.
- **Instalación guiada:** Ubuntu base, Node.js y OpenClaw con un flujo de un solo toque (más paquetes opcionales).
- **Compilación en GitHub Actions:** APK y AAB generados automáticamente; artefactos con prefijo **OpenClaw-ES-v\***.

## Cómo obtener el APK

1. Abre la pestaña **Actions** de este repositorio.
2. Entra en el workflow **Build OpenClaw ES Apps** y la ejecución más reciente con marca de éxito.
3. En **Artifacts**, descarga **openclaw-es-apks** (varios APK por arquitectura y uno universal) o **openclaw-es-aab** si necesitas el bundle.
4. Los archivos dentro del zip siguen el nombre `OpenClaw-ES-vVERSION-*.apk`.
5. Instala el APK en el teléfono (permite orígenes desconocidos si el sistema lo pide).

En la rama `main`, las **Releases** de GitHub pueden incluir los mismos binarios con el título **OpenClaw ES v\***.

## Cómo usar

1. Abre la app y pulsa **Instalar** en el asistente (la primera vez puede tardar varios minutos).
2. Cuando termine, en el panel principal pulsa **Iniciar Gateway**.
3. El panel web local está en `http://127.0.0.1:18789`.
4. Para entrar desde fuera de la red local, con el gateway en marcha usa **Habilitar acceso remoto** y comparte la URL que aparece (puedes **Copiar URL pública**).

## Notas importantes

- Se recomienda al menos **4 GB de RAM**.
- Mantén la app abierta o exclúyela de la optimización agresiva de batería para que el proceso no se cierre en segundo plano.
- **Localtunnel** depende del servicio público loca.lt; en redes restrictivas puede fallar.

## Créditos

Basado en el trabajo original de [mithun50/openclaw-termux](https://github.com/mithun50/openclaw-termux).
