class AddRecurringContracts < ActiveRecord::Migration[4.2]
  def up
    unless column_exists? :contracts, :recurring_frequency
      add_column :contracts, :recurring_frequency, :integer, :default => 0
    end
    unless column_exists? :contracts, :series_id
      add_column :contracts, :series_id, :integer
    end
  end

  def down
    remove_column :contracts, :recurring_frequency
    remove_column :contracts, :series_id
  end
end
