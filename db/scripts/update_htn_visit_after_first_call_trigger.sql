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
    RAISE NOTICE 'Trigger invoked....';

    IF NEW.programstageid = (SELECT programstageid FROM programstage WHERE uid = calling_report_program_stage_uid) THEN
        -- Query the programstageinstance table to find the latest overdue event of the HTN & diabetes program stage

        SELECT eventdatavalues, programstageinstanceid INTO latest_overdue_event_data, latest_overdue_event_id
        FROM programstageinstance
        WHERE programinstanceid = NEW.programinstanceid
          AND programstageid = (SELECT programstageid FROM programstage WHERE uid = htn_diabetes_program_stage_uid)
          AND deleted = 'f'
          AND status = 'SCHEDULE'
          AND duedate < NEW.executiondate
        ORDER BY duedate DESC
        LIMIT 1;

        IF (latest_overdue_event_data IS NULL) OR NOT ( latest_overdue_event_data ? first_call_date_data_element_uid) THEN
            -- Update eventdatavalues in HTN & diabetes event program stage
            RAISE NOTICE 'Adding first call details....';

            latest_overdue_event_data = latest_overdue_event_data || NEW.eventdatavalues || jsonb_build_object(
                    first_call_date_data_element_uid,
                    jsonb_build_object(
                            'value',
                            NEW.executiondate,
                            'created',
                            NEW.created,
                            'lastUpdated',
                            NEW.lastUpdated,
                            'providedElsewhere',
                            false
                        )
                );

            UPDATE
                programstageinstance
            SET
                eventdatavalues = latest_overdue_event_data
            WHERE
                    programstageinstanceid = latest_overdue_event_id;

            RAISE NOTICE 'Updated event deatils.....';

        ELSE RAISE NOTICE 'Ignore other calls';

        END IF;
    END IF;

    RETURN NEW;

END;

$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER after_insert_calling_report_programstageinstance
    AFTER INSERT ON programstageinstance
    FOR EACH ROW
EXECUTE FUNCTION update_htn_visit_after_first_call_trigger();