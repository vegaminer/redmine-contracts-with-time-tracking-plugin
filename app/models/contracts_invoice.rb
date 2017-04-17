class ContractsInvoice < ActiveRecord::Base
  belongs_to :contract
  validates_presence_of :invoice_number, :invoice_date, :amount, :contract_id
  validates :amount, :numericality => { :greater_than => 0 }

  enum status: {
      draft: 0,
      sent: 1,
      paid: 2
  }

  DRAFT = "draft"
  SENT  = "sent"
  PAID  = "paid"

  INVOICE_STATUS = [DRAFT, SENT, PAID]

end
