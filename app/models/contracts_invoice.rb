class ContractsInvoice < ActiveRecord::Base
  belongs_to :contract
  validates_presence_of :invoice_number, :invoice_date, :amount, :contract_id
  validates :amount, :numericality => { :greater_than => 0 }

end
