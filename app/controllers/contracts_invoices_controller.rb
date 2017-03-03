class ContractsInvoicesController < ApplicationController
  before_filter :set_project, :authorize, :only => [:new, :edit, :update, :create, :destroy]
  before_filter :set_invoice, :only => [:edit, :update, :destroy]

  def new
    @contracts_invoice = ContractsInvoice.new
    # If creating an invoice from a contract (the usual case), use the provided contract_id (if any)
    @contracts_invoice.contract_id = params[:contract_id]
    load_contracts
  end

  def edit
    load_contracts
  end

  def create
    @contracts_invoice = ContractsInvoice.new(invoice_params)

    respond_to do |format|
      if @contracts_invoice.save
        format.html { redirect_to contract_urlpath(@contracts_invoice), notice: l(:text_invoice_created) }
      else
        load_contracts
        format.html { render action: 'new' }
      end
    end
  end

  def update
    respond_to do |format|
      if @contracts_invoice.update_attributes(invoice_params)
        format.html { redirect_to contract_urlpath(@contracts_invoice), notice: l(:text_invoice_updated) }
      else
        load_contracts
        format.html { render action: 'edit' }
      end
    end
  end

  def destroy
    back_to = contract_urlpath(@contracts_invoice)
    @contracts_invoice.destroy
    flash[:notice] = l(:text_invoice_deleted)
    respond_to do |format|
      format.html { redirect_to back_to }
    end
  end

  private

    def contract_urlpath(invoice)
      url_for({ :controller => 'contracts', :action => 'show', :project_id => invoice.contract.project.identifier, :id => invoice.contract.id, :contracts_invoices => 'true'})
    end

    def set_invoice
      @contracts_invoice = ContractsInvoice.find(params[:id])
      if @contracts_invoice.contract.is_locked
        flash[:error] = l(:text_invoices_uneditable)
        redirect_to contract_urlpath(@contracts_invoice)
      end
    end

    def set_project
      @project = Project.find(params[:project_id])
    end

    def load_contracts
      @contracts = Contract.order("start_date ASC").where(:project_id => @project.id).where(:is_locked => false)
    end

    private

    def invoice_params
      params.require(:contracts_invoice).permit(:invoice_date, :invoice_number, :amount, :contract_id)
    end

end
