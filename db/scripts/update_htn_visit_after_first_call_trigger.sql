CREATE OR REPLACE FUNCTION update_patient_status(program_instance_id BIGINT, remove_reason TEXT) RETURNS VOID AS
$$
DECLARE
    tracked_entity_attribute_uid   TEXT := 'fI1P3Mg1zOZ';
BEGIN
    UPDATE trackedentityattributevalue
    SET value = CASE
                    WHEN remove_reason = 'DIED' THEN 'DIED'
                    WHEN remove_reason = 'TRANSFERRED_TO_PRIVATE_PRACTITIONER' THEN 'TRANSFER'
                    WHEN remove_reason = 'TRANSFERRED_TO_ANOTHER_FACILITY' THEN 'TRANSFER'
                    WHEN remove_reason = 'MOVED' THEN 'TRANSFER'
        ELSE value
        END
    WHERE trackedentityattributeid = (select trackedentityattributeid from trackedentityattribute where uid = tracked_entity_attribute_uid)
      AND trackedentityinstanceid = (select trackedentityinstanceid from programinstance where programinstanceid = program_instance_id);

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error updating patient status: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_htn_visit_after_first_call_trigger()
    RETURNS TRIGGER AS $$
DECLARE
    htn_diabetes_program_stage_uid              TEXT := 'anb2cjLx3WM';
    calling_report_program_stage_uid            TEXT := 'W7BCOaSquMd';
    first_call_date_data_element_uid            TEXT := 'RQqUzIsuj7t';
    result_of_call_data_element_uid             TEXT := 'q362A7evMYt';
    remove_from_overdue_reason_data_element_uid TEXT := 'MZkqsWH2KSe';
    latest_overdue_event_data                   JSONB;
    latest_overdue_event_id                     BIGINT;
BEGIN
    -- Check if the newly inserted row corresponds to the calling report program stage
    IF NEW.programstageid =
       ( SELECT programstageid FROM programstage WHERE uid = calling_report_program_stage_uid ) THEN
        -- Query the programstageinstance table to find the latest overdue event of the HTN & diabetes program stage

        IF (NEW.eventdatavalues -> result_of_call_data_element_uid ->> 'value') = 'REMOVE_FROM_OVERDUE' THEN
            PERFORM update_patient_status(NEW.programinstanceid,
                                          NEW.eventdatavalues -> remove_from_overdue_reason_data_element_uid ->>
                                          'value');
        END IF;

        SELECT eventdatavalues, programstageinstanceid
        INTO latest_overdue_event_data, latest_overdue_event_id
        FROM programstageinstance
        WHERE programinstanceid = NEW.programinstanceid
          AND programstageid = ( SELECT programstageid FROM programstage WHERE uid = htn_diabetes_program_stage_uid )
          AND deleted = 'f'
          AND status = 'SCHEDULE'
          AND duedate::date < NEW.executiondate::date
        ORDER BY duedate DESC
        LIMIT 1;

        IF (latest_overdue_event_data IS NULL) OR
           NOT (latest_overdue_event_data ? first_call_date_data_element_uid) OR
           (NEW.executiondate::date <
            (latest_overdue_event_data -> first_call_date_data_element_uid ->> 'value')::date) OR
           (NEW.executiondate::date >
            (latest_overdue_event_data -> first_call_date_data_element_uid ->> 'value')::date AND
            (DATE_PART('year', NEW.executiondate::date) >
             DATE_PART('year', (latest_overdue_event_data -> first_call_date_data_element_uid ->> 'value')::date) OR
             (DATE_PART('year', NEW.executiondate::date) =
              DATE_PART('year', (latest_overdue_event_data -> first_call_date_data_element_uid ->> 'value')::date) AND
              DATE_PART('month', NEW.executiondate::date) >
              DATE_PART('month', (latest_overdue_event_data -> first_call_date_data_element_uid ->> 'value')::date)))
               ) THEN
            RAISE NOTICE 'Update eventdatavalues in HTN & diabetes event program stage.';
            latest_overdue_event_data = COALESCE(latest_overdue_event_data, '{}'::jsonb) || JSONB_BUILD_OBJECT(
                    first_call_date_data_element_uid,
                    JSONB_BUILD_OBJECT(
                            'value', NEW.executiondate,
                            'created', NEW.created,
                            'lastUpdated', NEW.lastUpdated,
                            'providedElsewhere', FALSE
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
