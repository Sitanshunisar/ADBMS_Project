SET LINESIZE 220;
SET PAGESIZE 50;

PROMPT ================================================================
PROMPT 1. Carrier Reliability & Punctuality Ranking
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
    ROUND(SUM(carrier_delay), 0)       AS total_carrier_delay_min,
    ROUND(SUM(weather_delay), 0)       AS total_weather_delay_min,
    ROUND(SUM(nas_delay), 0)           AS total_nas_delay_min,
    ROUND(SUM(late_aircraft_delay), 0) AS total_late_aircraft_min,
    ROUND(100 * SUM(carrier_delay) / 
          NULLIF(SUM(carrier_delay + weather_delay + nas_delay + late_aircraft_delay), 0), 2) AS carrier_fault_pct,
    ROUND(100 * SUM(weather_delay) / 
          NULLIF(SUM(carrier_delay + weather_delay + nas_delay + late_aircraft_delay), 0), 2) AS weather_pct
FROM delay_attributions;

PROMPT ================================================================
PROMPT 3. Top 10 Most Delayed Airport Pairs (IATA Codes)
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
PROMPT 4. Diversions and Gate Returns Summary
PROMPT ================================================================
SELECT 
    f.carrier_code,
    COUNT(d.flight_id) AS total_diverted_or_returned,
    SUM(CASE WHEN d.first_dep_time IS NOT NULL THEN 1 ELSE 0 END) AS gate_returns,
    ROUND(AVG(d.total_add_gtime_min), 2) AS avg_gate_return_delay_min,
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