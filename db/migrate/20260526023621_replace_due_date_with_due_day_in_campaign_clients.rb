class ReplaceDueDateWithDueDayInCampaignClients < ActiveRecord::Migration[8.1]
  def up
    add_column :campaign_clients, :due_day, :integer

    # Migrate existing data: extract the day number from next_due_date.
    # Rows with a null next_due_date fall back to day 1.
    execute "UPDATE campaign_clients SET due_day = EXTRACT(DAY FROM next_due_date)::integer WHERE next_due_date IS NOT NULL"
    execute "UPDATE campaign_clients SET due_day = 1 WHERE due_day IS NULL"

    # Clamp to 30 (max allowed day)
    execute "UPDATE campaign_clients SET due_day = 30 WHERE due_day > 30"

    change_column_null :campaign_clients, :due_day, false

    remove_column :campaign_clients, :next_due_date
  end

  def down
    add_column :campaign_clients, :next_due_date, :date

    # Approximate: reconstruct next_due_date as the next occurrence of due_day from today.
    execute <<~SQL
      UPDATE campaign_clients
      SET next_due_date = (
        CASE
          WHEN EXTRACT(DAY FROM CURRENT_DATE)::integer <= due_day
            THEN (DATE_TRUNC('month', CURRENT_DATE) + (due_day - 1) * INTERVAL '1 day')::date
          ELSE
            (DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 month' + (due_day - 1) * INTERVAL '1 day')::date
        END
      )
    SQL

    remove_column :campaign_clients, :due_day
  end
end
