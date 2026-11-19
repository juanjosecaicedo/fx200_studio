/// Spanish UI texts, keyed by the English source text passed to tr().
///
/// Names the FX200 shows on its own screen (FOOTSWITCH, GLOBAL EQ, CAB
/// SYNC, FS MODE, MIDI, module/parameter/model names...) are deliberately
/// not translated, so they match the pedal and its manual.
const Map<String, String> stringsEs = <String, String>{
  // General
  'CANCEL': 'CANCELAR',
  'Close': 'Cerrar',
  'Delete': 'Eliminar',
  'Undo': 'Deshacer',
  'Redo': 'Rehacer',
  'SAVE': 'GUARDAR',
  'UNSAVED': 'SIN GUARDAR',
  'ALL': 'TODOS',
  'NONE': 'NINGUNO',
  'OVERWRITE': 'SOBRESCRIBIR',
  'Next {0}': '{0} siguiente',
  'Previous {0}': '{0} anterior',
  '{0} selected': '{0} seleccionados',
  'Applied to the pedal immediately': 'Se aplica al pedal al instante',
  'Connect the FX200 first.': 'Conecta primero la FX200.',
  'USB OFFLINE': 'USB DESCONECTADO',
  'WAITING FX200 USB...': 'ESPERANDO FX200 USB...',
  'SYNCING PRESETS...': 'SINCRONIZANDO PRESETS...',
  'FIRMWARE UPDATE': 'ACTUALIZAR FIRMWARE',
  'Firmware update': 'Actualizar firmware',
  'BACK TO EDITOR': 'VOLVER AL EDITOR',
  'NAM A2 / IR TOOLS': 'HERRAMIENTAS NAM A2 / IR',
  'FX200 STUDIO · CORTEX/AMPERO EDITOR': 'FX200 STUDIO · EDITOR',
  'Scenes: not supported by the current FX200 firmware':
      'Escenas: no disponibles con el firmware actual de la FX200',

  // Unsaved changes
  'Unsaved changes': 'Cambios sin guardar',
  '{0} has changes that are not saved. Save them before switching to {1}?':
      '{0} tiene cambios sin guardar. ¿Guardarlos antes de cambiar a {1}?',
  'KEEP EDITING': 'SEGUIR EDITANDO',
  'DON\'T SAVE': 'NO GUARDAR',
  'SAVE & SWITCH': 'GUARDAR Y CAMBIAR',
  'Could not save the preset: {0}': 'No se pudo guardar el preset: {0}',

  // Editor / chain / browser
  'SIGNAL CHAIN': 'CADENA DE SEÑAL',
  'Add effect block': 'Añadir bloque de efecto',
  'Add to signal chain': 'Añadir a la cadena de señal',
  'MODEL BROWSER': 'NAVEGADOR DE MODELOS',
  'MODELS': 'MODELOS',
  'MODEL': 'MODELO',
  'MODE': 'MODO',
  'Search models...': 'Buscar modelos...',
  'SELECT A BLOCK IN THE SIGNAL CHAIN TO EDIT PARAMETERS':
      'SELECCIONA UN BLOQUE DE LA CADENA PARA EDITAR SUS PARÁMETROS',
  '{0} illustration': 'Ilustración de {0}',
  'Drag up/down · double-click resets':
      'Arrastra arriba/abajo · doble clic restablece',
  'Drag LC / HC · past the edge = OFF':
      'Arrastra LC / HC · más allá del borde = OFF',
  'Drag T (threshold) and R (ratio) · double-click resets':
      'Arrastra T (umbral) y R (ratio) · doble clic restablece',
  'Gain-reduction onset (relative shape)':
      'Inicio de la reducción de ganancia (forma relativa)',
  'Max gain reduction (0 dB in): {0} dB':
      'Reducción máxima (entrada 0 dB): {0} dB',
  'The FX200 has no microphone placement: SPACE adds room ambience, LOW / HI CUT shape the cabinet response.':
      'La FX200 no tiene posición de micrófono: SPACE añade ambiente de '
      'sala y LOW / HI CUT dan forma a la respuesta del gabinete.',

  // Preset sidebar
  'Search presets...': 'Buscar presets...',
  'COPY': 'COPIAR',
  'PASTE': 'PEGAR',
  'Copy {0}': 'Copiar {0}',
  'Paste here': 'Pegar aquí',
  'Paste {0} here': 'Pegar {0} aquí',
  'Clear {0}...': 'Borrar {0}...',
  'Clear the active preset': 'Borrar el preset activo',
  'Clipboard: {0}': 'Portapapeles: {0}',
  'Drag to move this preset': 'Arrastra para mover este preset',
  'Paste preset': 'Pegar preset',
  'Overwrite {0} "{1}" on the pedal with {2}?':
      '¿Sobrescribir {0} "{1}" en el pedal con {2}?',
  'Clear preset': 'Borrar preset',
  'Clear {0} "{1}" on the pedal?\n\nAll modules are switched off, the chain order and footswitch are reset, the EXP assignment is removed and it is renamed "Empty". Copy it first if you may want it back.':
      '¿Borrar {0} "{1}" en el pedal?\n\nSe apagan todos los módulos, se '
      'restablecen el orden de la cadena y el footswitch, se quita la '
      'asignación EXP y se renombra "Empty". Cópialo antes si quieres '
      'recuperarlo.',
  'Move preset': 'Mover preset',
  'Presets {0}–{1} move up one slot.':
      'Los presets {0}–{1} suben una posición.',
  'Presets {0}–{1} move down one slot.':
      'Los presets {0}–{1} bajan una posición.',
  'Move {0} "{1}" to position {2}?\n\n{3} This reads and rewrites {4} presets on the pedal (about {5} s). Do not unplug the pedal meanwhile.':
      '¿Mover {0} "{1}" a la posición {2}?\n\n{3} Se leen y reescriben {4} '
      'presets en el pedal (unos {5} s). No desconectes el pedal mientras '
      'tanto.',
  'Export presets to .pfl files': 'Exportar presets a archivos .pfl',
  'Import .pfl files into the active slot onwards':
      'Importar archivos .pfl desde la posición activa',
  'Export {0} to .pfl...': 'Exportar {0} a .pfl...',
  'Import .pfl here...': 'Importar .pfl aquí...',
  'Export presets (.pfl)': 'Exportar presets (.pfl)',
  'EXPORT...': 'EXPORTAR...',
  'Export {0} preset(s) here': 'Exportar {0} preset(s) aquí',
  'FX200 preset': 'Preset de FX200',
  'Import presets': 'Importar presets',
  'Overwrite preset {0} on the pedal with "{1}"?':
      '¿Sobrescribir el preset {0} del pedal con "{1}"?',
  'Overwrite presets {0}–{1} on the pedal with {2} files (in the order chosen)?':
      '¿Sobrescribir los presets {0}–{1} del pedal con {2} archivos (en el '
      'orden elegido)?',
  'Copying preset {0}...': 'Copiando preset {0}...',
  'Copied {0} {1}': 'Copiado {0} {1}',
  'Pasting into {0}...': 'Pegando en {0}...',
  'Pasted {0} into {1}': 'Pegado {0} en {1}',
  'Clearing preset {0}...': 'Borrando preset {0}...',
  'Cleared {0}': 'Borrado {0}',
  'Moved {0} → {1}': 'Movido {0} → {1}',
  'Exporting {0} preset(s)...': 'Exportando {0} preset(s)...',
  'Reading the presets from the pedal (about 30 s)...':
      'Leyendo los presets del pedal (unos 30 s)...',
  'Preset {0} could not be read; nothing more was exported.':
      'No se pudo leer el preset {0}; no se exportó nada más.',
  'Exported {0} {1}': 'Exportado {0} {1}',
  'Exported {0} preset(s) to {1}': 'Exportados {0} preset(s) a {1}',
  'Not enough slots after {0} for {1} presets.':
      'No hay posiciones suficientes después de {0} para {1} presets.',
  'Importing {0} preset(s)...': 'Importando {0} preset(s)...',
  'Writing {0} into {1}...': 'Escribiendo {0} en {1}...',
  'Imported {0} preset(s) from {1}': 'Importados {0} preset(s) desde {1}',

  'Some presets arrived incomplete from the FX200 after {0} reads (USB packets lost): {1}.':
      'Algunos presets llegaron incompletos de la FX200 tras {0} lecturas '
      '(se perdieron paquetes USB): {1}.',

  'The FX200 did not accept preset {0} after {1} attempts; {2} presets were restored before it.':
      'La FX200 no aceptó el preset {0} tras {1} intentos; antes se '
      'restauraron {2} presets.',
  'The FX200 did not request the preset data (0x83); nothing was written.':
      'La FX200 no pidió los datos del preset (0x83); no se escribió nada.',

  'Verifying: reading the presets back (about 30 s)...':
      'Verificando: releyendo los presets (unos 30 s)...',
  'The pedal reports {0} presets that differ from the backup: {1}':
      'El pedal tiene {0} presets distintos de la copia: {1}',
  ' (verified on the pedal)': ' (verificado en el pedal)',

  // Footswitch
  'Connect the FX200 to assign the footswitch.':
      'Conecta la FX200 para asignar el footswitch.',
  'Waiting for the footswitch state (0xA4). Select a preset to load it.':
      'Esperando el estado del footswitch (0xA4). Selecciona un preset para '
      'cargarlo.',
  'The preset footswitch turns the selected modules on/off (LED blue / purple).':
      'El footswitch del preset enciende/apaga los módulos seleccionados '
      '(LED azul / morado).',
  'The preset footswitch taps the tempo (LED blinks red). Current tempo: {0} BPM. Turn on SUB-D in the DELAY module to follow it.':
      'El footswitch del preset marca el tempo (el LED parpadea en rojo). '
      'Tempo actual: {0} BPM. Activa SUB-D en el módulo DELAY para que lo '
      'siga.',
  'Pressing the footswitch only selects presets (LED stays green).':
      'El footswitch solo selecciona presets (el LED queda en verde).',
  'Per-preset assignment': 'Asignación por preset',
  'Assignment for preset {0}': 'Asignación del preset {0}',
  'Not saved — the pedal forgets it when you change preset.':
      'Sin guardar: el pedal lo olvida al cambiar de preset.',
  'SAVE TO PRESET': 'GUARDAR EN EL PRESET',

  // Expression pedal
  'Connect the FX200 to set up the expression pedals.':
      'Conecta la FX200 para configurar los pedales de expresión.',
  'Waiting for the expression pedal setup (0xA3). Select a preset to load it.':
      'Esperando la configuración del pedal de expresión (0xA3). Selecciona '
      'un preset para cargarla.',
  'PEDAL 1 · INTERNAL': 'PEDAL 1 · INTERNO',
  'PEDAL 2 · EXTERNAL': 'PEDAL 2 · EXTERNO',
  'EXPRESSION — the external pedal cannot work in VOLUME mode.':
      'EXPRESSION: el pedal externo no puede funcionar en modo VOLUME.',
  'Per-preset setup': 'Configuración por preset',
  'Setup for preset {0}': 'Configuración del preset {0}',
  'CONTROLLED PARAMETERS': 'PARÁMETROS CONTROLADOS',
  'Add a parameter': 'Añadir un parámetro',
  'ADD PARAMETER': 'AÑADIR PARÁMETRO',
  'Nothing assigned. Add one or more parameters; each moves from its HEEL value (pedal up) to its TOE value (pedal down).':
      'Nada asignado. Añade uno o más parámetros; cada uno va de su valor '
      'HEEL (pedal arriba) a su valor TOE (pedal abajo).',
  'The internal pedal controls the FX200 output volume between the HEEL (pedal up) and TOE (pedal down) levels.':
      'El pedal interno controla el volumen de salida de la FX200 entre los '
      'niveles HEEL (pedal arriba) y TOE (pedal abajo).',

  // Drum
  'Connect the FX200 to use the drum machine.':
      'Conecta la FX200 para usar la caja de ritmos.',
  'Waiting for the drum machine state (0xAD). It is sent when the pedal connects.':
      'Esperando el estado de la caja de ritmos (0xAD). Se recibe al '
      'conectar el pedal.',
  'Drum machine and metronome': 'Caja de ritmos y metrónomo',
  'Global setting, applied immediately (no preset save needed).':
      'Ajuste global, se aplica al instante (no hace falta guardar el '
      'preset).',

  // User IR
  'Connect the FX200 to manage user IRs.':
      'Conecta la FX200 para gestionar los IR de usuario.',
  'Waiting for the IR list (0x85). It is sent when the pedal connects.':
      'Esperando la lista de IR (0x85). Se recibe al conectar el pedal.',
  'Impulse responses in CAB slots 31-80':
      'Respuestas de impulso en las ranuras CAB 31-80',
  'Impulse response': 'Respuesta de impulso',
  'LOAD WAV': 'CARGAR WAV',
  'REPLACE': 'REEMPLAZAR',
  'WAV 44.1 / 48 / 88.2 / 96 kHz, 16 / 24 / 32-bit float. The first 1024 points at 44.1 kHz are kept, like the official editor. Turn on the CAB module and pick the slot to use it.':
      'WAV de 44,1 / 48 / 88,2 / 96 kHz, 16 / 24 / 32 bits float. Se '
      'conservan los primeros 1024 puntos a 44,1 kHz, como en el editor '
      'oficial. Enciende el módulo CAB y elige la ranura para usarlo.',
  'Loading {0} into CAB {1}...': 'Cargando {0} en CAB {1}...',
  'Loaded {0} into CAB {1}.': '{0} cargado en CAB {1}.',
  'Delete IR': 'Eliminar IR',
  'DELETE': 'ELIMINAR',
  'Delete "{0}" from CAB {1} on the pedal? Presets using it will have an empty cabinet.':
      '¿Eliminar "{0}" de CAB {1} en el pedal? Los presets que lo usen '
      'quedarán con un gabinete vacío.',
  'Deleting IR {0}...': 'Eliminando IR {0}...',
  'IR {0} deleted.': 'IR {0} eliminado.',
  'OFFICIAL BACKUP (.BFL)...': 'COPIA OFICIAL (.BFL)...',
  'Official FX200 backup': 'Copia oficial de FX200',
  'Official backup saved: 200 presets, {0} IRs → {1}':
      'Copia oficial guardada: 200 presets, {0} IR → {1}',
  'The pedal did not send its SYSTEM block or IR list.':
      'El pedal no envió su bloque SYSTEM ni la lista de IR.',

  // SYSTEM
  'SYSTEM · GLOBAL SETTINGS': 'SYSTEM · AJUSTES GLOBALES',
  'Connect the FX200 to edit its SYSTEM settings.':
      'Conecta la FX200 para editar sus ajustes de SYSTEM.',
  'Waiting for the SYSTEM block (0xA1). It arrives with the preset sync after connecting.':
      'Esperando el bloque SYSTEM (0xA1). Llega con la sincronización de '
      'presets al conectar.',
  'Changing the AMP model also picks its matching cabinet':
      'Al cambiar el modelo de AMP también se elige su gabinete',
  'Cab sim on the left / right output channel':
      'Simulación de gabinete en el canal de salida izquierdo / derecho',
  'NORMAL: banks + A/B · FAVORITE: 4 favorite presets':
      'NORMAL: bancos + A/B · FAVORITE: 4 presets favoritos',
  'Let delay and reverb tails ring out when switching':
      'Deja sonar las colas de delay y reverb al cambiar',
  'Applies to OUTPUT / XLR OUT / PHONES':
      'Se aplica a OUTPUT / XLR OUT / PHONES',
  'Receive (IN) or send (OUT) MIDI clock':
      'Recibir (IN) o enviar (OUT) reloj MIDI',
  '0 = direct monitoring only · 100 = USB playback only':
      '0 = solo monitorización directa · 100 = solo reproducción USB',
  'Drag L / M / H for frequency + gain, LC / HC for the cuts. Double-click a node to reset it.':
      'Arrastra L / M / H para frecuencia + ganancia, LC / HC para los '
      'cortes. Doble clic en un nodo para restablecerlo.',
  'Turn GLOBAL EQ on to edit (the pedal ignores the values while off).':
      'Activa GLOBAL EQ para editar (el pedal ignora los valores mientras '
      'está apagado).',
  'EXACT VALUES': 'VALORES EXACTOS',
  'Global input gain, as in the official editor (0 to 20 dB)':
      'Ganancia de entrada global, como en el editor oficial (0 a 20 dB)',
  'DISPLAY': 'PANTALLA',

  // Backup
  'BACKUP & RESTORE': 'COPIA DE SEGURIDAD Y RESTAURACIÓN',
  '200 presets + SYSTEM settings': '200 presets + ajustes de SYSTEM',
  'Connect the FX200 to create or restore a backup. You can still open a backup file to inspect it.':
      'Conecta la FX200 para crear o restaurar una copia. Igualmente puedes '
      'abrir un archivo de copia para revisarlo.',
  'Reads every preset from the pedal (about one minute). The pedal steps through all presets while reading and returns to the current one at the end.':
      'Lee todos los presets del pedal (aproximadamente un minuto). El '
      'pedal recorre todos los presets durante la lectura y al final vuelve '
      'al actual.',
  'BACKUP TO FILE...': 'COPIA A ARCHIVO...',
  'CREATE BACKUP': 'CREAR COPIA',
  'RESTORE': 'RESTAURAR',
  'OPEN BACKUP...': 'ABRIR COPIA...',
  'RESTORE TO PEDAL': 'RESTAURAR EN EL PEDAL',
  'FX200 Studio backup': 'Copia de FX200 Studio',
  'FX200 backup (FX200 Studio or official .bfl)':
      'Copia de FX200 (FX200 Studio o .bfl oficial)',
  'Official backup: {0}\n200 presets · {1} user IRs · SYSTEM settings':
      'Copia oficial: {0}\n200 presets · {1} IR de usuario · ajustes de '
      'SYSTEM',
  'Presets (200)': 'Presets (200)',
  'User IRs ({0})': 'IR de usuario ({0})',
  'Global settings and drum machine': 'Ajustes globales y caja de ritmos',
  'Presets ({0} of {1})': 'Presets ({0} de {1})',
  'Global settings (not in this backup)':
      'Ajustes globales (no están en esta copia)',
  'Global settings (SYSTEM)': 'Ajustes globales (SYSTEM)',
  'I understand this overwrites the selected data on the pedal':
      'Entiendo que esto sobrescribe los datos seleccionados en el pedal',
  'Created {0} · {1} presets{2}': 'Creada {0} · {1} presets{2}',
  ' · SYSTEM block': ' · bloque SYSTEM',
  'Starting backup...': 'Iniciando copia...',
  'Starting restore...': 'Iniciando restauración...',
  'Backup saved: {0} presets + global settings → {1}':
      'Copia guardada: {0} presets + ajustes globales → {1}',
  'Backup saved → {0} ({1} presets incomplete, they will be skipped on restore)':
      'Copia guardada → {0} ({1} presets incompletos; se omitirán al '
      'restaurar)',
  'Backup cancelled. No file written.':
      'Copia cancelada. No se escribió ningún archivo.',
  'Could not open backup: {0}': 'No se pudo abrir la copia: {0}',
  'Restore complete: {0}.': 'Restauración completa: {0}.',
  'Restore complete: {0} presets, {1} IRs{2}.':
      'Restauración completa: {0} presets, {1} IR{2}.',
  ', global settings': ', ajustes globales',
  'Restore cancelled. Presets already written stay written.':
      'Restauración cancelada. Los presets ya escritos se mantienen.',
  'Restore cancelled. Data already written stays written.':
      'Restauración cancelada. Los datos ya escritos se mantienen.',

  // Firmware
  'Make a BACKUP first: an update can reset presets and IRs.':
      'Haz primero una COPIA: una actualización puede borrar presets e IR.',
  'Switch the FX200 off, then hold the VALUE knob while switching it on. It boots in update mode.':
      'Apaga la FX200 y mantén pulsado el mando VALUE mientras la enciendes. '
      'Arrancará en modo actualización.',
  'Keep it connected by USB, choose the .fl file and START.':
      'Mantenla conectada por USB, elige el archivo .fl y pulsa START.',
  'FX200 in update mode detected': 'FX200 en modo actualización detectada',
  'Waiting for the FX200 in update mode (USB 0483:5703)...':
      'Esperando la FX200 en modo actualización (USB 0483:5703)...',
  'CHOOSE .FL FILE...': 'ELEGIR ARCHIVO .FL...',
  'FX200 firmware': 'Firmware de FX200',
  'Official firmware: {0}': 'Firmware oficial: {0}',
  'Unknown firmware (not a known official release). It may be modified or damaged.':
      'Firmware desconocido (no es una versión oficial conocida). Puede '
      'estar modificado o dañado.',
  '• {0}: {1} KB': '• {0}: {1} KB',
  'I have a backup and will not unplug or switch off the pedal until the update finishes.':
      'Tengo una copia y no desconectaré ni apagaré el pedal hasta que '
      'termine la actualización.',
  'I understand this is not an official firmware and may leave the pedal unusable.':
      'Entiendo que no es un firmware oficial y que puede dejar el pedal '
      'inutilizable.',
  '{0} · {1} / {2} blocks{3}': '{0} · {1} / {2} bloques{3}',
  ' · about {0} min {1} s left': ' · quedan unos {0} min {1} s',
  'Device: {0}': 'Dispositivo: {0}',
  'Do not unplug or switch off the FX200.':
      'No desconectes ni apagues la FX200.',
  'Update complete. The FX200 restarts with the new firmware; restore your backup if presets or IRs were reset.':
      'Actualización completa. La FX200 se reinicia con el nuevo firmware; '
      'restaura tu copia si se borraron presets o IR.',
  '{0}\nThe pedal stays in update mode: you can start the update again.':
      '{0}\nEl pedal sigue en modo actualización: puedes iniciar la '
      'actualización de nuevo.',
  'Wait for the update to finish': 'Espera a que termine la actualización',
  'RETRY': 'REINTENTAR',
  'START': 'INICIAR',
  // firmware steps (from the updater service)
  'Connecting': 'Conectando',
  'Preparing the pedal': 'Preparando el pedal',
  'Starting': 'Iniciando',
  'Done': 'Terminado',
  'Done (the pedal restarted)': 'Terminado (el pedal se reinició)',
  'Main MCU application': 'Aplicación del MCU principal',
  'Audio engine (DSP MCU)': 'Motor de audio (MCU DSP)',
  'Audio resources': 'Recursos de audio',
  'Factory presets': 'Presets de fábrica',
};
