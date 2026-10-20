SET LINESIZE 250;
SET PAGESIZE 60;
SET FEEDBACK ON;
SET TIMING ON;
SET TRIMSPOOL ON;

-- Clear previous column formatting
CLEAR COLUMNS;
CLEAR BREAKS;

COLUMN carrier_name FORMAT A25 HEADING "Airline Carrier";
COLUMN route_corridor FORMAT A32 HEADING "Route Corridor";
COLUMN punctuality_rank FORMAT 999 HEADING "Rank";
COLUMN total_assessed_fines FORMAT A18 HEADING "Total DOT Fines";
COLUMN worst_tarmac_min FORMAT 999,999 HEADING "Max Taxi (min)";

SPOOL C:\database_project\data\05_queries_output.txt;

PROMPT ================================================================
PROMPT 1. Carrier Reliability & Punctuality Ranking (Window Function)
PROMPT ================================================================
SELECT 
    a.carrier_name,
    COUNT(f.flight_id) AS total_flights,
    ROUND(100 * (1 - (SUM(f.cancelled) / COUNT(f.flight_id))), 2) AS completion_rate_pct,
    ROUND(AVG(f.arr_delay_min), 2) AS avg_arr_delay_min,
    DENSE_RANK() OVER (ORDER BY AVG(f.arr_delay_min) ASC) AS punctuality_rank
FROM flight_operations f
JOIN airlines a ON a.carrier_code = f.carrier_code
GROUP BY a.carrier_name
ORDER BY punctuality_rank;

PROMPT ================================================================
PROMPT 2. Delay Root-Cause Attribution Summary
PROMPT ================================================================
SELECT 
    ROUND(SUM(carrier_delay), 0)       AS total_carrier_min,
    ROUND(SUM(weather_delay), 0)       AS total_weather_min,
    ROUND(SUM(nas_delay), 0)           AS total_nas_min,
    ROUND(SUM(late_aircraft_delay), 0) AS total_late_ac_min,
    ROUND(100 * SUM(carrier_delay) / 
          NULLIF(SUM(carrier_delay + weather_delay + nas_delay + late_aircraft_delay), 0), 2) AS carrier_fault_pct,
    ROUND(100 * SUM(weather_delay) / 
          NULLIF(SUM(carrier_delay + weather_delay + nas_delay + late_aircraft_delay), 0), 2) AS weather_pct
FROM delay_attributions;

PROMPT ================================================================
PROMPT 3. Top 10 Most Delayed Airport Pairs (IATA Code Double Join)
PROMPT ================================================================
SELECT * FROM (
    SELECT 
        o.airport_code || ' (' || o.city_name || ') -> ' || 
        d.airport_code || ' (' || d.city_name || ')' AS route_corridor,
        r.distance_miles,
        COUNT(f.flight_id) AS total_flights,
        ROUND(AVG(f.arr_delay_min), 2) AS avg_arr_delay_min
    FROM flight_operations f
    JOIN flight_routes r ON r.route_id = f.route_id
    JOIN airports o ON o.airport_id = r.origin_airport_id
    JOIN airports d ON d.airport_id = r.dest_airport_id
    GROUP BY o.airport_code, o.city_name, d.airport_code, d.city_name, r.distance_miles
    HAVING COUNT(f.flight_id) >= 100
    ORDER BY avg_arr_delay_min DESC
) WHERE ROWNUM <= 10;

PROMPT ================================================================
PROMPT 4. Gate Returns & Diversion Operational Impact
PROMPT ================================================================
SELECT 
    f.carrier_code,
    COUNT(d.flight_id) AS total_diverted_or_returned,
    SUM(CASE WHEN d.first_dep_time IS NOT NULL THEN 1 ELSE 0 END) AS gate_returns,
    ROUND(AVG(d.total_add_gtime_min), 2) AS avg_gate_return_delay_min,
    MAX(d.longest_add_gtime_min) AS worst_single_gate_return_min,
    SUM(NVL(d.div_airport_landings, 0)) AS diverted_landings
FROM flight_diversions d
JOIN flight_operations f ON f.flight_id = d.flight_id
GROUP BY f.carrier_code
ORDER BY total_diverted_or_returned DESC;

PROMPT ================================================================
PROMPT 5. Assessed DOT Tarmac Violation Civil Penalties
PROMPT ================================================================
SELECT 
    f.carrier_code,
    a.carrier_name,
    COUNT(v.violation_id) AS total_violations,
    MAX(v.metric_value_min) AS worst_tarmac_min,
    TO_CHAR(SUM(v.fine_assessed_usd), '$999,999,999.00') AS total_assessed_fines
FROM regulatory_violations v
JOIN flight_operations f ON f.flight_id = v.flight_id
JOIN airlines a ON a.carrier_code = f.carrier_code
GROUP BY f.carrier_code, a.carrier_name
ORDER BY total_violations DESC;

PROMPT ================================================================
PROMPT 6. Aircraft Model Reliability & Maintenance Attributions
PROMPT ================================================================
SELECT 
    m.model_name,
    m.manufacturer,
    m.aircraft_type,
    COUNT(DISTINCT f.tail_num) AS active_aircraft_count,
    COUNT(f.flight_id) AS total_flights,
    ROUND(AVG(d.carrier_delay), 2) AS avg_carrier_maintenance_delay_min
FROM flight_operations f
JOIN aircraft_fleet fl ON fl.tail_num = f.tail_num
JOIN aircraft_models m ON m.model_id = fl.model_id
LEFT JOIN delay_attributions d ON d.flight_id = f.flight_id
GROUP BY m.model_name, m.manufacturer, m.aircraft_type
ORDER BY avg_carrier_maintenance_delay_min DESC;

PROMPT ================================================================
PROMPT 7. Departure Taxi Efficiency Across Top 10 Busiest Hubs (CTE)
PROMPT ================================================================
WITH hub_traffic AS (
    SELECT 
        o.airport_code,
        o.city_name,
        COUNT(f.flight_id) AS departures_count,
        ROUND(AVG(f.taxi_out_min), 2) AS avg_taxi_out,
        ROUND(AVG(f.dep_delay_min), 2) AS avg_dep_delay
    FROM flight_operations f
    JOIN flight_routes r ON r.route_id = f.route_id
    JOIN airports o ON o.airport_id = r.origin_airport_id
    WHERE f.cancelled = 0
    GROUP BY o.airport_code, o.city_name
)
SELECT * FROM (
    SELECT 
        airport_code,
        city_name,
        departures_count,
        avg_taxi_out,
        avg_dep_delay,
        RANK() OVER (ORDER BY avg_taxi_out DESC) AS taxi_congestion_rank
    FROM hub_traffic
    ORDER BY departures_count DESC
) WHERE ROWNUM <= 10;

PROMPT ================================================================
PROMPT 8. Hourly Congestion & Delay Progression Across the Day
PROMPT ================================================================
SELECT 
    TRUNC(crs_dep_time / 100) AS scheduled_hour,
    COUNT(flight_id) AS scheduled_flights,
    ROUND(AVG(dep_delay_min), 2) AS avg_dep_delay_min,
    ROUND(AVG(arr_delay_min), 2) AS avg_arr_delay_min,
    ROUND(100 * SUM(CASE WHEN arr_delay_min > 15 THEN 1 ELSE 0 END) / COUNT(flight_id), 2) AS late_flight_pct
FROM flight_operations
WHERE cancelled = 0 AND crs_dep_time IS NOT NULL
GROUP BY TRUNC(crs_dep_time / 100)
ORDER BY scheduled_hour;

PROMPT ================================================================
PROMPT 9. Diversion Recovery: Landed Alternate vs Reached Destination
PROMPT ================================================================
SELECT 
    NVL(d.div1_airport_code, 'N/A') AS diverted_airport,
    COUNT(d.flight_id) AS total_diversion_landings,
    SUM(CASE WHEN d.div_reached_dest = 1 THEN 1 ELSE 0 END) AS successfully_resumed,
    SUM(CASE WHEN d.div_reached_dest = 0 THEN 1 ELSE 0 END) AS terminated_at_diversion,
    ROUND(AVG(d.div_arr_delay_min), 1) AS avg_final_arrival_delay_min
FROM flight_diversions d
WHERE d.div1_airport_code IS NOT NULL
GROUP BY d.div1_airport_code
HAVING COUNT(d.flight_id) >= 15
ORDER BY total_diversion_landings DESC;

PROMPT ================================================================
PROMPT 10. Inter-State Travel Corridors Delay Analysis
PROMPT ================================================================
SELECT * FROM (
    SELECT 
        o.state_abr || ' -> ' || d.state_abr AS state_corridor,
        COUNT(f.flight_id) AS flight_volume,
        ROUND(AVG(f.arr_delay_min), 2) AS avg_delay_min,
        ROUND(100 * SUM(f.cancelled) / COUNT(f.flight_id), 2) AS cancellation_rate_pct
    FROM flight_operations f
    JOIN flight_routes r ON r.route_id = f.route_id
    JOIN airports o ON o.airport_id = r.origin_airport_id
    JOIN airports d ON d.airport_id = r.dest_airport_id
    WHERE o.state_abr IS NOT NULL AND d.state_abr IS NOT NULL
      AND o.state_abr <> d.state_abr
    GROUP BY o.state_abr, d.state_abr
    HAVING COUNT(f.flight_id) >= 1000
    ORDER BY avg_delay_min DESC
) WHERE ROWNUM <= 10;

SPOOL OFF;
SET TIMING OFF;
PROMPT All analytical queries executed successfully! Output saved to data\05_queries_output.txt.