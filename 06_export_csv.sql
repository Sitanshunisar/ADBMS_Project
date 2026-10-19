SET HEADING OFF
SET FEEDBACK OFF
SET ECHO OFF
SET TERMOUT OFF
SET TRIMSPOOL ON
SET LINESIZE 32767
SET PAGESIZE 0
SET ARRAYSIZE 5000

-- 1. Export AIRPORTS
SPOOL C:\database_project\airports.csv
PROMPT AIRPORT_ID,AIRPORT_CODE,CITY_NAME,STATE_ABR,STATE_NAME,CITY_MARKET_ID
SELECT airport_id || ',"' || airport_code || '","' || REPLACE(city_name, '"', '""') || '","' || state_abr || '","' || REPLACE(state_name, '"', '""') || '",' || city_market_id
FROM airports
ORDER BY airport_id;
SPOOL OFF;

-- 2. Export AIRLINES
SPOOL C:\database_project\airlines.csv
PROMPT CARRIER_CODE,AIRLINE_ID,CARRIER_NAME
SELECT carrier_code || ',' || airline_id || ',"' || REPLACE(carrier_name, '"', '""') || '"'
FROM airlines
ORDER BY carrier_code;
SPOOL OFF;

-- 3. Export AIRCRAFT_MODELS
SPOOL C:\database_project\aircraft_models.csv
PROMPT MODEL_ID,MODEL_NAME,MANUFACTURER,DEFAULT_SEATS,AIRCRAFT_TYPE
SELECT model_id || ',"' || model_name || '","' || manufacturer || '",' || default_seats || ',"' || aircraft_type || '"'
FROM aircraft_models
ORDER BY model_id;
SPOOL OFF;

-- 4. Export AIRCRAFT_FLEET
SPOOL C:\database_project\aircraft_fleet.csv
PROMPT TAIL_NUM,CARRIER_CODE,MODEL_ID
SELECT tail_num || ',"' || carrier_code || '",' || model_id
FROM aircraft_fleet
ORDER BY tail_num;
SPOOL OFF;

-- 5. Export FLIGHT_ROUTES
SPOOL C:\database_project\flight_routes.csv
PROMPT ROUTE_ID,ORIGIN_AIRPORT_ID,DEST_AIRPORT_ID,DISTANCE_MILES
SELECT route_id || ',' || origin_airport_id || ',' || dest_airport_id || ',' || distance_miles
FROM flight_routes
ORDER BY route_id;
SPOOL OFF;

-- 6. Export DELAY_ATTRIBUTIONS
SPOOL C:\database_project\delay_attributions.csv
PROMPT FLIGHT_ID,CARRIER_DELAY,WEATHER_DELAY,NAS_DELAY,SECURITY_DELAY,LATE_AIRCRAFT_DELAY
SELECT flight_id || ',' || carrier_delay || ',' || weather_delay || ',' || nas_delay || ',' || security_delay || ',' || late_aircraft_delay
FROM delay_attributions
ORDER BY flight_id;
SPOOL OFF;

-- 7. Export FLIGHT_DIVERSIONS
SPOOL C:\database_project\flight_diversions.csv
PROMPT FLIGHT_ID,FIRST_DEP_TIME,TOTAL_ADD_GTIME_MIN,LONGEST_ADD_GTIME_MIN,DIV_AIRPORT_LANDINGS,DIV_REACHED_DEST,DIV_ACTUAL_ELAPSED_MIN,DIV_ARR_DELAY_MIN,DIV_DISTANCE_MILES,DIV1_AIRPORT_CODE,DIV1_AIRPORT_ID
SELECT flight_id || ',' || first_dep_time || ',' || total_add_gtime_min || ',' || longest_add_gtime_min || ',' || div_airport_landings || ',' || div_reached_dest || ',' || div_actual_elapsed_min || ',' || div_arr_delay_min || ',' || div_distance_miles || ',"' || div1_airport_code || '",' || div1_airport_id
FROM flight_diversions
ORDER BY flight_id;
SPOOL OFF;

-- 8. Export FLIGHT_OPERATIONS (631,970 rows)
SPOOL C:\database_project\flight_operations.csv
PROMPT FLIGHT_ID,FLIGHT_DATE,CARRIER_CODE,FLIGHT_NUM,TAIL_NUM,ROUTE_ID,CRS_DEP_TIME,DEP_TIME,DEP_DELAY_MIN,TAXI_OUT_MIN,WHEELS_OFF,WHEELS_ON,TAXI_IN_MIN,CRS_ARR_TIME,ARR_TIME,ARR_DELAY_MIN,CANCELLED,CANCELLATION_CODE,DIVERTED,CRS_ELAPSED_TIME_MIN,ACTUAL_ELAPSED_TIME_MIN,AIR_TIME_MIN
SELECT 
    flight_id || ',' || 
    TO_CHAR(flight_date, 'YYYY-MM-DD') || ',"' || 
    carrier_code || '",' || 
    flight_num || ',"' || 
    NVL(tail_num, '') || '",' || 
    route_id || ',' || 
    crs_dep_time || ',' || 
    dep_time || ',' || 
    dep_delay_min || ',' || 
    taxi_out_min || ',' || 
    wheels_off || ',' || 
    wheels_on || ',' || 
    taxi_in_min || ',' || 
    crs_arr_time || ',' || 
    arr_time || ',' || 
    arr_delay_min || ',' || 
    cancelled || ',"' || 
    NVL(cancellation_code, '') || '",' || 
    diverted || ',' || 
    crs_elapsed_time_min || ',' || 
    actual_elapsed_time_min || ',' || 
    air_time_min
FROM flight_operations
ORDER BY flight_id;
SPOOL OFF;

SET TERMOUT ON
SET FEEDBACK ON
SET HEADING ON
PROMPT All 8 tables exported to CSV in C:\database_project successfully!