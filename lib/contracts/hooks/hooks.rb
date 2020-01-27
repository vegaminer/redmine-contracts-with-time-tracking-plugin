module Contracts
  class ContractsHookListener < Redmine::Hook::ViewListener
  
    def view_timelog_edit_form_bottom(context={})
      return if Setting.plugin_contracts['enable_smart_time_entries']
      if context[:time_entry].project_id != nil
        @current_project = Project.find(context[:time_entry].project_id)
        @contracts = @current_project.contracts_for_all_ancestor_projects

        if !@contracts.empty?
          if context[:time_entry].contract_id != nil
            selected_contract = context[:time_entry].contract_id
          elsif !(@current_project.contracts.empty?)
            selected_contract = @current_project.contracts.maximum(:id)
          elsif !(@contracts.empty?)
            selected_contract = @contracts.max_by(&:id).id
          else
            selected_contract = ''
          end
          contract_unselectable = false
          if !selected_contract.blank?
            # There is a selected contract. Check to see if it has been locked
            selected_contract_obj = Contract.find(selected_contract)
            if selected_contract_obj.is_locked
              # Contract has been locked. Only list that contract in the drop-down
              @contracts = [selected_contract_obj]
              contract_unselectable = true
            else
              # Only show NON-locked contracts in the drop-down
              @contracts = @current_project.unlocked_contracts_for_all_ancestor_projects
            end
          else
            # There is NO selected contract. Only show NON-locked contracts in the drop-down
            @contracts = @current_project.unlocked_contracts_for_all_ancestor_projects
          end
          db_options = options_from_collection_for_select(@contracts, :id, :getDisplayTitle, selected_contract)
          no_contract_option = "<option value=''>-- #{l(:label_contract_empty)} -- </option>\n".html_safe
          if !contract_unselectable
            all_options = no_contract_option << db_options
          else
            # Contract selected has already been locked. Do not show the [Select Contract] label.
            all_options = db_options
          end
          select = context[:form].select :contract_id, all_options
          return "<p>#{select}</p>"
        end
      else
        "<p>This page will not work due to the contracts plugin. You must log time entries from within a project."
      end
    end

    # Poor Man's Cron
    def controller_account_success_authentication_after(context={})
      # for unknown reasons, some reported a problem here and it seems Setting.plugin_contracts
      # was a String.  A string is the default value for a missing setting.  Until more is known
      # simply replace by a fresh object here.
      Setting.plugin_contracts = ActionController::Parameters.new unless Setting.plugin_contracts.is_a? ActionController::Parameters
      
      # check to see if cron has ran today or if its null
      last_run = Setting.plugin_contracts[:last_cron_run]
      if last_run.nil? || last_run < Date.today
        # Get all monthly recurring contracts
        monthly_contracts = Contract.monthly
        # Loop thru the contracts and check if any have passed their recurring date
        monthly_contracts.each do |contract|
          if Date.today > (contract.start_date + 1.month)
            # Create new contract and expire the old one
            new_contract = Contract.new
            if new_contract.copy(contract)
              expire_contract(contract)
            end
          end
        end

        # Get all yearly recurring contracts
        yearly_contracts = Contract.yearly
        # Loop thru the contracts and check if any have passed their recurring date
        yearly_contracts.each do |contract|
          if Date.today > (contract.start_date + 1.year)
            # Create new contract and expire the old one
            new_contract = Contract.new
            if new_contract.copy(contract)
              expire_contract(contract)
            end
          end
        end
      end

     # Setting.plugin_contracts.update({last_cron_run: Date.today})
    end

    def expire_contract(contract)
      contract.completed!
      contract.save
    end

    render_on :view_time_entries_context_menu_end, :partial => "contracts/context_menus/assign_time_entries"
  end

  class ViewsLayoutsHook < Redmine::Hook::ViewListener
    def view_layouts_base_html_head(context={})
      return stylesheet_link_tag(:contracts, :plugin => 'contracts')
    end
  end
end
