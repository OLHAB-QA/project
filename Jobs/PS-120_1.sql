BEGIN
    DBMS_SCHEDULER.create_job (
        job_name        => 'JOB_SYNC_NBU',
        job_type        => 'PLSQL_BLOCK',
        job_action      => 'BEGIN util_p.api_nbu_sync; END;',
        start_date      => SYSTIMESTAMP,
        repeat_interval => 'FREQ=DAILY; BYHOUR=6; BYMINUTE=0; BYSECOND=0',
        enabled         => TRUE
    );
END;
/