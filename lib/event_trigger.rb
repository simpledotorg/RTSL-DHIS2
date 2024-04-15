# frozen_string_literal: true

# This is a placeholder class for the trigger function - 'update_htn_visits_after_first_call_trigger' in Database.
class EventTrigger

  # This trigger function is invoked when a calling report event is created in the dhis2 instance.
  # Once it's invoked, it fetches the latest 'htn & diabetes visit' event which is overdue as of the `eventDate` of the
  # 'calling report' event. If an overdue `htn & diabetes visit` event exists and it doesn't already have the details of
  # a calling report event then the function saves the date of first call (`eventDate` of calling report event), 'result of
  # call' data element and 'remove from overdue list because:' data element.
  def update_overdue_htn_visit_event_after_first_call
    puts 'This function is a placeholder for the trigger function in Database'
  end
end
