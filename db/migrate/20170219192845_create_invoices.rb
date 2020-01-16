class CreateInvoices < ActiveRecord::Migration[4.2]
  def change
    create_table :contracts_invoices do |t|
      t.integer :invoice_number
      t.date :invoice_date
      t.float :amount, :length => 10, :decimals => 2
      t.integer :contract_id
    end
  end
end
