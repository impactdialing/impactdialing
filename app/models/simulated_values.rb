class SimulatedValues < ActiveRecord::Base
end

# ## Schema Information
#
# Table name: `simulated_values`
#
# ### Columns
#
# Name                        | Type               | Attributes
# --------------------------- | ------------------ | ---------------------------
# **`id`**                    | `integer`          | `not null, primary key`
# **`campaign_id`**           | `integer`          |
# **`created_at`**            | `datetime`         |
# **`updated_at`**            | `datetime`         |
# **`best_dials`**            | `float`            |
# **`best_conversation`**     | `float`            |
# **`longest_conversation`**  | `float`            |
# **`best_wrapup_time`**      | `float`            |
#
