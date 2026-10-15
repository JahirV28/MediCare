# MediCare - Sistema Integral de Expediente Médico Electrónico (EMR / EHR)

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Supabase](https://img.shields.io/badge/Backend-Supabase-3ECF8E?logo=supabase&logoColor=white)](https://supabase.com)
[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Web%20%7C%20macOS-blue)](https://flutter.dev/multi-platform)

MediCare es una solución integral y moderna de Registro Médico Electrónico (EMR) desarrollada en **Flutter** con arquitectura desacoplada y persistencia en **Supabase (PostgreSQL)**, pensada para consultorios, clínicas especializadas y centros odontológicos.

---

## 🌟 Características Principales

### 📋 Gestión de Pacientes y Directorio Clínico
- Registro con validación de documentos de identidad, formato telefónico y contactos de emergencia.
- Directorio de pacientes con búsqueda rápida por código de expediente, nombre o cédula.
- Identificación inmediata de alertas clínicas (alergias graves, condiciones crónicas, tipo de sangre).

### 🦷 Módulo de Odontología y Odontograma Interactivo
- Odontograma digital interactivo para las 32 piezas dentales permanentes según la nomenclatura universal (FDI).
- Control de condiciones por diente y caras dentales (Caries, Tratado/Obturado, Ausente, Sano).
- Registro clínico de procedimientos dentales asociados a cada pieza, costos y tipo de anestesia.
- Historial y bitácora de intervenciones odontológicas por paciente.

### 🩺 Consultas SOAP y Prescripción Médica
- Estructuración de consultas mediante el formato estándar SOAP (Subjetivo, Objetivo, Análisis, Plan).
- Generador de recetas médicas con cálculo automático de dosis e instrucciones farmacológicas.
- Exportación formal de recetas y reportes médicos a formato **PDF**.

### 📅 Agenda y Calendario Médico
- Vista de calendario interactivo para citas programadas por día, semana y mes.
- Control de estados: *En Espera*, *Confirmado*, *Atendido*, *En Progreso* y *Cancelado*.
- Autocompletado reactivo de pacientes existentes al crear nuevas citas.

### 📊 Dashboard Analítico y Finanzas
- Métricas en tiempo real: citas del día, pacientes activos, ingresos diarios y tendencia semanal.
- Gestión de transacciones financieras y cobros vinculados a consultas médicas y odontológicas.

### 💾 Sistema de Copias de Seguridad y Respaldo
- Descarga y exportación integral de datos clínicos y esquemas en formatos **JSON** y **SQL** (.sql).
- Soporte multiplataforma con descarga automática en Web y selector nativo de guardado en Windows/Escritorio.
- Auditoría histórica de copias de seguridad realizadas.

---

## 🛠️ Tecnologías y Arquitectura

- **Frontend / Framework**: Flutter 3 (Desktop Windows & Web).
- **Lenguaje**: Dart.
- **Backend as a Service**: Supabase (PostgreSQL, Procedimientos Almacenados / RPC, RLS).
- **Gestión de Estado**: `provider` (arquitectura orientada a servicios y repositorios).
- **Generación de Documentos**: `pdf` y `printing`.
- **Estructura de Base de Datos**: Scripts DDL y esquemas documentados en `medicore_emr/database/`.

---

## 🚀 Puesta en Marcha Local

### Prerrequisitos
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (versión 3.19 o superior).
- Visual Studio / Build Tools para soporte de escritorio Windows (o navegador Chrome/Edge para Web).

### Instalación

1. Clonar el repositorio:
   ```bash
   git clone https://github.com/JahirV28/MediCare.git
   cd MediCare/medicore_emr
   ```

2. Instalar las dependencias de Flutter:
   ```bash
   flutter pub get
   ```

3. Ejecutar la aplicación:
   - **En Windows**:
     ```bash
     flutter run -d windows
     ```
   - **En Web (Navegador)**:
     ```bash
     flutter run -d chrome
     ```

---

## 📂 Estructura del Proyecto

```text
MediCare/
├── medicore_emr/
│   ├── database/                    # Scripts SQL, esquemas y procedimientos almacenados
│   │   ├── supabase_schema.sql
│   │   ├── stored_procedures.sql
│   │   └── medicore_backup_schema.sql
│   ├── lib/
│   │   ├── core/                    # Constantes, temas, formateadores y utilidades
│   │   ├── models/                  # Modelos de datos (Patient, Appointment, Odontogram, etc.)
│   │   ├── providers/               # Controladores de estado (Auth, Clinical, Dashboard, Patient)
│   │   ├── screens/                 # Pantallas por módulo (Login, Odontology, Patients, etc.)
│   │   ├── services/                # Conexión Supabase, servicio de respaldo y generador PDF
│   │   └── widgets/                 # Componentes reutilizables de UI
│   └── pubspec.yaml                 # Dependencias del proyecto
└── README.md
```

---

## 📄 Licencia

Este proyecto es privado y propiedad de su autor. Todos los derechos reservados.
