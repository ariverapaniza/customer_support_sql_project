/* ============================================================
   PROYECTO SQL - ANALISIS DE TICKETS DE SOPORTE
   Archivo: 03_validation.sql
   Autor: Arturo Rivera Paniza
   ============================================================ */

USE analitica_soporte_clientes;


-- ------------------------------------------------------------
-- 1. TABLA AUXILIAR PARA DOCUMENTAR RESULTADOS DE VALIDACION
-- ------------------------------------------------------------
/*
   Esta tabla guarda un resumen de cada prueba de calidad y sirve para dejar evidencia ejecutable de las validaciones realizadas.
*/

CREATE TABLE IF NOT EXISTS resumen_validacion_calidad (
    id_validacion INT AUTO_INCREMENT PRIMARY KEY,
    nombre_validacion VARCHAR(150) NOT NULL,
    total_casos_detectados INT NOT NULL,
    resultado VARCHAR(30) NOT NULL,
    detalle TEXT NULL,
    fecha_ejecucion TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

TRUNCATE TABLE resumen_validacion_calidad;


-- ------------------------------------------------------------
-- 2. CONTEOS GENERALES DE TABLAS PRINCIPALES
-- ------------------------------------------------------------
/*
   Validacion inicial:
   Confirmar que la tabla de origen y la tabla de hechos tienen la misma cantidad de tickets cargados.
*/

SELECT 'origen_tickets_soporte' AS tabla, COUNT(*) AS total_registros
FROM origen_tickets_soporte
UNION ALL
SELECT 'hecho_tickets' AS tabla, COUNT(*) AS total_registros
FROM hecho_tickets
UNION ALL
SELECT 'dim_cliente' AS tabla, COUNT(*) AS total_registros
FROM dim_cliente
UNION ALL
SELECT 'dim_producto' AS tabla, COUNT(*) AS total_registros
FROM dim_producto
UNION ALL
SELECT 'dim_tipo_ticket' AS tabla, COUNT(*) AS total_registros
FROM dim_tipo_ticket
UNION ALL
SELECT 'dim_asunto_ticket' AS tabla, COUNT(*) AS total_registros
FROM dim_asunto_ticket
UNION ALL
SELECT 'dim_estado' AS tabla, COUNT(*) AS total_registros
FROM dim_estado
UNION ALL
SELECT 'dim_prioridad' AS tabla, COUNT(*) AS total_registros
FROM dim_prioridad
UNION ALL
SELECT 'dim_canal' AS tabla, COUNT(*) AS total_registros
FROM dim_canal
UNION ALL
SELECT 'dim_fecha' AS tabla, COUNT(*) AS total_registros
FROM dim_fecha;

INSERT INTO resumen_validacion_calidad (nombre_validacion, total_casos_detectados, resultado, detalle)
SELECT
    'Comparacion de registros entre origen y tabla de hechos' AS nombre_validacion,
    ABS((SELECT COUNT(*) FROM origen_tickets_soporte) - (SELECT COUNT(*) FROM hecho_tickets)) AS total_casos_detectados,
    CASE
        WHEN (SELECT COUNT(*) FROM origen_tickets_soporte) = (SELECT COUNT(*) FROM hecho_tickets)
        THEN 'OK'
        ELSE 'REVISAR'
    END AS resultado,
    'La cantidad de tickets en origen debe coincidir con la cantidad de tickets en hecho_tickets.' AS detalle;


-- ------------------------------------------------------------
-- 3. VALIDACION DE NULOS EN CAMPOS CRITICOS DEL ORIGEN
-- ------------------------------------------------------------
/*
   En la tabla de origen algunos campos son obligatorios para poder construir correctamente el modelo dimensional.
*/

SELECT
    SUM(CASE WHEN id_ticket_origen IS NULL OR TRIM(id_ticket_origen) = '' THEN 1 ELSE 0 END) AS nulos_id_ticket,
    SUM(CASE WHEN nombre_cliente IS NULL OR TRIM(nombre_cliente) = '' THEN 1 ELSE 0 END) AS nulos_nombre_cliente,
    SUM(CASE WHEN correo_cliente IS NULL OR TRIM(correo_cliente) = '' THEN 1 ELSE 0 END) AS nulos_correo_cliente,
    SUM(CASE WHEN producto_comprado IS NULL OR TRIM(producto_comprado) = '' THEN 1 ELSE 0 END) AS nulos_producto,
    SUM(CASE WHEN fecha_compra_texto IS NULL OR TRIM(fecha_compra_texto) = '' THEN 1 ELSE 0 END) AS nulos_fecha_compra,
    SUM(CASE WHEN estado_ticket IS NULL OR TRIM(estado_ticket) = '' THEN 1 ELSE 0 END) AS nulos_estado,
    SUM(CASE WHEN prioridad_ticket IS NULL OR TRIM(prioridad_ticket) = '' THEN 1 ELSE 0 END) AS nulos_prioridad,
    SUM(CASE WHEN canal_ticket IS NULL OR TRIM(canal_ticket) = '' THEN 1 ELSE 0 END) AS nulos_canal
FROM origen_tickets_soporte;

INSERT INTO resumen_validacion_calidad (nombre_validacion, total_casos_detectados, resultado, detalle)
SELECT
    'Nulos en campos criticos del origen' AS nombre_validacion,
    (
        SUM(CASE WHEN id_ticket_origen IS NULL OR TRIM(id_ticket_origen) = '' THEN 1 ELSE 0 END) +
        SUM(CASE WHEN nombre_cliente IS NULL OR TRIM(nombre_cliente) = '' THEN 1 ELSE 0 END) +
        SUM(CASE WHEN correo_cliente IS NULL OR TRIM(correo_cliente) = '' THEN 1 ELSE 0 END) +
        SUM(CASE WHEN producto_comprado IS NULL OR TRIM(producto_comprado) = '' THEN 1 ELSE 0 END) +
        SUM(CASE WHEN fecha_compra_texto IS NULL OR TRIM(fecha_compra_texto) = '' THEN 1 ELSE 0 END) +
        SUM(CASE WHEN estado_ticket IS NULL OR TRIM(estado_ticket) = '' THEN 1 ELSE 0 END) +
        SUM(CASE WHEN prioridad_ticket IS NULL OR TRIM(prioridad_ticket) = '' THEN 1 ELSE 0 END) +
        SUM(CASE WHEN canal_ticket IS NULL OR TRIM(canal_ticket) = '' THEN 1 ELSE 0 END)
    ) AS total_casos_detectados,
    CASE
        WHEN (
            SUM(CASE WHEN id_ticket_origen IS NULL OR TRIM(id_ticket_origen) = '' THEN 1 ELSE 0 END) +
            SUM(CASE WHEN nombre_cliente IS NULL OR TRIM(nombre_cliente) = '' THEN 1 ELSE 0 END) +
            SUM(CASE WHEN correo_cliente IS NULL OR TRIM(correo_cliente) = '' THEN 1 ELSE 0 END) +
            SUM(CASE WHEN producto_comprado IS NULL OR TRIM(producto_comprado) = '' THEN 1 ELSE 0 END) +
            SUM(CASE WHEN fecha_compra_texto IS NULL OR TRIM(fecha_compra_texto) = '' THEN 1 ELSE 0 END) +
            SUM(CASE WHEN estado_ticket IS NULL OR TRIM(estado_ticket) = '' THEN 1 ELSE 0 END) +
            SUM(CASE WHEN prioridad_ticket IS NULL OR TRIM(prioridad_ticket) = '' THEN 1 ELSE 0 END) +
            SUM(CASE WHEN canal_ticket IS NULL OR TRIM(canal_ticket) = '' THEN 1 ELSE 0 END)
        ) = 0 THEN 'OK'
        ELSE 'REVISAR'
    END AS resultado,
    'Campos necesarios para construir dimensiones y tabla de hechos.' AS detalle
FROM origen_tickets_soporte;


-- ------------------------------------------------------------
-- 4. VALIDACION DE DUPLICADOS POR ID DE TICKET
-- ------------------------------------------------------------
/*
   Regla:
   id_ticket_origen debe ser unico, porque representa un ticket individual, si hay un duplicado se vera.
*/

SELECT
    id_ticket_origen,
    COUNT(*) AS cantidad_registros
FROM origen_tickets_soporte
GROUP BY id_ticket_origen
HAVING COUNT(*) > 1
ORDER BY cantidad_registros DESC, id_ticket_origen;

INSERT INTO resumen_validacion_calidad (nombre_validacion, total_casos_detectados, resultado, detalle)
SELECT
    'Duplicados por id_ticket_origen' AS nombre_validacion,
    COUNT(*) AS total_casos_detectados,
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'REVISAR' END AS resultado,
    'Cada id_ticket_origen debe aparecer una sola vez en la tabla de origen.' AS detalle
FROM (
    SELECT id_ticket_origen
    FROM origen_tickets_soporte
    GROUP BY id_ticket_origen
    HAVING COUNT(*) > 1
) duplicados;


-- ------------------------------------------------------------
-- 5. DETECCION DE DUPLICADOS USANDO FUNCION VENTANA
-- ------------------------------------------------------------
/*
   Esta consulta demuestra el uso de ROW_NUMBER() OVER(PARTITION BY ...).
   Si existieran tickets duplicados, numero_fila > 1 permitiria ubicar las filas repetidas candidatas a revision o eliminacion.
*/

WITH tickets_numerados AS (
    SELECT
        id_registro_origen,
        id_ticket_origen,
        correo_cliente,
        producto_comprado,
        estado_ticket,
        ROW_NUMBER() OVER (
            PARTITION BY id_ticket_origen
            ORDER BY id_registro_origen
        ) AS numero_fila
    FROM origen_tickets_soporte
)
SELECT *
FROM tickets_numerados
WHERE numero_fila > 1;


-- ------------------------------------------------------------
-- 6. CORREOS REPETIDOS EN ORIGEN
-- ------------------------------------------------------------
/*
   Un correo repetido no necesariamente es un error asi que en este modelo significa que un mismo cliente puede tener varios tickets y por eso dim_cliente tiene menos filas que origen_tickets_soporte.
*/

SELECT
    correo_cliente,
    COUNT(*) AS cantidad_tickets
FROM origen_tickets_soporte
GROUP BY correo_cliente
HAVING COUNT(*) > 1
ORDER BY cantidad_tickets DESC, correo_cliente
LIMIT 20;

INSERT INTO resumen_validacion_calidad (nombre_validacion, total_casos_detectados, resultado, detalle)
SELECT
    'Clientes con mas de un ticket en origen' AS nombre_validacion,
    COUNT(*) AS total_casos_detectados,
    'INFORMATIVO' AS resultado,
    'No es un error: un mismo cliente puede registrar varios tickets.' AS detalle
FROM (
    SELECT correo_cliente
    FROM origen_tickets_soporte
    GROUP BY correo_cliente
    HAVING COUNT(*) > 1
) clientes_recurrentes;


-- ------------------------------------------------------------
-- 7. FORMATO BASICO DE CORREO ELECTRONICO
-- ------------------------------------------------------------
/*
   Aqui haremos una validacion sencilla de formato de correo y aunque no busca ser una validacion perfecta, sino detectar casos claramente invalidos.
*/

SELECT
    id_registro_origen,
    id_ticket_origen,
    correo_cliente
FROM origen_tickets_soporte
WHERE correo_cliente IS NULL
   OR TRIM(correo_cliente) = ''
   OR correo_cliente NOT LIKE '%@%.%'
ORDER BY id_registro_origen;

INSERT INTO resumen_validacion_calidad (nombre_validacion, total_casos_detectados, resultado, detalle)
SELECT
    'Correos con formato posiblemente invalido' AS nombre_validacion,
    COUNT(*) AS total_casos_detectados,
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'REVISAR' END AS resultado,
    'Revision simple: el correo debe contener @ y punto.' AS detalle
FROM origen_tickets_soporte
WHERE correo_cliente IS NULL
   OR TRIM(correo_cliente) = ''
   OR correo_cliente NOT LIKE '%@%.%';


-- ------------------------------------------------------------
-- 8. EDADES FUERA DE RANGO O NO NUMERICAS
-- ------------------------------------------------------------
/*
   La dimension dim_cliente exige edad entre 18 y 100 y esta consulta revisa el campo crudo antes de la conversion.
*/

WITH edades_convertidas AS (
    SELECT
        id_registro_origen,
        id_ticket_origen,
        edad_cliente,
        CASE
            WHEN REGEXP_LIKE(TRIM(edad_cliente), '^[0-9]+$')
            THEN CAST(TRIM(edad_cliente) AS UNSIGNED)
            ELSE NULL
        END AS edad_convertida
    FROM origen_tickets_soporte
)
SELECT *
FROM edades_convertidas
WHERE edad_convertida IS NULL
   OR edad_convertida NOT BETWEEN 18 AND 100
ORDER BY id_registro_origen;

INSERT INTO resumen_validacion_calidad (nombre_validacion, total_casos_detectados, resultado, detalle)
SELECT
    'Edades fuera de rango o no numericas' AS nombre_validacion,
    COUNT(*) AS total_casos_detectados,
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'REVISAR' END AS resultado,
    'La edad debe ser numerica y estar entre 18 y 100.' AS detalle
FROM (
    SELECT
        CASE
            WHEN REGEXP_LIKE(TRIM(edad_cliente), '^[0-9]+$')
            THEN CAST(TRIM(edad_cliente) AS UNSIGNED)
            ELSE NULL
        END AS edad_convertida
    FROM origen_tickets_soporte
) edades
WHERE edad_convertida IS NULL
   OR edad_convertida NOT BETWEEN 18 AND 100;


-- ------------------------------------------------------------
-- 9. CALIFICACIONES FUERA DE RANGO O NO NUMERICAS
-- ------------------------------------------------------------
/*
   Regla:
   La satisfaccion debe estar entre 1 y 5 y puede ser NULL cuando el ticket no esta cerrado.
*/

WITH calificaciones_convertidas AS (
    SELECT
        id_registro_origen,
        id_ticket_origen,
        estado_ticket,
        calificacion_satisfaccion_texto,
        CASE
            WHEN calificacion_satisfaccion_texto IS NULL OR TRIM(calificacion_satisfaccion_texto) = '' THEN NULL
            WHEN REGEXP_LIKE(TRIM(calificacion_satisfaccion_texto), '^[0-9]+(\\.[0-9]+)?$')
            THEN CAST(TRIM(calificacion_satisfaccion_texto) AS DECIMAL(3,2))
            ELSE NULL
        END AS calificacion_convertida
    FROM origen_tickets_soporte
)
SELECT *
FROM calificaciones_convertidas
WHERE calificacion_convertida IS NOT NULL
  AND calificacion_convertida NOT BETWEEN 1 AND 5
ORDER BY id_registro_origen;

INSERT INTO resumen_validacion_calidad (nombre_validacion, total_casos_detectados, resultado, detalle)
SELECT
    'Calificaciones fuera de rango' AS nombre_validacion,
    COUNT(*) AS total_casos_detectados,
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'REVISAR' END AS resultado,
    'La calificacion debe estar entre 1 y 5 cuando exista.' AS detalle
FROM (
    SELECT
        CASE
            WHEN calificacion_satisfaccion_texto IS NULL OR TRIM(calificacion_satisfaccion_texto) = '' THEN NULL
            WHEN REGEXP_LIKE(TRIM(calificacion_satisfaccion_texto), '^[0-9]+(\\.[0-9]+)?$')
            THEN CAST(TRIM(calificacion_satisfaccion_texto) AS DECIMAL(3,2))
            ELSE NULL
        END AS calificacion_convertida
    FROM origen_tickets_soporte
) calificaciones
WHERE calificacion_convertida IS NOT NULL
  AND calificacion_convertida NOT BETWEEN 1 AND 5;


-- ------------------------------------------------------------
-- 10. FECHAS INVALIDAS EN CAMPOS DE TEXTO
-- ------------------------------------------------------------
/*
   Se valida que las fechas de texto puedan convertirse correctamente y esto demuestra control de tipos antes y despues de la transformacion.
*/

SELECT
    id_registro_origen,
    id_ticket_origen,
    fecha_compra_texto
FROM origen_tickets_soporte
WHERE STR_TO_DATE(fecha_compra_texto, '%Y-%m-%d') IS NULL
ORDER BY id_registro_origen;

INSERT INTO resumen_validacion_calidad (nombre_validacion, total_casos_detectados, resultado, detalle)
SELECT
    'Fechas de compra invalidas' AS nombre_validacion,
    COUNT(*) AS total_casos_detectados,
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'REVISAR' END AS resultado,
    'fecha_compra_texto debe poder convertirse con formato YYYY-MM-DD.' AS detalle
FROM origen_tickets_soporte
WHERE STR_TO_DATE(fecha_compra_texto, '%Y-%m-%d') IS NULL;

SELECT
    id_registro_origen,
    id_ticket_origen,
    fecha_primera_respuesta_texto
FROM origen_tickets_soporte
WHERE fecha_primera_respuesta_texto IS NOT NULL
  AND TRIM(fecha_primera_respuesta_texto) <> ''
  AND STR_TO_DATE(fecha_primera_respuesta_texto, '%Y-%m-%d %H:%i:%s') IS NULL
ORDER BY id_registro_origen;

INSERT INTO resumen_validacion_calidad (nombre_validacion, total_casos_detectados, resultado, detalle)
SELECT
    'Fechas de primera respuesta invalidas' AS nombre_validacion,
    COUNT(*) AS total_casos_detectados,
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'REVISAR' END AS resultado,
    'fecha_primera_respuesta_texto debe poder convertirse con formato YYYY-MM-DD HH:MM:SS cuando exista.' AS detalle
FROM origen_tickets_soporte
WHERE fecha_primera_respuesta_texto IS NOT NULL
  AND TRIM(fecha_primera_respuesta_texto) <> ''
  AND STR_TO_DATE(fecha_primera_respuesta_texto, '%Y-%m-%d %H:%i:%s') IS NULL;

SELECT
    id_registro_origen,
    id_ticket_origen,
    fecha_resolucion_texto
FROM origen_tickets_soporte
WHERE fecha_resolucion_texto IS NOT NULL
  AND TRIM(fecha_resolucion_texto) <> ''
  AND STR_TO_DATE(fecha_resolucion_texto, '%Y-%m-%d %H:%i:%s') IS NULL
ORDER BY id_registro_origen;

INSERT INTO resumen_validacion_calidad (nombre_validacion, total_casos_detectados, resultado, detalle)
SELECT
    'Fechas de resolucion invalidas' AS nombre_validacion,
    COUNT(*) AS total_casos_detectados,
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'REVISAR' END AS resultado,
    'fecha_resolucion_texto debe poder convertirse con formato YYYY-MM-DD HH:MM:SS cuando exista.' AS detalle
FROM origen_tickets_soporte
WHERE fecha_resolucion_texto IS NOT NULL
  AND TRIM(fecha_resolucion_texto) <> ''
  AND STR_TO_DATE(fecha_resolucion_texto, '%Y-%m-%d %H:%i:%s') IS NULL;


-- ------------------------------------------------------------
-- 11. REGLAS DE NEGOCIO POR ESTADO DEL TICKET
-- ------------------------------------------------------------
/*
   Regla esperada:
   - Tickets cerrados deberian tener resolucion, fecha de resolucion valida y posterior a la fecha de inicio del ticket y calificacion de satisfaccion.
   - Tickets abiertos o pendientes pueden tener esos campos como NULL.
*/

SELECT
    id_ticket,
    nombre_estado,
    resolucion_ticket,
    fecha_resolucion,
    calificacion_satisfaccion
FROM vista_detalle_tickets
WHERE nombre_estado = 'Closed'
  AND (
        resolucion_ticket IS NULL
        OR TRIM(resolucion_ticket) = ''
        OR fecha_resolucion IS NULL
        OR calificacion_satisfaccion IS NULL
      )
ORDER BY id_ticket;

INSERT INTO resumen_validacion_calidad (nombre_validacion, total_casos_detectados, resultado, detalle)
SELECT
    'Tickets cerrados sin resolucion, fecha o satisfaccion' AS nombre_validacion,
    COUNT(*) AS total_casos_detectados,
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'REVISAR' END AS resultado,
    'Los tickets cerrados deberian tener resolucion, fecha de resolucion y calificacion.' AS detalle
FROM vista_detalle_tickets
WHERE nombre_estado = 'Closed'
  AND (
        resolucion_ticket IS NULL
        OR TRIM(resolucion_ticket) = ''
        OR fecha_resolucion IS NULL
        OR calificacion_satisfaccion IS NULL
      );

SELECT
    nombre_estado,
    COUNT(*) AS total_tickets,
    SUM(CASE WHEN resolucion_ticket IS NULL THEN 1 ELSE 0 END) AS tickets_sin_resolucion,
    SUM(CASE WHEN calificacion_satisfaccion IS NULL THEN 1 ELSE 0 END) AS tickets_sin_satisfaccion
FROM vista_detalle_tickets
GROUP BY nombre_estado
ORDER BY total_tickets DESC;


-- ------------------------------------------------------------
-- 12. FECHAS INCONSISTENTES Y TIEMPOS NEGATIVOS
-- ------------------------------------------------------------
/*
   En una operacion real, la resolucion no deberia ocurrir antes de la primera respuesta. Si ocurre, se marca como inconsistencia.
*/

SELECT
    id_ticket,
    nombre_prioridad,
    nombre_estado,
    fecha_primera_respuesta,
    fecha_resolucion,
    TIMESTAMPDIFF(HOUR, fecha_primera_respuesta, fecha_resolucion) AS horas_resolucion
FROM vista_detalle_tickets
WHERE fecha_primera_respuesta IS NOT NULL
  AND fecha_resolucion IS NOT NULL
  AND fecha_resolucion < fecha_primera_respuesta
ORDER BY horas_resolucion ASC, id_ticket
LIMIT 50;

INSERT INTO resumen_validacion_calidad (nombre_validacion, total_casos_detectados, resultado, detalle)
SELECT
    'Tickets con fecha de resolucion anterior a primera respuesta' AS nombre_validacion,
    COUNT(*) AS total_casos_detectados,
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'REVISAR' END AS resultado,
    'La fecha de resolucion no deberia ser menor que la fecha de primera respuesta.' AS detalle
FROM vista_detalle_tickets
WHERE fecha_primera_respuesta IS NOT NULL
  AND fecha_resolucion IS NOT NULL
  AND fecha_resolucion < fecha_primera_respuesta;


-- ------------------------------------------------------------
-- 13. OUTLIERS DE TIEMPO DE RESOLUCION
-- ------------------------------------------------------------
/*
   Se consideran outliers operativos los tickets con resolucion mayor a 72 horas desde la primera respuesta. Este umbral es una regla
   practica para detectar casos que requieren revision.
*/

SELECT
    id_ticket,
    nombre_prioridad,
    nombre_canal,
    nombre_producto,
    fecha_primera_respuesta,
    fecha_resolucion,
    TIMESTAMPDIFF(HOUR, fecha_primera_respuesta, fecha_resolucion) AS horas_resolucion
FROM vista_detalle_tickets
WHERE fecha_primera_respuesta IS NOT NULL
  AND fecha_resolucion IS NOT NULL
  AND TIMESTAMPDIFF(HOUR, fecha_primera_respuesta, fecha_resolucion) > 72
ORDER BY horas_resolucion DESC, id_ticket
LIMIT 50;

INSERT INTO resumen_validacion_calidad (nombre_validacion, total_casos_detectados, resultado, detalle)
SELECT
    'Outliers de tiempo de resolucion mayor a 72 horas' AS nombre_validacion,
    COUNT(*) AS total_casos_detectados,
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'REVISAR' END AS resultado,
    'Tickets con mas de 72 horas entre primera respuesta y resolucion.' AS detalle
FROM vista_detalle_tickets
WHERE fecha_primera_respuesta IS NOT NULL
  AND fecha_resolucion IS NOT NULL
  AND TIMESTAMPDIFF(HOUR, fecha_primera_respuesta, fecha_resolucion) > 72;


-- ------------------------------------------------------------
-- 14. INTEGRIDAD ENTRE DIMENSIONES Y TABLA DE HECHOS
-- ------------------------------------------------------------
/*
   Con LEFT JOIN se buscan dimensiones que quedaron sin uso. Esto no necesariamente es error, pero en este proyecto se espera que
   todas las dimensiones provengan de valores presentes en los tickets.
*/

SELECT
    dp.id_producto,
    dp.nombre_producto
FROM dim_producto dp
LEFT JOIN hecho_tickets ht
    ON dp.id_producto = ht.id_producto
WHERE ht.id_ticket IS NULL;

INSERT INTO resumen_validacion_calidad (nombre_validacion, total_casos_detectados, resultado, detalle)
SELECT
    'Productos sin tickets asociados' AS nombre_validacion,
    COUNT(*) AS total_casos_detectados,
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'REVISAR' END AS resultado,
    'Busca productos en la dimension que no tengan registros en la tabla de hechos.' AS detalle
FROM dim_producto dp
LEFT JOIN hecho_tickets ht
    ON dp.id_producto = ht.id_producto
WHERE ht.id_ticket IS NULL;

SELECT
    dc.id_canal,
    dc.nombre_canal
FROM dim_canal dc
LEFT JOIN hecho_tickets ht
    ON dc.id_canal = ht.id_canal
WHERE ht.id_ticket IS NULL;

INSERT INTO resumen_validacion_calidad (nombre_validacion, total_casos_detectados, resultado, detalle)
SELECT
    'Canales sin tickets asociados' AS nombre_validacion,
    COUNT(*) AS total_casos_detectados,
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'REVISAR' END AS resultado,
    'Busca canales en la dimension que no tengan registros en la tabla de hechos.' AS detalle
FROM dim_canal dc
LEFT JOIN hecho_tickets ht
    ON dc.id_canal = ht.id_canal
WHERE ht.id_ticket IS NULL;


-- ------------------------------------------------------------
-- 15. DEMOSTRACION CONTROLADA DE UPDATE Y ROLLBACK
-- ------------------------------------------------------------
/*
   Este bloque demuestra como se podria corregir un valor nulo.
   Sin embargo, se usa ROLLBACK porque en este modelo los NULL en resolucion son validos para tickets abiertos o pendientes.

   Esto permite demostrar dominio de transacciones sin alterar el resultado final del analisis.
*/

START TRANSACTION;

UPDATE hecho_tickets ht
INNER JOIN dim_estado de
    ON ht.id_estado = de.id_estado
SET ht.resolucion_ticket = 'SIN RESOLUCION TODAVIA'
WHERE de.nombre_estado <> 'Closed'
  AND ht.resolucion_ticket IS NULL;

SELECT
    ROW_COUNT() AS registros_que_se_habrian_actualizado,
    'Se ejecuta ROLLBACK porque estos NULL son validos para tickets no cerrados.' AS explicacion;

ROLLBACK;


-- ------------------------------------------------------------
-- 16. RESUMEN FINAL DE VALIDACION
-- ------------------------------------------------------------
/*
   Esta salida final resume todas las pruebas documentadas.
   OK significa que no se detectaron problemas en esa validacion.
   REVISAR significa que hay casos que deben analizarse.
   INFORMATIVO significa que el hallazgo no necesariamente es un error.
*/

SELECT
    nombre_validacion,
    total_casos_detectados,
    resultado,
    detalle,
    fecha_ejecucion
FROM resumen_validacion_calidad
ORDER BY
    CASE resultado
        WHEN 'REVISAR' THEN 1
        WHEN 'INFORMATIVO' THEN 2
        WHEN 'OK' THEN 3
        ELSE 4
    END,
    nombre_validacion;
