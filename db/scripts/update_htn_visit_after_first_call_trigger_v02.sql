CREATE OR REPLACE FUNCTION update_ncd_patient_status(program_instance_id BIGINT, remove_reason TEXT) RETURNS VOID AS
$$
DECLARE
    ncd_patient_status_tea_uid TEXT := 'fI1P3Mg1zOZ';
BEGIN
    UPDATE trackedentityattributevalue
    SET value = CASE
                    WHEN remove_reason = 'DIED' THEN 'DIED'
                    WHEN remove_reason = 'TRANSFERRED_TO_PRIVATE_PRACTITIONER' THEN 'TRANSFER'
                    WHEN remove_reason = 'TRANSFERRED_TO_ANOTHER_FACILITY' THEN 'TRANSFER'
                    WHEN remove_reason = 'MOVED' THEN 'TRANSFER'
                    ELSE value
        END
    WHERE trackedentityattributeid =
          ( SELECT trackedentityattributeid FROM trackedentityattribute WHERE uid = ncd_patient_status_tea_uid )
      AND trackedentityinstanceid =
          ( SELECT trackedentityinstanceid FROM programinstance WHERE programinstanceid = program_instance_id );

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error updating patient status: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_htn_visit_after_first_call_trigger()
    RETURNS TRIGGER AS
$$
DECLARE
    htn_diabetes_program_stage_uid              TEXT := 'anb2cjLx3WM';
    calling_report_program_stage_uid            TEXT := 'W7BCOaSquMd';
    first_call_date_data_element_uid            TEXT := 'XMtcYl6Y3Jp';
    result_of_call_data_element_uid             TEXT := 'q362A7evMYt';
    remove_from_overdue_reason_data_element_uid TEXT := 'MZkqsWH2KSe';
    previous_visit_date                         TIMESTAMP;
    first_calling_report_data                   JSONB;
    first_calling_report_id                     BIGINT;
    first_calling_report_date                   TIMESTAMP;
BEGIN
    -- Update event status from OVERDUE to SCHEDULE
    IF NEW.programstageid = ( SELECT programstageid FROM programstage WHERE uid = htn_diabetes_program_stage_uid ) AND
       NEW.status IN ('OVERDUE') THEN
        NEW.status := 'SCHEDULE';
    END IF;

    -- Check if the newly inserted row corresponds to the calling report program stage
    IF NEW.programstageid =
       ( SELECT programstageid FROM programstage WHERE uid = calling_report_program_stage_uid ) THEN

        IF (NEW.eventdatavalues -> result_of_call_data_element_uid ->> 'value') = 'REMOVE_FROM_OVERDUE' THEN
            PERFORM update_ncd_patient_status(NEW.programinstanceid,
                                              NEW.eventdatavalues -> remove_from_overdue_reason_data_element_uid ->>
                                              'value');
        END IF;
        -- Check if the newly inserted row corresponds to the visit program stage
        -- **Note** If the health worker skips a scheduled event after or before creating
        -- an new visit event, the scheduled date is lost. This means this patient will
        -- not be counted as overdue in the statistics. This workflow needs to prevented
        -- by proper training.

    ELSEIF (NEW.programstageid =
            ( SELECT programstageid FROM programstage WHERE uid = htn_diabetes_program_stage_uid ) AND
            NEW.status IN ('ACTIVE', 'COMPLETED')) THEN

        -- Find the execution date of the previous visit
        SELECT MAX(psi.executiondate)
        INTO previous_visit_date
        FROM programstageinstance psi
        JOIN programstage ps ON psi.programstageid = ps.programstageid
        WHERE psi.programinstanceid = NEW.programinstanceid
          AND psi.executiondate < NEW.executiondate
          AND ps.uid = htn_diabetes_program_stage_uid;

        -- Find the execution date of the first calling report of the month between the previous visit and the current visit

        SELECT executiondate, programstageinstanceid, eventdatavalues
        INTO first_calling_report_date, first_calling_report_id, first_calling_report_data
        FROM ( SELECT *,
                      ROW_NUMBER()
                      OVER (PARTITION BY psi.programinstanceid, DATE_TRUNC('month', psi.executiondate) ORDER BY psi.executiondate) AS call_number
               FROM programstageinstance psi
               JOIN programstage ps ON psi.programstageid = ps.programstageid
               WHERE psi.programinstanceid = NEW.programinstanceid
                 AND psi.executiondate >= previous_visit_date
                 AND psi.executiondate < NEW.executiondate
                 AND ps.uid = calling_report_program_stage_uid
             ) AS first_call_report_of_month
        WHERE call_number = 1
        ORDER BY executiondate DESC
        LIMIT 1;

        first_calling_report_data = COALESCE(NEW.eventdatavalues, '{}'::jsonb) ||
                                    first_calling_report_data ||
                                    JSONB_BUILD_OBJECT(
                                            first_call_date_data_element_uid,
                                            JSONB_BUILD_OBJECT(
                                                    'value', first_calling_report_date,
                                                    'created', ( SELECT created
                                                                 FROM programstageinstance
                                                                 WHERE programstageinstanceid = first_calling_report_id
                                                               ),
                                                    'lastUpdated', ( SELECT lastupdated
                                                                     FROM programstageinstance
                                                                     WHERE programstageinstanceid = first_calling_report_id
                                                                   ),
                                                    'providedElsewhere', FALSE
                                                )
                                        );
        NEW.eventdatavalues := first_calling_report_data;
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
    AFTER INSERT OR UPDATE
    ON programstageinstance
    FOR EACH ROW
    WHEN (PG_TRIGGER_DEPTH() = 0)
EXECUTE FUNCTION update_htn_visit_after_first_call_trigger();
