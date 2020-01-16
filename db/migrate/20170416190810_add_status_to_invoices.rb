class AddStatusToInvoices < ActiveRecord::Migration[4.2]
  def change
    add_column :contracts_invoices , :status, :integer, :default => 0
  end
end
