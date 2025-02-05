CREATE OR REPLACE PROCEDURE copy_table(
    p_source_scheme IN VARCHAR2,
    p_target_scheme IN VARCHAR2 DEFAULT USER,
    p_list_table    IN VARCHAR2,
    p_copy_data     IN BOOLEAN DEFAULT FALSE,
    po_result       OUT VARCHAR2
) AS
    v_proc_name CONSTANT VARCHAR2(50) := 'copy_table';
    v_sql       VARCHAR2(4000); 
    v_count     NUMBER; 

  
    CURSOR cur_tables IS 
        SELECT t.table_name, 
               'CREATE TABLE ' || p_target_scheme || '.' || t.table_name || ' (' ||
               LISTAGG(t.column_name || ' ' || t.data_type || t.count_symbol, ', ') 
               WITHIN GROUP (ORDER BY t.column_id) || ')' AS ddl_code
        FROM (SELECT table_name,
                     column_name,
                     data_type,
                     CASE
                         WHEN data_type IN ('VARCHAR2', 'CHAR') THEN '(' || data_length || ')'
                         WHEN data_type = 'DATE' THEN NULL
                         WHEN data_type = 'NUMBER' THEN REPLACE('(' || data_precision || ',' || data_scale || ')', '(,)', NULL)
                     END AS count_symbol,
                     column_id
              FROM all_tab_columns
              WHERE owner = p_source_scheme
              AND table_name IN (SELECT regexp_substr(p_list_table, '[^,]+', 1, level) 
                                 FROM dual 
                                 CONNECT BY level <= length(p_list_table) - length(replace(p_list_table, ',', '')) + 1)
              ORDER BY table_name, column_id) t
        GROUP BY t.table_name;

    
    PROCEDURE do_create_table(p_sql IN VARCHAR2) IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        EXECUTE IMMEDIATE p_sql;
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            log_util.log_error(v_proc_name, SQLERRM, 'Помилка при створенні таблиці');
            ROLLBACK;
    END do_create_table;

BEGIN
   
    log_util.log_start(v_proc_name, 'Початок копіювання таблиць.');

   
    FOR rec IN cur_tables LOOP
      
        SELECT COUNT(*) INTO v_count
        FROM all_tables
        WHERE owner = p_target_scheme AND table_name = rec.table_name;

        IF v_count = 0 THEN
            BEGIN
             
                do_create_table(rec.ddl_code);
                log_util.to_log(v_proc_name, 'Таблиця створена: ' || rec.table_name);
                
           
                IF p_copy_data THEN
                    v_sql := 'INSERT INTO ' || p_target_scheme || '.' || rec.table_name ||
                             ' SELECT * FROM ' || p_source_scheme || '.' || rec.table_name;
                    EXECUTE IMMEDIATE v_sql;
                    log_util.to_log(v_proc_name, 'Дані скопійовано: ' || rec.table_name);
                END IF;

            EXCEPTION
                WHEN OTHERS THEN
                    log_util.log_error(v_proc_name, SQLERRM, 'Помилка при копіюванні таблиці: ' || rec.table_name);
                    CONTINUE; 
            END;
        ELSE
            log_util.to_log(v_proc_name, 'Таблиця пропущена (вже існує): ' || rec.table_name);
        END IF;
    END LOOP;

  
    log_util.log_finish(v_proc_name, 'Копіювання завершено');
    po_result := 'Копіювання завершено';
EXCEPTION
    WHEN OTHERS THEN
        po_result := 'Помилка: ' || SQLERRM;
        log_util.log_error(v_proc_name, SQLERRM, 'Загальна помилка в copy_table');
END copy_table;
/
