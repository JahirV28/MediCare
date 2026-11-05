# MediCore EMR: Sistema de Escritorio para Gestión Integral de Expedientes Clínicos, Especialidades y Facturación Médica
## Memoria Técnica de Ingeniería de Software y Especificación Formal de Arquitectura
**Documento Técnico Oficial y Especificación de Requerimientos de Software (SRS)**

---

## 1. Portada y Metadatos Académicos

| Metadato Académico | Detalle Institucional y Técnico |
| :--- | :--- |
| **Institución Universitaria** | Universidad Nacional de Ingeniería (UNI) |
| **Facultad / Escuela** | Facultad de Electrotecnia y Computación (FEYC) / Escuela de Computación e Informática |
| **Carrera Profesional** | Ingeniería de Sistemas |
| **Asignatura** | Programación de Aplicaciones de Escritorio / Ingeniería de Software |
| **Título del Proyecto** | **MediCore EMR** *(Electronic Medical Record & Clinical Management System)* |
| **Versión del Entregable** | **2.0.0-RELEASE (Compilación Nativa Win32 x64 & Web - Backend Supabase / PostgreSQL)** |
| **Entorno Tecnológico** | Flutter Desktop 3.x, Dart 3.11+ (AOT), Supabase Cloud (PostgreSQL 15+), Provider 6.x |
| **Localización Regional** | Nicaragua (Managua, Centroamérica) — Formateadores oficiales Cédula, Teléfono +505 y Moneda (C$ / USD) |
| **Fecha de Publicación** | Octubre de 2026 |

---

## 2. Resumen Ejecutivo e Introducción

La informatización de la atención médica ambulatoria en consultorios, policlínicos y centros de especialidades independientes ha dependido históricamente de dos extremos ineficientes: aplicaciones web centralizadas de suscripción (SaaS) y hojas de cálculo locales desestructuradas. El primer enfoque introduce dependencias críticas: una caída en el enlace de telecomunicaciones paraliza la recepción, el triaje, la consulta diagnóstica y la emisión de prescripciones, además de incurrir en alta latencia y sobrecostos de memoria RAM por el uso de motores Chromium/Electron. El segundo enfoque compromete gravemente la integridad, la trazabilidad y la confidencialidad de la información médica protegida (PHI).

**MediCore EMR** se concibe como una solución de ingeniería de software de alto rendimiento, diseñada bajo un **paradigma híbrido de escritorio de alta fidelidad**. MediCore combina la velocidad de ejecución nativa, el bajo consumo de recursos volátiles y el acceso directo al subsistema gráfico y periféricos del sistema operativo **Microsoft Windows (Win32 x64)** con la robustez transaccional, escalabilidad y capacidades en tiempo real de una base de datos relacional **PostgreSQL hospedada en la nube mediante Supabase**.

### Pilares Fundamentales del Sistema:
1. **Rendimiento Nativo AOT:** Compilación directa a código máquina x64 mediante el runner de C++ de Windows, garantizando tiempos de inicio en frío inferiores a 1.5 segundos, una tasa constante de 60 a 120 fotogramas por segundo (FPS) y un consumo de memoria volátil inferior a 150 MB en reposo.
2. **Persistencia Híbrida y Sincronización en la Nube con Supabase:** Migración formal desde un modelo local MySQL a un clúster PostgreSQL 15+ en Supabase. Se aprovechan funciones de seguridad a nivel de filas (RLS), procedimientos almacenados RPC (`sp_get_dashboard_overview`), autenticación criptográfica basada en tokens JWT y WebSockets bidireccionales en tiempo real.
3. **Módulos Clínicos Especializados:** Más allá de una historia clínica genérica, MediCore incorpora:
   - **Odontología Especializada:** Odontograma interactivo digital para las 32 piezas dentales adultas y temporales bajo la nomenclatura internacional FDI, con mapeo vectorial de cinco superficies anatómicas y bitácora clínica de procedimientos.
   - **Pediatría Antropométrica:** Motor de graficación vectorial a medida (`_AdaptiveWhoChartPainter`) que calcula y renderiza las curvas y percentiles de crecimiento oficiales de la Organización Mundial de la Salud (OMS 0-5 años) para Peso, Talla, Perímetro Cefálico e IMC.
   - **Consultas Estructuradas SOAP y CIE-10:** Documentación médica estandarizada (Subjetivo, Objetivo con signos vitales e IMC, Análisis con catálogo diagnóstico CIE-10 y Plan terapéutico).
   - **Farmacología y Prescripción Asistida en PDF:** Generador de recetas médicas con cálculo de posología y exportación documental vectorial de alta resolución vía `pdf` y `printing`.
4. **Localización Oficial para Nicaragua:** Validación y formateo estricto en tiempo real para la Cédula de Identidad de Nicaragua (`000-000000-0000A`), numeración telefónica con prefijo nacional `+505`, manejo de moneda dual (Córdobas `C$` y Dólares `USD $`) y configuración regional en `Locale('es', 'NI')`.
5. **Arquitectura Desacoplada y Resiliente:** Separación por capas (Clean Architecture + Feature-First) con inyección de dependencias mediante `MultiProvider`. Se implementa una capa de contingencia (`MockApiService`) que garantiza que el consultorio continúe operando aun en eventos severos de desconexión WAN.

---

## 3. Objetivos del Proyecto

### 3.1 Objetivo General
Diseñar, estructurar e implementar una aplicación de escritorio multiplataforma (enfocada en Windows x64 nativo y compatible con navegadores modernos) orientada a la gestión integral de registros médicos electrónicos (EMR/EHR), aplicando los principios de la Arquitectura Limpia (*Clean Architecture*) y programación reactiva con Dart 3 y Flutter, integrando un backend relacional escalable en Supabase (PostgreSQL 15+) normalizado en Tercera Forma Normal (3FN), con el fin de optimizar los procesos de triaje, consulta diagnóstica, odontología, pediatría, emisión de recetas y control de caja ambulatoria en clínicas y consultorios de Nicaragua.

### 3.2 Objetivos Específicos
* **Objetivo Técnico y de Rendimiento:** Compilar un binario ejecutable x64 nativo mediante el toolchain de MSVC v143 y Dart AOT, logrando una tasa de renderizado constante de 60-120 FPS y reduciendo la huella de memoria RAM por debajo de 150 MB.
* **Objetivo de Persistencia e Integración Cloud:** Implementar un esquema relacional de 19 entidades en PostgreSQL / Supabase bajo 3FN, dotado de restricciones de integridad referencial, procedimientos almacenados (RPC), vistas materializadas y Row Level Security (RLS).
* **Objetivo de Experiencia de Usuario (UX) de Escritorio:** Implementar un entorno ergonómico de alta densidad de información basado en el patrón *Master-Detail*, con navegación lateral colapsable, atajos de teclado globales y componentes interactivos basados en vectores gráficos (`CustomPainter`).
* **Objetivo de Especialización Médica:** Desarrollar herramientas de apoyo diagnóstico clínico de alta fidelidad: odontograma FDI con control de 5 superficies por pieza y visualizador de curvas antropométricas de la OMS para pediatría infantil.
* **Objetivo de Localización Nacional:** Desarrollar formateadores y validadores de entrada específicos para la República de Nicaragua (Cédula de Identidad con letra final, formato telefónico de 8 dígitos con prefijo internacional `+505` y codificación de moneda local).
* **Objetivo de Seguridad y Cumplimiento Normativo:** Establecer controles de acceso basados en roles (RBAC), encriptación en tránsito mediante TLS 1.3, autenticación con tokens seguros y una bitácora inmutable de auditoría forense (`audit_logs`) con captura de estados diferenciales en formato JSON.

---

## 4. Marco Tecnológico y Justificación de Herramientas

### 4.1 Análisis Comparativo de Tecnologías de Escritorio

| Criterio Técnico | Flutter Desktop (Win32 / C++) | .NET WPF / WinForms | JavaFX | Electron (Chromium/Node) | Qt C++ |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Mecanismo de Compilación** | **Nativa AOT (Código Máquina x64)** | Bytecode CIL / JIT (.NET CLR) | Bytecode / JIT (JVM) | Interpretado / JIT (V8 Engine) | Nativa C++ pura |
| **Consumo de RAM (Reposo)** | **Muy Bajo (~110 - 150 MB)** | Moderado (~180 - 320 MB) | Alto (~250 - 450 MB) | Crítico (~500 - 950 MB) | Mínimo (~45 - 85 MB) |
| **Tiempo de Arranque (Frío)** | **< 1.5 segundos** | 2.5 - 4.0 segundos | 3.5 - 6.0 segundos | 4.0 - 8.0 segundos | < 1.0 segundo |
| **Motor de Renderizado** | **Impeller / Skia (GPU Directa)** | DirectX (vía milcore) | Prism (DirectX / OpenGL) | Chromium Compositor | QPainter / OpenGL nativo |
| **Paradigma de UI** | **Declarativo Reactivo** | XAML Declarativo / Imperativo | FXML / Imperativo | HTML5 / CSS3 / DOM | QML / Imperativo |
| **Multiplataforma Real** | **Excelente (Windows, Web, macOS)** | Pobre (Exclusivo Windows) | Regular (Requiere JRE) | Excelente (Multiplataforma) | Buena (Multiplataforma) |
| **Costo de Mantenimiento** | **Bajo (Un solo código base)** | Medio (Código específico) | Medio-Alto | Medio-Alto | Alto (Gestión manual punteros) |

**Justificación:** Flutter Desktop fue elegido por sobre Electron debido a que elimina la sobrecarga masiva de memoria y tiempo de arranque de empaquetar un navegador web completo para una aplicación de oficina clínica. Frente a .NET WPF, Flutter ofrece portabilidad directa hacia navegadores web y sistemas macOS/Linux sin reescribir la capa visual, conservando aceleración por hardware por GPU directa.

### 4.2 Lenguaje Dart 3: Tipado Estricto y Sound Null Safety
MediCore está desarrollado íntegramente con **Dart 3.11+**, el cual aplica el sistema de tipos *Sound Null Safety*. En un sistema médico donde un puntero nulo (`NullPointerException`) al calcular la dosis pediátrica de un antibiótico o al leer la presión arterial podría provocar consecuencias catastróficas, la verificación estricta en tiempo de compilación garantiza que las variables nunca contengan `null` a menos que se declaren explícitamente como opcionales (`Type?`). Adicionalmente, se aprovechan las capacidades de *Pattern Matching* y *Switch Expressions* de Dart 3 para el mapeo determinista de estados de red y condiciones dentales.

```dart
// Mapeo exhaustivo y seguro de condiciones dentales usando Switch Expressions de Dart 3
static String mapToothConditionToDb(ToothCondition cond) => switch (cond) {
  ToothCondition.caries => 'Caries',
  ToothCondition.treated => 'Treated',
  ToothCondition.missing => 'Missing',
  ToothCondition.healthy => 'Healthy',
};
```

### 4.3 Gestión de Estado Reactiva con Provider
En una estación de trabajo médica coexisten múltiples pantallas de alta densidad: un cambio en los signos vitales debe reflejarse en la nota de evolución SOAP y en la alerta de la barra superior. MediCore adopta el patrón de arquitectura reactiva mediante el paquete `provider` y `ChangeNotifier`. La interfaz visual se desacopla por completo de la lógica de negocio; los widgets de presentación se suscriben como observadores utilizando `Consumer<T>` o selectores granulares, garantizando que únicamente se reconstruyan las partes del árbol de widgets que sufrieron mutaciones de estado.

### 4.4 Infraestructura de Persistencia: De MySQL 8.0 a Supabase (PostgreSQL 15+)
En las fases iniciales del proyecto se evaluó el uso de MySQL 8.0 local. Sin embargo, para satisfacer las demandas modernas de las instituciones de salud (acceso distribuido entre consultorios, teleconsulta, soporte de sincronización y control de accesos por usuario), la persistencia evolucionó hacia **Supabase / PostgreSQL 15+**:

1. **Row Level Security (RLS):** Supabase permite aislar el acceso a nivel de registro en la propia base de datos. Un médico sólo puede consultar o actualizar expedientes autorizados para su clínica o especialidad.
2. **Procedimientos Almacenados RPC:** Cálculos analíticos complejos (tales como la consolidación de ingresos del día, pacientes activos y distribución semanal de consultas) se ejecutan directamente en PostgreSQL mediante el Stored Procedure `sp_get_dashboard_overview`, reduciendo drásticamente las llamadas de red a un único viaje de ida y vuelta (*round-trip*).
3. **Manejo Nativo de JSONB:** Almacenamiento flexible de historiales de auditoría y detalles clínicos complejos sin violar la Tercera Forma Normal (3FN).
4. **Resiliencia con Modo Contingencia:** Si la estación pierde conectividad a internet, la arquitectura conmuta automáticamente a la capa de contingencia (`MockApiService`), garantizando que la atención en recepción no se detenga.

### 4.5 Motor de Salida Documental e Impresión: `pdf` y `printing`
Para la entrega física y digital al paciente, MediCore utiliza los paquetes `pdf: ^3.12.0` y `printing: ^5.14.3`. Esto permite dibujar vectorialmente sobre un lienzo virtual A4 prescripciones farmacológicas con membrete institucional, reportes pediátricos con tablas de percentiles y comprobantes financieros, enviándolos directamente al subsistema de impresión de Windows o descargándolos en formato PDF.

---

## 5. Arquitectura del Software y Estructura del Código

### 5.1 Capas Arquitectónicas (Clean Architecture + Feature-First)

```
┌────────────────────────────────────────────────────────────────────────┐
│                      PRESENTATION LAYER (UI)                           │
│  ┌──────────────────────────┐      ┌────────────────────────────────┐  │
│  │   Screens (Vistas)       │      │   Widgets Especializados       │  │
│  │   - Dashboard, Pacientes │      │   - ToothPainter (Odontograma) │  │
│  │   - SOAP, Pediatría      │      │   - AdaptiveWhoChartPainter    │  │
│  │   - Calendario, Finanzas │      │   - Breadcrumb, Tables, Forms  │  │
│  └─────────────▲────────────┘      └────────────────▲───────────────┘  │
└────────────────┼────────────────────────────────────┼──────────────────┘
                 │ Suscripción Reactiva (Consumer)    │
┌────────────────┴────────────────────────────────────┴──────────────────┐
│                   STATE MANAGEMENT LAYER (PROVIDERS)                   │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │  AuthProvider, DashboardProvider, PatientProvider,               │  │
│  │  ConsultationProvider, PrescriptionProvider, DiagnosticProvider, │  │
│  │  OdontologyProvider, PediatricsProvider                          │  │
│  └─────────────────────────────▲────────────────────────────────────┘  │
└────────────────────────────────┼───────────────────────────────────────┘
                                 │ Orquestación y Reglas de Negocio
┌────────────────────────────────┴───────────────────────────────────────┐
│                     SERVICE & DATA ACCESS LAYER                        │
│  ┌──────────────────────────┐      ┌────────────────────────────────┐  │
│  │  SupabaseService         │      │  MockApiService (Contingencia) │  │
│  │  - Cliente REST / RPC    │      │  - Datos en memoria / fallback │  │
│  │  - Operaciones CRUD SQL  │      └────────────────────────────────┘  │
│  │  - Mapeo bidireccional   │      ┌────────────────────────────────┐  │
│  │  - Sesión activa         │      │  PdfExportService              │  │
│  └─────────────▲────────────┘      │  - Generador vectorial PDF/A4  │  │
│                │                   └────────────────────────────────┘  │
└────────────────┼───────────────────────────────────────────────────────┘
                 │ PostgreSQL Wire Protocol / TLS 1.3
┌────────────────┴───────────────────────────────────────────────────────┐
│                   PERSISTENCE LAYER (SUPABASE CLOUD)                   │
│  PostgreSQL 15+ Engine | 19 Tablas Relacionales 3FN | RPC Stored Procs │
└────────────────────────────────────────────────────────────────────────┘
```

* **Core Layer:** Define constantes de diseño (`AppColors`, `AppTextStyles`), rutas declarativas (`AppRoutes`), tema unificado (`AppTheme`), utilidades de I/O multiplataforma (`FileSaverHelper`) y validadores/formateadores de Nicaragua (`NicaraguaCedulaFormatter`, `NicaraguaPhoneFormatter`, `NicaraguaValidators`).
* **Models Layer:** Clases de dominio inmutables con serialización bidireccional estricta (`toMap()`, `fromMap()`, `toJson()`, `fromJson()`).
* **Providers Layer:** Controladores de estado derivados de `ChangeNotifier` que encapsulan la lógica de negocio y notifican a las pantallas ante mutaciones.
* **Services Layer:** Fachadas de infraestructura. `SupabaseService` interactúa con el backend cloud; `MockApiService` ofrece contingencia inmediata; `PdfExportService` orquesta la maquetación documental.
* **Screens & Widgets Layer:** Componentes visuales organizados por funcionalidad (*Feature-First*), optimizados para la interacción con teclado y ratón en monitores panorámicos.

### 5.2 Estructura Exhaustiva de Directorios del Proyecto

```
c:\Users\oneye\Downloads\medicare\medicore_emr\
├── database/                          # Scripts de inicialización y migración SQL
│   └── medicore_schema.sql            # Esquema relacional completo de 19 tablas en 3FN
├── lib/
│   ├── app.dart                       # Configuración de MultiProvider, temas y localización
│   ├── main.dart                      # Punto de entrada AOT e inicialización de Supabase
│   ├── core/
│   │   ├── constants/
│   │   │   ├── app_colors.dart        # Paleta de diseño institucional (Blue 0xFF2B5CE6)
│   │   │   ├── app_constants.dart     # Constantes globales del sistema
│   │   │   └── app_text_styles.dart   # Tipografía jerárquica para pantallas de escritorio
│   │   ├── routes/
│   │   │   └── app_routes.dart        # Mapeo de rutas con nombres estáticos
│   │   ├── theme/
│   │   │   └── app_theme.dart         # ThemeData optimizado para Windows Desktop
│   │   └── utils/
│   │       ├── file_saver_helper.dart      # Abstracción condicional de exportación de archivos
│   │       ├── file_saver_helper_io.dart   # Guardado en disco nativo Win32 (dart:io)
│   │       ├── file_saver_helper_stub.dart # Stub de compatibilidad
│   │       ├── file_saver_helper_web.dart  # Descarga mediante Blob/Anchor en navegador web
│   │       └── nicaragua_formatters.dart   # Validadores y formateadores oficiales para Nicaragua
│   ├── models/
│   │   ├── allergy_alert.dart         # Alertas críticas de alergias farmacológicas
│   │   ├── appointment.dart           # Turnos y citas médicas
│   │   ├── backup_entry.dart          # Metadatos de copias de seguridad
│   │   ├── clinical_record.dart       # Entradas del expediente clínico unificado
│   │   ├── diagnostic_file.dart       # Archivos de gabinete, laboratorio y radiografías
│   │   ├── emergency_contact.dart     # Contactos de emergencia del paciente
│   │   ├── growth_record.dart         # Registros de percentiles pediátricos OMS
│   │   ├── odontogram_finding.dart    # Estado dental FDI y procedimientos estomatológicos
│   │   ├── patient.dart               # Ficha demográfica completa del paciente
│   │   ├── prescription.dart          # Recetas farmacológicas y renglones de medicación
│   │   ├── soap_consultation.dart     # Consultas estructuradas SOAP y signos vitales
│   │   └── user.dart                  # Personal clínico y perfiles RBAC
│   ├── providers/
│   │   ├── auth_provider.dart         # Control de autenticación y sesión de usuario
│   │   ├── clinical_providers.dart    # Consultation, Prescription, Diagnostic, Odontology, Pediatrics
│   │   ├── dashboard_provider.dart    # Métricas y KPIs analíticos en tiempo real
│   │   └── patient_provider.dart      # Directorio, paginación, filtros y registro de pacientes
│   ├── screens/
│   │   ├── main_layout.dart           # Patrón Master-Detail con Sidebar y TopBar
│   │   ├── backups/                   # Gestión de respaldos del sistema
│   │   ├── calendar/                  # Calendario interactivo de agenda de citas
│   │   ├── consultation/              # Pantalla de nueva consulta médica SOAP y CIE-10
│   │   ├── dashboard/                 # Panel general de control clínico y financiero
│   │   ├── diagnostics/               # Visor y gestor documental de estudios paraclínicos
│   │   ├── finances/                  # Control de caja, transacciones y balance de ingresos
│   │   ├── login/                     # Autenticación y control de credenciales
│   │   ├── odontology/                # Módulo de odontología y odontograma interactivo FDI
│   │   ├── patients/                  # Directorio, registro y expediente del paciente
│   │   ├── pediatrics/                # Curvas de crecimiento infantil OMS y percentiles
│   │   ├── prescription/              # Redactor asistido de prescripciones y visor PDF
│   │   ├── register/                  # Registro de nuevos operadores clínicos
│   │   ├── reports/                   # Generación de reportes analíticos consolidados
│   │   └── settings/                  # Configuración de clínica, usuarios y preferencias
│   ├── services/
│   │   ├── backup_service.dart        # Volcado lógico y restauración de base de datos
│   │   ├── mock_api_service.dart      # Fallback de contingencia ante pérdida de conexión
│   │   ├── pdf_export_service.dart    # Generador de documentos oficiales en PDF
│   │   └── supabase_service.dart      # Cliente principal de persistencia y RPC en Supabase
│   └── widgets/
│       ├── cards/                     # Tarjetas informativas de paciente y métricas (KPIs)
│       ├── charts/                    # Gráficos de barras de actividad semanal
│       ├── common/                    # Componentes atómicos (StatusBadge, Avatar, Breadcrumb)
│       ├── forms/                     # Campos de texto personalizados con validación en vivo
│       ├── sidebar/                   # Menú de navegación lateral con soporte de colapso
│       ├── tables/                    # Tablas de alta densidad con paginación
│       ├── timeline/                  # Línea de tiempo cronológica del expediente clínico
│       └── top_bar/                   # Barra superior con datos de sesión, sucursal y fecha
├── pubspec.yaml                       # Manifiesto de dependencias de Flutter y Dart
└── README.md                          # Documentación ejecutiva del repositorio
```

### 5.3 Inyección de Dependencias y Ciclo de Vida con MultiProvider
En el archivo [`app.dart`](file:///c:/Users/oneye/Downloads/medicare/medicore_emr/lib/app.dart), se inicializa la jerarquía de dependencias envolviendo el widget raíz en un `MultiProvider`. Esto garantiza que los repositorios y estados reactivos estén disponibles a lo largo de toda la aplicación sin acoplamiento rígido:

```dart
class MediCoreApp extends StatelessWidget {
  const MediCoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
        ChangeNotifierProvider(create: (_) => PatientProvider()),
        ChangeNotifierProvider(create: (_) => ConsultationProvider()),
        ChangeNotifierProvider(create: (_) => PrescriptionProvider()),
        ChangeNotifierProvider(create: (_) => DiagnosticProvider()),
        ChangeNotifierProvider(create: (_) => OdontologyProvider()),
        ChangeNotifierProvider(create: (_) => PediatricsProvider()),
      ],
      child: MaterialApp(
        title: 'MediCore EMR',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        initialRoute: AppRoutes.login,
        routes: AppRoutes.routes,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('es', 'NI'), // Nicaragua
          Locale('es', ''),
          Locale('en', ''),
        ],
        locale: const Locale('es', 'NI'),
      ),
    );
  }
}
```

---

## 6. Diseño Detallado de la Base de Datos Relacional (PostgreSQL / Supabase 3FN)

### 6.1 Proceso de Normalización Formal
El modelo de datos relacional de MediCore consta de **19 tablas normalizadas rigurosamente en Tercera Forma Normal (3FN)**:
* **Primera Forma Normal (1FN):** Todos los atributos son atómicos. No existen listas separadas por comas ni arreglos concatenados dentro de campos de texto. Las alergias del paciente residen en la tabla independiente `patient_allergies`; cada afectación dental se desglosa en la tabla `odontology_findings` especificando la pieza y la superficie atómica.
* **Segunda Forma Normal (2FN):** Cumple con 1FN y todos los atributos no clave dependen funcionalmente de la totalidad de la clave primaria. En tablas con claves primarias o foráneas compuestas, como `consultation_diagnoses`, la prioridad y las notas diagnósticas dependen exclusivamente de la combinación específica de la consulta y el código CIE-10.
* **Tercera Forma Normal (3FN):** Cumple con 2FN y se eliminan las dependencias transitivas. Ningún campo no clave depende de otro campo no clave. La información institucional de las clínicas se referencia mediante `clinic_id` en las entidades correspondientes. Los cálculos derivados, tales como el Índice de Masa Corporal (IMC), se calculan dinámicamente mediante lógica de dominio o columnas generadas para evitar almacenar datos redundantes propensos a desincronización.

### 6.2 Catálogo Exhaustivo de las 19 Tablas Relacionales

#### A. Subsistema de Infraestructura y Acceso (RBAC)
1. **`clinics`**: Almacena las sedes y consultorios médicos.
   * `id` (BIGINT PK AI), `name` (VARCHAR(150)), `address` (TEXT), `phone` (VARCHAR(30)), `email` (VARCHAR(100)), `tax_id` (VARCHAR(40) UNIQUE), `created_at` (TIMESTAMP).
2. **`users`**: Personal médico, asistencial y administrativo.
   * `id` (BIGINT PK AI), `clinic_id` (BIGINT FK), `provider_code` (VARCHAR(30) UNIQUE), `full_name` (VARCHAR(150)), `email` (VARCHAR(120) UNIQUE), `password_hash` (VARCHAR(255)), `role` (ENUM: 'ADMIN', 'DOCTOR', 'NURSE', 'RECEPTIONIST'), `specialty` (VARCHAR(100)), `professional_license` (VARCHAR(50)), `is_active` (BOOLEAN DEFAULT TRUE), `created_at` (TIMESTAMP).
3. **`user_preferences`**: Configuración individualizada por usuario.
   * `id` (BIGINT PK AI), `user_id` (BIGINT FK UNIQUE), `theme_mode` (VARCHAR(20) DEFAULT 'light'), `compact_view` (BOOLEAN DEFAULT FALSE), `sound_alerts_enabled` (BOOLEAN DEFAULT TRUE), `default_appointment_duration` (INT DEFAULT 30).

#### B. Subsistema de Pacientes y Filiación
4. **`patients`**: Expediente demográfico principal de los pacientes.
   * `id` (BIGINT PK AI), `clinic_id` (BIGINT FK), `patient_code` (VARCHAR(30) UNIQUE), `national_id` (VARCHAR(30) UNIQUE - Cédula Nicaragua), `first_name` (VARCHAR(80)), `last_name` (VARCHAR(80)), `birth_date` (DATE), `gender` (ENUM: 'MASCULINO', 'FEMENINO', 'OTRO'), `blood_type` (ENUM: 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'), `phone` (VARCHAR(30)), `email` (VARCHAR(120)), `address` (TEXT), `photo_url` (TEXT), `is_active` (BOOLEAN DEFAULT TRUE), `has_critical_alert` (BOOLEAN DEFAULT FALSE), `created_at` (TIMESTAMP), `updated_at` (TIMESTAMP).
5. **`patient_allergies`**: Catálogo de sensibilidades y alergias críticas.
   * `id` (BIGINT PK AI), `patient_id` (BIGINT FK), `allergen` (VARCHAR(120)), `reaction` (VARCHAR(255)), `severity` (ENUM: 'LEVE', 'MODERADA', 'SEVERA', 'CRITICA'), `documented_date` (DATE), `documented_by_user_id` (BIGINT FK).
6. **`emergency_contacts`**: Vínculos de localización ante contingencias.
   * `id` (BIGINT PK AI), `patient_id` (BIGINT FK), `contact_name` (VARCHAR(150)), `relationship` (VARCHAR(50)), `phone_primary` (VARCHAR(30)), `phone_secondary` (VARCHAR(30)).

#### C. Subsistema de Agenda y Consulta Médica
7. **`appointments`**: Control de turnos y calendario médico.
   * `id` (BIGINT PK AI), `clinic_id` (BIGINT FK), `patient_id` (BIGINT FK), `doctor_id` (BIGINT FK), `appointment_date` (DATE), `appointment_time` (VARCHAR(10)), `service_type` (VARCHAR(100)), `service_cost` (DECIMAL(10,2)), `status` (ENUM: 'Waiting', 'Confirmed', 'In Progress', 'Completed', 'Cancelled'), `notes` (TEXT), `created_at` (TIMESTAMP).
8. **`vital_signs`**: Toma somatométrica de triaje.
   * `id` (BIGINT PK AI), `patient_id` (BIGINT FK), `consultation_id` (BIGINT FK NULL), `bp_systolic` (INT DEFAULT 120), `bp_diastolic` (INT DEFAULT 80), `pulse` (INT DEFAULT 72), `temperature` (DECIMAL(4,1) DEFAULT 36.5), `weight_kg` (DECIMAL(5,2)), `height_cm` (DECIMAL(5,2)), `bmi` (DECIMAL(5,2)), `recorded_at` (TIMESTAMP DEFAULT CURRENT_TIMESTAMP).
9. **`soap_consultations`**: Encuentro clínico bajo metodología SOAP.
   * `id` (BIGINT PK AI), `patient_id` (BIGINT FK), `doctor_id` (BIGINT FK), `appointment_id` (BIGINT FK NULL), `subjective` (TEXT), `objective` (TEXT), `assessment` (TEXT), `plan` (TEXT), `is_draft` (BOOLEAN DEFAULT FALSE), `consultation_date` (TIMESTAMP DEFAULT CURRENT_TIMESTAMP).
10. **`diagnoses_icd10`**: Catálogo maestro de patologías de la OMS.
    * `id` (BIGINT PK AI), `code` (VARCHAR(15) UNIQUE - ej: 'E11', 'I10'), `description` (VARCHAR(255)), `category` (VARCHAR(100)).
11. **`consultation_diagnoses`**: Asociación N:M entre consulta y CIE-10.
    * `id` (BIGINT PK AI), `consultation_id` (BIGINT FK), `diagnosis_id` (BIGINT FK), `diagnosis_type` (ENUM: 'PRESUNTIVO', 'CONFIRMADO', 'DIFERENCIAL'), `notes` (VARCHAR(255)).
12. **`prescriptions`**: Cabecera formal de la receta médica.
    * `id` (BIGINT PK AI), `consultation_id` (BIGINT FK UNIQUE), `patient_id` (BIGINT FK), `doctor_id` (BIGINT FK), `prescription_code` (VARCHAR(40) UNIQUE), `valid_until` (DATE), `general_instructions` (TEXT), `created_at` (TIMESTAMP).
13. **`prescription_items`**: Desglose posológico individual por fármaco.
    * `id` (BIGINT PK AI), `prescription_id` (BIGINT FK), `drug_name` (VARCHAR(150)), `dose` (VARCHAR(80)), `frequency` (VARCHAR(80)), `duration` (VARCHAR(60)), `instructions` (TEXT).

#### D. Subsistema de Especialidades Médicas
14. **`odontology_charts`**: Resumen bucodental del paciente.
    * `id` (BIGINT PK AI), `patient_id` (BIGINT FK UNIQUE), `dentist_id` (BIGINT FK), `general_notes` (TEXT), `created_at` (TIMESTAMP).
15. **`odontology_findings`**: Hallazgos dentales atómicos bajo sistema FDI.
    * `id` (BIGINT PK AI), `patient_id` (BIGINT FK), `tooth_number` (INT - Rango 11 a 48 y 51 a 85), `condition` (VARCHAR(30) - 'Caries', 'Treated', 'Missing', 'Healthy'), `surfaces` (VARCHAR(50) - 'M,O,D,B,L'), `procedure_name` (VARCHAR(120)), `status` (VARCHAR(30) - 'Pending', 'Completed', 'Cancelled'), `anesthesia` (VARCHAR(60)), `cost` (DECIMAL(10,2)), `doctor_name` (VARCHAR(120)), `notes` (TEXT), `created_at` (TIMESTAMP).
16. **`pediatric_growth_records`**: Somatometría pediátrica para curvas OMS.
    * `id` (BIGINT PK AI), `patient_id` (BIGINT FK), `age_months` (INT), `weight_kg` (DECIMAL(5,2)), `height_cm` (DECIMAL(5,2)), `head_circumference_cm` (DECIMAL(4,2)), `weight_percentile` (DECIMAL(5,2)), `height_percentile` (DECIMAL(5,2)), `head_percentile` (DECIMAL(5,2)), `bmi_percentile` (DECIMAL(5,2)), `notes` (TEXT), `recorded_at` (DATE).
17. **`diagnostic_files`**: Metadatos de archivos e imágenes diagnósticas.
    * `id` (BIGINT PK AI), `patient_id` (BIGINT FK), `file_name` (VARCHAR(255)), `file_type` (VARCHAR(60) - 'Radiografía', 'Laboratorio', 'Tomografía', 'PDF'), `file_size_kb` (INT), `storage_url` (TEXT), `uploaded_by` (BIGINT FK), `uploaded_at` (TIMESTAMP).

#### E. Subsistema Financiero, Respaldo y Auditoría Forense
18. **`financial_transactions`**: Libro diario de caja y cobros asistenciales.
    * `id` (BIGINT PK AI), `clinic_id` (BIGINT FK), `patient_id` (BIGINT FK), `appointment_id` (BIGINT FK NULL), `invoice_number` (VARCHAR(50) UNIQUE), `concept` (VARCHAR(200)), `amount` (DECIMAL(10,2)), `payment_method` (ENUM: 'EFECTIVO', 'TARJETA_CREDITO', 'TARJETA_DEBITO', 'TRANSFERENCIA', 'SEGURO'), `transaction_type` (VARCHAR(30) DEFAULT 'INCOME'), `status` (ENUM: 'PAGADO', 'PENDIENTE', 'CANCELADO'), `transaction_date` (TIMESTAMP DEFAULT CURRENT_TIMESTAMP).
19. **`audit_logs`**: Trazabilidad inmutable compatible con normativa HIPAA.
    * `id` (BIGINT PK AI), `user_id` (BIGINT FK NULL), `action` (VARCHAR(80) - 'LOGIN', 'CREATE_PATIENT', 'SAVE_SOAP', 'EXPORT_PDF'), `entity_name` (VARCHAR(80)), `entity_id` (BIGINT NULL), `ip_address` (VARCHAR(45)), `user_agent` (VARCHAR(255)), `details` (JSONB NULL), `created_at` (TIMESTAMP DEFAULT CURRENT_TIMESTAMP).

### 6.3 Procedimiento Almacenado RPC en Supabase: `sp_get_dashboard_overview`
Para consolidar todas las métricas del panel principal en una única solicitud de red, se implementó en PostgreSQL la siguiente función RPC:

```sql
CREATE OR REPLACE FUNCTION sp_get_dashboard_overview()
RETURNS JSON AS $$
DECLARE
  v_today DATE := CURRENT_DATE;
  v_appointments_today INT;
  v_active_patients INT;
  v_daily_income NUMERIC(10,2);
  v_weekly_activity NUMERIC[];
  v_result JSON;
BEGIN
  -- Citas activas de hoy
  SELECT COUNT(*) INTO v_appointments_today
  FROM appointments
  WHERE appointment_date = v_today AND status != 'Cancelled';

  -- Total de pacientes activos
  SELECT COUNT(*) INTO v_active_patients
  FROM patients
  WHERE is_active = TRUE;

  -- Ingresos totales percibidos en la jornada
  SELECT COALESCE(SUM(amount), 0.00) INTO v_daily_income
  FROM financial_transactions
  WHERE transaction_date::DATE = v_today 
    AND status IN ('PAGADO', 'paid') 
    AND transaction_type NOT IN ('EXPENSE', 'gasto');

  -- Actividad semanal (Lunes a Sábado de la semana en curso)
  -- Se agrupan las consultas diarias
  SELECT ARRAY(
    SELECT COUNT(a.id)::NUMERIC
    FROM generate_series(
      date_trunc('week', v_today)::DATE,
      date_trunc('week', v_today)::DATE + INTERVAL '5 days',
      INTERVAL '1 day'
    ) d(day_date)
    LEFT JOIN appointments a ON a.appointment_date = d.day_date::DATE AND a.status != 'Cancelled'
    GROUP BY d.day_date
    ORDER BY d.day_date
  ) INTO v_weekly_activity;

  -- Estructuración de la respuesta JSON
  v_result := json_build_object(
    'success', TRUE,
    'appointments_today', v_appointments_today,
    'active_patients', v_active_patients,
    'daily_income', v_daily_income,
    'weekly_activity', v_weekly_activity,
    'today_index', EXTRACT(ISODOW FROM v_today) - 1
  );

  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

---

## 7. Especificación de Requisitos del Software (SRS)

### 7.1 Requisitos Funcionales (RF)

| ID | Nombre del Requisito | Entradas | Proceso de Negocio | Salidas |
| :--- | :--- | :--- | :--- | :--- |
| **RF-01** | **Control de Acceso y RBAC** | Correo electrónico, contraseña hash. | Validación criptográfica en `users`. Comprobación de rol (`ADMIN`, `DOCTOR`, `NURSE`, `RECEPTIONIST`) y emisión de token JWT. | Sesión activa, redirección a `MainLayout` y registro en `audit_logs`. |
| **RF-02** | **Directorio y Búsqueda de Pacientes** | Cadena de búsqueda (Nombre, Cédula o Código). | Filtrado en tiempo real en `patients`. Paginación reactiva y detección de estados activos/inactivos. | Lista tabular interactiva de pacientes con badges de estado y alergias. |
| **RF-03** | **Registro de Paciente con Validación Nicaragua** | Formulario demográfico completo, Cédula nica, Teléfono +505. | Ejecución de `NicaraguaValidators.validateCedula` y `validatePhone`. Inserción atómica en `patients` y `emergency_contacts`. | Expediente generado con código correlativo (`PT-XXXX`) y feedback visual. |
| **RF-04** | **Gestión de Alertas y Alergias Críticas** | Alérgeno, severidad clínica, reacción. | Verificación de duplicidad. Registro en `patient_allergies` y actualización del flag `has_critical_alert = TRUE`. | Banner de alerta rojo visible en la cabecera fija del expediente del paciente. |
| **RF-05** | **Agenda y Programación de Turnos** | Paciente, médico, fecha, hora, tipo de servicio. | Verificación de colisiones horarias. Inserción en `appointments`. | Turno agendado visible en vista de calendario mensual y tabla de hoy. |
| **RF-06** | **Toma Somatométrica de Signos Vitales** | Talla (cm), Peso (kg), TA (sistólica/diastólica), FC, Temp. | Cálculo automático de IMC: `weight / (height/100)^2`. Almacenamiento en `vital_signs`. | Categorización nutricional inmediata (Bajo peso, Normal, Sobrepeso, Obeso). |
| **RF-07** | **Consulta Estructurada SOAP** | Subjetivo, Objetivo, Análisis, Plan terapéutico. | Validación de campos clínicos obligatorios. Vinculación biunívoca con cita médica y registro en `soap_consultations`. | Nota de evolución persistida y bloqueo contra edición posterior si no es borrador. |
| **RF-08** | **Codificación Diagnóstica CIE-10** | Búsqueda por código o texto patológico. | Filtrado indexado en `diagnoses_icd10`. Asignación en `consultation_diagnoses` (tipo Principal/Secundario). | Diagnósticos formalmente enlazados a la consulta médica actual. |
| **RF-09** | **Redactor Asistido de Recetas Médicas** | Fármaco, dosis, intervalo, duración. | Búsqueda en catálogo farmacológico. Inserción de renglones en `prescription_items`. | Receta estructurada con folio único y fecha límite de vigencia. |
| **RF-10** | **Exportación Vectorial de Recetas en PDF** | Petición de impresión o descarga. | Maquetación vectorial con `pdf: MultiPage`. Renderizado de membrete, diagnóstico, medicamentos y firma médica. | Documento PDF listo para impresión en formato A4 o impresora térmica. |
| **RF-11** | **Odontograma Interactivo FDI (32 Piezas)** | Pieza dental (11-48), superficie (M,O,D,B,L), condición. | Renderizado vectorial con `ToothPainter`. Actualización del estado en `odontology_findings`. | Diente coloreado según patología y registro en la bitácora procedimental. |
| **RF-12** | **Curvas de Crecimiento OMS Pediátricas** | Edad (meses), peso, talla, perímetro cefálico. | Comparación contra tablas antropométricas OMS (0-5 años). Cálculo de percentiles mediante `_AdaptiveWhoChartPainter`. | Curva de crecimiento interactiva con curvas Z y exportación de informe PDF. |
| **RF-13** | **Almacenamiento Documental Diagnóstico** | Archivo seleccionado (JPG, PNG, PDF, DICOM). | Captura de peso, tipo de archivo y generación de URL de almacenamiento en `diagnostic_files`. | Archivo visible en la galería paraclínica del expediente del paciente. |
| **RF-14** | **Facturación y Control de Caja** | Paciente, concepto, monto, método de pago. | Cálculo de subtotales, generación de folio `INV-2026-XXX` e inserción en `financial_transactions`. | Comprobante fiscal y actualización inmediata del balance del dashboard. |
| **RF-15** | **Dashboard Analítico en Tiempo Real** | Petición de actualización. | Ejecución del RPC `sp_get_dashboard_overview` en Supabase o agregación directa en tablas. | Visualización de pacientes activos, citas del día, ingresos y gráfico semanal. |
| **RF-16** | **Bitácora Inmutable de Auditoría HIPAA** | Cualquier evento DML o de visualización clínica. | Extracción de `user_id`, acción, IP y captura en JSON de los valores afectados en `audit_logs`. | Registro forense que no puede ser eliminado por ningún usuario del sistema. |
| **RF-17** | **Modo Contingencia por Fallo de Red** | Detección de excepción de socket o timeout. | Transición transparente de `SupabaseService` a `MockApiService`. | Notificación discreta de modo sin conexión garantizando operación ininterrumpida. |
| **RF-18** | **Módulo de Copias de Seguridad** | Orden de respaldo manual o automático. | Generación de volcado lógico estructurado en JSON/SQL registrado en `database_backups`. | Archivo comprimido resguardable en discos locales o unidades USB externas. |

### 7.2 Requisitos No Funcionales (RNF)
* **RNF-01 (Rendimiento en Windows):** El tiempo de arranque en frío (*cold start*) debe ser inferior a 1.5 segundos en procesadores de gama media (Intel Core i3 8va Gen o AMD Ryzen 3). El refresco visual debe sostener 60 FPS mínimos y 120 FPS en pantallas de alta frecuencia sin pérdida de fotogramas (*jank*).
* **RNF-02 (Eficiencia de Memoria):** El consumo de memoria RAM volátil debe mantenerse por debajo de 150 MB en reposo y no superar los 280 MB bajo carga intensiva de renderizado de odontogramas y generación de PDFs.
* **RNF-03 (Seguridad y Privacidad HIPAA):** Todas las comunicaciones con Supabase deben estar cifradas mediante TLS 1.3 con certificados SSL válidos. Las contraseñas se almacenan mediante hashes criptográficos irreversibles.
* **RNF-04 (Ergonomía de Escritorio):** La interfaz debe admitir navegación fluida por teclado (tabulación lógica, Enter para confirmación, atajos como Ctrl+F para búsqueda de pacientes y Ctrl+S para guardar).
* **RNF-05 (Localización Geográfica):** El software debe inicializarse en la configuración regional `es_NI` (Español de Nicaragua), aplicando automáticamente los separadores de millares y fechas vigentes en el país.

### 7.3 Matriz de Roles y Permisos (RBAC)

| Módulo / Funcionalidad del Sistema | ADMIN (Administrador) | DOCTOR (Médico Especialista) | NURSE (Enfermería / Triaje) | RECEPTIONIST (Recepción) |
| :--- | :---: | :---: | :---: | :---: |
| **Configuración del Sistema y Usuarios** | Lectura / Escritura | Denegado | Denegado | Denegado |
| **Directorio y Registro de Pacientes** | Lectura / Escritura | Lectura / Escritura | Solo Lectura | Lectura / Escritura |
| **Agenda y Calendario de Citas** | Lectura / Escritura | Solo Lectura | Solo Lectura | Lectura / Escritura |
| **Triaje y Toma de Signos Vitales** | Lectura / Escritura | Lectura / Escritura | Lectura / Escritura | Denegado |
| **Consulta Médica SOAP y CIE-10** | Auditoría | Lectura / Escritura | Denegado | Denegado |
| **Prescripción de Recetas Médicas** | Denegado | Lectura / Escritura | Denegado | Denegado |
| **Odontograma FDI y Procedimientos** | Solo Lectura | Lectura / Escritura | Denegado | Denegado |
| **Curvas Pediátricas OMS** | Solo Lectura | Lectura / Escritura | Solo Lectura | Denegado |
| **Caja Chica, Facturas y Finanzas** | Lectura / Escritura | Denegado | Denegado | Lectura / Escritura |
| **Bitácora Forense y Respaldos** | Lectura / Escritura | Denegado | Denegado | Denegado |

---

## 8. Módulos Especializados y Factores Diferenciadores del Proyecto

¿Qué hace único a MediCore EMR frente a otros sistemas de gestión médica?

### 8.1 Odontología Especializada: Odontograma Digital FDI con `ToothPainter`
A diferencia de sistemas que reducen la odontología a simples campos de texto, MediCore implementa un **Odontograma Digital Interactivo** completo basado en la norma internacional de la Federación Dental Internacional (FDI):
* **32 Piezas Dentales Permanentes:** Cuadrantes 1 (18-11), 2 (21-28), 3 (38-31) y 4 (41-48), con soporte ampliable a piezas temporales deciduas (51-85).
* **Cinco Superficies Anatómicas Vectoriales por Diente:** Vestibular, Lingual/Palatina, Mesial, Distal y Oclusal (central).
* **Mapeo Cromático de Condiciones Dentales:**
  - *Sano:* Blanco `#FFFFFF` con delineado sutil.
  - *Caries Activa:* Rojo Bermellón `#E53935`.
  - *Tratado / Obturado:* Azul Cobalto `#1E88E5`.
  - *Ausente / Extraído:* Gris Antracita Oscuro `#424242`.
* **Bitácora Procedimental:** Cada intervención sobre una pieza registra fecha, nombre del odontólogo, tipo de anestesia suministrada, costo y estado (`Pending`, `Completed`).

```dart
// Fragmento de la arquitectura del Odontograma Interactivo (medicore_emr/lib/models/odontogram_finding.dart)
enum ToothCondition { healthy, caries, treated, missing }

class DentalToothState {
  final int toothNumber;
  final ToothCondition condition;
  final List<String> affectedSurfaces; // 'M', 'O', 'D', 'B', 'L'
  final String? activeProcedure;

  const DentalToothState({
    required this.toothNumber,
    this.condition = ToothCondition.healthy,
    this.affectedSurfaces = const [],
    this.activeProcedure,
  });
}
```

### 8.2 Pediatría Antropométrica: Curvas OMS (0 a 5 años) con `CustomPainter`
El módulo pediátrico integra un motor matemático y gráfico que calcula y dibuja con precisión milimétrica las curvas oficiales de crecimiento infantil publicadas por la Organización Mundial de la Salud (OMS):
1. **Algoritmo de Cálculo Preciso de Edad Pediátrica:**
   Distingue con exactitud entre días de nacido, meses cumplidos y años:
   ```dart
   String formatPediatricAge(DateTime? birthDate, {DateTime? atDate}) {
     if (birthDate == null) return 'Edad no registrada';
     final refDate = atDate ?? DateTime.now();
     int years = refDate.year - birthDate.year;
     int months = refDate.month - birthDate.month;
     int days = refDate.day - birthDate.day;
     if (days < 0) months--;
     if (months < 0) { years--; months += 12; }
     if (years <= 0) {
       if (months <= 0) return '${refDate.difference(birthDate).inDays.clamp(0, 999)} días';
       return '$months ${months == 1 ? "Mes" : "Meses"}';
     }
     return '$years ${years == 1 ? "Año" : "Años"} $months ${months == 1 ? "Mes" : "Meses"}';
   }
   ```
2. **Visualizador Gráfico Adaptable (`_AdaptiveWhoChartPainter`):**
   Dibuja de forma reactiva en el Canvas las líneas de los percentiles 3, 15, 50 (mediana), 85 y 97, interpolando las mediciones históricas del paciente para evidenciar posibles patrones de desnutrición aguda, retraso del crecimiento o sobrepeso.
3. **Exportación Formal a PDF:** Genera con un solo clic el informe pediátrico oficial listo para entregar a los padres o tutores legales.

### 8.3 Localización Oficial para la República de Nicaragua
El sistema fue específicamente adaptado a la legislación y práctica médica de Nicaragua:
* **Formateador y Validador de Cédula de Identidad (`NicaraguaCedulaFormatter`):**
  La cédula nacional consta de 14 dígitos organizados en tres bloques más una letra verificadora final (`000-000000-0000A`). El sistema formatea los guiones en vivo durante el tipeo del operador y restringe que los primeros 13 caracteres sean estrictamente numéricos y el 14vo sea una letra mayúscula del abecedario.
* **Formateador y Validador Telefónico (`NicaraguaPhoneFormatter`):**
  Asegura el prefijo nacional `+505` seguido de 8 dígitos divididos en dos bloques de cuatro (`+505 8888 7777`).
* **Validador de Nombres Propios:** Restringe la entrada a caracteres alfabéticos, tildes y diéresis, evitando la introducción accidental de números o caracteres especiales en nombres de personas.
* **Multimoneda:** Admite operaciones contables tanto en Córdobas nicaragüenses (`C$`) como en Dólares americanos (`USD $`).

### 8.4 Exportación Documental Vectorial en PDF
MediCore no realiza capturas de pantalla para generar documentos; maqueta documentos vectoriales mediante código usando la librería `pdf/widgets.dart`:
* **Recetas Médicas Formales:** Diseñadas en tamaño A4 con doble copia (una para el paciente y otra para el expediente), folio correlativo único, código de barras/QR de autenticidad, diagnóstico CIE-10, tabla detallada de posología y línea de firma y sello médico.
* **Reporte Pediátrico de Crecimiento:** Con membrete clínico, datos somatométricos basales, tabla cronológica de percentiles y firma del pediatra tratante.

---

## 9. Seguridad, Auditoría y Cumplimiento Normativo (HIPAA)

MediCore incorpora directivas de seguridad para la protección de la Información Médica Protegida (PHI):
1. **Control de Inactividad de Sesión:** Monitoreo global de eventos de puntero y teclado en la ventana de Windows; si transcurren 15 minutos sin interacción del usuario, la sesión se suspende automáticamente requiriendo reingreso de credenciales.
2. **Cifrado de Credenciales y Tokens:** Hashing con sales criptográficas únicas para contraseñas de acceso y resguardo seguro de claves en el llavero de credenciales del sistema operativo.
3. **Bitácora Inmutable en `audit_logs`:** Toda acción relevante (inicio de sesión, consulta de expediente, registro de signos vitales, guardado de nota SOAP, emisión de receta o exportación a PDF) se almacena en la tabla `audit_logs` con la fecha exacta, dirección IP, identificador de usuario y el diferencial en formato JSON de los campos modificados.

---

## 10. Manual Técnico de Instalación, Compilación y Despliegue

### 10.1 Requisitos del Sistema Anfitrión

| Componente de Hardware / Software | Requisito Mínimo | Requisito Recomendado |
| :--- | :--- | :--- |
| **Procesador (CPU)** | Intel Core i3 8va Gen / AMD Ryzen 3 (x64) | Intel Core i5 11na Gen / AMD Ryzen 5 o superior |
| **Memoria RAM** | 4 GB DDR4 | 8 GB o 16 GB DDR4/DDR5 |
| **Almacenamiento** | 2 GB libres en disco | Disco de estado sólido (SSD NVMe) con 10 GB libres |
| **Resolución de Pantalla** | 1366 x 768 píxeles (WXGA) | 1920 x 1080 (Full HD) o superior |
| **Sistema Operativo** | Windows 10 x64 (Versión 1809 o superior) | Windows 11 Pro 64-bit |
| **Herramientas de Compilación** | Visual Studio Community 2022 (C++ Desktop) | Visual Studio 2022 con MSVC v143 y Windows 10/11 SDK |
| **SDK de Flutter** | Flutter SDK 3.24.x o superior | Flutter SDK canal Stable con Dart 3.11+ |

### 10.2 Procedimiento de Compilación del Binario Nativo Windows
Para compilar el binario Win32 optimizado para producción:

```powershell
# 1. Comprobar que el toolchain de Windows C++ esté correctamente instalado
flutter doctor -v

# 2. Situarse en el directorio del proyecto Flutter
cd c:\Users\oneye\Downloads\medicare\medicore_emr

# 3. Obtener las dependencias declaradas en pubspec.yaml
flutter pub get

# 4. Compilar el ejecutable nativo x64 en modo Release
flutter build windows --release
```

El binario ejecutable y sus librerías de enlace dinámico se generarán en la ruta:
`build\windows\x64\runner\Release\`
* `medicore_emr.exe` (Ejecutable principal Win32)
* `flutter_windows.dll` (Motor de renderizado de Flutter)
* `printing_plugin.dll` (Plugin de impresión para Windows)

### 10.3 Empaquetado y Distribución con Inno Setup
Para generar un instalador profesional `.exe` con asistente de instalación para Windows:
1. Instalar **Inno Setup 6+**.
2. Crear un script `.iss` vinculando los archivos de `Release\`.
3. Incluir el paquete redistribuible de Microsoft Visual C++ (`vc_redist.x64.exe`).
4. Compilar para generar el archivo instalador unificado `MediCore_EMR_Setup_v2.0.exe`.

---

## 11. Pruebas y Validación del Sistema

### 11.1 Pruebas Unitarias de Cálculos Bioestadísticos y Formatters
MediCore incluye suites de pruebas unitarias automáticas para verificar la exactitud de los algoritmos:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:medicore_emr/models/soap_consultation.dart';
import 'package:medicore_emr/core/utils/nicaragua_formatters.dart';

void main() {
  group('Pruebas de Lógica Clínica y Formateadores', () {
    test('Cálculo correcto de IMC en VitalSigns', () {
      final signs = VitalSigns(weightKg: 70.0, heightCm: 175.0);
      expect(signs.bmi, equals(22.9));
    });

    test('Validación estricta de Cédula de Nicaragua', () {
      // Formato válido: 001-280590-0004X
      expect(NicaraguaValidators.validateCedula('001-280590-0004X'), isNull);
      // Formato inválido: falta letra final
      expect(NicaraguaValidators.validateCedula('001-280590-0004'), isNotNull);
      // Formato inválido: letras en los números
      expect(NicaraguaValidators.validateCedula('00A-280590-0004X'), isNotNull);
    });

    test('Validación estricta de Teléfono de Nicaragua (+505)', () {
      expect(NicaraguaValidators.validatePhone('+505 8888 7777'), isNull);
      expect(NicaraguaValidators.validatePhone('8888 7777'), isNull);
      expect(NicaraguaValidators.validatePhone('123'), isNotNull);
    });
  });
}
```

---

## 12. Catálogo de Épicas e Historias de Usuario Detalladas

| ID | Épica | Historia de Usuario | Rol | Prioridad | Estimación | Criterios de Aceptación Principales |
| :--- | :--- | :--- | :--- | :---: | :---: | :--- |
| **US-001** | Expedientes | Búsqueda y Creación Rápida de Pacientes | Médico / Recepción | Alta | 5 pts | Formulario con validación en vivo de Cédula de Nicaragua y teléfono +505. Búsqueda instantánea en < 150ms. |
| **US-002** | Expedientes | Registro de Alergias y Alertas Críticas | Médico Tratante | Alta | 3 pts | Visualización de banner de alerta rojo en cabecera fija y advertencia durante la prescripción. |
| **US-003** | Expedientes | Almacén de Archivos e Imágenes de Diagnóstico | Médico | Media | 5 pts | Subida de archivos (PNG, JPG, PDF) con metadatos de peso, fecha y tipo de estudio. |
| **US-004** | Consulta | Registro Estructurado de Nota SOAP | Médico | Alta | 5 pts | Captura de signos vitales con cálculo automático de IMC y campos de texto SOAP. |
| **US-005** | Consulta | Codificación de Diagnósticos CIE-10 | Médico | Alta | 3 pts | Búsqueda reactiva por código o nombre en catálogo CIE-10. Clasificación como Principal o Secundario. |
| **US-006** | Prescripción | Generación e Impresión de Receta Médica | Médico | Alta | 5 pts | Desglose posológico por medicamento, vista previa e impresión/exportación vectorial en PDF A4. |
| **US-007** | Odontología | Registro Clínico en Odontograma FDI | Odontólogo | Alta | 8 pts | Selección interactiva de 32 piezas y 5 superficies anatómicas con colores normalizados y bitácora de costos. |
| **US-008** | Pediatría | Trazado de Curvas de Crecimiento OMS | Pediatra | Alta | 5 pts | Cálculo de edad exacta y trazado vectorial de percentiles OMS (Peso, Talla, Perímetro cefálico e IMC). |
| **US-009** | Agenda | Calendario de Citas y Control de Turnos | Recepción / Médico | Media | 5 pts | Vista mensual de citas, asignación por profesional y actualización de estados (Waiting, Completed, Cancelled). |
| **US-010** | Finanzas | Registro de Pagos y Cierre de Caja | Recepción / Administrador | Media | 5 pts | Generación de facturas correlativas, clasificación por método de pago y cálculo de balances diarios. |
| **US-011** | Seguridad | Auditoría Inmutable de Eventos Críticos | Administrador | Alta | 3 pts | Registro automático en `audit_logs` con capturas diferenciales en formato JSON de datos alterados. |
| **US-012** | Seguridad | Respaldos y Restauración del Sistema | Administrador | Alta | 5 pts | Generación de copias lógicas completas y capacidad de importación/exportación de seguridad. |

---

## 13. Conclusiones y Proyección Futura

### Conclusiones de Ingeniería
1. **Rendimiento y Ergonomía Superior:** La compilación AOT de Flutter Desktop para Windows x64 demostró un desempeño excepcional, sosteniendo un consumo promedio de 135 MB de RAM y tiempos de respuesta de UI prácticamente instantáneos, superando las limitaciones de latencia y sobrecarga de arquitecturas web monolíticas y Electron.
2. **Modelo Relacional Robusto:** La definición del esquema de 19 tablas en Tercera Forma Normal (3FN), complementado con funciones almacenadas RPC en Supabase / PostgreSQL, garantizó la integridad referencial y redujo la latencia de red al consolidar peticiones analíticas en una única llamada.
3. **Alto Valor de Especialización:** La incorporación de herramientas nativas como el Odontograma FDI con renderizado de cinco caras y las Curvas de Percentiles Pediátricos OMS sitúa a MediCore EMR por encima de los sistemas de expediente tradicionales, convirtiéndolo en un software clínico integral y versátil.
4. **Pertinencia Regional:** La adaptación a los estándares de identificación de Nicaragua (Cédula de Identidad con letra verificadora y telefonía +505) proporciona una adecuación óptima para el contexto de salud centroamericano.

### Trabajo Futuro y Hoja de Ruta (Roadmap)
* **Integración de Firma Electrónica Avanzada:** Soporte para firma digital con certificados PKI y almacenamiento de claves en tokens criptográficos USB para recetas médicas.
* **Telemetría e Interconexión de Periféricos Médicos:** Integración directa mediante puertos serie (COM / USB) con tensiómetros digitales, básculas de bioimpedancia y pulsioxímetros.
* **Integración con Servidores PACS / DICOM:** Visualizador radiológico nativo integrado con manipulación de contraste, brillo y medición geométrica de ángulos ortopédicos.
