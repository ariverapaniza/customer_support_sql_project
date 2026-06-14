/* ============================================================
   PROYECTO SQL - ANALISIS DE TICKETS DE SOPORTE
   Archivo: 04_eda_analisis.sql
   Autor: Arturo Rivera Paniza

   Objetivo:
   Realizar analisis exploratorio y consultas de negocio sobre el
   modelo relacional de tickets de soporte tecnico.

   Este script incluye:
   - Consultas descriptivas del modelo
   - KPIs generales
   - Analisis por estado, prioridad, canal, producto y tipo de ticket
   - CTEs simples y encadenadas
   - Subqueries
   - INNER JOIN y LEFT JOIN
   - Agregaciones: COUNT, SUM, AVG
   - CASE y logica condicional
   - Funciones de fecha
   - Funcion ventana RANK() OVER
   - Uso de la funcion de negocio fn_sla_prioridad_horas

   Nota:
   Este archivo es el nucleo analitico del proyecto. No modifica datos.
   Todas las consultas estan documentadas con el insight esperado.
   ============================================================ */

USE analitica_soporte_clientes;


-- ------------------------------------------------------------
-- 0. VERIFICACION INICIAL DEL MODELO
-- ------------------------------------------------------------
/*
   Objetivo:
   Confirmar que las tablas principales tienen datos cargados antes de
   iniciar el analisis.

   Insight:
   Si origen_tickets_soporte y hecho_tickets tienen el mismo total,
   la carga principal fue consistente.
*/

SELECT '00 - Verificacion inicial del modelo' AS seccion;

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
SELECT 'dim_estado' AS tabla, COUNT(*) AS total_registros
FROM dim_estado
UNION ALL
SELECT 'dim_prioridad' AS tabla, COUNT(*) AS total_registros
FROM dim_prioridad
UNION ALL
SELECT 'dim_canal' AS tabla, COUNT(*) AS total_registros
FROM dim_canal;


-- ------------------------------------------------------------
-- 1. KPIS GENERALES DEL AREA DE SOPORTE
-- ------------------------------------------------------------
/*
   Objetivo:
   Obtener una vista ejecutiva del estado general de soporte.

   SQL utilizado:
   - VIEW
   - COUNT
   - SUM
   - AVG
   - CASE dentro de la vista vista_kpis_soporte

   Insight:
   Resume el total de tickets, cuantos estan cerrados, cuantos siguen
   abiertos o pendientes, la satisfaccion promedio y el porcentaje de
   cierre. Es la consulta mas ejecutiva del proyecto.
*/

SELECT '01 - KPIs generales del area de soporte' AS seccion;

SELECT *
FROM vista_kpis_soporte;


-- ------------------------------------------------------------
-- 2. DISTRIBUCION DE TICKETS POR ESTADO
-- ------------------------------------------------------------
/*
   Objetivo:
   Medir el volumen de tickets por estado operativo.

   SQL utilizado:
   - INNER JOIN
   - COUNT
   - ROUND
   - Subquery para calcular el porcentaje sobre el total

   Insight:
   Permite entender que parte del volumen esta cerrado y que parte
   sigue pendiente de gestion o respuesta del cliente.
*/

SELECT '02 - Distribucion de tickets por estado' AS seccion;

SELECT
    de.nombre_estado,
    COUNT(*) AS total_tickets,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM hecho_tickets), 2) AS porcentaje_total
FROM hecho_tickets ht
INNER JOIN dim_estado de
    ON ht.id_estado = de.id_estado
GROUP BY de.nombre_estado
ORDER BY total_tickets DESC;


-- ------------------------------------------------------------
-- 3. VOLUMEN DE TICKETS POR PRIORIDAD
-- ------------------------------------------------------------
/*
   Objetivo:
   Identificar como se distribuyen los tickets segun prioridad.

   SQL utilizado:
   - INNER JOIN
   - COUNT
   - GROUP BY
   - ORDER BY por nivel de prioridad

   Insight:
   Ayuda a entender la carga operativa segun urgencia. Una cantidad alta
   de tickets Critical o High puede indicar presion sobre el equipo de
   soporte.
*/

SELECT '03 - Volumen de tickets por prioridad' AS seccion;

SELECT
    dp.nombre_prioridad,
    dp.nivel_prioridad,
    COUNT(*) AS total_tickets
FROM hecho_tickets ht
INNER JOIN dim_prioridad dp
    ON ht.id_prioridad = dp.id_prioridad
GROUP BY
    dp.nombre_prioridad,
    dp.nivel_prioridad
ORDER BY dp.nivel_prioridad DESC;


-- ------------------------------------------------------------
-- 4. BACKLOG POR PRIORIDAD Y CANAL
-- ------------------------------------------------------------
/*
   Objetivo:
   Analizar tickets que no estan cerrados, agrupados por prioridad y canal.

   SQL utilizado:
   - INNER JOIN multiple
   - COUNT
   - CASE
   - GROUP BY

   Insight:
   Esta consulta es muy util para operaciones: muestra donde esta la
   carga pendiente y que canales concentran tickets urgentes sin cerrar.
*/

SELECT '04 - Backlog por prioridad y canal' AS seccion;

SELECT
    dp.nombre_prioridad,
    dc.nombre_canal,
    COUNT(*) AS tickets_no_cerrados,
    SUM(CASE WHEN de.nombre_estado = 'Open' THEN 1 ELSE 0 END) AS tickets_abiertos,
    SUM(CASE WHEN de.nombre_estado = 'Pending Customer Response' THEN 1 ELSE 0 END) AS tickets_pendientes_cliente
FROM hecho_tickets ht
INNER JOIN dim_estado de
    ON ht.id_estado = de.id_estado
INNER JOIN dim_prioridad dp
    ON ht.id_prioridad = dp.id_prioridad
INNER JOIN dim_canal dc
    ON ht.id_canal = dc.id_canal
WHERE de.nombre_estado <> 'Closed'
GROUP BY
    dp.nombre_prioridad,
    dp.nivel_prioridad,
    dc.nombre_canal
ORDER BY
    dp.nivel_prioridad DESC,
    tickets_no_cerrados DESC;


-- ------------------------------------------------------------
-- 5. SATISFACCION PROMEDIO POR CANAL
-- ------------------------------------------------------------
/*
   Objetivo:
   Comparar la satisfaccion del cliente segun el canal de atencion.

   SQL utilizado:
   - VIEW
   - AVG
   - COUNT
   - CASE para clasificar resultado

   Insight:
   Permite detectar canales con mejor o peor experiencia. Si un canal
   tiene menor satisfaccion promedio, podria requerir revision de proceso,
   tiempos de respuesta o calidad de atencion.
*/

SELECT '05 - Satisfaccion promedio por canal' AS seccion;

SELECT
    nombre_canal,
    COUNT(calificacion_satisfaccion) AS tickets_con_calificacion,
    ROUND(AVG(calificacion_satisfaccion), 2) AS promedio_satisfaccion,
    CASE
        WHEN AVG(calificacion_satisfaccion) >= 4 THEN 'Experiencia alta'
        WHEN AVG(calificacion_satisfaccion) >= 3 THEN 'Experiencia media'
        WHEN AVG(calificacion_satisfaccion) IS NULL THEN 'Sin calificacion'
        ELSE 'Experiencia baja'
    END AS lectura_negocio
FROM vista_detalle_tickets
GROUP BY nombre_canal
ORDER BY promedio_satisfaccion ASC;


-- ------------------------------------------------------------
-- 6. SATISFACCION PROMEDIO POR PRODUCTO
-- ------------------------------------------------------------
/*
   Objetivo:
   Encontrar productos con menor satisfaccion promedio.

   SQL utilizado:
   - INNER JOIN
   - AVG
   - COUNT
   - HAVING

   Insight:
   Un producto con muchos tickets cerrados y baja satisfaccion puede ser
   candidato a analisis de calidad, documentacion, garantia o soporte.
*/

SELECT '06 - Productos con menor satisfaccion promedio' AS seccion;

SELECT
    dp.nombre_producto,
    COUNT(ht.id_ticket) AS total_tickets,
    COUNT(ht.calificacion_satisfaccion) AS tickets_con_calificacion,
    ROUND(AVG(ht.calificacion_satisfaccion), 2) AS promedio_satisfaccion
FROM hecho_tickets ht
INNER JOIN dim_producto dp
    ON ht.id_producto = dp.id_producto
GROUP BY dp.nombre_producto
HAVING COUNT(ht.calificacion_satisfaccion) >= 20
ORDER BY promedio_satisfaccion ASC, total_tickets DESC
LIMIT 10;


-- ------------------------------------------------------------
-- 7. TIPOS DE TICKET CON MAYOR VOLUMEN Y SATISFACCION
-- ------------------------------------------------------------
/*
   Objetivo:
   Analizar que tipos de solicitud generan mas volumen y como se relacionan
   con la satisfaccion del cliente.

   SQL utilizado:
   - INNER JOIN
   - COUNT
   - AVG
   - ROUND

   Insight:
   Permite identificar si ciertos tipos de ticket generan mas friccion.
   Por ejemplo, si Refund request o Technical issue tienen baja satisfaccion,
   pueden requerir mejoras especificas.
*/

SELECT '07 - Tipos de ticket por volumen y satisfaccion' AS seccion;

SELECT
    dtt.nombre_tipo_ticket,
    COUNT(*) AS total_tickets,
    ROUND(AVG(ht.calificacion_satisfaccion), 2) AS promedio_satisfaccion,
    COUNT(ht.calificacion_satisfaccion) AS tickets_calificados
FROM hecho_tickets ht
INNER JOIN dim_tipo_ticket dtt
    ON ht.id_tipo_ticket = dtt.id_tipo_ticket
GROUP BY dtt.nombre_tipo_ticket
ORDER BY total_tickets DESC;


-- ------------------------------------------------------------
-- 8. TIEMPO PROMEDIO DE RESOLUCION POR PRIORIDAD
-- ------------------------------------------------------------
/*
   Objetivo:
   Medir cuantas horas toma resolver tickets cerrados segun prioridad.

   SQL utilizado:
   - INNER JOIN
   - TIMESTAMPDIFF
   - AVG
   - CASE
   - WHERE para excluir fechas inconsistentes

   Insight:
   En teoria, tickets Critical y High deberian tener tiempos de resolucion
   menores que Medium o Low. Si no ocurre, puede indicar problemas de
   priorizacion operativa.
*/

SELECT '08 - Tiempo promedio de resolucion por prioridad' AS seccion;

SELECT
    dp.nombre_prioridad,
    dp.nivel_prioridad,
    COUNT(*) AS tickets_cerrados_validos,
    ROUND(AVG(TIMESTAMPDIFF(HOUR, ht.fecha_primera_respuesta, ht.fecha_resolucion)), 2) AS promedio_horas_resolucion,
    MIN(TIMESTAMPDIFF(HOUR, ht.fecha_primera_respuesta, ht.fecha_resolucion)) AS minimo_horas_resolucion,
    MAX(TIMESTAMPDIFF(HOUR, ht.fecha_primera_respuesta, ht.fecha_resolucion)) AS maximo_horas_resolucion
FROM hecho_tickets ht
INNER JOIN dim_prioridad dp
    ON ht.id_prioridad = dp.id_prioridad
INNER JOIN dim_estado de
    ON ht.id_estado = de.id_estado
WHERE de.nombre_estado = 'Closed'
  AND ht.fecha_primera_respuesta IS NOT NULL
  AND ht.fecha_resolucion IS NOT NULL
  AND ht.fecha_resolucion >= ht.fecha_primera_respuesta
GROUP BY
    dp.nombre_prioridad,
    dp.nivel_prioridad
ORDER BY dp.nivel_prioridad DESC;


-- ------------------------------------------------------------
-- 9. RANKING DE PRODUCTOS POR VOLUMEN DE TICKETS
-- ------------------------------------------------------------
/*
   Objetivo:
   Priorizar productos segun volumen de tickets.

   SQL utilizado:
   - CTE
   - RANK() OVER
   - GROUP BY

   Insight:
   La funcion ventana permite rankear productos sin perder el detalle
   agregado. Los productos en los primeros lugares concentran mayor carga
   de soporte y pueden requerir atencion prioritaria.
*/

SELECT '09 - Ranking de productos por volumen de tickets' AS seccion;

WITH tickets_por_producto AS (
    SELECT
        dp.nombre_producto,
        COUNT(*) AS total_tickets,
        ROUND(AVG(ht.calificacion_satisfaccion), 2) AS promedio_satisfaccion
    FROM hecho_tickets ht
    INNER JOIN dim_producto dp
        ON ht.id_producto = dp.id_producto
    GROUP BY dp.nombre_producto
)
SELECT
    RANK() OVER (ORDER BY total_tickets DESC) AS ranking_producto,
    nombre_producto,
    total_tickets,
    promedio_satisfaccion
FROM tickets_por_producto
ORDER BY ranking_producto, nombre_producto
LIMIT 15;


-- ------------------------------------------------------------
-- 10. CTE ENCADENADA: PRODUCTOS CON ALTO VOLUMEN Y BAJA SATISFACCION
-- ------------------------------------------------------------
/*
   Objetivo:
   Detectar productos que combinan dos senales de riesgo:
   mucho volumen de tickets y satisfaccion por debajo del promedio global.

   SQL utilizado:
   - CTE encadenada
   - AVG
   - Subconsulta logica dentro de CTE
   - CASE

   Insight:
   Esta consulta convierte datos operativos en una lista accionable de
   productos a revisar por negocio, soporte o calidad.
*/

SELECT '10 - Productos con alto volumen y baja satisfaccion' AS seccion;

WITH promedio_global AS (
    SELECT
        AVG(calificacion_satisfaccion) AS promedio_satisfaccion_global
    FROM hecho_tickets
    WHERE calificacion_satisfaccion IS NOT NULL
),
metricas_producto AS (
    SELECT
        dp.nombre_producto,
        COUNT(*) AS total_tickets,
        COUNT(ht.calificacion_satisfaccion) AS tickets_calificados,
        AVG(ht.calificacion_satisfaccion) AS promedio_satisfaccion_producto
    FROM hecho_tickets ht
    INNER JOIN dim_producto dp
        ON ht.id_producto = dp.id_producto
    GROUP BY dp.nombre_producto
),
productos_clasificados AS (
    SELECT
        mp.nombre_producto,
        mp.total_tickets,
        mp.tickets_calificados,
        ROUND(mp.promedio_satisfaccion_producto, 2) AS promedio_satisfaccion_producto,
        ROUND(pg.promedio_satisfaccion_global, 2) AS promedio_satisfaccion_global,
        CASE
            WHEN mp.total_tickets >= 200
             AND mp.promedio_satisfaccion_producto < pg.promedio_satisfaccion_global
            THEN 'Revisar prioridad alta'
            WHEN mp.total_tickets >= 150
             AND mp.promedio_satisfaccion_producto < pg.promedio_satisfaccion_global
            THEN 'Revisar prioridad media'
            ELSE 'Monitorear'
        END AS recomendacion
    FROM metricas_producto mp
    CROSS JOIN promedio_global pg
)
SELECT *
FROM productos_clasificados
WHERE recomendacion <> 'Monitorear'
ORDER BY
    total_tickets DESC,
    promedio_satisfaccion_producto ASC;


-- ------------------------------------------------------------
-- 11. CLIENTES RECURRENTES CON MAS TICKETS
-- ------------------------------------------------------------
/*
   Objetivo:
   Identificar clientes que han abierto mas de un ticket.

   SQL utilizado:
   - LEFT JOIN
   - COUNT
   - AVG
   - GROUP BY
   - HAVING

   Insight:
   Los clientes recurrentes pueden indicar problemas repetidos, mayor
   necesidad de acompanamiento o clientes con alto uso del producto.
*/

SELECT '11 - Clientes recurrentes con mas tickets' AS seccion;

SELECT
    dc.nombre_cliente,
    dc.correo_cliente,
    COUNT(ht.id_ticket) AS total_tickets,
    ROUND(AVG(ht.calificacion_satisfaccion), 2) AS promedio_satisfaccion,
    MAX(ht.fecha_compra) AS ultima_fecha_compra_registrada
FROM dim_cliente dc
LEFT JOIN hecho_tickets ht
    ON dc.id_cliente = ht.id_cliente
GROUP BY
    dc.id_cliente,
    dc.nombre_cliente,
    dc.correo_cliente
HAVING COUNT(ht.id_ticket) > 1
ORDER BY total_tickets DESC, promedio_satisfaccion ASC
LIMIT 20;


-- ------------------------------------------------------------
-- 12. TENDENCIA MENSUAL DE TICKETS SEGUN FECHA DE COMPRA
-- ------------------------------------------------------------
/*
   Objetivo:
   Analizar volumen de tickets por mes de compra del producto.

   SQL utilizado:
   - Funcion de fecha DATE_FORMAT
   - GROUP BY
   - COUNT
   - AVG

   Insight:
   Ayuda a encontrar periodos de compra asociados con mayor volumen de
   tickets. Puede ser util para investigar lotes, campanas o periodos de
   mayor demanda.
*/

SELECT '12 - Tendencia mensual de tickets por fecha de compra' AS seccion;

SELECT
    DATE_FORMAT(ht.fecha_compra, '%Y-%m') AS anio_mes_compra,
    COUNT(*) AS total_tickets,
    ROUND(AVG(ht.calificacion_satisfaccion), 2) AS promedio_satisfaccion
FROM hecho_tickets ht
GROUP BY DATE_FORMAT(ht.fecha_compra, '%Y-%m')
ORDER BY anio_mes_compra;


-- ------------------------------------------------------------
-- 13. ANALISIS DE CUMPLIMIENTO DE SLA POR PRIORIDAD
-- ------------------------------------------------------------
/*
   Objetivo:
   Comparar el tiempo real de resolucion contra una regla de negocio SLA.

   SQL utilizado:
   - CTE encadenada
   - Funcion personalizada fn_sla_prioridad_horas
   - TIMESTAMPDIFF
   - CASE
   - SUM
   - AVG

   Regla de negocio:
   Critical = 4 horas
   High     = 8 horas
   Medium   = 24 horas
   Low      = 48 horas

   Insight:
   Esta consulta permite pasar de un analisis descriptivo a un analisis
   de gestion: no solo cuanto tardamos, sino si cumplimos el objetivo.
*/

SELECT '13 - Cumplimiento de SLA por prioridad' AS seccion;

WITH tickets_cerrados_validos AS (
    SELECT
        ht.id_ticket,
        dp.nombre_prioridad,
        dp.nivel_prioridad,
        TIMESTAMPDIFF(HOUR, ht.fecha_primera_respuesta, ht.fecha_resolucion) AS horas_resolucion,
        fn_sla_prioridad_horas(dp.nombre_prioridad) AS sla_objetivo_horas
    FROM hecho_tickets ht
    INNER JOIN dim_prioridad dp
        ON ht.id_prioridad = dp.id_prioridad
    INNER JOIN dim_estado de
        ON ht.id_estado = de.id_estado
    WHERE de.nombre_estado = 'Closed'
      AND ht.fecha_primera_respuesta IS NOT NULL
      AND ht.fecha_resolucion IS NOT NULL
      AND ht.fecha_resolucion >= ht.fecha_primera_respuesta
),
tickets_con_clasificacion_sla AS (
    SELECT
        id_ticket,
        nombre_prioridad,
        nivel_prioridad,
        horas_resolucion,
        sla_objetivo_horas,
        CASE
            WHEN horas_resolucion <= sla_objetivo_horas THEN 'Dentro de SLA'
            ELSE 'Fuera de SLA'
        END AS resultado_sla
    FROM tickets_cerrados_validos
)
SELECT
    nombre_prioridad,
    nivel_prioridad,
    COUNT(*) AS tickets_evaluados,
    ROUND(AVG(horas_resolucion), 2) AS promedio_horas_resolucion,
    sla_objetivo_horas,
    SUM(CASE WHEN resultado_sla = 'Dentro de SLA' THEN 1 ELSE 0 END) AS tickets_dentro_sla,
    SUM(CASE WHEN resultado_sla = 'Fuera de SLA' THEN 1 ELSE 0 END) AS tickets_fuera_sla,
    ROUND(
        SUM(CASE WHEN resultado_sla = 'Dentro de SLA' THEN 1 ELSE 0 END) * 100.0 / COUNT(*),
        2
    ) AS porcentaje_cumplimiento_sla
FROM tickets_con_clasificacion_sla
GROUP BY
    nombre_prioridad,
    nivel_prioridad,
    sla_objetivo_horas
ORDER BY nivel_prioridad DESC;


-- ------------------------------------------------------------
-- 14. CONSULTA DEMO MODIFICABLE PARA LA PRESENTACION
-- ------------------------------------------------------------
/*
   Objetivo:
   Tener una consulta sencilla para demostrar dominio en vivo.

   Como usarla en clase:
   1. Ejecutar la consulta filtrando solo Critical.
   2. Cambiar el filtro a ('Critical', 'High').
   3. Explicar como cambia el backlog mostrado.

   Ejemplo de modificacion:
   Cambiar esta linea:
       WHERE dpr.nombre_prioridad = 'Critical'

   Por esta:
       WHERE dpr.nombre_prioridad IN ('Critical', 'High')

   Insight:
   Sirve para mostrar que el modelo permite cambiar rapidamente el foco
   del analisis sin reescribir toda la consulta.
*/

SELECT '14 - Consulta demo modificable para presentacion' AS seccion;

SELECT
    vdt.nombre_prioridad,
    vdt.nombre_canal,
    vdt.nombre_estado,
    COUNT(*) AS total_tickets
FROM vista_detalle_tickets vdt
WHERE vdt.nombre_prioridad = 'Critical'
  AND vdt.nombre_estado <> 'Closed'
GROUP BY
    vdt.nombre_prioridad,
    vdt.nombre_canal,
    vdt.nombre_estado
ORDER BY total_tickets DESC;


/* ------------------------------------------------------------
   15. RESUMEN FINAL DE INSIGHTS PRINCIPALES
   ------------------------------------------------------------
   Objetivo:
   Presentar en una sola salida algunos resultados clave del análisis.

   Nota técnica:
   Se fuerza la misma collation en todas las columnas de texto para
   evitar errores de UNION por mezcla de collations en MySQL.
*/

SELECT
    CONVERT('Total de tickets analizados' USING utf8mb4) COLLATE utf8mb4_spanish_ci AS insight,
    CONVERT(CAST(COUNT(*) AS CHAR) USING utf8mb4) COLLATE utf8mb4_spanish_ci AS valor
FROM hecho_tickets

UNION ALL

SELECT
    CONVERT('Producto con mas tickets' USING utf8mb4) COLLATE utf8mb4_spanish_ci AS insight,
    CONVERT(nombre_producto USING utf8mb4) COLLATE utf8mb4_spanish_ci AS valor
FROM (
    SELECT
        dp.nombre_producto,
        COUNT(*) AS total_tickets
    FROM hecho_tickets ht
    INNER JOIN dim_producto dp
        ON ht.id_producto = dp.id_producto
    GROUP BY dp.nombre_producto
    ORDER BY total_tickets DESC
    LIMIT 1
) producto_top

UNION ALL

SELECT
    CONVERT('Canal con menor satisfaccion promedio' USING utf8mb4) COLLATE utf8mb4_spanish_ci AS insight,
    CONVERT(nombre_canal USING utf8mb4) COLLATE utf8mb4_spanish_ci AS valor
FROM (
    SELECT
        dc.nombre_canal,
        AVG(ht.calificacion_satisfaccion) AS promedio_satisfaccion
    FROM hecho_tickets ht
    INNER JOIN dim_canal dc
        ON ht.id_canal = dc.id_canal
    WHERE ht.calificacion_satisfaccion IS NOT NULL
    GROUP BY dc.nombre_canal
    ORDER BY promedio_satisfaccion ASC
    LIMIT 1
) canal_bajo

UNION ALL

SELECT
    CONVERT('Tickets no cerrados' USING utf8mb4) COLLATE utf8mb4_spanish_ci AS insight,
    CONVERT(CAST(COUNT(*) AS CHAR) USING utf8mb4) COLLATE utf8mb4_spanish_ci AS valor
FROM vista_detalle_tickets
WHERE nombre_estado <> 'Closed';