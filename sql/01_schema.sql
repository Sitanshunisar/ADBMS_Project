SET DEFINE OFF;

PROMPT Dropping existing schema entities (preserving external table)...
BEGIN
    FOR cur_rec IN (SELECT table_name FROM user_tables WHERE table_name NOT IN ('EXT_FLIGHT_RAW')) LOOP
        EXECUTE IMMEDIATE 'DROP TABLE ' || cur_rec.table_name || ' CASCADE CONSTRAINTS PURGE';
    END LOOP;
    FOR cur_rec IN (SELECT sequence_name FROM user_sequences) LOOP
        EXECUTE IMMEDIATE 'DROP SEQUENCE ' || cur_rec.sequence_name;
    END LOOP;
END;
/

PROMPT Creating Sequences...
CREATE SEQUENCE seq_model_id     START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_route_id     START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_flight_id    START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_violation_id START WITH 1 INCREMENT BY 1 NOCACHE;

PROMPT 1/8: Creating AIRPORTS...
CREATE TABLE airports (
    airport_id      NUMBER PRIMARY KEY,
    airport_code    VARCHAR2(5) NOT NULL,
    city_name       VARCHAR2(100),
    state_abr       VARCHAR2(2),
    state_name      VARCHAR2(50),
    city_market_id  NUMBER
);

PROMPT 2/8: Creating AIRLINES...
CREATE TABLE airlines (
    carrier_code    VARCHAR2(10) PRIMARY KEY,
    airline_id      NUMBER UNIQUE,
    carrier_name    VARCHAR2(100)
);

PROMPT 3/8: Creating AIRCRAFT_MODELS...
CREATE TABLE aircraft_models (
    model_id        NUMBER PRIMARY KEY,
    model_name      VARCHAR2(50),
    manufacturer    VARCHAR2(50),
    default_seats   NUMBER,
    aircraft_type   VARCHAR2(20)
);

PROMPT 4/8: Creating AIRCRAFT_FLEET...
CREATE TABLE aircraft_fleet (
    tail_num        VARCHAR2(20) PRIMARY KEY,
    carrier_code    VARCHAR2(10) NOT NULL,
    model_id        NUMBER NOT NULL,
    CONSTRAINT fk_af_carrier FOREIGN KEY (carrier_code) REFERENCES airlines(carrier_code),
    CONSTRAINT fk_af_model   FOREIGN KEY (model_id)     REFERENCES aircraft_models(model_id)
);

PROMPT 5/8: Creating FLIGHT_ROUTES...
CREATE TABLE flight_routes (
    route_id            NUMBER PRIMARY KEY,
    origin_airport_id   NUMBER NOT NULL,
    dest_airport_id     NUMBER NOT NULL,
    distance_miles      NUMBER,
    CONSTRAINT fk_fr_origin FOREIGN KEY (origin_airport_id) REFERENCES airports(airport_id),
    CONSTRAINT fk_fr_dest   FOREIGN KEY (dest_airport_id)   REFERENCES airports(airport_id),
    CONSTRAINT uq_route     UNIQUE (origin_airport_id, dest_airport_id)
);

PROMPT 6/8: Creating FLIGHT_OPERATIONS...
CREATE TABLE flight_operations (
    flight_id               NUMBER PRIMARY KEY,
    flight_date             DATE NOT NULL,
    carrier_code            VARCHAR2(10) NOT NULL,
    flight_num              NUMBER NOT NULL,
    tail_num                VARCHAR2(20),
    route_id                NUMBER NOT NULL,
    crs_dep_time            NUMBER(4),
    dep_time                NUMBER(4),
    dep_delay_min           NUMBER,
    taxi_out_min            NUMBER,
    wheels_off              NUMBER(4),
    wheels_on               NUMBER(4),
    taxi_in_min             NUMBER,
    crs_arr_time            NUMBER(4),
    arr_time                NUMBER(4),
    arr_delay_min           NUMBER,
    cancelled               NUMBER(1) DEFAULT 0,
    cancellation_code       VARCHAR2(1),
    diverted                NUMBER(1) DEFAULT 0,
    crs_elapsed_time_min    NUMBER,
    actual_elapsed_time_min NUMBER,
    air_time_min            NUMBER,
    CONSTRAINT fk_fo_carrier FOREIGN KEY (carrier_code) REFERENCES airlines(carrier_code),
    CONSTRAINT fk_fo_route   FOREIGN KEY (route_id)     REFERENCES flight_routes(route_id)
);

PROMPT 7/8: Creating DELAY_ATTRIBUTIONS...
CREATE TABLE delay_attributions (
    flight_id               NUMBER PRIMARY KEY,
    carrier_delay           NUMBER DEFAULT 0,
    weather_delay           NUMBER DEFAULT 0,
    nas_delay               NUMBER DEFAULT 0,
    security_delay          NUMBER DEFAULT 0,
    late_aircraft_delay     NUMBER DEFAULT 0,
    CONSTRAINT fk_da_flight FOREIGN KEY (flight_id) REFERENCES flight_operations(flight_id)
);

PROMPT 8/8: Creating FLIGHT_DIVERSIONS...
CREATE TABLE flight_diversions (
    flight_id               NUMBER PRIMARY KEY,
    first_dep_time          NUMBER(4),
    total_add_gtime_min     NUMBER,
    longest_add_gtime_min   NUMBER,
    div_airport_landings    NUMBER,
    div_reached_dest        NUMBER(1),
    div_actual_elapsed_min  NUMBER,
    div_arr_delay_min       NUMBER,
    div_distance_miles      NUMBER,
    div1_airport_code       VARCHAR2(10),
    div1_airport_id         NUMBER,
    CONSTRAINT fk_fd_flight FOREIGN KEY (flight_id) REFERENCES flight_operations(flight_id)
);

PROMPT Creating REGULATORY_VIOLATIONS (Audit Table)...
CREATE TABLE regulatory_violations (
    violation_id        NUMBER PRIMARY KEY,
    flight_id           NUMBER NOT NULL,
    violation_type      VARCHAR2(50),
    metric_value_min    NUMBER,
    fine_assessed_usd   NUMBER(12,2),
    logged_at           TIMESTAMP DEFAULT SYSTIMESTAMP,
    notes               VARCHAR2(400),
    CONSTRAINT fk_rv_flight FOREIGN KEY (flight_id) REFERENCES flight_operations(flight_id)
);

PROMPT Schema Definition Complete!