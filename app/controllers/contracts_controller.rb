class ContractsController < ApplicationController
  before_action :find_project, :authorize, :only => [:index, :show, :new, :create, :edit, :update, :destroy,
                                                     :add_time_entries, :assoc_time_entries_with_contract, :series]
  before_action :set_contract_visibility, :only => [:index, :all, :series]


  Struct.new("DefaultContract", :project, :hours)

  def index
    show_locked = session[:show_locked_contracts] || (params[:contract_list].present? && params[:contract_list][:show_locked_contracts] == 'true')

    fixed_contracts = Contract.order("start_date ASC").where(:project_id => @project.id, :is_fixed_price => true).where("is_locked = false or is_locked = ?", show_locked)
    hourly_contracts = Contract.order("start_date ASC").where(:project_id => @project.id, :is_fixed_price => false).where("is_locked = false or is_locked = ?", show_locked)

    # Show the tabs only if there are hourly and fixed contracts within the same project.
    if fixed_contracts.size > 0 && hourly_contracts.size > 0
      @show_tabs = true
    end

    # Show fixed contracts if the fixed tab is selected or if there aren't any hourly contracts.
    @show_fixed_contracts = (fixed_contracts.size > 0 && hourly_contracts.size == 0) || params[:fixed_tab_active] == 'true'

    # Set @contracts to the fixed our hourly array of contracts to be displayed.
    if @show_fixed_contracts
      @contracts = fixed_contracts
    else
      @contracts = hourly_contracts
    end
    
    # Calculate metrics for display.
    @total_purchased_dollars = @project.total_amount_purchased
    @total_purchased_fixed = fixed_contracts.map(&:purchase_amount).inject(0, &:+)
    @total_amount_billable_fixed = fixed_contracts.map(&:smart_billable_amount_total).inject(0, &:+) -
        fixed_contracts.map(&:invoices_amount).inject(0, &:+)
    @total_amount_billable_fixed_limit = fixed_contracts.map(&:smart_billable_amount_total_limit).inject(0, &:+) -
        fixed_contracts.map(&:invoices_amount).inject(0, &:+)
    @total_purchased_hourly = hourly_contracts.map(&:purchase_amount).inject(0, &:+)
    @total_purchased_hourly_hours = hourly_contracts.map(&:hours_purchased).inject(0, &:+)
    @total_amount_billable_hourly = hourly_contracts.map(&:smart_billable_amount_total).inject(0, &:+) -
        hourly_contracts.map(&:invoices_amount).inject(0, &:+)
    @total_amount_billable_hourly_limit = hourly_contracts.map(&:smart_billable_amount_total_limit).inject(0, &:+) -
        hourly_contracts.map(&:invoices_amount).inject(0, &:+)
    @total_amount_remaining_hourly = hourly_contracts.map(&:amount_remaining).inject(0, &:+)
    @total_remaining_hours = hourly_contracts.map(&:hours_remaining).inject(0, &:+)

    @defaultContracts = []

    # all time entries
    te = TimeEntry.where(:project_id => @project).to_a
    Contract.where(:project_id => @project).each do |contract|
      te -= contract.smart_time_entries
    end

    unless te.empty?
      @defaultContracts << Struct::DefaultContract.new(@project, te.sum { |entry| entry.hours })
    end

  end

  def default
    @project = Project.find(params[:project_id])

    # all time entries
    @time_entries = TimeEntry.where(:project_id => @project)
    Contract.where(:project_id => @project).each do |contract|
      @time_entries -= contract.smart_time_entries
    end

    @entry_count = @time_entries.count
    @entry_pages = Paginator.new @entry_count, per_page_option, params['page']
    @time_entries_page = @time_entries[@entry_pages.offset, @entry_pages.per_page]
  end

  def all
    show_locked = session[:show_locked_contracts] || (params[:contract_list].present? && params[:contract_list][:show_locked_contracts] == 'true')

    user = User.current
    projects = Project.select { |project| user.allowed_to?(:view_all_contracts_for_project, project) }

    fixed_contracts = projects.collect { |project| project.contracts.order("start_date ASC").where(:is_fixed_price => '1').where("is_locked = false or is_locked = ?", show_locked) }
    fixed_contracts.flatten!
    hourly_contracts = projects.collect { |project| project.contracts.order("start_date ASC").where(:is_fixed_price => '0').where("is_locked = false or is_locked = ?", show_locked) }
    hourly_contracts.flatten!
    all_contracts = projects.collect { |project| project.contracts.order("start_date ASC").where("is_locked = false or is_locked = ?", show_locked) }
    all_contracts.flatten!

    # Show the tabs only if there are hourly and fixed contracts within the same project.
    if fixed_contracts.size > 0 && hourly_contracts.size > 0
      @show_tabs = true
    end

    if params[:invoices_tab_active]
      @show_invoices = true
      @invoices = ContractsInvoice.order(:invoice_date => "desc", :id => "desc").all
    end

    # Show fixed contracts if the fixed tab is selected or if there aren't any hourly contracts.
    @show_fixed_contracts = (fixed_contracts.size > 0 && hourly_contracts.size == 0) || params[:fixed_tab_active] == 'true'

    if @show_fixed_contracts
      @contracts = fixed_contracts
    else
      @contracts = hourly_contracts
    end

    @total_purchased_dollars = all_contracts.map(&:purchase_amount).inject(0, &:+)
    @total_purchased_fixed = fixed_contracts.map(&:purchase_amount).inject(0, &:+)
    @total_purchased_hourly = hourly_contracts.map(&:purchase_amount).inject(0, &:+)
    @total_purchased_hourly_hours = hourly_contracts.map(&:hours_purchased).inject(0, &:+)
    @total_amount_remaining_hourly = hourly_contracts.map(&:amount_remaining).inject(0, &:+)
    @total_remaining_hours = hourly_contracts.map(&:hours_remaining).inject(0, &:+)
    # Show only billable totals for contract that user can see the hourly rate
    @total_amount_billable_fixed = fixed_contracts
                                       .select{ |contrat| User.current.allowed_to?(:view_hourly_rate, contrat.project) }
                                       .sum { |contract| contract.smart_billable_amount_total - contract.invoices_amount }
    @total_amount_billable_fixed_limit = fixed_contracts
                                              .select{ |contrat| User.current.allowed_to?(:view_hourly_rate, contrat.project) }
                                              .sum { |contract| contract.smart_billable_amount_total_limit - contract.invoices_amount }
    @total_amount_billable_hourly = hourly_contracts
                                        .select{ |contrat| User.current.allowed_to?(:view_hourly_rate, contrat.project) }
                                        .sum { |contract| contract.smart_billable_amount_total - contract.invoices_amount }
    @total_amount_billable_hourly_limit = hourly_contracts
                                        .select{ |contrat| User.current.allowed_to?(:view_hourly_rate, contrat.project) }
                                        .sum { |contract| contract.smart_billable_amount_total_limit - contract.invoices_amount }

    @defaultContracts = []

    # all time entries
    te = TimeEntry.visible.to_a
    Contract.all.each do |contract|
      te -= contract.smart_time_entries
    end

    unless te.empty?
      te.uniq{|te| te.project }.each do |te_project|
        @defaultContracts << Struct::DefaultContract.new(te_project.project, te.select { |te| te.project == te_project.project }.sum { |entry| entry.hours })
      end
    end

    render "index"
  end

  def new
    @contract = Contract.new
    @project = Project.find(params[:project_id])
    load_contractors_and_rates
  end

  def create
    if contract_params[:contract_type] != 'recurring'
      params[:contract][:recurring_frequency] = :not_recurring
    end

    @contract = Contract.new(contract_params)

    if !rates_are_valid(params[:rates])
      flash[:error] = l(:text_invalid_rate)
      load_contractors_and_rates
      render :new
      return
    end

    if contract_params[:contract_type] != 'recurring'
      params[:contract][:recurring_frequency] = :not_recurring
    end

    @contract.rates = params[:rates]
    @contract.project_contract_id = @project.contracts.empty? ? 1 : @project.contracts.last.project_contract_id + 1

    # Set the series ID to the project_contract_id if its a new recurring contract.
    @contract.series_id = @contract.project_contract_id if contract_params[:contract_type] == 'recurring'

    if @contract.save
      if contract_params[:contract_type] == 'recurring'
        if @contract.monthly?
          @contract.update_attribute(:end_date, @contract.start_date + 1.month)
        elsif @contract.yearly?
          @contract.update_attribute(:end_date, @contract.start_date + 1.year)
        end
      end

      flash[:notice] = l(:text_contract_saved)
      redirect_to :action => "show", :id => @contract.id
    else
      flash[:error] = "* " + @contract.errors.full_messages.join("</br>* ")
      load_contractors_and_rates
      render :new
    end
  end

  def show
    @contract = Contract.find(params[:id])
    @time_entries = @contract.smart_time_entries.order("spent_on DESC, id DESC")
    @members = []
    @time_entries.each { |entry| @members.append(entry.user) unless @members.include?(entry.user) }
    @expenses_tab = (params[:contracts_expenses] == 'true')
    @invoices_tab = (params[:contracts_invoices] == 'true')
    @summary_tab = (params[:contract_summary] == 'true')
    if @expenses_tab
      @expenses = @contract.contracts_expenses.order(:expense_date => "desc", :id => "desc").all
    end
    if @invoices_tab
      @invoices = @contract.contracts_invoices.order(:invoice_date => "desc", :id => "desc").all
    end
    if @summary_tab
      @issues = []
      @time_entries.each { |entry| @issues.append(entry.issue) unless @issues.include?(entry.issue) }
      @issues.sort! { |a,b| @contract.amount_spent_on_issue(b) <=> @contract.amount_spent_on_issue(a)}
    end

    @entry_count = @time_entries.count
    @entry_pages = Paginator.new @entry_count, per_page_option, params['page']
    @time_entries_page = @time_entries[@entry_pages.offset, @entry_pages.per_page]
  end

  def edit
    @contract = Contract.find(params[:id])
    @projects = Project.all
    load_contractors_and_rates
  end

  def update
    @contract = Contract.find(params[:id])

    if !rates_are_valid(params[:rates])
      flash[:error] = l(:text_invalid_rate)
      redirect_to :action => "edit", :id => @contract.id
      return
    end

    # Set the end date to null so that the start_date end_date validation passes
    # if the start date is changed to after the end date.
    if @contract.contract_type == 'recurring'
      params[:contract][:end_date] = nil
      @contract.end_date = nil
    end

    if @contract.update_attributes(contract_params)
      @contract.update_attribute(:rates, params[:rates])
      if @contract.contract_type == 'recurring'
        if @contract.monthly?
          @contract.update_attribute(:end_date, @contract.start_date + 1.month)
        elsif @contract.yearly?
          @contract.update_attribute(:end_date, @contract.start_date + 1.year)
        end
      end
      flash[:notice] = l(:text_contract_updated)
      redirect_back_or_default url_for({ :controller => 'contracts', :action => 'show', :project_id => @contract.project.identifier, :id => @contract.id })
    else
      flash[:error] = "* " + @contract.errors.full_messages.join("</br>* ")
      redirect_to :action => "edit", :id => @contract.id
    end
  end

  def series
    @contracts = Contract.order("start_date ASC").where(:project_id => @project.id, :series_id => params[:id])
    @show_fixed_contracts = true

    # Calculate metrics for display.
    @total_purchased_fixed = @contracts.map(&:purchase_amount).inject(0, &:+)

    render "index"
  end

  def cancel_recurring
    @contract = Contract.find(params[:id])
    @contract.completed!

    if @contract.save
      flash[:notice] = l(:text_contract_updated)
      redirect_to :action => "show", :id => @contract.id
    else
      flash[:error] = "* " + @contract.errors.full_messages.join("</br>* ")
      redirect_to :action => "edit", :id => @contract.id
    end
  end

  def destroy
    @contract = Contract.find(params[:id])
    if @contract.destroy
      flash[:notice] = l(:text_contract_deleted)
      redirect_back_or_default url_for({ :controller => 'contracts', :action => 'index', :project_id => params[:project_id] })
    else
      redirect_to(:back)
    end
  end

  def add_time_entries
    @contract = Contract.find(params[:id])
    @project = @contract.project
    @time_entries = @contract.project.time_entries_for_all_descendant_projects.order("spent_on ASC")
  end

  def assoc_time_entries_with_contract
    @contract = Contract.find(params[:id])
    changeCount = 0
    successCount = 0
    time_entries = params[:time_entries]
    if time_entries != nil
      time_entries.each do |time_entry|
        updated_time_entry = TimeEntry.find(time_entry)
        changeCount += 1
        # We can change if the time entry has either no contract or its contract is not locked
        # and the contract we want to associate to is not locked neither.
        if ((updated_time_entry.contract.nil? || !updated_time_entry.contract.is_locked) && !@contract.is_locked)
          updated_time_entry.contract = @contract
          updated_time_entry.save
          successCount += 1
        end
      end
    end
    # Can also unassociate
    time_entries = params[:unassoc_time_entries]
    if time_entries != nil
      time_entries.each do |time_entry|
        updated_time_entry = TimeEntry.find(time_entry)
        changeCount += 1
        # We can change if the time entry has either no contract or its contract is not locked
        if (updated_time_entry.contract.nil? || !updated_time_entry.contract.is_locked)
          updated_time_entry.contract = nil
          updated_time_entry.save
          successCount += 1
        end
      end
    end

    if successCount != changeCount
      flash[:warning] = l(:text_some_contracts_are_locked)
    end

    unless @contract.nil? || @contract.hours_remaining >= 0
      flash[:error] = l(:text_hours_over_contract, :hours_over => l_hours(-1 * @contract.hours_remaining))
    end

    redirect_back_or_default url_for({ :controller => 'contracts', :action => 'show', :project_id => @contract.project.identifier, :id => @contract.id })
  end

  def lock
    @contract = Contract.find(params[:id])
    @lock = (params[:lock] == 'true')
    if @lock
      # Associate all time entries to the contract because a locked
      # contract will not receive 'smart' time entries anymore and those
      # that were 'smartly' associated must stay.
      if Setting.plugin_contracts['enable_smart_time_entries']
        @contract.smart_time_entries.each do |time_entry|
          time_entry.update_attribute(:contract, @contract)
        end
      end
      @contract.update_attribute(:is_locked, @lock)
      flash[:notice] = l(:text_contract_locked)
    else
      teCountBefore = @contract.smart_time_entries.count
      @contract.is_locked = false
      @contract.hours_worked = nil
      @contract.billable_amount_total = nil
      @contract.save!
      teCountAfter = @contract.smart_time_entries.count
      flash[:notice] = l(:text_contract_unlocked)
      if (teCountAfter != teCountBefore)
        flash[:warning] = l(:text_some_time_entries_were_added, :contract => view_context.link_to(@contract.getDisplayTitle, url_for({ :controller => 'contracts', :action => 'show', :project_id => @contract.project.identifier, :id => @contract.id })))
      end
    end

    redirect_back_or_default url_for({ :controller => 'contracts', :action => 'show', :project_id => @contract.project.identifier, :id => @contract.id })
  end

  def tooltips
    @id = params[:id]
  end


  private

  def rates_are_valid(rates)
    return true if rates.nil?
    rates.each_pair do |user_id, rate|
      if !is_number?(rate) or rate.to_f < 0
        return false
      end
    end
    return true
  end

  def load_contractors_and_rates
    @contractors = Contract.users_for_project_and_sub_projects(@project)
    @contractor_rates = {}
    @contractors.each do |contractor|
      if @contract.new_record?
        rate = @project.rate_for_user(contractor)
      else
        rate = @contract.user_contract_rate_or_default(contractor)
      end
      @contractor_rates[contractor.id] = rate
    end
    unless params[:rates].nil?
      params[:rates].each do |contractor, rate|
        @contractor_rates[contractor.to_i] = rate.to_f
      end
    end
  end

  def find_project
    #@project variable must be set before calling the authorize filter
    @project = Project.find(params[:project_id]) 
  end

  def contract_params
    params.require(:contract).permit(:description, :agreement_date, :start_date, :end_date, :contract_url,
      :invoice_url, :project_id, :purchase_amount, :hourly_rate, :category_id, :is_fixed_price, :title,
      :contract_type, :recurring_frequency)
  end

  # Allows the user to hide or show locked contracts on contract list pages
  def set_contract_visibility
    # set session variable to the boolean true and false instead of using the string parameter
    if params[:contract_list].present?
      if params[:contract_list][:show_locked_contracts] == "true"
        session[:show_locked_contracts] = true
      else
        session[:show_locked_contracts] = false
      end
      if params[:contract_list][:show_only_active_recurring] == "true"
        session[:show_only_active_recurring] = true
      else
        session[:show_only_active_recurring] = false
      end
    elsif session[:show_locked_contracts].nil?
      # set session variable for first time guests
      session[:show_locked_contracts] = false
      session[:show_only_active_recurring] = false
    end
  end

  # Helper method for determining if a string is numeric.
  def is_number? string
    true if Float(string) rescue false
  end

end
