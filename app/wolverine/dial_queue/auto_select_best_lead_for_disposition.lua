--house       = households.find(phone)
--leads       = house[:leads].sort_by{|lead| lead['sequence'].to_i}
--lead        = leads.detect{|v| v['sql_id'].blank?}
--lead      ||= leads.detect{|v| (not households.lead_completed?)}

