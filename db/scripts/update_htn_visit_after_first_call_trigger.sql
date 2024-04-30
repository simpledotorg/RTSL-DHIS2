CREATE OR REPLACE FUNCTION update_htn_visit_after_first_call_trigger()
    RETURNS TRIGGER AS $$
DECLARE
    htn_diabetes_program_stage_uid TEXT := 'anb2cjLx3WM';
    calling_report_program_stage_uid TEXT := 'W7BCOaSquMd';
    first_call_date_data_element_uid TEXT := 'Y6WYj6bbgeV';

    latest_overdue_event_data JSONB;
    latest_overdue_event_id BIGINT;
BEGIN
    -- Check if the newly inserted row corresponds to the calling report program stage
    IF NEW.programstageid = (SELECT programstageid FROM programstage WHERE uid = calling_report_program_stage_uid) THEN
        -- Query the programstageinstance table to find the latest overdue event of the HTN & diabetes program stage
        SELECT eventdatavalues, programstageinstanceid INTO latest_overdue_event_data, latest_overdue_event_id
        FROM programstageinstance
        WHERE programinstanceid = NEW.programinstanceid
          AND programstageid = (SELECT programstageid FROM programstage WHERE uid = htn_diabetes_program_stage_uid)
          AND deleted = 'f'
          AND status = 'SCHEDULE'
          AND duedate::date < NEW.executiondate::date
        ORDER BY duedate DESC
        LIMIT 1;

        IF (latest_overdue_event_data IS NULL) OR
           NOT (latest_overdue_event_data ? first_call_date_data_element_uid) OR
           (NEW.executiondate::date < (latest_overdue_event_data -> first_call_date_data_element_uid ->> 'value')::date) OR
           (NEW.executiondate::date > (latest_overdue_event_data -> first_call_date_data_element_uid ->> 'value')::date AND
            (DATE_PART('year', NEW.executiondate::date) > DATE_PART('year', (latest_overdue_event_data -> first_call_date_data_element_uid ->> 'value')::date) OR
             (DATE_PART('year', NEW.executiondate::date) = DATE_PART('year', (latest_overdue_event_data -> first_call_date_data_element_uid ->> 'value')::date) AND
              DATE_PART('month', NEW.executiondate::date) > DATE_PART('month', (latest_overdue_event_data -> first_call_date_data_element_uid ->> 'value')::date)))
               ) THEN
            RAISE NOTICE 'Update eventdatavalues in HTN & diabetes event program stage.';
            latest_overdue_event_data = COALESCE(latest_overdue_event_data, '{}'::jsonb) || jsonb_build_object(
                    first_call_date_data_element_uid,
                    jsonb_build_object(
                            'value', NEW.executiondate,
                            'created', NEW.created,
                            'lastUpdated', NEW.lastUpdated,
                            'providedElsewhere', false
                        )
                );

            UPDATE programstageinstance
            SET eventdatavalues = latest_overdue_event_data
            WHERE programstageinstanceid = latest_overdue_event_id;

        ELSE
            RAISE NOTICE 'Ignore current call result';
        END IF;
    END IF;

    RETURN NEW;

EXCEPTION
    WHEN OTHERS THEN
        -- Log the error message
        RAISE NOTICE 'Failed to update HTN & Diabetes visit event with call report event details: %', SQLERRM;
        RETURN NEW;

END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER after_insert_calling_report_programstageinstance
    AFTER INSERT ON programstageinstance
    FOR EACH ROW
EXECUTE FUNCTION update_htn_visit_after_first_call_trigger();
