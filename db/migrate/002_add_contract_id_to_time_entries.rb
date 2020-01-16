class AddContractIdToTimeEntries < ActiveRecord::Migration[4.2]
  def change
    add_column :time_entries, :contract_id, :integer
  end
end
