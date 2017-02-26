class Contract < ActiveRecord::Base
  belongs_to :project
  has_many   :time_entries
  has_many   :user_contract_rates
  has_many   :contracts_expenses
  has_many   :contracts_invoices
  belongs_to :category, :class_name => 'ContractCategory'

  validates_presence_of :start_date, :purchase_amount, :hourly_rate, :project_id
  validates_uniqueness_of :project_contract_id, :scope => :project_id
  validates :project_contract_id, :numericality => { :greater_than_or_equal_to => 1, :less_than_or_equal_to => 999 }
  validates :purchase_amount, :numericality => { :greater_than_or_equal_to => 0 }
  validates :hourly_rate, :numericality => { :greater_than_or_equal_to => 0 }
  validates :end_date, :is_after_start_date => true
  before_destroy { |contract| contract.time_entries.clear }
  after_save :apply_rates
  attr_accessor :rates

  def hours_purchased
    self.purchase_amount / self.hourly_rate
  end

  def reset_cache!
    update_attributes(:hours_worked => nil, :billable_amount_total => nil)
  end

  def smart_hours_spent
    if self.is_locked
      if self.hours_worked.nil?
        self.hours_worked = hours_spent
        save!
      end
      return self.hours_worked
    end
    hours_spent
  end

  def smart_time_entries
    if Setting.plugin_contracts['enable_smart_time_entries']

      # Time entries that are assigned to the contract will obviously stay assigned.
      # Unassigned time entries that fall in the dates range of the contract will also
      # be added in.  If multiple contracts overlap, the unassigned entries will go in the
      # oldest contract.

      # We recursively get the time entries of older (lower id) contracts here.  This may get
      # slow in case many contracts overlap in a project, but since this is really expected
      # that many contracts will be ongoing with the same date ranges in the same project.  One
      # should use sub projects for such cases.

      # Retrieve older contracts
      allProjectContracts = Contract.where(:project => self.project).where('id < ?', self.id)
      # Then all the time entries that they cover.
      otherContractsTEs = allProjectContracts.collect{|contract| contract.smart_time_entries.pluck(:id) }

      # Select time entries that where either manually assigned to this contract
      # or that have no contract but falls in the dates range of this contract
      te = TimeEntry.where(:project => self.project)
      # Remove time entries assigned or 'smart' assigned to other contracts
      te = te.where("id not in (#{otherContractsTEs.join(",")})") unless otherContractsTEs.empty?
      if self.is_locked
        te = te.where("(contract_id = '#{self.id}')")
      else
        te = te.where("((contract_id = '#{self.id}') or (contract_id IS NULL and spent_on >= '#{self.start_date}'" + (self.end_date.nil? ? "" : " and spent_on <= '#{self.end_date}'") + "))")
      end
    else
      time_entries
    end
  end

  def self.contract_for_time_entry(time_entry)
    return time_entry.contract unless time_entry.contract.nil?

    # Take first contract that has proper date ranges and not locked
    time_entry.project.contracts.all.order("id asc").each do |contract|
      afterStart = time_entry.spent_on >= contract.start_date
      beforeEnd  = contract.end_date.nil? || time_entry.spent_on <= contract.start_date
      return contract if !contract.is_locked && afterStart && beforeEnd
    end
    nil
  end

  def hours_spent
    self.smart_time_entries.map(&:hours).inject(0, &:+)
  end

  def hours_spent_by_user(user)
    self.smart_time_entries.select { |entry| entry.user == user }.map(&:hours).inject(0, &:+)
  end

  def hours_spent_on_issue(issue)
    self.smart_time_entries.select { |entry| entry.issue == issue }.map(&:hours).inject(0, &:+)
  end

  def amount_spent_on_issue(issue)
    time_entries = self.smart_time_entries.select { |entry| entry.issue == issue }
    total_amount = 0
    time_entries.each do |entry|
      total_amount += entry.hours * self.user_contract_rate_or_default(entry.user)
    end
    return total_amount
  end

  def effective_rate
    if self.expenses_total >= self.purchase_amount
      0
    elsif self.smart_hours_spent >= 1
      (self.purchase_amount - self.expenses_total) / self.smart_hours_spent
    else
      self.purchase_amount - self.expenses_total
    end
  end

  def billable_amount_for_user(user)
    member_hours = self.smart_time_entries.select { |entry| entry.user == user }.map(&:hours).inject(0, &:+)
    member_rate = self.user_contract_rate_or_default(user)
    member_hours * member_rate
  end

  # IF the contract is locked
  #  - check to see if the billable amount total is pre-calculcated, if so, return it
  #  - if not, calculate and save the billable amount total, and return it
  # ELSE return the calculated billable amount total
  def smart_billable_amount_total
    if self.is_locked
      if self.billable_amount_total.nil?
        self.billable_amount_total = calculate_billable_amount_total
        save!
      end
      return self.billable_amount_total
    end
    calculate_billable_amount_total
  end

  def invoices_amount
    return self.contracts_invoices.sum(:amount)
  end

  def calculate_billable_amount_total
    members = members_with_entries
    return 0 if members.empty?
    total_billable_amount = 0
    members.each do |member|
      member_hours = self.smart_time_entries.select { |entry| entry.user_id == member.id }.map(&:hours).inject(0, &:+)
      member_rate = self.user_contract_rate_or_default(member)
      billable_amount = member_hours * member_rate
      total_billable_amount += billable_amount
    end
    total_billable_amount
  end

  def amount_remaining
    self.purchase_amount - self.smart_billable_amount_total - self.expenses_total
  end

  def hours_remaining
    self.amount_remaining / self.hourly_rate
  end

  def user_contract_rate_by_user(user)
    self.user_contract_rates.select { |ucr| ucr.user_id == user.id}.first
  end

  def rate_for_user(user)
    ucr = self.user_contract_rate_by_user(user)
    ucr.nil? ? 0.0 : ucr.rate
  end

  def set_user_contract_rate(user, rate)
    ucr = self.user_contract_rate_by_user(user)
    if ucr.nil?
      self.user_contract_rates.create!(:user_id => user.id, :rate => rate)
    else
      ucr.update_attribute(:rate, rate)
    end
  end

  def user_contract_rate_or_default(user)
    ucr = self.user_contract_rate_by_user(user)
    ucr.nil? ? self.hourly_rate : ucr.rate
  end

  # Usage:
  #   contract.rates = {"3"=>"27.00", "1"=>"35.00"}
  #  (where the hash keys are user_id's and the values are the rates)
  def rates=(rates)
    @rates = rates
  end

  def user_project_rate_or_default(user)
    upr = self.project.user_project_rate_by_user(user)
    upr.nil? ? self.hourly_rate : upr.rate
  end

  def members_with_entries
    return [] if self.smart_time_entries.empty?
    uniq_user_ids = self.smart_time_entries.collect { |entry| entry.user_id }.uniq
    return [] if uniq_user_ids.nil?
    User.find(uniq_user_ids)
  end

  def self.users_for_project_and_sub_projects(project)
    users = []
    users += project.users
    users += Contract.users_for_sub_projects(project)
    users.flatten!
    users.uniq
  end

  def self.users_for_sub_projects(project)
    users = []
    sub_projects = Project.where(:parent_id => project.id)
    sub_projects.each do |sub_project|
      subs = Project.where(:parent_id => sub_project.id)
      if !subs.empty?
        users << Contract.users_for_sub_projects(sub_project)
      end
      users << sub_project.users
    end
    users.uniq
  end

  def expenses_total
    expenses_sum = self.contracts_expenses.map(&:amount).inject(0, &:+)
  end

  def title
    return self[:title] if self[:title].present? || self.id.nil?
    if self.category_id.blank?
      category = 'Contract'
    else
      category = ContractCategory.find(self.category_id).name
    end
    Project.find(self.project_id).identifier + "_" + category + "#" + ("%03d" % (self.project_contract_id))
  end

  private

  def apply_rates
    return unless @rates
    @rates.each_pair do |user_id, rate|
      user = User.find(user_id)
      self.project.set_user_rate(user, rate)
      self.set_user_contract_rate(user, rate)
    end
  end

  def remove_contract_id_from_associated_time_entries
    self.time_entries.each do |time_entry|
      time_entry.contract_id = nil
      time_entry.save
    end
  end
end
