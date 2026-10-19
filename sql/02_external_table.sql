SET DEFINE OFF;

BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE ext_flight_raw PURGE';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/

CREATE TABLE ext_flight_raw (
    year                    VARCHAR2(10),
    month                   VARCHAR2(10),
    day_of_month            VARCHAR2(10),
    fl_date                 VARCHAR2(30),
    op_unique_carrier       VARCHAR2(10),
    op_carrier_airline_id   VARCHAR2(10),
    op_carrier              VARCHAR2(50),
    tail_num                VARCHAR2(20),
    op_carrier_fl_num       VARCHAR2(10),
    origin_airport_id       VARCHAR2(10),
    origin_airport_seq_id   VARCHAR2(10),
    origin_city_market_id   VARCHAR2(10),
    origin                  VARCHAR2(10),
    origin_city_name        VARCHAR2(100),
    origin_state_abr        VARCHAR2(10),
    origin_state_nm         VARCHAR2(50),
    dest_airport_id         VARCHAR2(10),
    dest_airport_seq_id     VARCHAR2(10),
    dest_city_market_id     VARCHAR2(10),
    dest                    VARCHAR2(10),
    dest_city_name          VARCHAR2(100),
    dest_state_abr          VARCHAR2(10),
    dest_state_nm           VARCHAR2(50),
    crs_dep_time            VARCHAR2(10),
    dep_time                VARCHAR2(10),
    dep_delay               VARCHAR2(10),
    taxi_out                VARCHAR2(10),
    wheels_off              VARCHAR2(10),
    wheels_on               VARCHAR2(10),
    taxi_in                 VARCHAR2(10),
    crs_arr_time            VARCHAR2(10),
    arr_time                VARCHAR2(10),
    arr_delay               VARCHAR2(10),
    cancelled               VARCHAR2(10),
    cancellation_code       VARCHAR2(10),
    diverted                VARCHAR2(10),
    crs_elapsed_time        VARCHAR2(10),
    actual_elapsed_time     VARCHAR2(10),
    air_time                VARCHAR2(10),
    flights                 VARCHAR2(10),
    distance                VARCHAR2(10),
    carrier_delay           VARCHAR2(10),
    weather_delay           VARCHAR2(10),
    nas_delay               VARCHAR2(10),
    security_delay          VARCHAR2(10),
    late_aircraft_delay     VARCHAR2(10),
    first_dep_time          VARCHAR2(10),
    total_add_gtime         VARCHAR2(10),
    longest_add_gtime       VARCHAR2(10),
    div_airport_landings    VARCHAR2(10),
    div_reached_dest        VARCHAR2(10),
    div_actual_elapsed_time VARCHAR2(10),
    div_arr_delay           VARCHAR2(10),
    div_distance            VARCHAR2(10),
    div1_airport            VARCHAR2(10),
    div1_airport_id         VARCHAR2(10)
)
ORGANIZATION EXTERNAL (
    TYPE ORACLE_LOADER
    DEFAULT DIRECTORY bts_data_dir
    ACCESS PARAMETERS (
        RECORDS DELIMITED BY NEWLINE
        SKIP 1
        FIELDS TERMINATED BY ','
        OPTIONALLY ENCLOSED BY '"'
        MISSING FIELD VALUES ARE NULL
    )
    LOCATION ('T_ONTIME_REPORTING.csv')
)
REJECT LIMIT UNLIMITED;

PROMPT External Table ext_flight_raw Created Successfully!