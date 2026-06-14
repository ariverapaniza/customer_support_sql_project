/* ============================================================
   PROYECTO SQL - ANALISIS DE TICKETS DE SOPORTE
   Archivo: 01_schema.sql
   Autor: Arturo Rivera Paniza
   ============================================================ */


-- ------------------------------------------------------------
-- 1. CREACION LIMPIA DE LA BASE DE DATOS
-- ------------------------------------------------------------

DROP DATABASE IF EXISTS analitica_soporte_clientes;

CREATE DATABASE IF NOT EXISTS analitica_soporte_clientes
CHARACTER SET utf8mb4
COLLATE utf8mb4_spanish_ci;

USE analitica_soporte_clientes;


-- ------------------------------------------------------------
-- 2. TABLA DE ORIGEN / STAGING
-- ------------------------------------------------------------
/*
   Esta tabla representa la capa de carga inicial.
*/

CREATE TABLE IF NOT EXISTS origen_tickets_soporte (
    id_registro_origen INT AUTO_INCREMENT PRIMARY KEY,

    id_ticket_origen VARCHAR(50),
    nombre_cliente VARCHAR(255),
    correo_cliente VARCHAR(255),
    edad_cliente VARCHAR(20),
    genero_cliente VARCHAR(50),

    producto_comprado VARCHAR(255),
    fecha_compra_texto VARCHAR(50),

    tipo_ticket VARCHAR(100),
    asunto_ticket VARCHAR(150),
    descripcion_ticket TEXT,

    estado_ticket VARCHAR(100),
    resolucion_ticket TEXT,

    prioridad_ticket VARCHAR(50),
    canal_ticket VARCHAR(50),

    fecha_primera_respuesta_texto VARCHAR(50),
    fecha_resolucion_texto VARCHAR(50),

    calificacion_satisfaccion_texto VARCHAR(20),

    fecha_carga TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);


-- ------------------------------------------------------------
-- 3. DIMENSION CLIENTE
-- ------------------------------------------------------------
/*
   Tabla: dim_cliente
*/

CREATE TABLE IF NOT EXISTS dim_cliente (
    id_cliente INT AUTO_INCREMENT PRIMARY KEY,
    nombre_cliente VARCHAR(255) NOT NULL,
    correo_cliente VARCHAR(255) NOT NULL,
    edad_cliente TINYINT NOT NULL,
    genero_cliente VARCHAR(50) NOT NULL,

    fecha_creacion TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_dim_cliente_correo UNIQUE (correo_cliente),
    CONSTRAINT chk_dim_cliente_edad CHECK (edad_cliente BETWEEN 18 AND 100),
    CONSTRAINT chk_dim_cliente_genero CHECK (genero_cliente IN ('Male', 'Female', 'Other'))
);


-- ------------------------------------------------------------
-- 4. DIMENSION PRODUCTO
-- ------------------------------------------------------------
/*
   Tabla: dim_producto
*/

CREATE TABLE IF NOT EXISTS dim_producto (
    id_producto INT AUTO_INCREMENT PRIMARY KEY,
    nombre_producto VARCHAR(255) NOT NULL,

    CONSTRAINT uq_dim_producto_nombre UNIQUE (nombre_producto)
);


-- ------------------------------------------------------------
-- 5. DIMENSION TIPO DE TICKET
-- ------------------------------------------------------------
/*
   Tabla: dim_tipo_ticket
*/

CREATE TABLE IF NOT EXISTS dim_tipo_ticket (
    id_tipo_ticket INT AUTO_INCREMENT PRIMARY KEY,
    nombre_tipo_ticket VARCHAR(100) NOT NULL,

    CONSTRAINT uq_dim_tipo_ticket_nombre UNIQUE (nombre_tipo_ticket)
);


-- ------------------------------------------------------------
-- 6. DIMENSION ASUNTO DE TICKET
-- ------------------------------------------------------------
/*
   Tabla: dim_asunto_ticket
*/

CREATE TABLE IF NOT EXISTS dim_asunto_ticket (
    id_asunto_ticket INT AUTO_INCREMENT PRIMARY KEY,
    nombre_asunto_ticket VARCHAR(150) NOT NULL,

    CONSTRAINT uq_dim_asunto_ticket_nombre UNIQUE (nombre_asunto_ticket)
);


-- ------------------------------------------------------------
-- 7. DIMENSION ESTADO
-- ------------------------------------------------------------
/*
   Tabla: dim_estado
*/

CREATE TABLE IF NOT EXISTS dim_estado (
    id_estado INT AUTO_INCREMENT PRIMARY KEY,
    nombre_estado VARCHAR(100) NOT NULL,
    es_estado_final BOOLEAN NOT NULL DEFAULT FALSE,

    CONSTRAINT uq_dim_estado_nombre UNIQUE (nombre_estado),
    CONSTRAINT chk_dim_estado_final CHECK (es_estado_final IN (0, 1))
);


-- ------------------------------------------------------------
-- 8. DIMENSION PRIORIDAD
-- ------------------------------------------------------------
/*
   Tabla: dim_prioridad
   nivel_prioridad:
   Permite ordenar prioridades de forma lógica:
   1 = Low
   2 = Medium
   3 = High
   4 = Critical
*/

CREATE TABLE IF NOT EXISTS dim_prioridad (
    id_prioridad INT AUTO_INCREMENT PRIMARY KEY,
    nombre_prioridad VARCHAR(50) NOT NULL,
    nivel_prioridad TINYINT NOT NULL,

    CONSTRAINT uq_dim_prioridad_nombre UNIQUE (nombre_prioridad),
    CONSTRAINT uq_dim_prioridad_nivel UNIQUE (nivel_prioridad),
    CONSTRAINT chk_dim_prioridad_nivel CHECK (nivel_prioridad BETWEEN 1 AND 4)
);


-- ------------------------------------------------------------
-- 9. DIMENSION CANAL
-- ------------------------------------------------------------
/*
   Tabla: dim_canal

   Ejemplos: Email, Phone, Chat, Social media.
*/

CREATE TABLE IF NOT EXISTS dim_canal (
    id_canal INT AUTO_INCREMENT PRIMARY KEY,
    nombre_canal VARCHAR(50) NOT NULL,

    CONSTRAINT uq_dim_canal_nombre UNIQUE (nombre_canal)
);


-- ------------------------------------------------------------
-- 10. DIMENSION FECHA
-- ------------------------------------------------------------
/*
   Tabla: dim_fecha
*/

CREATE TABLE IF NOT EXISTS dim_fecha (
    id_fecha DATE PRIMARY KEY,
    anio SMALLINT NOT NULL,
    trimestre TINYINT NOT NULL,
    mes TINYINT NOT NULL,
    nombre_mes VARCHAR(20) NOT NULL,
    dia_mes TINYINT NOT NULL,
    dia_semana TINYINT NOT NULL,
    nombre_dia_semana VARCHAR(20) NOT NULL,

    CONSTRAINT chk_dim_fecha_trimestre CHECK (trimestre BETWEEN 1 AND 4),
    CONSTRAINT chk_dim_fecha_mes CHECK (mes BETWEEN 1 AND 12),
    CONSTRAINT chk_dim_fecha_dia_mes CHECK (dia_mes BETWEEN 1 AND 31),
    CONSTRAINT chk_dim_fecha_dia_semana CHECK (dia_semana BETWEEN 1 AND 7)
);


-- ------------------------------------------------------------
-- 11. TABLA PRINCIPAL DE HECHOS
-- ------------------------------------------------------------
/*
   Tabla: hecho_tickets

   id_ticket viene del dataset original y representa el identificador
   único del ticket.
*/

CREATE TABLE IF NOT EXISTS hecho_tickets (
    id_ticket INT PRIMARY KEY,

    id_cliente INT NOT NULL,
    id_producto INT NOT NULL,
    id_tipo_ticket INT NOT NULL,
    id_asunto_ticket INT NOT NULL,
    id_estado INT NOT NULL,
    id_prioridad INT NOT NULL,
    id_canal INT NOT NULL,

    id_fecha_compra DATE NOT NULL,

    fecha_compra DATE NOT NULL,
    fecha_primera_respuesta DATETIME NULL,
    fecha_resolucion DATETIME NULL,

    descripcion_ticket TEXT NOT NULL,
    resolucion_ticket TEXT NULL,

    calificacion_satisfaccion DECIMAL(3,2) NULL,

    fecha_creacion_registro TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_hecho_cliente
        FOREIGN KEY (id_cliente) REFERENCES dim_cliente(id_cliente),

    CONSTRAINT fk_hecho_producto
        FOREIGN KEY (id_producto) REFERENCES dim_producto(id_producto),

    CONSTRAINT fk_hecho_tipo_ticket
        FOREIGN KEY (id_tipo_ticket) REFERENCES dim_tipo_ticket(id_tipo_ticket),

    CONSTRAINT fk_hecho_asunto_ticket
        FOREIGN KEY (id_asunto_ticket) REFERENCES dim_asunto_ticket(id_asunto_ticket),

    CONSTRAINT fk_hecho_estado
        FOREIGN KEY (id_estado) REFERENCES dim_estado(id_estado),

    CONSTRAINT fk_hecho_prioridad
        FOREIGN KEY (id_prioridad) REFERENCES dim_prioridad(id_prioridad),

    CONSTRAINT fk_hecho_canal
        FOREIGN KEY (id_canal) REFERENCES dim_canal(id_canal),

    CONSTRAINT fk_hecho_fecha_compra
        FOREIGN KEY (id_fecha_compra) REFERENCES dim_fecha(id_fecha),

    CONSTRAINT chk_hecho_calificacion
        CHECK (
            calificacion_satisfaccion IS NULL
            OR calificacion_satisfaccion BETWEEN 1 AND 5
        )
);


-- ------------------------------------------------------------
-- 12. INDICES
-- ------------------------------------------------------------
/*
   Los índices ayudan a mejorar el rendimiento de consultas analíticas.

   idx_hecho_estado_prioridad:
   Útil para consultas de backlog, por ejemplo tickets abiertos por prioridad.

   idx_hecho_producto:
   Útil para analizar volumen de tickets por producto.

   idx_hecho_canal:
   Útil para analizar tickets y satisfacción por canal.

   idx_hecho_fecha_compra:
   Útil para análisis temporal.
*/

CREATE INDEX idx_hecho_estado_prioridad
ON hecho_tickets (id_estado, id_prioridad);

CREATE INDEX idx_hecho_producto
ON hecho_tickets (id_producto);

CREATE INDEX idx_hecho_canal
ON hecho_tickets (id_canal);

CREATE INDEX idx_hecho_fecha_compra
ON hecho_tickets (id_fecha_compra);


-- ------------------------------------------------------------
-- 13. VISTA DE DETALLE DE TICKETS
-- ------------------------------------------------------------
/*
   Vista: vista_detalle_tickets
*/

CREATE OR REPLACE VIEW vista_detalle_tickets AS
SELECT
    ht.id_ticket,

    dc.nombre_cliente,
    dc.correo_cliente,
    dc.edad_cliente,
    dc.genero_cliente,

    dp.nombre_producto,

    dtt.nombre_tipo_ticket,
    dat.nombre_asunto_ticket,
    de.nombre_estado,
    de.es_estado_final,
    dpr.nombre_prioridad,
    dpr.nivel_prioridad,
    dca.nombre_canal,

    ht.fecha_compra,
    ht.fecha_primera_respuesta,
    ht.fecha_resolucion,

    ht.descripcion_ticket,
    ht.resolucion_ticket,
    ht.calificacion_satisfaccion
FROM hecho_tickets ht
INNER JOIN dim_cliente dc
    ON ht.id_cliente = dc.id_cliente
INNER JOIN dim_producto dp
    ON ht.id_producto = dp.id_producto
INNER JOIN dim_tipo_ticket dtt
    ON ht.id_tipo_ticket = dtt.id_tipo_ticket
INNER JOIN dim_asunto_ticket dat
    ON ht.id_asunto_ticket = dat.id_asunto_ticket
INNER JOIN dim_estado de
    ON ht.id_estado = de.id_estado
INNER JOIN dim_prioridad dpr
    ON ht.id_prioridad = dpr.id_prioridad
INNER JOIN dim_canal dca
    ON ht.id_canal = dca.id_canal;


-- ------------------------------------------------------------
-- 14. VISTA DE KPIS GENERALES
-- ------------------------------------------------------------
/*
   Vista: vista_kpis_soporte

   Métricas:
   - Total de tickets
   - Tickets cerrados
   - Tickets abiertos o pendientes
   - Promedio de satisfacción
   - Porcentaje de tickets cerrados
*/

CREATE OR REPLACE VIEW vista_kpis_soporte AS
SELECT
    COUNT(*) AS total_tickets,

    SUM(CASE WHEN nombre_estado = 'Closed' THEN 1 ELSE 0 END) AS tickets_cerrados,

    SUM(CASE WHEN nombre_estado <> 'Closed' THEN 1 ELSE 0 END) AS tickets_no_cerrados,

    ROUND(AVG(calificacion_satisfaccion), 2) AS promedio_satisfaccion,

    ROUND(
        SUM(CASE WHEN nombre_estado = 'Closed' THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0),
        2
    ) AS porcentaje_tickets_cerrados
FROM vista_detalle_tickets;


-- ------------------------------------------------------------
-- 15. FUNCION DE NEGOCIO PARA SLA
-- ------------------------------------------------------------
/*
   Funcion: fn_sla_prioridad_horas

   Regla de negocio propuesta:
   - Critical: 4 horas
   - High: 8 horas
   - Medium: 24 horas
   - Low: 48 horas

   Esta función se usará luego en el EDA para comparar tiempos de
   resolución contra una regla de negocio tipo SLA.
*/

DROP FUNCTION IF EXISTS fn_sla_prioridad_horas;

DELIMITER $$

CREATE FUNCTION fn_sla_prioridad_horas(p_prioridad VARCHAR(50))
RETURNS INT
DETERMINISTIC
NO SQL
BEGIN
    RETURN CASE
        WHEN p_prioridad = 'Critical' THEN 4
        WHEN p_prioridad = 'High' THEN 8
        WHEN p_prioridad = 'Medium' THEN 24
        WHEN p_prioridad = 'Low' THEN 48
        ELSE 24
    END;
END$$

DELIMITER ;


-- ------------------------------------------------------------
-- 16. CONSULTAS RAPIDAS DE VERIFICACION DEL ESQUEMA
-- ------------------------------------------------------------
/*
   Estas consultas permiten confirmar que las tablas, vistas y función
   fueron creadas correctamente.
*/

SHOW TABLES;

SELECT
    fn_sla_prioridad_horas('Critical') AS sla_critical_horas,
    fn_sla_prioridad_horas('High') AS sla_high_horas,
    fn_sla_prioridad_horas('Medium') AS sla_medium_horas,
    fn_sla_prioridad_horas('Low') AS sla_low_horas;