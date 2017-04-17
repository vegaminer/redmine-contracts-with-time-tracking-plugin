class AddStatusToInvoices < ActiveRecord::Migration
  def change
    add_column :contracts_invoices , :status, :integer, :default => 0
  end
end